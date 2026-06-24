# Persisting data in Kubernetes

## Table of contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Infrastructure setup](#infrastructure-setup)
- [Part 1 - Deploying nginx without a volume](#part-1---deploying-nginx-without-a-volume)
- [Part 2 - Attaching an EBS volume manually](#part-2---attaching-an-ebs-volume-manually)
- [Part 3 - Mounting the volume into the container](#part-3---mounting-the-volume-into-the-container)
- [Part 4 - Persistent volumes and persistent volume claims](#part-4---persistent-volumes-and-persistent-volume-claims)
- [Part 5 - ConfigMaps as configuration volumes](#part-5---configmaps-as-configuration-volumes)
- [Key issues encountered](#key-issues-encountered)
- [Tools used](#tools-used)
- [Conclusion](#conclusion)

## Overview

Containers are stateless by design. When a pod restarts or gets replaced, any data written inside the container's filesystem is lost. This project explores three approaches to making data persist across pod restarts in Kubernetes: manually attaching an AWS EBS volume directly to a pod, using a PersistentVolumeClaim with dynamic provisioning via a StorageClass, and using a ConfigMap to persist configuration files.

The project runs on an EKS cluster in `eu-central-1` and uses an nginx deployment as the workload throughout.

## Prerequisites

- AWS CLI configured with sufficient IAM permissions
- `kubectl` v1.35+
- `eksctl` v0.227+
- An EKS cluster (instructions below)

## Infrastructure setup

An EKS cluster was provisioned using eksctl with two managed worker nodes across availability zones in `eu-central-1`.

```bash
eksctl create cluster \
  --name k8s-cluster \
  --region eu-central-1 \
  --nodegroup-name worker-nodes \
  --node-type t3.medium \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 3 \
  --managed
```

After cluster creation, verify nodes are ready:

```bash
kubectl get nodes
```
<img width="1366" height="768" alt="eks 1" src="https://github.com/user-attachments/assets/75f31b8f-001c-46e8-b5f3-5bff7786d9ac" />

The EBS CSI driver is required on EKS 1.34+ for volume attachment. The `awsElasticBlockStore` volume type is deprecated and requires the CSI driver to function. Install it and configure the necessary IAM permissions:

```bash
eksctl utils associate-iam-oidc-provider \
  --region eu-central-1 \
  --cluster k8s-cluster \
  --approve

eksctl create addon \
  --name aws-ebs-csi-driver \
  --cluster k8s-cluster \
  --region eu-central-1 \
  --force

eksctl create iamserviceaccount \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster k8s-cluster \
  --region eu-central-1 \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve \
  --override-existing-serviceaccounts

kubectl rollout restart deployment ebs-csi-controller -n kube-system
```

Verify the CSI driver pods are running:

```bash
kubectl get pods -n kube-system | grep ebs
```

Both `ebs-csi-controller` pods should show `6/6 Running` before proceeding.

## Part 1 - Deploying nginx without a volume

The first step is deploying nginx with three replicas and no volume attached, to confirm the default stateless behaviour before introducing persistence.

```bash
# nginx-pod.yaml
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

```bash
kubectl apply -f nginx-pod.yaml
kubectl get pods
```

With the pods running, exec into one of them and inspect the nginx configuration:

```bash
kubectl exec -it <pod-name> -- bash
ls /etc/nginx/conf.d
cat /etc/nginx/conf.d/default.conf
```

The config shows nginx serves files from `/usr/share/nginx/html`. This directory lives inside the container's writable layer and disappears when the pod is replaced.


## Part 2 - Attaching an EBS volume manually

Before creating an EBS volume, identify which node the pod is running on and confirm its availability zone. EBS volumes must exist in the same AZ as the node they will be attached to.

```bash
kubectl get po <pod-name> -o wide
kubectl describe node <node-name> | grep topology.kubernetes.io/zone
```

Create the EBS volume in the matching AZ:

```bash
aws ec2 create-volume \
  --availability-zone eu-central-1a \
  --size 10 \
  --volume-type gp2 \
  --region eu-central-1 \
  --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=nginx-volume}]'
```

Update the deployment to reference the volume. Note that `volumeMounts` is not added yet — this step only attaches the volume to the pod, it does not mount it inside the container:

```bash
# nginx-pod.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    tier: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      tier: frontend
  template:
    metadata:
      labels:
        tier: frontend
    spec:
      nodeSelector:
        topology.kubernetes.io/zone: eu-central-1a
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
      volumes:
      - name: nginx-volume
        awsElasticBlockStore:
          volumeID: "vol-0ef16d48044851688"
          fsType: ext4
```

```bash
kubectl apply -f nginx-pod.yaml
kubectl describe pod <pod-name>
kubectl describe deployment nginx-deployment
```

The pod describe output shows the volume under the `Volumes` section, but `Mounts: <none>` in the container spec confirms it is attached but not yet accessible to the container.
<img width="1366" height="768" alt="mounts none" src="https://github.com/user-attachments/assets/83ac134b-77e4-47b1-b229-5c1a6fbd67bd" />

## Part 3 - Mounting the volume into the container

Add a `volumeMounts` section to the container spec to mount the EBS volume at `/usr/share/nginx/`:

```bash
# nginx-pod.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    tier: frontend
spec:
  replicas: 1
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 0
  selector:
    matchLabels:
      tier: frontend
  template:
    metadata:
      labels:
        tier: frontend
    spec:
      nodeSelector:
        topology.kubernetes.io/zone: eu-central-1a
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
        volumeMounts:
        - name: nginx-volume
          mountPath: /usr/share/nginx/
      volumes:
      - name: nginx-volume
        awsElasticBlockStore:
          volumeID: "vol-0ef16d48044851688"
          fsType: ext4
```

```bash
kubectl apply -f nginx-pod.yaml
kubectl get pods
```

Confirm the mount inside the container:

```bash
kubectl exec -it <pod-name> -- df -h | grep nginx
kubectl exec -it <pod-name> -- ls /usr/share/nginx/
```

The volume mounts at `/usr/share/nginx/` and shows only `lost+found`. Mounting a volume onto a directory that already contains data wipes the existing content — this is expected behaviour. Accessing nginx via port-forward at this point returns a 403 because the `html/` directory that holds `index.html` no longer exists.

This approach has significant limitations: the volume must be pre-created in the correct AZ, the volumeID must be hardcoded in the manifest, and EBS only supports attachment to a single EC2 instance at a time. These constraints make it impractical for production use.
<img width="1366" height="768" alt="html files wiped" src="https://github.com/user-attachments/assets/17377fdd-041e-4635-aab4-8962b2e94c07" />


## Part 4 - Persistent volumes and persistent volume claims

PersistentVolumeClaims decouple the pod spec from the underlying storage details. Instead of referencing a specific EBS volume by ID, a PVC requests storage from the cluster and the StorageClass handles provisioning automatically.

Check the default StorageClass on the cluster:

```bash
kubectl get storageclass
```

EKS comes with a `gp2` StorageClass configured with `WaitForFirstConsumer` binding mode, which means the PV is not created until a pod actually requests it.

Create the PVC:

```bash
# nginx-volume-claim.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nginx-volume-claim
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
  storageClassName: gp2
```

```bash
kubectl apply -f nginx-volume-claim.yaml
kubectl get pvc
kubectl describe pvc nginx-volume-claim
kubectl get pv
```

The PVC shows `Pending` and the describe output confirms it is `waiting for first consumer to be created before binding`. No PV exists yet.
<img width="1366" height="768" alt="waiting for customer efore binding" src="https://github.com/user-attachments/assets/292563a9-7aa1-4998-835f-053af1cd2e25" />


Update the deployment to reference the PVC instead of a raw EBS volume:

```bash
# nginx-pod.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    tier: frontend
spec:
  replicas: 1
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
        volumeMounts:
        - name: nginx-volume-claim
          mountPath: "/tmp/dare"
      volumes:
      - name: nginx-volume-claim
        persistentVolumeClaim:
          claimName: nginx-volume-claim
```

```bash
kubectl apply -f nginx-pod.yaml
kubectl get pods
kubectl get pvc
kubectl get pv
```

Once the pod starts, the PVC moves to `Bound` and a PV is dynamically created. The PV name corresponds to an EBS volume that Kubernetes provisioned automatically in the correct AZ, without any manual intervention.
<img width="1366" height="768" alt="pvc bound" src="https://github.com/user-attachments/assets/198af84a-f372-496e-a2f9-6025b13991a4" />


## Part 5 - ConfigMaps as configuration volumes

ConfigMaps store non-sensitive key-value data and can be mounted into pods as files. This makes configuration persistent across pod restarts without requiring block storage.

First, get the default nginx `index.html` content from a running pod:

```bash
kubectl exec -it <pod-name> -- cat /usr/share/nginx/html/index.html
```

Create a ConfigMap using that content:

```bash
# nginx-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: website-index-file
data:
  index-file: |
    <!DOCTYPE html>
    <html>
    <head>
    <title>Welcome to nginx!</title>
    <style>
    html { color-scheme: light dark; }
    body { width: 35em; margin: 0 auto;
    font-family: Tahoma, Verdana, Arial, sans-serif; }
    </style>
    </head>
    <body>
    <h1>Welcome to nginx!</h1>
    <p>If you see this page, nginx is successfully installed and working.
    Further configuration is required for the web server, reverse proxy,
    API gateway, load balancer, content cache, or other features.</p>
    <p>For online documentation and support please refer to
    <a href="https://nginx.org/">nginx.org</a>.<br/>
    To engage with the community please visit
    <a href="https://community.nginx.org/">community.nginx.org</a>.<br/>
    For enterprise grade support, professional services, additional
    security features and capabilities please refer to
    <a href="https://f5.com/nginx">f5.com/nginx</a>.</p>
    <p><em>Thank you for using nginx.</em></p>
    </body>
    </html>
```

```bash
kubectl apply -f nginx-configmap.yaml
kubectl get cm
```

Update the deployment to mount the ConfigMap as a volume at `/usr/share/nginx/html`:

```bash
# nginx-pod-with-cm.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    tier: frontend
spec:
  replicas: 1
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
        volumeMounts:
          - name: config
            mountPath: /usr/share/nginx/html
            readOnly: true
      volumes:
      - name: config
        configMap:
          name: website-index-file
          items:
          - key: index-file
            path: index.html
```

```bash
kubectl apply -f nginx-pod-with-cm.yaml
kubectl exec -it <pod-name> -- ls -ltr /usr/share/nginx/html
```

The output shows `index.html` as a symlink pointing to `..data/index.html`. This is how Kubernetes delivers ConfigMap updates into the pod without a restart — when the ConfigMap is edited, the symlink target updates automatically within about 60 seconds.

Edit the ConfigMap directly to test this:

```bash
kubectl edit cm website-index-file
```

Change the title and heading text, save, then wait about 60 seconds:

```bash
kubectl exec -it <pod-name> -- cat /usr/share/nginx/html/index.html
```

The updated content appears inside the running pod without any pod restart. To trigger a restart manually if needed:

```bash
kubectl rollout restart deploy nginx-deployment
```
<img width="1366" height="768" alt="websited edited" src="https://github.com/user-attachments/assets/0f0a6be7-98a0-4099-981c-8a8d8522760d" />


## Key issues encountered

**EBS CSI driver not installed:** On EKS 1.34+, the `awsElasticBlockStore` volume type requires the EBS CSI driver. Without it, pods stay stuck in `ContainerCreating` with an `AttachVolume` timeout error. The fix is to install the `aws-ebs-csi-driver` addon and attach `AmazonEBSCSIDriverPolicy` to the CSI controller service account via IRSA.

**AZ mismatch:** EBS volumes are AZ-specific. If a pod gets scheduled on a node in a different AZ from the volume, the attachment fails. The fix for the manual EBS approach is to add a `nodeSelector` matching `topology.kubernetes.io/zone` to pin the pod to the correct AZ. This problem disappears entirely when using PVCs because the StorageClass handles AZ placement automatically.

**Rolling update deadlock:** With `maxSurge: 1` and a single-attach EBS volume, the rolling update creates the new pod before terminating the old one. The new pod can not attach the volume because the old pod still holds it, so it stays `Pending` indefinitely. Setting `maxUnavailable: 1` and `maxSurge: 0` forces the old pod to terminate before the new one starts.

**OIDC provider missing:** `eksctl create iamserviceaccount` requires an IAM OIDC provider associated with the cluster. Run `eksctl utils associate-iam-oidc-provider` first if this step fails.

## Tools used

- Amazon EKS (Kubernetes 1.34)
- eksctl 0.227
- kubectl 1.35
- AWS EBS (gp2)
- AWS EBS CSI Driver
- nginx:latest


## Conclusion

This project demonstrates three distinct approaches to persistence in Kubernetes, each with different tradeoffs. Manually attaching EBS volumes works but requires knowing the AZ in advance, hardcoding the volumeID, and is limited to a single node. PVCs with a StorageClass abstract all of that away and let Kubernetes handle volume lifecycle automatically. ConfigMaps handle configuration files specifically and support live updates without pod restarts, which makes them useful for config data that changes independently of the application itself.

The practical issues encountered during this project, particularly around the EBS CSI driver requirement on newer EKS versions and the rolling update deadlock with single-attach volumes, reflect real constraints that affect production Kubernetes workloads on AWS.
