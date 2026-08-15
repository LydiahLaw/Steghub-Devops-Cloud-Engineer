# Deploying and packaging applications into Kubernetes with Helm

This project documents how I deployed JFrog Artifactory into an Amazon EKS cluster using Helm, exposed it through the Nginx Ingress Controller, and connected it to a custom domain using Amazon Route 53.

Artifactory will serve as a private repository for Docker images and Helm charts. The goal is to provide a controlled location where artifacts can be stored and reviewed before they are deployed into an environment.

## Table of contents

- [Project objectives](#project-objectives)
- [Environment](#environment)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Preparing the EKS cluster](#preparing-the-eks-cluster)
- [Deploying Artifactory with Helm](#deploying-artifactory-with-helm)
- [Checking the Artifactory deployment](#checking-the-artifactory-deployment)
- [Installing the Nginx Ingress Controller](#installing-the-nginx-ingress-controller)
- [Completing the Helm repository challenge](#completing-the-helm-repository-challenge)
- [Creating the Artifactory Ingress](#creating-the-artifactory-ingress)
- [Configuring Route 53](#configuring-route-53)
- [Completing the Artifactory setup](#completing-the-artifactory-setup)
- [Problems encountered and how I fixed them](#problems-encountered-and-how-i-fixed-them)
- [Verification](#verification)
- [Project files](#project-files)
- [Cleanup](#cleanup)
- [What I learned](#what-i-learned)

## Project objectives

The objectives were to:

- Deploy JFrog Artifactory into Kubernetes using an official Helm chart.
- Keep the DevOps tools in a dedicated `tools` namespace.
- Use persistent EBS volumes for Artifactory and PostgreSQL data.
- Install the Nginx Ingress Controller using Helm.
- Route external requests to Artifactory through a Kubernetes Ingress.
- Create a Route 53 record for `tooling.artifactory.lydiahnganga.cloud`.
- Access Artifactory through the custom domain.
- Reset the administrator password and activate a self-hosted trial licence.
- Set the Artifactory Base URL to the custom domain.

## Environment

| Component | Configuration |
|---|---|
| Local environment | Windows with Ubuntu on WSL |
| Cloud provider | AWS |
| AWS region | `us-west-1` |
| Kubernetes service | Amazon EKS |
| Cluster name | `lydiah-eks-cluster` |
| Worker nodes | Two `t3.large` self-managed nodes |
| Package manager | Helm |
| Artifactory chart | `jfrog/artifactory` version `107.161.15` |
| Artifactory version | `7.161.15` |
| Ingress chart | `ingress-nginx/ingress-nginx` version `4.15.1` |
| Ingress Controller | Nginx `1.15.1` |
| Storage class | `gp3` using `ebs.csi.aws.com` |
| Domain | `tooling.artifactory.lydiahnganga.cloud` |

## Architecture

Requests follow this route:

```text
User
  -> Route 53 CNAME record
  -> AWS Load Balancer
  -> Nginx Ingress Controller
  -> Artifactory Ingress rule
  -> artifactory-artifactory-nginx service
  -> JFrog Artifactory
```

Artifactory and its bundled PostgreSQL database use EBS volumes provisioned through the EBS CSI driver and the default `gp3` storage class.

## Prerequisites

The following tools were installed and configured in WSL:

```bash
aws --version
kubectl version --client
helm version
terraform version
```

The EKS cluster was provisioned in Project 24 using Terraform. I confirmed that `kubectl` was connected to the correct cluster:

```bash
kubectl config current-context
```

I also confirmed that both worker nodes were ready:

```bash
kubectl get nodes -o wide
```

## Preparing the EKS cluster

Before installing Artifactory, I verified that the EBS CSI add-on was active:

```bash
aws eks describe-addon \
  --cluster-name lydiah-eks-cluster \
  --addon-name aws-ebs-csi-driver \
  --region us-west-1 \
  --query 'addon.{Status:status,Health:health.issues}' \
  --output json
```

The healthy response was:

```json
{
  "Status": "ACTIVE",
  "Health": []
}
```

I checked the EBS CSI pods:

```bash
kubectl get pods -n kube-system | grep ebs-csi
```

I then verified the available storage classes:

```bash
kubectl get storageclass
```

The `gp3` class used `ebs.csi.aws.com`, allowed volume expansion, and was marked as the default storage class.


## Deploying Artifactory with Helm

The JFrog repository was already configured locally, so I confirmed it with:

```bash
helm repo list
```

I created the namespace for the DevOps tools:

```bash
kubectl create namespace tools
kubectl get namespace tools
```

I updated the Helm repository indexes:

```bash
helm repo update
```

Before installation, I confirmed that the required chart version was available:

```bash
helm search repo jfrog/artifactory \
  --versions | grep '107.161.15'
```

Artifactory requires a master key and a join key. I generated both values without printing them:

```bash
export MASTER_KEY=$(openssl rand -hex 32)
export JOIN_KEY=$(openssl rand -hex 32)

echo "MASTER_KEY length: ${#MASTER_KEY}"
echo "JOIN_KEY length: ${#JOIN_KEY}"
```

Both keys contained 64 characters. I did not store the actual values in Git.

I installed Artifactory using `helm upgrade --install`. This command installs the release when it does not exist and upgrades it when it already exists:

```bash
helm upgrade --install artifactory jfrog/artifactory \
  --version 107.161.15 \
  --namespace tools \
  --set-string global.masterKey="${MASTER_KEY}" \
  --set-string global.joinKey="${JOIN_KEY}" \
  --set nginx.generateSelfSignedCert=true
```

<img width="1366" height="768" alt="installed artifactory" src="https://github.com/user-attachments/assets/fc8bcea7-ad48-4d54-833b-bcef80c93a82" />

## Checking the Artifactory deployment

I confirmed the Helm release:

```bash
helm list -n tools
```

I checked the pods, services, and persistent volume claims:

```bash
kubectl get pods,svc,pvc -n tools
```

The deployment created:

- The main Artifactory pod.
- Artifactory frontend, event, metadata, and bus services.
- An Nginx proxy for Artifactory.
- A bundled PostgreSQL database.
- A 20 GiB `gp3` volume for Artifactory.
- A 200 GiB `gp3` volume for PostgreSQL.

I waited for all pods to become ready:

```bash
kubectl wait \
  --namespace tools \
  --for=condition=Ready pod \
  --all \
  --timeout=15m
```

The final check showed every pod running and every container ready:

```bash
kubectl get pods -n tools
```

<img width="1366" height="768" alt="ingress controller" src="https://github.com/user-attachments/assets/b8b2b020-bdad-4ba6-9f15-3aec93bad4d3" />

## Installing the Nginx Ingress Controller

I first installed the controller using the repository URL directly, as shown in the project instructions:

```bash
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace
```

I waited for the controller pod:

```bash
kubectl wait \
  --namespace ingress-nginx \
  --for=condition=Ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

I verified the service and IngressClass:

```bash
kubectl get service -n ingress-nginx
kubectl get ingressclass
```

The `ingress-nginx-controller` service received an external AWS Load Balancer hostname, and the controller created the `nginx` IngressClass.

## Completing the Helm repository challenge

The project included a challenge to uninstall the first release and reinstall it without the `--repo` option.

I removed the release:

```bash
helm uninstall ingress-nginx -n ingress-nginx
```

I added the repository separately and updated the local index:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
```

I reinstalled the controller using the repository name and chart name:

```bash
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx
```

I verified the new release:

```bash
helm list -n ingress-nginx
kubectl get pods,service -n ingress-nginx
kubectl get ingressclass
```


## Creating the Artifactory Ingress

I created `manifests/artifactory-ingress.yaml` with the following configuration:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: artifactory-ingress
  namespace: tools
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
    service.beta.kubernetes.io/aws-load-balancer-type: nlb
    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: tcp
  labels:
    name: artifactory
spec:
  ingressClassName: nginx
  rules:
    - host: tooling.artifactory.lydiahnganga.cloud
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: artifactory-artifactory-nginx
                port:
                  number: 80
```

The older project example referenced backend port `8082`. The current Artifactory Nginx service exposed service ports `80` and `443`, so I referenced service port `80` in the Ingress.

I validated and applied the manifest:

```bash
kubectl apply \
  --dry-run=client \
  -f manifests/artifactory-ingress.yaml

kubectl apply -f manifests/artifactory-ingress.yaml
```

I inspected the result:

```bash
kubectl get ingress artifactory-ingress -n tools
kubectl describe ingress artifactory-ingress -n tools
```

Before creating DNS, I tested the host-based route directly against the Ingress Load Balancer:

```bash
export INGRESS_HOST=$(kubectl get service \
  ingress-nginx-controller \
  -n ingress-nginx \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

curl -I --max-time 30 \
  -H "Host: tooling.artifactory.lydiahnganga.cloud" \
  "http://${INGRESS_HOST}"
```

The request returned `HTTP/1.1 200 OK`, which confirmed that Nginx routed the request to Artifactory correctly.
<img width="1366" height="768" alt="curlmax" src="https://github.com/user-attachments/assets/70958c75-dd5b-4d80-a8b2-e5d4ea399893" />


## Configuring Route 53

My domain, `lydiahnganga.cloud`, uses an Amazon Route 53 hosted zone. I created the following record without changing the existing Zoho Mail records:

| Setting | Value |
|---|---|
| Record name | `tooling.artifactory` |
| Record type | `CNAME` |
| Value | Nginx Ingress Controller Load Balancer hostname |
| TTL | `300` |
| Routing policy | Simple routing |

I verified the DNS record:

```bash
dig +short CNAME tooling.artifactory.lydiahnganga.cloud
dig +short tooling.artifactory.lydiahnganga.cloud
```

I tested the final domain:

```bash
curl -I --max-time 30 \
  "http://tooling.artifactory.lydiahnganga.cloud"
```

The domain returned `HTTP/1.1 200 OK`.

<img width="1366" height="768" alt="cname" src="https://github.com/user-attachments/assets/ebf83f12-67d2-488a-9cfb-470725fca839" />


## Completing the Artifactory setup

I opened:

```text
https://tooling.artifactory.lydiahnganga.cloud
```

The browser displayed a certificate warning because the deployment used a chart-generated self-signed certificate. Trusted TLS configuration is outside the scope of this project.

I completed the onboarding wizard by:

1. Signing in with the chart's initial administrator credentials.
2. Replacing the default administrator password.
3. Activating a 14-day self-hosted JFrog trial licence.
4. Setting the Base URL to `https://tooling.artifactory.lydiahnganga.cloud`.
5. Skipping the default proxy because the EKS nodes already had outbound access through the NAT Gateway.
6. Skipping automatic repository creation so repositories can be configured separately later.

No passwords, licence keys, master keys, or join keys are stored in this repository.

<img width="1366" height="653" alt="tooling art" src="https://github.com/user-attachments/assets/4be62c31-e53c-46f1-b25a-f394d8097e01" />
<img width="1366" height="608" alt="art dashboard" src="https://github.com/user-attachments/assets/0eea3d0e-97f0-49a2-bbdb-8a73fb142c1f" />



## Problems encountered and how I fixed them

### Artifactory could not schedule on the original nodes

The original self-managed node group used `t3.small` and `t2.small` instances. Artifactory pods remained in `Pending` and initialization states because the nodes did not have enough memory. Kubernetes reported memory pressure, too many pods, and a volume node affinity conflict.

I changed the mixed instance types in the Project 24 Terraform variables to `t3.large` and `t3a.large`. The rebuilt node group provided enough capacity for Artifactory and the other tools planned for later projects.

### Running EC2 instances did not appear as Kubernetes nodes

The two `t3.large` EC2 instances were running and had passed all AWS status checks, but this command returned no nodes:

```bash
kubectl get nodes
```

The EKS control plane was active, but the `aws-auth` ConfigMap did not exist:

```bash
kubectl get configmap aws-auth -n kube-system -o yaml
```


### The EBS CSI add-on became degraded

The EBS CSI add-on initially timed out in the `DEGRADED` state with `InsufficientNumberOfReplicas`. Its pods could not schedule because no worker nodes had joined the cluster.

After fixing `aws-auth`, I ran a normal Terraform apply. The add-on became `ACTIVE`, its controller and node pods became ready, and Terraform created the default `gp3` storage class.

### Terraform tried to read the EKS cluster before creating it

The original Kubernetes provider depended on this data source:

```hcl
data "aws_eks_cluster" "cluster" {
  name = module.eks_cluster.cluster_name
}
```

During a clean rebuild, Terraform attempted to call `DescribeCluster` before the cluster existed. Adding `depends_on` caused a cycle because the EKS module also used the Kubernetes provider to manage `aws-auth`.

I removed the `aws_eks_cluster` data source and configured the provider with the EKS module outputs:

```hcl
provider "kubernetes" {
  host                   = module.eks_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}
```

This tied the provider configuration to values produced by the actual cluster resource.

### Early Artifactory health probes failed

Some startup and liveness probes returned connection refused or HTTP `503` while Artifactory services were initializing. Kubernetes restarted two containers during startup. I did not reinstall the release. I waited for the application to finish initializing, and all pods eventually became ready.

## Verification

These commands provide a final deployment check:

```bash
helm list --all-namespaces

kubectl get nodes -o wide

kubectl get pods,svc,pvc -n tools

kubectl get pods,service -n ingress-nginx

kubectl get ingress artifactory-ingress -n tools

kubectl get storageclass

dig +short CNAME tooling.artifactory.lydiahnganga.cloud

curl -I --max-time 30 \
  "http://tooling.artifactory.lydiahnganga.cloud"
```

Expected results:

- Both EKS worker nodes are `Ready`.
- All Artifactory and PostgreSQL pods are `Running`.
- All persistent volume claims are `Bound`.
- The EBS CSI add-on is `ACTIVE`.
- The Nginx Ingress Controller is `Running`.
- The Artifactory Ingress uses class `nginx` and the correct hostname.
- DNS resolves to the Ingress Load Balancer.
- The final domain returns a successful HTTP response.

## Project files

```text
Project-25-Deploying-Packaging-Applications-into-Kubernetes-Helm/
├── README.md
├── images/
└── manifests/
    └── artifactory-ingress.yaml
```

The `images` directory contains screenshots used as deployment evidence. Sensitive values are excluded.

## Cleanup

These resources incur AWS charges. When the environment is no longer required, Helm-managed resources should be removed before destroying the Terraform infrastructure so Kubernetes-created Load Balancers and EBS volumes do not block VPC deletion.

```bash
helm uninstall artifactory -n tools
helm uninstall ingress-nginx -n ingress-nginx

kubectl delete namespace tools
kubectl delete namespace ingress-nginx
```

I would then verify that the Kubernetes-created Load Balancers and persistent volumes were deleted before running Terraform destroy from Project 24:

```bash
terraform destroy -var-file="variables.tfvars"
```

## What I learned

This project showed me that a Helm deployment depends on more than a successful `helm install` command. The cluster needed enough memory, correctly authorized self-managed nodes, a working EBS CSI driver, and a suitable default storage class before Artifactory could start.

I also learned how Kubernetes Ingress separates hostname-based routing from the services behind it, how Route 53 connects a readable domain to an AWS Load Balancer, and why Kubernetes-created cloud resources must be removed before destroying the VPC that contains them.
