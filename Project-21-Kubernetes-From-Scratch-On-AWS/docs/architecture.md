# Kubernetes Architecture Overview

This cluster consists of:

- Control Plane (Masters)
  - API Server
  - Controller Manager
  - Scheduler

- Worker Nodes
  - Kubelet
  - Container Runtime (containerd)
  - Kube Proxy

## Request Flow

User → kubectl → API Server → etcd  
                         ↓  
                   Scheduler → Worker Node → Pod
