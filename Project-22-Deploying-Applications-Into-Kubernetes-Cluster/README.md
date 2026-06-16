# Deploying Applications Into a Kubernetes Cluster

## Table of contents

- [Overview](#overview)
- [Why minikube instead of AWS](#why-minikube-instead-of-aws)
- [Prerequisites](#prerequisites)
- [Setting up the local cluster](#setting-up-the-local-cluster)
- [Creating a pod](#creating-a-pod)
- [Reaching a pod directly by its IP](#reaching-a-pod-directly-by-its-ip)
- [Creating a service](#creating-a-service)
- [Exposing the service with nodeport](#exposing-the-service-with-nodeport)
- [Replicasets and self healing](#replicasets-and-self-healing)
- [Scaling a replicaset](#scaling-a-replicaset)
- [Advanced label selectors](#advanced-label-selectors)
- [Loadbalancer service type](#loadbalancer-service-type)
- [Deployments](#deployments)
- [Why pods do not store data](#why-pods-do-not-store-data)
- [Cleanup](#cleanup)
- [Lessons learned](#lessons-learned)
- [Next steps](#next-steps)

## Overview

This project covers the core building blocks used to run an application on Kubernetes: Pods, Services, ReplicaSets, and Deployments. Each object was created from a YAML manifest, applied with `kubectl`, and inspected to confirm what Kubernetes actually did versus what was written in the manifest. The goal was to understand how each object behaves on its own and how they layer on top of each other, rather than just getting an application running.

## Why minikube instead of AWS

The original plan was to continue working against the kubeadm cluster built on EC2 in Project 21. That cluster had already been terminated to avoid ongoing AWS charges, since a multi-node kubeadm setup typically needs instance types larger than the free tier allows.

None of the objects covered in this project depend on AWS specifically. Pods, Services, ReplicaSets, and Deployments behave the same way on any conformant Kubernetes cluster. The only AWS-specific piece in the original material is the LoadBalancer service type, which provisions a real Elastic Load Balancer on EKS. Minikube has its own way of simulating this locally through `minikube tunnel`, which made it possible to test that service type for real instead of skipping it.

Running locally also meant zero ongoing cost while learning the concepts, with the option to return to a real cloud cluster for the EKS-specific project later.

## Prerequisites

- Docker Desktop with WSL2 integration enabled
- WSL (Ubuntu) as the working shell, not Git Bash, since most Kubernetes tooling assumes a Linux environment
- kubectl
- minikube

`kubectl` and `kind` were already installed from earlier work. `minikube` was the only missing piece and was installed with:

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64
```

## Setting up the local cluster

```bash
minikube start --driver=docker
kubectl get nodes
```

The Docker driver was used since Docker Desktop was already configured and working in WSL, removing the need for a separate VM hypervisor.

## Creating a pod

A Pod is the smallest deployable unit in Kubernetes. It wraps one or more containers and gives them a shared network namespace. Every manifest follows the same structure: `apiVersion`, `kind`, `metadata`, and `spec`.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  labels:
    app: nginx-pod
spec:
  containers:
  - image: nginx:latest
    name: nginx-pod
    ports:
    - containerPort: 80
      protocol: TCP
```

```bash
kubectl apply -f nginx-pod.yaml
kubectl get pods
kubectl describe pod nginx-pod
kubectl get pod nginx-pod -o yaml
```

`describe` gives a human readable summary plus an event log, useful for troubleshooting when a Pod will not start. `-o yaml` shows the full live object, including fields Kubernetes adds on its own under `status`, which never existed in the original manifest.

<img width="1366" height="768" alt="nginx 1" src="https://github.com/user-attachments/assets/f139394d-18d2-426c-86d0-bfe14249c1fc" />

## Reaching a pod directly by its IP

Before introducing a Service, a temporary Pod with curl installed was used to hit the nginx Pod directly by its internal cluster IP, to demonstrate why depending on a Pod's IP directly is unreliable.

```bash
kubectl run curl --image=dareyregistry/curl -i --tty --rm
curl -v <nginx-pod-ip>:80
```

This returned the default nginx welcome page, confirming Pod to Pod communication works inside the cluster network. The problem: a Pod's IP changes every time it is recreated, so anything hardcoded to that IP breaks the moment the Pod restarts. This is the exact problem a Service solves.

<img width="1366" height="768" alt="nginx up 4" src="https://github.com/user-attachments/assets/6dcf24c5-f1f9-4250-b5fc-647f06851351" />


## Creating a service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx-pod
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

```bash
kubectl apply -f nginx-service.yaml
kubectl port-forward svc/nginx-service 8089:80
```

The first attempt at `port-forward` failed with `error: timed out waiting for the condition`. The cause: the Pod manifest had not yet been given the `app: nginx-pod` label that the Service's selector was looking for, so the Service had zero endpoints to forward traffic to. Adding the label to the Pod and reapplying resolved it immediately.

```bash
kubectl get service nginx-service -o wide
kubectl get pod nginx-pod -o wide
```

Comparing these two outputs shows the mechanism directly: the Service's `CLUSTER-IP` acts as a stable internal address, and its `SELECTOR` column determines which Pod's actual IP it forwards traffic to.

<img width="1366" height="768" alt="port forwarding works 5" src="https://github.com/user-attachments/assets/5f828e8c-700d-4732-8afc-b796eeb85eea" />

## Exposing the service with nodeport

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: NodePort
  selector:
    app: nginx-pod
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
      nodePort: 30080
```

On a cloud VM, this service type would normally be reached using the node's public IP plus the chosen port. Minikube's Docker driver does not expose a host-reachable node IP the same way, so `minikube service` was used instead to handle the access path automatically:

```bash
kubectl apply -f nginx-service.yaml
minikube service nginx-service --url
```
<img width="1366" height="768" alt="nordport added 6" src="https://github.com/user-attachments/assets/cc491308-55f9-4f6b-9d3d-bf75bffeeeda" />

## Replicasets and self healing

A ReplicaSet keeps a fixed number of identical Pods running at all times. The original lab material wrote the ReplicaSet's selector as a bare key value pair directly under `selector`, which is syntax from a deprecated API that no longer exists in current Kubernetes. Under `apps/v1`, the selector must be a structured object using `matchLabels`.

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-rs
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx-pod
  template:
    metadata:
      name: nginx-pod
      labels:
        app: nginx-pod
    spec:
      containers:
      - image: nginx:latest
        name: nginx-pod
        ports:
        - containerPort: 80
          protocol: TCP
```

```bash
kubectl delete -f nginx-pod.yaml
kubectl apply -f rs.yaml
kubectl get pods
```

To confirm self healing, one of the three Pods was deleted directly:

```bash
kubectl delete po <pod-name>
kubectl get pods
```

A replacement Pod appeared within seconds, keeping the total at three. This is the core behaviour a ReplicaSet provides: it is constantly reconciling the live state of the cluster against the desired count in its spec.

<img width="1366" height="768" alt="self healing test 9" src="https://github.com/user-attachments/assets/f8d47cb6-af5d-4982-a36d-aa067ce44ad3" />

## Scaling a replicaset

Two ways to change the replica count were tested.

Imperative, changing the live cluster state directly without touching the file:

```bash
kubectl scale rs nginx-rs --replicas=5
kubectl scale rs nginx-rs --replicas=3
```

Declarative, editing `replicas` in the YAML file and reapplying:

```bash
kubectl apply -f rs.yaml
```

The declarative approach is the one to default to in practice. An imperative scale changes the cluster but leaves the YAML file out of sync, so a later `kubectl apply` of the unchanged file would silently undo the imperative change. Treating the YAML file as the single source of truth avoids that.
<img width="1366" height="768" alt="declarative" src="https://github.com/user-attachments/assets/77566625-0851-4bcc-be57-f6a4f3b8c470" />


## Advanced label selectors

A second ReplicaSet was created to demonstrate `matchExpressions` alongside `matchLabels`. It was given its own name, `nginx-rs-advanced`, rather than reusing the name from the previous section, since a ReplicaSet's selector is immutable once created and cannot be changed by reapplying the same name with a different selector.

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-rs-advanced
spec:
  replicas: 3
  selector:
    matchLabels:
      env: prod
    matchExpressions:
    - { key: tier, operator: In, values: [frontend] }
  template:
    metadata:
      name: nginx
      labels:
        env: prod
        tier: frontend
    spec:
      containers:
      - name: nginx-container
        image: nginx:latest
        ports:
        - containerPort: 80
          protocol: TCP
```

`matchLabels` checks for exact equality. `matchExpressions` allows richer conditions such as `In`, `NotIn`, `Exists`, and `DoesNotExist`. Both conditions in a selector are combined with AND logic, meaning a Pod has to satisfy all of them to be considered part of that ReplicaSet.

## Loadbalancer service type

The original material marks this service type as something to skip locally and only test once a real EKS cluster exists, since it relies on a cloud provider's load balancer integration. Minikube has its own equivalent through `minikube tunnel`, which made it possible to test this for real.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: LoadBalancer
  selector:
    tier: frontend
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

```bash
kubectl apply -f nginx-service.yaml
minikube tunnel
```

`minikube tunnel` needs elevated permissions to modify local network routes, so it prompts for a sudo password internally. Running `sudo minikube tunnel` directly causes the opposite problem: sudo switches the effective home directory to root's, and minikube looks for the cluster profile there instead of the actual user's home directory, resulting in a `Profile "minikube" not found` error. The fix is to run `minikube tunnel` without the sudo prefix and let it prompt for elevation only when it actually needs to change routes.

Once running, `kubectl get service nginx-service` showed `EXTERNAL-IP` change from `<pending>` to `127.0.0.1`, which on the Docker driver is the most direct route back into the cluster. The service was reachable in the browser at `http://127.0.0.1:80`.

<img width="1366" height="768" alt="loadbalancer external ip" src="https://github.com/user-attachments/assets/77ed330f-3144-493e-8714-fff5e7eaede1" />

## Deployments

A Deployment manages a ReplicaSet, which in turn manages Pods. It adds rolling updates and rollback capability on top of what a plain ReplicaSet provides, and is the recommended way to manage replicated stateless workloads.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    tier: frontend
spec:
  replicas: 3
  selector:
    matchLabels:
      tier: frontend
  template:
    metadata:
      labels:
        tier: frontend
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
```

This manifest deliberately reused the `tier: frontend` label that the existing LoadBalancer Service was already watching for. After deleting the previous ReplicaSet and applying this Deployment, the same Service began routing to the Deployment's Pods without any change on the Service's side, confirming that Services are fully decoupled from whichever controller is managing the Pods behind them.

```bash
kubectl delete rs nginx-rs-advanced
kubectl apply -f deployment.yaml
kubectl get deployment
kubectl get rs
kubectl get pods
```

The three layers were all visible in that output: the Deployment, an auto named ReplicaSet underneath it, and Pods underneath that.

Scaling and inspecting a running container:

```bash
kubectl scale deployment nginx-deployment --replicas=15
kubectl exec -it <pod-name> -- bash
ls -ltr /etc/nginx/
cat /etc/nginx/conf.d/default.conf
```

<img width="1366" height="768" alt="deployment working" src="https://github.com/user-attachments/assets/dbda1a37-cbda-4134-8332-5bfd1b8aa8a9" />
<img width="1366" height="768" alt="deployment sacled to 15" src="https://github.com/user-attachments/assets/699b2377-d998-464a-9637-c700de1c283a" />




## Why pods do not store data

This was the most important practical demonstration in the project. The Deployment was scaled down to a single replica to remove any ambiguity about which Pod was being reached, then its default page was overwritten from inside the container:

```bash
kubectl scale deployment nginx-deployment --replicas=1
kubectl exec -it <pod-name> -- bash
apt-get update
apt-get install vim -y
cat > /usr/share/nginx/html/index.html << 'EOF'
... custom page content ...
EOF
exit
```
<img width="1366" height="721" alt="nginx page edited" src="https://github.com/user-attachments/assets/cbfcb519-53f3-447f-ad0f-375f1b60ef00" />

The edited page loaded correctly in the browser. The Pod was then deleted directly:

```bash
kubectl delete pod <pod-name>
```

Kubernetes immediately created a replacement to maintain the desired count of one. Refreshing the browser showed the original default nginx page again, not the edited version. The edit existed only inside the dead container's writable layer, which Kubernetes does not preserve across restarts. Deployments guarantee a Pod count, not data continuity, which is the reason the next project in this series introduces Volumes, PersistentVolumes, and PersistentVolumeClaims.

<img width="1366" height="768" alt="deployment scaledown" src="https://github.com/user-attachments/assets/62b0cc08-cdfa-4a3e-93a5-97755cf58676" />

## Cleanup

```bash
kubectl delete deployment nginx-deployment
```

## Lessons learned

Services exist to solve a single, specific problem: Pods are disposable and their IPs are not stable, so anything that needs to reach a Pod reliably needs a layer of indirection in front of it. That same indirection is what allowed the Service in this project to survive being repointed from a ReplicaSet to a Deployment without any reconfiguration.

The data loss demonstration was the clearest illustration of a boundary that is easy to miss when first learning Kubernetes: a Deployment's job is to keep a certain number of Pods running, not to protect anything written inside them. Confusing those two responsibilities is a common source of surprise in real production incidents, not just a classroom exercise.

Two parts of the original lab material did not match the current Kubernetes API and needed correcting before they would apply cleanly: the ReplicaSet selector syntax, which used a deprecated bare key value format instead of the `matchLabels` structure required under `apps/v1`, and the assumption that the LoadBalancer service type could only be tested on EKS, when `minikube tunnel` made it possible to test locally instead.

## Next steps

The document this project is based on includes an additional self directed task: containerize the Tooling app from an earlier project, push the image to a registry, and write a Pod and Service for it. The image already exists on Docker Hub from earlier work (`lydiahlaw/tooling`), so this only requires writing the Kubernetes manifests, not rebuilding the image. Wiring up the Tooling app's MySQL database properly is deferred to the next project, which introduces ConfigMaps and Secrets, the right tools for that job.
