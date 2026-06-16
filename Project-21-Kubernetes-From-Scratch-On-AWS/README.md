# Kubernetes From Scratch on AWS


## Table of Contents
- [Overview](#overview)  
- [Why I Built This](#why-i-built-this)  
- [Architecture](#architecture)  
- [Technologies Used](#technologies-used)  
- [Project Structure](#project-structure)  
- [Step 1: Infrastructure Setup](#step-1-infrastructure-setup)  
- [Step 2: Certificate Authority and TLS](#step-2-certificate-authority-and-tls)  
- [Step 3: Kubeconfigs](#step-3-kubeconfigs)  
- [Step 4: etcd Cluster](#step-4-etcd-cluster)  
- [Step 5: Control Plane Setup](#step-5-control-plane-setup)  
- [Step 6: Worker Nodes Setup](#step-6-worker-nodes-setup)  
- [Step 7: Networking (CNI)](#step-7-networking-cni)  
- [Validation](#validation)  
- [Challenges and Debugging](#challenges-and-debugging)  
- [Security Considerations](#security-considerations)  
- [Key Takeaways](#key-takeaways)  



## Overview

This project documents how I built a Kubernetes cluster completely from scratch on AWS.

No EKS, no kubeadm, no shortcuts.

Everything from certificates, networking, and control plane components was configured manually.



## Why I Built This

I didn’t just want to “use Kubernetes”. I wanted to understand:

* what actually happens when a node joins a cluster
* how the API server talks to etcd
* how TLS is used across every component
* what breaks when things are misconfigured



## Architecture

* 3 Control Plane Nodes
* 3 Worker Nodes
* etcd cluster running across masters
* AWS Network Load Balancer for API server


## Technologies Used

* AWS EC2
* Kubernetes v1.28
* containerd
* cfssl
* Linux (Ubuntu)



## Project Structure

```bash
Project-21-Kubernetes-From-Scratch-On-AWS/
├── README.md
├── configs/
├── docs/
├── scripts/
```

Sensitive files like certificates, keys, and SSH configs were excluded from version control.



## Step 1: Infrastructure Setup

I provisioned EC2 instances manually using AWS CLI.

Each node was tagged for identification:

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=${NAME}-master-0"
```

Key lesson: naming consistency matters because later scripts depend on it.

<img width="1366" height="768" alt="instances created and confirmed console" src="https://github.com/user-attachments/assets/36ca4178-30ff-4304-a02b-2d8e9fd21e66" />


## Step 2: Certificate Authority and TLS

I generated my own CA and signed certificates for:

* API server
* kubelet
* kube-proxy
* controller manager
* scheduler

Example:

```bash
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
```

Each worker node certificate had to match its hostname exactly or kubelet would fail to authenticate.

<img width="1366" height="768" alt="cert files created" src="https://github.com/user-attachments/assets/e9c36a02-fb3d-45a4-a237-3d4eb8a4166b" />


## Step 3: Kubeconfigs

I created kubeconfigs to connect components to the API server.

Example:

```bash
kubectl config set-cluster kubernetes \
  --certificate-authority=ca.pem \
  --server=https://<LOAD_BALANCER>:6443 \
  --kubeconfig=admin.kubeconfig
```

Workers use the load balancer, control plane uses localhost.



## Step 4: etcd Cluster

Installed etcd manually:

```bash
tar -xvf etcd-v3.5.9-linux-amd64.tar.gz
sudo mv etcd* /usr/local/bin/
```
<img width="1366" height="768" alt="etcd downloaded on master" src="https://github.com/user-attachments/assets/4440f299-e8aa-4861-9de4-05e88d7b2267" />

Started cluster and verified:

```bash
ETCDCTL_API=3 etcdctl member list \
--endpoints=https://127.0.0.1:2379
```

<img width="1366" height="768" alt="etcd started" src="https://github.com/user-attachments/assets/f093ca1c-8ca0-45e8-a537-8b47416c3ad2" />


## Step 5: Control Plane Setup

Configured kube-apiserver with encryption:

```bash
--encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml
```

This is where I hit a major issue.

My YAML had a formatting error:

```
yaml: could not find expected ':'
```

Fixing indentation solved it.



## Step 6: Worker Nodes Setup

Installed container runtime and kubelet.

Moved certificates:

```bash
sudo mv k8s-cluster-from-ground-up-worker-0.pem \
/var/lib/kubernetes/kubelet.pem
```

Started kubelet:

```bash
sudo systemctl start kubelet
```

<img width="1366" height="768" alt="worker nodes cert" src="https://github.com/user-attachments/assets/bfaba1f6-0f9b-483c-a6d2-4e38d06178c9" />


## Step 7: Networking (CNI)

Configured bridge network:

```bash
cat <<EOF | sudo tee /etc/cni/net.d/10-bridge.conf
{
  "type": "bridge"
}
EOF
```

Without this, nodes stayed in NotReady state.



## Validation

Check cluster:

```bash
kubectl --kubeconfig=admin.kubeconfig get nodes
```

Result:

All nodes transitioned from NotReady to Ready.

This confirmed that:

- kubelet was correctly configured on each worker node  
- TLS certificates were valid and trusted  
- networking via CNI was functioning  
- the API server was successfully communicating with all nodes

<img width="1366" height="768" alt="nodes ready" src="https://github.com/user-attachments/assets/f7cce89c-534f-4c3c-a4e5-a6bb070567e2" />


## Challenges and Debugging

### 1. SSH Key Permissions

```
Permissions 0777 are too open
```

Fixed with:

```bash
chmod 600 key.pem
```



### 2. Missing AWS Region

```
argument --region: expected one argument
```

Fixed by exporting:

```bash
export AWS_REGION=eu-central-1
```



### 3. Encryption Config YAML Error

Cluster failed to start due to malformed YAML.


### 4. Kubelet Failure

```
unknown flag: --network-plugin
```

Removed deprecated flags.



### 5. Missing Files on Workers

Wrong filenames caused move failures.

Fixed by matching:

```
k8s-cluster-from-ground-up-worker-X.pem
```


## Security Considerations

I intentionally excluded:

* .pem files
* private keys
* kubeconfigs
* SSH keys

These were added to `.gitignore`.



## Key Takeaways

* Kubernetes complexity comes from how tightly components depend on each other  
* Most failures come from small misconfigurations
* TLS and identity are at the core of everything
* Debugging is the real skill, not setup


## Conclusion

Building this cluster from scratch forced me to move beyond using Kubernetes into understanding how it actually works.

What stood out most was how tightly everything is connected. A small issue like a misformatted YAML file or a mismatched certificate was enough to bring the entire control plane down. Fixing those issues required tracing how components interact rather than just re-running commands.

The most valuable part of this project was the debugging process. I dealt with:
- kubelet failing due to deprecated flags  
- API server failing because of encryption configuration errors  
- nodes staying NotReady due to missing CNI setup  
- SSH and file permission issues affecting access and automation  

Working through these made the system much clearer. By the end, I wasn’t just following steps, I understood why each component exists and what breaks when it is misconfigured.

This project gave me a much stronger foundation for working with Kubernetes in real environments, especially when things don’t work as expected.


## Blog Post

I wrote a detailed, step by step breakdown of this project, including the challenges I faced and how I debugged them.

You can read it here:

https://medium.com/@LydLaw/i-built-kubernetes-from-scratch-on-aws-and-it-broke-a-lot-5eb4f7a54c23
