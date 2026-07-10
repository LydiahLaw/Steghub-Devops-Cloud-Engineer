# Project 24: Building EKS with Terraform and Deploying Jenkins with Helm

## Table of contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Part A: provisioning EKS with Terraform](#part-a-provisioning-eks-with-terraform)
- [Part B: deploying Jenkins with Helm](#part-b-deploying-jenkins-with-helm)
- [Issues encountered and fixes](#issues-encountered-and-fixes)
- [Cleanup](#cleanup)
- [Conclusion](#conclusion)

## Overview

This project provisions an Amazon EKS cluster using Terraform, with a self-managed node group, VPC networking, and IAM-based cluster access. Jenkins is then deployed onto the cluster using Helm, with kubectl and Helm configured to communicate with the cluster through a merged kubeconfig.

The project follows the StegHub Project 24 curriculum, updated to current tool versions where the original material referenced deprecated commands or module versions.

## Architecture

The cluster runs in a dedicated VPC with public and private subnets across the region's availability zones. A single NAT gateway routes egress traffic from private subnets, where the worker nodes live. The EKS control plane is managed by AWS; the data plane is a self-managed Auto Scaling group of EC2 instances using a mixed spot instance policy.

Jenkins runs as a StatefulSet in its own namespace, backed by a PersistentVolumeClaim provisioned through the AWS EBS CSI driver.

## Prerequisites

- AWS CLI configured with credentials that have permissions to create VPCs, EC2 instances, IAM roles, and EKS clusters
- Terraform 1.9 or later
- kubectl matching the cluster's Kubernetes minor version
- Helm 3

## Part A: provisioning EKS with Terraform

The Terraform configuration is split across the following files:

- `backend.tf` configures remote state storage in S3 with DynamoDB locking
- `provider.tf` declares the AWS, random, and Kubernetes providers
- `network.tf` creates a VPC with public and private subnets tagged for EKS discovery, plus a NAT gateway backed by a reserved Elastic IP
- `variables.tf` and `variables.tfvars` hold the input variables and their values
- `data.tf` reads the account's available availability zones and caller identity, and the created cluster's connection details
- `locals.tf` builds the IAM user mappings for cluster access and the self-managed node group definition
- `eks.tf` defines the EKS cluster module itself

Provisioning proceeds in two applies. The first creates the VPC, the cluster, and the self-managed node group. Because the Kubernetes provider depends on data read from the cluster that does not yet exist, this first apply fails on the aws-auth ConfigMap step with a connection-refused error. The second apply, after the cluster's connection data is available in state, completes the ConfigMap creation and finishes cleanly.

Once the cluster is up, a kubeconfig is generated with:

```bash
aws eks update-kubeconfig --name lydiah-eks-cluster --region us-west-1
```

## Part B: deploying Jenkins with Helm

Helm is installed using the official install script rather than building from source. The Jenkins chart is added from the official Jenkins Helm repository and installed into a dedicated `jenkins-namespace` namespace:

```bash
helm repo add jenkinsci https://charts.jenkins.io
helm repo update
kubectl create namespace jenkins-namespace
helm install my-jenkins jenkinsci/jenkins --namespace jenkins-namespace
```

The `krew` plugin manager and its `konfig` plugin are used to demonstrate merging a separately generated kubeconfig into the default one, which is a common need when working across multiple clusters.

The Jenkins admin password is retrieved with:

```bash
kubectl exec --namespace jenkins-namespace -it svc/my-jenkins -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password && echo
```

The UI is reached by port-forwarding the service:

```bash
kubectl --namespace jenkins-namespace port-forward svc/my-jenkins 8080:8080
```

## Issues encountered and fixes

Several issues came up that were specific to running current tool versions rather than the versions the original material referenced.

The EKS module's `cluster_id` output stopped returning the cluster name from module version 19 onward. Any reference to it had to be changed to the `cluster_name` output instead.

Self-managed node groups do not come with the EBS CSI driver installed. Without it, the legacy `kubernetes.io/aws-ebs` in-tree provisioner cannot provision volumes, and any PersistentVolumeClaim depending on it stays pending indefinitely. The fix required enabling IRSA on the cluster module, creating an IAM role scoped to the CSI driver's service account through the `iam-role-for-service-accounts-eks` submodule, and installing `aws-ebs-csi-driver` as an EKS-managed addon.

Even with the CSI driver running, the Jenkins PersistentVolumeClaim stayed pending because no StorageClass was marked as the cluster's default. A new StorageClass on the modern `ebs.csi.aws.com` provisioner was created and marked default. Because a PVC's storage class is set once at creation and cannot be patched afterward, the existing PVC and pod had to be deleted so the StatefulSet could recreate them against the new default.

Running `kubectl logs` against the Jenkins pod no longer requires the `-c` flag to select a container, since current versions of kubectl read the pod's default-container annotation and select it automatically.

## Cleanup

Since this cluster carries hourly charges for the EKS control plane and worker nodes, it should not be left running. Jenkins and its volume are removed first so the underlying EBS volume is not orphaned when the cluster is destroyed:

```bash
helm uninstall my-jenkins --namespace jenkins-namespace
kubectl delete pvc my-jenkins --namespace jenkins-namespace
kubectl delete namespace jenkins-namespace
terraform destroy -var-file="variables.tfvars"
```

The S3 bucket and DynamoDB table used for Terraform state are not removed by `terraform destroy`, since the backend cannot delete the location storing its own state. These can be removed separately once the destroy is confirmed complete, or left in place for future use given their negligible cost.

## Conclusion

This project provided hands-on practice with the parts of running EKS that tutorials tend to skip over once they age: module output names changing between versions, add-ons that are not installed by default, and storage classes that require explicit configuration rather than working out of the box. Diagnosing each of these from the actual error output, rather than assuming the original material's steps would apply unchanged, was as much a part of the exercise as the deployment itself.
