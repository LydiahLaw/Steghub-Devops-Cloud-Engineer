# Kubernetes From Scratch on AWS

## Table of Contents

* Overview
* Project Goal
* Architecture
* Technologies Used
* Prerequisites
* Project Structure
* Implementation Steps

  * Infrastructure Setup
  * Certificate Authority and TLS Setup
  * etcd Cluster Setup
  * Control Plane Setup
  * Worker Node Setup
  * Networking Configuration
* Validation and Testing
* Challenges and Debugging
* Security Considerations
* Key Learnings
* Future Improvements

---

## Overview

This project documents the process of building a Kubernetes cluster from scratch on AWS using EC2 instances.

The entire setup is done manually without using tools such as managed Kubernetes services or automated cluster bootstrapping tools. The goal is to understand how Kubernetes works internally by configuring each component step by step.

---

## Project Goal

The objective of this project is to:

* Understand Kubernetes architecture by building it manually
* Configure secure communication between all components using TLS
* Deploy a highly available control plane
* Bootstrap worker nodes and join them to the cluster
* Implement basic networking using CNI plugins
* Validate that the cluster can run real workloads

---

## Architecture

The cluster consists of the following components:

### Control Plane (Master Nodes)

* Kubernetes API Server
* Controller Manager
* Scheduler

### Worker Nodes

* Kubelet
* Container Runtime (containerd)
* Kube Proxy

### Supporting Components

* etcd cluster for distributed key value storage
* Load balancer to expose the API server

### Request Flow

User interacts with the cluster using kubectl. Requests go through the API server, which stores state in etcd. The scheduler assigns workloads to worker nodes. The kubelet ensures containers are running on each node.

---

## Technologies Used

* AWS EC2
* Kubernetes v1.28
* containerd
* cfssl for certificate management
* Linux Ubuntu

---

## Prerequisites

* Basic understanding of Linux and networking
* AWS account with permissions to create EC2 instances
* AWS CLI configured
* kubectl installed locally
* SSH access to instances

---

## Project Structure

```
Project-21-Kubernetes-From-Scratch-On-AWS/
├── README.md
├── configs/
├── docs/
├── scripts/
```

Sensitive files such as certificates, private keys, kubeconfig files, and SSH keys are excluded from version control.

---

## Implementation Steps

### Infrastructure Setup

* Created EC2 instances for master and worker nodes
* Configured networking and security groups
* Set up a load balancer to expose the Kubernetes API

---

### Certificate Authority and TLS Setup

* Generated a Certificate Authority
* Created TLS certificates for:

  * API server
  * controller manager
  * scheduler
  * kubelet
  * kube proxy
* Distributed certificates securely across nodes

Purpose:
To ensure encrypted communication between all Kubernetes components

---

### etcd Cluster Setup

* Installed etcd binaries on master nodes
* Configured a distributed etcd cluster
* Secured communication using TLS certificates
* Verified cluster health

Purpose:
etcd stores the entire cluster state and must be consistent and secure

---

### Control Plane Setup

Configured the following components on master nodes:

#### API Server

* Connected to etcd
* Enabled TLS authentication
* Configured service networking

#### Controller Manager

* Handles background tasks such as node management and replication

#### Scheduler

* Assigns pods to worker nodes

All components were configured using systemd services

---

### Worker Node Setup

On each worker node:

* Installed containerd as the container runtime
* Installed kubelet and kube proxy
* Distributed certificates and kubeconfig files
* Configured kubelet for node registration

Purpose:
Worker nodes run application workloads

---

### Networking Configuration

* Installed CNI plugins
* Created network configuration files in `/etc/cni/net.d/`
* Enabled pod to pod communication

Purpose:
Without networking configuration, nodes remain in NotReady state

---

## Validation and Testing

Cluster validation steps:

```
kubectl get nodes
```

Expected result:
All nodes show Ready status

---

### Test workload

```
kubectl run nginx --image=nginx
kubectl get pods -o wide
```

Expected result:

* Pod is scheduled to a worker node
* Pod status is Running

---

## Challenges and Debugging

### Deprecated Kubernetes Flags

Some kubelet flags were removed in newer Kubernetes versions, causing kubelet to fail.

Fix:
Removed unsupported flags from kubelet service configuration

---

### YAML Configuration Errors

Improper formatting in configuration files caused services to fail.

Fix:
Carefully reviewed and corrected YAML structure

---

### Encryption Configuration Issues

Incorrect key length and formatting caused API server startup failures.

Fix:
Generated a valid key and corrected configuration

---

### Environment Variable Issues

Unset or incorrect variables caused AWS CLI commands to fail.

Fix:
Validated variables before running commands

---

### Node NotReady State

Nodes remained NotReady due to missing CNI configuration.

Fix:
Added required network configuration files

---

## Security Considerations

* All communication is secured using TLS
* Sensitive files such as private keys and kubeconfigs are not committed
* Database credentials and secrets are replaced with placeholders
* SSH keys are excluded from version control

---

## Key Learnings

* Deep understanding of Kubernetes architecture
* How control plane and worker nodes interact
* Importance of TLS in distributed systems
* How kubelet registers and manages nodes
* How networking enables pod communication
* Real world debugging and troubleshooting

---

## Future Improvements

* Automate infrastructure using Terraform
* Implement monitoring with Prometheus and Grafana
* Deploy applications using Helm
* Add ingress controller for external access
* Set up CI CD pipelines

---

## Conclusion

This project demonstrates how to build and understand Kubernetes from the ground up by manually configuring each component.

The experience gained from this process provides a strong foundation for working with Kubernetes in real world cloud environments.
