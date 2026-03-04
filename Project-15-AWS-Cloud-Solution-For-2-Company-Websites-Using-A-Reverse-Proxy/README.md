# AWS Multi-Website Infrastructure with NGINX Reverse Proxy

## Table of Contents
- [Project Overview](#project-overview)
- [Architecture Diagram](#architecture-diagram)
- [Phase 1: AWS Account Setup](#phase-1-aws-account-setup)
- [Phase 2: VPC and Networking](#phase-2-vpc-and-networking)
- [Phase 3: Security Groups](#phase-3-security-groups)
- [Phase 4: Compute Resources - NGINX](#phase-4-compute-resources---nginx)
- [Phase 5: Compute Resources - Bastion](#phase-5-compute-resources---bastion)
- [Phase 6: Compute Resources - Webservers](#phase-6-compute-resources---webservers)
- [Phase 7: Load Balancers](#phase-7-load-balancers)
- [Phase 8: Storage and Database](#phase-8-storage-and-database)
- [Phase 9: NGINX Reverse Proxy Configuration](#phase-9-nginx-reverse-proxy-configuration)
- [Testing](#testing)
- [Cleanup](#cleanup)

---

## Project Overview

This project implements a highly available, secure, and scalable AWS infrastructure to host two company websites (WordPress and Tooling) behind an NGINX reverse proxy.

**Key Features:**
- Multi-AZ deployment across 2 Availability Zones
- Auto Scaling Groups for all compute tiers
- NGINX reverse proxy for centralized routing
- Private subnet isolation for security
- Amazon EFS for shared storage
- Amazon RDS Multi-AZ for database

**Architecture:**
- VPC with 6 subnets (2 public, 2 private app, 2 private data)
- 1 Public ALB → NGINX layer
- 2 Internal ALBs → WordPress and Tooling webservers
- Bastion hosts for secure SSH access

---

## Architecture Diagram

<img width="1024" height="955" alt="architecture" src="https://github.com/user-attachments/assets/cefc6542-c374-4311-bb31-6ed099ef632d" />

---

## Phase 1: AWS Account Setup

### 1. Create AWS Master Account
- Sign up at https://aws.amazon.com
- Complete billing and identity verification
- This becomes the Root Account for organization management

### 2. Enable AWS Organizations
- Navigate to AWS Organizations
- Create organization with "All features"

### 3. Create Organizational Unit (OU)
- Name: `Dev`
- This OU contains development AWS accounts

### 4. Create DevOps Sub-Account
- Account name: `DevOps`
- Email: (Different from master account)
- IAM role: `OrganizationAccountAccessRole`


### 5. Move DevOps Account to Dev OU
- Select DevOps account → Move to `Dev` OU

<img width="1366" height="768" alt="create org unit" src="https://github.com/user-attachments/assets/34d58b25-462c-4c25-8dde-a6034a2f2568" />

**⚠️ All infrastructure deployed in DevOps account, not Master account.**

---

## Phase 2: VPC and Networking

### Network Design

| Subnet Type | AZ-A | AZ-B |
|-------------|------|------|
| Public | 10.0.1.0/24 | 10.0.3.0/24 |
| Private App | 10.0.2.0/24 | 10.0.4.0/24 |
| Private Data | 10.0.5.0/24 | 10.0.6.0/24 |
| **VPC CIDR** | **10.0.0.0/16** | |

### 1. Create VPC
- Name: `multiweb-vpc`
- CIDR: `10.0.0.0/16`
- Enable DNS hostnames and DNS resolution

<img width="1366" height="768" alt="vpc created 1" src="https://github.com/user-attachments/assets/9d35e7b7-275b-4849-ad96-0c8d8fc95c97" />

### 2. Create Subnets
Create all 6 subnets according to the network design table above.

**Enable auto-assign public IPv4 on both public subnets.**

<img width="1366" height="768" alt="subnets created" src="https://github.com/user-attachments/assets/87b60848-eacc-41b5-8c03-fe587e65b39d" />

### 3. Create Route Table for Public Subnets
- Name: `rtb-public`
- Associate with both public subnets (`public-subnet-az-a` & `public-subnet-az-b`)


### 4. Create Route Table for Private Subnets
- Name: `rtb-private`
- Associate with:
  - Private App Subnets (10.0.2.0/24 & 10.0.4.0/24)
  - Private Data Subnets (10.0.5.0/24 & 10.0.6.0/24)

<img width="1366" height="768" alt="private routetable" src="https://github.com/user-attachments/assets/05bd7125-766d-41c1-b993-88d947208248" />

### 5. Create Internet Gateway
- Name: `igw-multiweb`
- Attach to VPC `multiweb-vpc`

<img width="1366" height="768" alt="attach internet gateway" src="https://github.com/user-attachments/assets/6e81c227-d1a1-422a-996d-92f08cb4dd99" />

### 6. Update Public Route Table
In `rtb-public`, add route:
- Destination: `0.0.0.0/0`
- Target: `igw-multiweb`

This enables internet access for public subnets.


### 7. Allocate Elastic IPs
Allocate 3 Elastic IPs:
- `EIP-NAT` (for NAT Gateway)
- `EIP-Bastion-A`
- `EIP-Bastion-B`

<img width="1366" height="768" alt="elasticips allocated" src="https://github.com/user-attachments/assets/8a2efc0e-6397-44a7-8024-22710f06ce3d" />

### 8. Create NAT Gateway
- Name: `nat-gateway-az-a`
- Subnet: `public-subnet-az-a`
- Elastic IP: `EIP-NAT`

**Update `rtb-private` with route:**
- Destination: `0.0.0.0/0`
- Target: `nat-gateway-az-a`

This provides outbound internet access for private subnets.

<img width="1366" height="768" alt="natgateway created" src="https://github.com/user-attachments/assets/5cbc08d0-f5e1-4b41-bf5f-d4e29635ca77" />

---

## Phase 3: Security Groups

Created 7 security groups for network segmentation and access control:

### 1. sg-alb-public
Allow HTTP/HTTPS from internet to public ALB

**Inbound:**
- HTTP (80) from 0.0.0.0/0
- HTTPS (443) from 0.0.0.0/0

### 2. sg-nginx
Allow traffic from ALB and SSH from Bastion

**Inbound:**
- HTTP (80) from `sg-alb-public`
- HTTPS (443) from `sg-alb-public`
- SSH (22) from `sg-bastion`

### 3. sg-bastion
SSH access from admin IP only

**Inbound:**
- SSH (22) from your IP range

*Get your IP from https://checkip.amazonaws.com*

### 4. sg-alb-internal
Allow traffic from NGINX to internal ALBs

**Inbound:**
- HTTP (80) from `sg-nginx`

### 5. sg-webservers
Allow traffic from internal ALB and SSH from Bastion

**Inbound:**
- HTTP (80) from `sg-alb-internal`
- HTTPS (443) from `sg-alb-internal`
- SSH (22) from `sg-bastion`

### 6. sg-rds
Allow MySQL from webservers only

**Inbound:**
- MYSQL/Aurora (3306) from `sg-webservers`

### 7. sg-efs
Allow NFS from NGINX and webservers

**Inbound:**
- NFS (2049) from `sg-nginx`
- NFS (2049) from `sg-webservers`

<img width="1366" height="768" alt="security grroups created" src="https://github.com/user-attachments/assets/7f86ec4a-49d4-49f5-851e-b152f32b08e9" />

---

## Phase 4: Compute Resources - NGINX

### 1. Launch Base NGINX Instance
- AMI: Amazon Linux 2023
- Instance type: t2.micro
- Key pair: `multiweb-keypair` (create and download)
- Subnet: `public-subnet-az-a`
- Security group: `sg-nginx`
- User data: Install basic packages

```bash
#!/bin/bash
yum update -y
yum install python3 chrony net-tools vim wget telnet htop -y
```


### 2. Create NGINX AMI
- Name: `nginx-ami-v1`
- Terminate original instance after AMI creation


### 3. Create NGINX Launch Template
- Name: `lt-nginx`
- AMI: `nginx-ami-v1`
- User data: Install and start NGINX

```bash
#!/bin/bash
yum update -y
yum install nginx -y
systemctl enable nginx
systemctl start nginx
```
<img width="1366" height="768" alt="launchtemplate nginx" src="https://github.com/user-attachments/assets/9664cd8f-ca1a-4f48-b4e5-ad18a5e59185" />

### 4. Create NGINX Target Group
- Name: `tg-nginx`
- Protocol: HTTP | Port: 80
- Health check path: `/healthstatus`

### 5. Create NGINX Auto Scaling Group
- Name: `asg-nginx`
- Launch template: `lt-nginx`
- Subnets: Both public subnets
- Target group: `tg-nginx`
- Desired/Min/Max: 2/2/4
- Scaling policy: CPU 90%
- SNS topic: `sns-nginx-scaling`

---

## Phase 5: Compute Resources - Bastion

### 1. Launch Base Bastion Instance
- AMI: Amazon Linux 2023
- Subnet: `public-subnet-az-a`
- Security group: `sg-bastion`

### 2. Associate Elastic IP
Attach `EIP-Bastion-A` to the bastion instance

### 3. Create Bastion AMI
- Name: `bastion-ami-v1`
- Terminate original instance

### 4. Create Bastion Launch Template
- Name: `lt-bastion`
- User data: Install Ansible and Git

```bash
#!/bin/bash
yum update -y
yum install ansible git -y
```

### 5. Create Bastion Target Group
- Name: `tg-bastion`
- Protocol: TCP | Port: 22

### 6. Create Bastion Auto Scaling Group
- Name: `asg-bastion`
- Subnets: Both public subnets
- Desired/Min/Max: 2/2/4

<img width="1366" height="768" alt="bastionautoscaling" src="https://github.com/user-attachments/assets/554381f6-953b-4cda-b042-45631bedd252" />


---

## Phase 6: Compute Resources - Webservers

### 1. Launch WordPress Base Instance
- AMI: Amazon Linux 2023
- Subnet: `private-app-subnet-az-a`
- Security group: `sg-webservers`
- User data: Install Apache and PHP

```bash
#!/bin/bash
yum update -y
yum install python3 chrony net-tools vim wget telnet htop php php-cli php-common php-mysqlnd -y
```

### 2. Create WordPress AMI
- Name: `wordpress-ami-v1`

### 3. Launch Tooling Base Instance
Same as WordPress, create AMI: `tooling-ami-v1`

### 4. Create WordPress Launch Template
- Name: `lt-wordpress`
- AMI: `wordpress-ami-v1`
- User data: Install Apache, start service, create test page

```bash
#!/bin/bash
yum update -y
yum install httpd php php-mysqlnd -y
systemctl enable httpd
systemctl start httpd

cat > /var/www/html/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head><title>WordPress Server</title></head>
<body>
<h1>WordPress Server Running</h1>
<p>Health check: OK</p>
</body>
</html>
EOF

chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html
systemctl restart httpd
```

### 5. Create Tooling Launch Template
- Name: `lt-tooling`
- Similar user data with Tooling content

### 6. Create Target Groups
- WordPress: `tg-wordpress` (HTTP:80)
- Tooling: `tg-tooling` (HTTP:80)

### 7. Create Auto Scaling Groups
- WordPress: `asg-wordpress` (private app subnets, 2/2/4)
- Tooling: `asg-tooling` (private app subnets, 2/2/4)

<img width="1366" height="768" alt="autoscaling groups" src="https://github.com/user-attachments/assets/b7d6a118-f415-4d50-b929-832bb0e99798" />

<img width="1366" height="768" alt="alltarget groups created" src="https://github.com/user-attachments/assets/b210b38f-64dc-4119-9dc9-6af2ebcb3cff" />


---

## Phase 7: Load Balancers

### 1. Create Public ALB
- Name: `alb-nginx-public`
- Scheme: **Internet-facing**
- Subnets: Both public subnets
- Security group: `sg-alb-public`
- Listener: HTTP:80 → `tg-nginx`

**Save the ALB DNS name for accessing websites**


### 2. Create Internal ALB for WordPress
- Name: `alb-wordpress-internal`
- Scheme: **Internal**
- Subnets: Both private app subnets
- Security group: `sg-alb-internal`
- Listener: HTTP:80 → `tg-wordpress`

**Save DNS name for NGINX configuration**

### 3. Create Internal ALB for Tooling
- Name: `alb-tooling-internal`
- Scheme: **Internal**
- Subnets: Both private app subnets
- Security group: `sg-alb-internal`
- Listener: HTTP:80 → `tg-tooling`

**Save DNS name for NGINX configuration**

<img width="1366" height="768" alt="all loadbalancers created" src="https://github.com/user-attachments/assets/248e84c6-e533-4e37-89e2-b1cab0ea9b6d" />

---

## Phase 8: Storage and Database

### 1. Create KMS Key
- Name: `kms-rds-key`
- Type: Symmetric
- Usage: Encrypt and decrypt

### 2. Create RDS Subnet Group
- Name: `rds-subnet-group`
- Subnets: Both private data subnets

### 3. Create RDS Database
- Engine: MySQL 8.0.x
- Template: Dev/Test
- DB identifier: `multiweb-database`
- Username: `admin`
- Instance class: db.t3.micro
- VPC: multiweb-vpc
- Subnet group: `rds-subnet-group`
- Security group: `sg-rds`
- Encryption: `kms-rds-key`

<img width="1366" height="768" alt="kms created" src="https://github.com/user-attachments/assets/2e0d5fa6-8dce-43a9-a6c9-e10c1f0dba8c" />

### 4. Create EFS File System
- Name: `efs-shared-content`
- VPC: multiweb-vpc
- Mount targets: Both private data subnets
- Security group: `sg-efs`

<img width="1366" height="768" alt="efs system created" src="https://github.com/user-attachments/assets/b66053cc-d7d3-478e-ac0f-db4308ddf527" />

---

## Phase 9: NGINX Reverse Proxy Configuration

This phase configures NGINX to route traffic to internal load balancers.

### 1. Copy SSH Key to Bastion

```bash
scp -i multiweb-keypair.pem multiweb-keypair.pem ec2-user@<BASTION-PUBLIC-IP>:/home/ec2-user/
```

### 2. SSH to Bastion

```bash
ssh -i multiweb-keypair.pem ec2-user@<BASTION-PUBLIC-IP>
chmod 400 multiweb-keypair.pem
```

### 3. SSH to NGINX Instances

From bastion, SSH to each NGINX instance using their private IPs.

### 4. Configure NGINX Reverse Proxy

On **both NGINX instances**, perform these steps:

**Comment out default server block:**
```bash
sudo sed -i '37,60s/^/#/' /etc/nginx/nginx.conf
```

**Create reverse proxy configuration:**
```bash
sudo vim /etc/nginx/conf.d/reverse-proxy.conf
```

**Add this configuration** (replace ALB DNS names with your actual values):

```nginx
upstream wordpress {
    server internal-alb-wordpress-internal-XXXXXXXXXX.us-east-1.elb.amazonaws.com:80;
}

upstream tooling {
    server internal-alb-tooling-internal-XXXXXXXXXX.us-east-1.elb.amazonaws.com:80;
}

server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    location = /healthstatus {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }

    location /tooling/ {
        proxy_pass http://tooling/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /tooling {
        proxy_pass http://tooling/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location / {
        proxy_pass http://wordpress;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

**Test and restart:**
```bash
sudo nginx -t
sudo systemctl restart nginx
```

<img width="1366" height="768" alt="proxy config" src="https://github.com/user-attachments/assets/0746509c-d89e-40bd-8c0d-fdb15c877c99" />

---

## Testing

### Verify Target Groups
All target groups should show healthy:
- `tg-nginx`: 2/2 healthy
- `tg-wordpress`: 2/2 healthy
- `tg-tooling`: 2/2 healthy


### Test WordPress

```
http://<ALB-PUBLIC-DNS>/
```

Should display WordPress page.

<img width="1366" height="768" alt="wordpress server running" src="https://github.com/user-attachments/assets/d43d3b7b-5169-4530-b0fd-d992a83814d2" />

### Test Tooling

```
http://<ALB-PUBLIC-DNS>/tooling
```

Should display Tooling page.

<img width="1366" height="768" alt="tooling sever up" src="https://github.com/user-attachments/assets/b3e772bb-38cc-4022-89da-53977e7701aa" />

---

## Cleanup

**Delete resources in this order to avoid dependency errors:**

1. Auto Scaling Groups (all 4)
2. Load Balancers (all 3)
3. Target Groups
4. RDS Database
5. EFS File System
6. NAT Gateway
7. Elastic IPs (release all 3)
8. Launch Templates
9. AMIs (deregister)
10. Snapshots
11. Security Groups
12. Subnets
13. Route Tables
14. Internet Gateway
15. VPC

---

## Notes

**Domain Configuration:** This project was completed without a custom domain as Freenom no longer offers free domains. Access is via ALB DNS name instead of a custom domain.

**Production Considerations:** For production deployment with a registered domain:
- Create Route 53 hosted zone
- Obtain SSL/TLS certificates from ACM
- Configure HTTPS listeners on ALBs
- Create DNS A records pointing to ALB

---

## Conclusion

Successfully implemented a highly available, secure, and scalable multi-tier web application architecture on AWS with:
- Multi-AZ deployment for reliability
- Auto Scaling for elasticity
- NGINX reverse proxy for centralized routing
- Private subnet isolation for security
- Managed database and shared storage
