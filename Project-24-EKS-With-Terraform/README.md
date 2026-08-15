# Project 24: Building EKS with Terraform and Deploying Jenkins with Helm

## Table of contents

- [Overview](#overview)
- [Tools and versions](#tools-and-versions)
- [Prerequisites](#prerequisites)
- [Step 1: S3 bucket for remote state](#step-1-s3-bucket-for-remote-state)
- [Step 2: backend.tf](#step-2-backendtf)
- [Step 3: network.tf](#step-3-networktf)
- [Step 4: variables.tf, first pass](#step-4-variablestf-first-pass)
- [Step 5: data.tf](#step-5-datatf)
- [Step 6: eks.tf](#step-6-ekstf)
- [Step 7: locals.tf](#step-7-localstf)
- [Step 8: variables.tf, remaining variables](#step-8-variablestf-remaining-variables)
- [Step 9: variables.tfvars](#step-9-variablestfvars)
- [Step 10: provider.tf](#step-10-providertf)
- [Step 11 to 12: init and plan](#step-11-to-12-init-and-plan)
- [Step 13: apply, and the expected first failure](#step-13-apply-and-the-expected-first-failure)
- [Step 14: fixing the aws-auth ConfigMap failure](#step-14-fixing-the-aws-auth-configmap-failure)
- [Step 15: generating the kubeconfig](#step-15-generating-the-kubeconfig)
- [The EBS CSI driver gap](#the-ebs-csi-driver-gap)
- [The missing default StorageClass](#the-missing-default-storageclass)
- [Step 16: Helm chart concept](#step-16-helm-chart-concept)
- [Step 17 to 18: installing and verifying Helm](#step-17-to-18-installing-and-verifying-helm)
- [Step 19 to 21: installing Jenkins](#step-19-to-21-installing-jenkins)
- [Step 22 to 23: checking pods](#step-22-to-23-checking-pods)
- [Step 24: reading logs from a multi-container pod](#step-24-reading-logs-from-a-multi-container-pod)
- [Step 25 to 28: krew, konfig, and merging kubeconfigs](#step-25-to-28-krew-konfig-and-merging-kubeconfigs)
- [Step 29 to 30: confirming the merged context works](#step-29-to-30-confirming-the-merged-context-works)
- [Step 31 to 32: retrieving the admin password and logging in](#step-31-to-32-retrieving-the-admin-password-and-logging-in)
- [Cleanup](#cleanup)
- [Conclusion](#conclusion)

## Overview

This project provisions an Amazon EKS cluster with Terraform, using a self-managed node group and IAM-based cluster access, then deploys Jenkins onto it with Helm.

## Tools and versions

Terraform 1.9 or later, AWS provider `~> 5.0`, EKS module `~> 19.0`, cluster version 1.32, kubectl matching 1.32.x, and Helm 3 latest.

## Prerequisites

AWS CLI configured with credentials able to create VPCs, EC2 instances, IAM roles, and EKS clusters. Terraform 1.9 or later. kubectl matching the cluster's Kubernetes minor version. Helm 3.

## Step 1: S3 bucket for remote state

```bash
aws s3api create-bucket \
  --bucket lydiah-eks-terraform-state \
  --region us-west-1 \
  --create-bucket-configuration LocationConstraint=us-west-1

aws s3api put-bucket-versioning \
  --bucket lydiah-eks-terraform-state \
  --versioning-configuration Status=Enabled
```
<img width="1366" height="587" alt="eks" src="https://github.com/user-attachments/assets/0041c769-1bc7-486c-a494-d7f6c2ecfe70" />


A DynamoDB lock table is not used here. Terraform's S3 backend supports native state locking directly (`use_lockfile`), which removes the need for a separate DynamoDB table for this purpose.

## Step 2: backend.tf

Configures the S3 backend and pins the required provider versions.

```hcl
terraform {
  required_version = "~> 1.11"   # use_lockfile needs 1.11+ to be GA

  backend "s3" {
    bucket       = "lydiah-eks-terraform-state"
    key          = "eks/terraform.tfstate"
    region       = "us-west-1"
    use_lockfile = true    # native S3 state locking, no DynamoDB table needed
    encrypt      = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
  }
}
```

## Step 3: network.tf

Creates the VPC using the official `terraform-aws-modules/vpc/aws` module, with subnets computed per availability zone and tagged for EKS discovery.

```hcl
resource "aws_eip" "nat_gw_elastic_ip" {
  domain = "vpc"

  tags = {
    Name            = "${var.cluster_name}-nat-eip"
    iac_environment = var.iac_environment_tag
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.name_prefix}-vpc"
  cidr = var.main_network_block
  azs  = data.aws_availability_zones.available_azs.names

  private_subnets = [
    for zone_id in data.aws_availability_zones.available_azs.zone_ids :
    cidrsubnet(var.main_network_block, var.subnet_prefix_extension, tonumber(substr(zone_id, length(zone_id) - 1, 1)) - 1)
  ]

  public_subnets = [
    for zone_id in data.aws_availability_zones.available_azs.zone_ids :
    cidrsubnet(var.main_network_block, var.subnet_prefix_extension, tonumber(substr(zone_id, length(zone_id) - 1, 1)) + var.zone_offset - 1)
  ]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false
  enable_dns_hostnames   = true
  reuse_nat_ips          = true
  external_nat_ip_ids    = [aws_eip.nat_gw_elastic_ip.id]

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    iac_environment                             = var.iac_environment_tag
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
    iac_environment                             = var.iac_environment_tag
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
    iac_environment                             = var.iac_environment_tag
  }
}
```

## Step 4: variables.tf, first pass

```hcl
variable "cluster_name" {
  type        = string
  description = "EKS cluster name."
}

variable "iac_environment_tag" {
  type        = string
  description = "AWS tag to indicate environment name of each infrastructure object."
}

variable "name_prefix" {
  type        = string
  description = "Prefix to be used on each infrastructure object Name created in AWS."
}

variable "main_network_block" {
  type        = string
  description = "Base CIDR block to be used in our VPC."
}

variable "subnet_prefix_extension" {
  type        = number
  description = "CIDR block bits extension to calculate CIDR blocks of each subnetwork."
}

variable "zone_offset" {
  type        = number
  description = "CIDR block bits extension offset to calculate Public subnets, avoiding collisions with Private subnets."
}
```

## Step 5: data.tf

At this stage, only the availability zones and caller identity are needed. The cluster connection data sources are added later, in the Step 14 fix.

```hcl
data "aws_availability_zones" "available_azs" {
  state = "available"
}

data "aws_caller_identity" "current" {}
```

## Step 6: eks.tf

```hcl
module "eks_cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.32"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  enable_irsa = true

  self_managed_node_group_defaults = {
    instance_type                          = var.asg_instance_types[0].instance_type
    update_launch_template_default_version = true
  }

  self_managed_node_groups = local.self_managed_node_groups

  create_aws_auth_configmap = true
  manage_aws_auth_configmap = true
  aws_auth_users            = concat(local.admin_user_map_users, local.developer_user_map_users)

  tags = {
    Environment = "prod"
    Terraform   = "true"
  }
}
```

## Step 7: locals.tf

Builds the admin and developer IAM user lists in the shape the EKS module expects, and defines the self-managed node group with a mixed spot instance policy.

```hcl
locals {
  admin_user_map_users = [
    for admin_user in var.admin_users :
    {
      userarn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${admin_user}"
      username = admin_user
      groups   = ["system:masters"]
    }
  ]

  developer_user_map_users = [
    for developer_user in var.developer_users :
    {
      userarn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${developer_user}"
      username = developer_user
      groups   = ["${var.name_prefix}-developers"]
    }
  ]

  self_managed_node_groups = {
    worker_group1 = {
      name = "${var.cluster_name}-wg"

      min_size     = var.autoscaling_minimum_size_by_az * length(data.aws_availability_zones.available_azs.zone_ids)
      desired_size = var.autoscaling_minimum_size_by_az * length(data.aws_availability_zones.available_azs.zone_ids)
      max_size     = var.autoscaling_maximum_size_by_az * length(data.aws_availability_zones.available_azs.zone_ids)

      instance_type = var.asg_instance_types[0].instance_type

      bootstrap_extra_args = "--kubelet-extra-args '--node-labels=node.kubernetes.io/lifecycle=spot'"

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            delete_on_termination = true
            encrypted              = false
            volume_size            = 10
            volume_type             = "gp2"
          }
        }
      }

      use_mixed_instances_policy = true
      mixed_instances_policy = {
        instances_distribution = {
          spot_instance_pools = 4
        }
        override = var.asg_instance_types
      }
    }
  }
}
```

## Step 8: variables.tf, remaining variables

Appended to the same file from Step 4.

```hcl
variable "admin_users" {
  type        = list(string)
  description = "List of Kubernetes admins."
}

variable "developer_users" {
  type        = list(string)
  description = "List of Kubernetes developers."
}

variable "asg_instance_types" {
  description = "List of EC2 instance machine types to be used in EKS."
}

variable "autoscaling_minimum_size_by_az" {
  type        = number
  description = "Minimum number of EC2 instances to autoscale our EKS cluster on each AZ."
}

variable "autoscaling_maximum_size_by_az" {
  type        = number
  description = "Maximum number of EC2 instances to autoscale our EKS cluster on each AZ."
}
```

## Step 9: variables.tfvars

The real values used, kept out of version control since `admin_users` and `developer_users` must reference IAM usernames that actually exist in the AWS account. A sanitized `variables.tfvars.example` is committed instead.

```hcl
cluster_name            = "lydiah-eks-cluster"
iac_environment_tag     = "development"
name_prefix             = "lydiah-eks"
main_network_block      = "10.0.0.0/16"
subnet_prefix_extension = 4
zone_offset             = 8

admin_users     = ["lydiah"]
developer_users = ["devuser1"]

asg_instance_types = [
  { instance_type = "t3.small" },
  { instance_type = "t2.small" },
]

autoscaling_minimum_size_by_az = 1
autoscaling_maximum_size_by_az = 2
```

The maximum autoscaling size was set to 2 per availability zone rather than the higher value in the original material, since this is a learning cluster running on spot instances and does not need to scale to that many nodes.

## Step 10: provider.tf

```hcl
provider "aws" {
  region = "us-west-1"
}

provider "random" {
}
```

The Kubernetes provider block is added later, in Step 14, once the cluster's connection data exists to configure it from.

## Step 11 to 12: init and plan

```bash
terraform init
terraform plan -var-file="variables.tfvars"
```

## Step 13: apply, and the expected first failure

```bash
terraform apply -var-file="variables.tfvars"
```

The VPC, the EKS cluster, and the self-managed node group all create successfully. The apply then fails on the aws-auth ConfigMap:

```
Error: Post "http://localhost/api/v1/namespaces/kube-system/configmaps": dial tcp [::1]:80: connectex: No connection could be made because the target machine actively refused it.
```

This happens because the Kubernetes provider has no connection details configured yet, so it defaults to `localhost`.
<img width="1366" height="768" alt="furst error" src="https://github.com/user-attachments/assets/30a822fd-d0dc-4382-b94c-2d2d72bcd0a3" />


## Step 14: fixing the aws-auth ConfigMap failure

Two data sources are added to `data.tf`, to read the cluster's endpoint and authentication token. The first attempt referenced `module.eks_cluster.cluster_id`, which produced this error on apply:

```
Error: Missing required argument

  with data.aws_eks_cluster.cluster,
  on data.tf line 10, in data "aws_eks_cluster" "cluster":
  10:   name = module.eks_cluster.cluster_id

The argument "name" is required, but no definition was found.
```
<img width="1366" height="768" alt="4" src="https://github.com/user-attachments/assets/e7fd511e-101e-4a46-b8a1-79ff076b4606" />


Switching the reference to `module.eks_cluster.cluster_name` resolved it:

```hcl
data "aws_eks_cluster" "cluster" {
  name = module.eks_cluster.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks_cluster.cluster_name
}
```

The Kubernetes provider is then configured in `provider.tf` using that data:

```hcl
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}
```

```bash
terraform init
terraform plan -var-file="variables.tfvars"
terraform apply -var-file="variables.tfvars"
```

This creates the aws-auth ConfigMap successfully, since the cluster already exists in state from the first apply.
<img width="1366" height="768" alt="worked after the error" src="https://github.com/user-attachments/assets/50096bb3-3a4f-47a1-a5f2-e55499b4eddd" />

## Step 15: generating the kubeconfig

```bash
aws eks update-kubeconfig --name lydiah-eks-cluster --region us-west-1
kubectl config current-context
kubectl get nodes
```

Both worker nodes should show `STATUS: Ready`.
<img width="1366" height="768" alt="first kubectl get nodes" src="https://github.com/user-attachments/assets/dd17bfc7-bf62-43f4-b14e-cacd3ae418c8" />


## The EBS CSI driver gap

This was not part of the original material. Deploying Jenkins later requires a PersistentVolumeClaim, which stayed `Pending` with the event `pod has unbound immediate PersistentVolumeClaims`. Self-managed node groups do not include the EBS CSI driver, and the in-tree `kubernetes.io/aws-ebs` provisioner no longer provisions anything without it, since Kubernetes 1.23.

The fix required enabling IRSA on the cluster (already included in `eks.tf` above) and adding a new file, `ebs-csi-driver.tf`, containing an IAM role scoped to the CSI driver's service account and the addon itself:

```hcl
module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name             = "${var.cluster_name}-ebs-csi-driver"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn                = module.eks_cluster.oidc_provider_arn
      namespace_service_accounts  = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = module.eks_cluster.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [module.eks_cluster]
}
```

```bash
terraform init
terraform plan -var-file="variables.tfvars"
terraform apply -var-file="variables.tfvars"
kubectl get pods -n kube-system | grep ebs-csi
```

## The missing default StorageClass

Even with the CSI driver running, the PVC stayed pending with a different event: `no persistent volumes available for this claim and no storage class is set`. The cluster's existing `gp2` StorageClass, from the legacy in-tree provisioner, was never marked as the default, so PVCs created without an explicit storage class name have nothing to bind to.

A new file, `storageclass.tf`, defines a StorageClass on the current `ebs.csi.aws.com` provisioner and marks it default:

```hcl
resource "kubernetes_storage_class" "ebs_gp3_default" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner = "ebs.csi.aws.com"
  volume_binding_mode = "WaitForFirstConsumer"
  reclaim_policy      = "Delete"

  parameters = {
    type      = "gp3"
    encrypted = "true"
  }

  depends_on = [aws_eks_addon.ebs_csi_driver]
}
```

Because a PVC's storage class is set once at creation and cannot be patched afterward, the PVC and pod that were already stuck had to be deleted so the StatefulSet could recreate them against the new default:

```bash
terraform apply -var-file="variables.tfvars"
kubectl delete pod my-jenkins-0 --namespace jenkins-namespace
kubectl delete pvc my-jenkins --namespace jenkins-namespace
kubectl get pvc --namespace jenkins-namespace
kubectl get pods --namespace jenkins-namespace
```

The PVC then shows `STATUS: Bound` against the `gp3` class, and the pod reaches `2/2 Running`.
<img width="1366" height="768" alt="kubectl reading from kubeconfig" src="https://github.com/user-attachments/assets/2942532b-d1a1-4429-92f3-d99aabb5e2cf" />


## Step 16: Helm chart concept

A Helm chart packages a set of Kubernetes manifest templates together with a values file. Installing a chart renders those templates with the given values and applies the result as one unit, tracked as a release, which can later be upgraded, rolled back, or removed as a whole rather than by hunting down individual manifests.

## Step 17 to 18: installing and verifying Helm

```bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
helm version --short
```

## Step 19 to 21: installing Jenkins

```bash
helm repo add jenkinsci https://charts.jenkins.io
helm repo update
kubectl create namespace jenkins-namespace
helm install my-jenkins jenkinsci/jenkins --namespace jenkins-namespace
helm ls --namespace jenkins-namespace
```

Jenkins is installed into a dedicated `jenkins-namespace` namespace rather than the default namespace, for isolation from other workloads on the cluster.

## Step 22 to 23: checking pods

```bash
kubectl get pods --namespace jenkins-namespace
kubectl describe pod my-jenkins-0 --namespace jenkins-namespace
```

The pod runs two containers, `jenkins` and `config-reload`, plus two init containers.
<img width="1366" height="768" alt="jenkins running" src="https://github.com/user-attachments/assets/0c66a41b-952f-4bb3-aa97-8d88c1646591" />


## Step 24: reading logs from a multi-container pod

```bash
kubectl logs my-jenkins-0 --namespace jenkins-namespace
```

The pod runs more than one container, so kubectl needs to know which one to read from. It defaults to `jenkins` automatically and prints which one it picked:

```
Defaulted container "jenkins" out of: jenkins, config-reload, config-reload-init (init), init (init)
```

To read a different container's logs explicitly:

```bash
kubectl logs my-jenkins-0 --namespace jenkins-namespace -c config-reload
```

## Step 25 to 28: krew, konfig, and merging kubeconfigs

```bash
(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
)
echo 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
kubectl krew install konfig
```

A separate kubeconfig file is generated and merged into the default one, to demonstrate the konfig workflow:

```bash
aws eks update-kubeconfig --name lydiah-eks-cluster --region us-west-1 --kubeconfig ./eks-kubeconfig
kubectl konfig import --save ./eks-kubeconfig
```
<img width="1366" height="768" alt="kubectl reading from kubeconfig" src="https://github.com/user-attachments/assets/d68101c0-18ba-439e-9b64-99bfb8dc6b43" />


## Step 29 to 30: confirming the merged context works

```bash
kubectl config get-contexts
kubectl config use-context arn:aws:eks:us-west-1:835960997504:cluster/lydiah-eks-cluster
kubectl get pods --namespace jenkins-namespace
kubectl config current-context
```

## Step 31 to 32: retrieving the admin password and logging in

```bash
kubectl exec --namespace jenkins-namespace -it svc/my-jenkins -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password && echo
kubectl --namespace jenkins-namespace port-forward svc/my-jenkins 8080:8080
```

With the port-forward running, the UI is reached at `http://127.0.0.1:8080` and logged into with username `admin` and the retrieved password.
<img width="1366" height="768" alt="jenk log" src="https://github.com/user-attachments/assets/a2ee5717-13a4-40e5-acd8-2fb69b572cef" />


## Cleanup

Jenkins and its volume are removed before the cluster, so the underlying EBS volume is not orphaned:

```bash
helm uninstall my-jenkins --namespace jenkins-namespace
kubectl delete pvc my-jenkins --namespace jenkins-namespace
kubectl delete namespace jenkins-namespace
```

```bash
terraform destroy -var-file="variables.tfvars"
```

Verification that nothing billable remains:

```bash
aws eks list-clusters --region us-west-1
aws ec2 describe-instances --region us-west-1 --filters "Name=tag:Name,Values=*lydiah-eks*" --query "Reservations[].Instances[].State.Name"
aws ec2 describe-nat-gateways --region us-west-1 --filter "Name=state,Values=available"
aws ec2 describe-addresses --region us-west-1
aws ec2 describe-volumes --region us-west-1 --filters "Name=status,Values=available"
```

`terraform destroy` does not remove the S3 bucket backing the remote state, since the backend cannot delete the location storing its own state. This can be removed separately:

```bash
aws s3api delete-objects --bucket lydiah-eks-terraform-state \
  --delete "$(aws s3api list-object-versions --bucket lydiah-eks-terraform-state \
  --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json)"

aws s3api delete-objects --bucket lydiah-eks-terraform-state \
  --delete "$(aws s3api list-object-versions --bucket lydiah-eks-terraform-state \
  --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' --output json)"

aws s3api delete-bucket --bucket lydiah-eks-terraform-state --region us-west-1
```

The bucket has versioning enabled, so a plain `aws s3 rm --recursive` is not sufficient to empty it; the object versions and delete markers left behind have to be removed explicitly before the bucket itself can be deleted.

## Problems encountered during a fresh rebuild

### Terraform tried to read the EKS cluster before creating it

The original configuration used `data.aws_eks_cluster.cluster` to configure the Kubernetes provider. During a fresh apply, Terraform attempted to read `lydiah-eks-cluster` through the AWS API before the cluster had been created. The apply failed with:

```text
Error: reading EKS Cluster (lydiah-eks-cluster): couldn't find resource
```

Adding `depends_on = [module.eks_cluster]` to the data source caused a dependency cycle. The EKS module used the Kubernetes provider to manage resources inside the cluster, while the provider depended on a data source waiting for the entire module.

I removed `data.aws_eks_cluster.cluster` and configured the Kubernetes provider with outputs from the EKS module:

```hcl
provider "kubernetes" {
  host                   = module.eks_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}
```

These outputs depend on the actual EKS cluster resource, so Terraform waits until the endpoint and certificate data exist.

### Self-managed EC2 instances did not join the cluster

The Auto Scaling Group launched two healthy `t3.large` instances, but `kubectl get nodes` returned:

```text
No resources found
```

The EKS control plane was active, but the `aws-auth` ConfigMap did not exist. Both of these settings were disabled in the EKS module:

```hcl
create_aws_auth_configmap = false
manage_aws_auth_configmap = false
```

I changed both values to `true`. Terraform created `aws-auth` and mapped the self-managed node IAM role to the `system:bootstrappers` and `system:nodes` groups. Both instances then joined the cluster and became `Ready`.

### The EBS CSI add-on became degraded

The EBS CSI add-on timed out in the `DEGRADED` state with this health issue:

```text
InsufficientNumberOfReplicas
The add-on is unhealthy because all deployments have all pods unscheduled no nodes available to schedule pods
```

The add-on was not the root problem. Its pods could not run because the self-managed instances had not been authorized to join the cluster.

After fixing `aws-auth`, I ran Terraform again. The add-on became `ACTIVE`, its controller and node pods started successfully, and the `gp3` storage class was created.

### The original worker nodes were too small for Artifactory

The original node group used `t3.small` and `t2.small` instances. The EKS cluster could run on them, but Artifactory could not. Its pods remained in `Pending` and initialization states while the nodes experienced memory pressure and heavy memory overcommit.

I changed the mixed instance types to `t3.large` and `t3a.large`. The two larger nodes provided enough capacity for Artifactory, PostgreSQL, the Nginx Ingress Controller, and the Kubernetes system workloads.


## Conclusion

Provisioning the cluster surfaced a real error at the aws-auth ConfigMap step, caused by the Kubernetes provider having no connection details until the cluster's own data was read back into it, and a second error from referencing the wrong module output for the cluster name. Deploying Jenkins surfaced two further gaps: the EBS CSI driver not being installed on the self-managed node group, and no StorageClass marked as default, both of which left the PersistentVolumeClaim stuck pending until diagnosed from the `kubectl describe` output and fixed directly in Terraform.
