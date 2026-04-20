# Kubernetes From Scratch on AWS

## Table of Contents

* Overview
* Why I Built This
* Architecture
* Technologies Used
* Project Structure
* Step 1: Infrastructure Setup
* Step 2: Certificate Authority and TLS
* Step 3: Kubeconfigs
* Step 4: etcd Cluster
* Step 5: Control Plane Setup
* Step 6: Worker Nodes Setup
* Step 7: Networking (CNI)
* Validation
* Challenges and Debugging
* Security Considerations
* Key Takeaways

---

## Overview

This project documents how I built a Kubernetes cluster completely from scratch on AWS.

No EKS, no kubeadm, no shortcuts.

Everything from certificates, networking, and control plane components was configured manually.

---

## Why I Built This

I didn’t just want to “use Kubernetes”. I wanted to understand:

* what actually happens when a node joins a cluster
* how the API server talks to etcd
* how TLS is used across every component
* what breaks when things are misconfigured

---

## Architecture

* 3 Control Plane Nodes
* 3 Worker Nodes
* etcd cluster running across masters
* AWS Network Load Balancer for API server

---

## Technologies Used

* AWS EC2
* Kubernetes v1.28
* containerd
* cfssl
* Linux (Ubuntu)

---

## Project Structure

```bash
Project-21-Kubernetes-From-Scratch-On-AWS/
├── README.md
├── configs/
├── docs/
├── scripts/
```

Sensitive files like certificates, keys, and SSH configs were excluded from version control.

---

## Step 1: Infrastructure Setup

I provisioned EC2 instances manually using AWS CLI.

Each node was tagged for identification:

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=${NAME}-master-0"
```

Key lesson: naming consistency matters because later scripts depend on it.

---

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

---

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

---

## Step 4: etcd Cluster

Installed etcd manually:

```bash
tar -xvf etcd-v3.5.9-linux-amd64.tar.gz
sudo mv etcd* /usr/local/bin/
```

Started cluster and verified:

```bash
ETCDCTL_API=3 etcdctl member list \
--endpoints=https://127.0.0.1:2379
```

---

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

---

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

---

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

---

## Validation

Check cluster:

```bash
kubectl --kubeconfig=admin.kubeconfig get nodes
```

Result:

All nodes moved from NotReady → Ready

---

## Challenges and Debugging

### 1. SSH Key Permissions

```
Permissions 0777 are too open
```

Fixed with:

```bash
chmod 600 key.pem
```

---

### 2. Missing AWS Region

```
argument --region: expected one argument
```

Fixed by exporting:

```bash
export AWS_REGION=eu-central-1
```

---

### 3. Encryption Config YAML Error

Cluster failed to start due to malformed YAML.

---

### 4. Kubelet Failure

```
unknown flag: --network-plugin
```

Removed deprecated flags.

---

### 5. Missing Files on Workers

Wrong filenames caused move failures.

Fixed by matching:

```
k8s-cluster-from-ground-up-worker-X.pem
```

---

## Security Considerations

I intentionally excluded:

* .pem files
* private keys
* kubeconfigs
* SSH keys

These were added to `.gitignore`.

---

## Key Takeaways

* Kubernetes is not complex, it’s just very detailed
* Most failures come from small misconfigurations
* TLS and identity are at the core of everything
* Debugging is the real skill, not setup

---

## Conclusion

This project forced me to understand Kubernetes at a systems level.

Not just how to use it, but how it actually works under the hood.
