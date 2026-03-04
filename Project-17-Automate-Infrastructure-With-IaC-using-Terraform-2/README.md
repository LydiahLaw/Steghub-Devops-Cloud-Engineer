# Project 17 — Automate Infrastructure With IaC Using Terraform Part 2

## Table of Contents

1. [Introduction](#introduction)
2. [Architecture Overview](#architecture-overview)
3. [Prerequisites](#prerequisites)
4. [Project Structure](#project-structure)
5. [Step 1 — Add Private Subnets](#step-1--add-private-subnets)
6. [Step 2 — Create Internet Gateway](#step-2--create-internet-gateway)
7. [Step 3 — Create NAT Gateway](#step-3--create-nat-gateway)
8. [Step 4 — Create Route Tables](#step-4--create-route-tables)
9. [Step 5 — IAM Roles and Instance Profile](#step-5--iam-roles-and-instance-profile)
10. [Step 6 — Security Groups](#step-6--security-groups)
11. [Step 7 — ACM Certificate](#step-7--acm-certificate)
12. [Step 8 — Application Load Balancers](#step-8--application-load-balancers)
13. [Step 9 — User Data Scripts](#step-9--user-data-scripts)
14. [Step 10 — Auto Scaling Groups and SNS](#step-10--auto-scaling-groups-and-sns)
15. [Step 11 — Elastic File System](#step-11--elastic-file-system)
16. [Step 12 — RDS Instance](#step-12--rds-instance)
17. [Step 13 — Variables and Outputs](#step-13--variables-and-outputs)
18. [Step 14 — Plan, Apply, Verify, Destroy](#step-14--plan-apply-verify-destroy)
19. [Conclusion](#conclusion)

---

## Introduction

This project extends the VPC and subnet infrastructure built in Project 16 into a full, production-style AWS environment — entirely automated using Terraform. No manual console clicks. Every resource is declared as code, versioned, and reproducible.

By the end, Terraform provisions private subnets, routing, NAT, IAM, security groups, load balancers, auto scaling groups, shared file storage, and a managed database — all wired together across multiple availability zones.

---

## Architecture Overview

```
Internet
   │
   ▼
External ALB (public subnets)
   │
   ▼
Nginx Reverse Proxy ASG (public subnets)
   │
   ▼
Internal ALB (private subnets 0 & 1)
   │                   │
   ▼                   ▼
WordPress ASG     Tooling ASG
        │
        ▼
Data Layer (private subnets 2 & 3)
├── EFS (shared file storage)
└── RDS MySQL (multi-AZ)
```

Traffic flows from the internet through the external ALB to Nginx, which proxies internally to WordPress or Tooling based on host header. The data layer sits in the deepest private subnets, reachable only from webservers and the bastion host.

---

## Prerequisites

- Terraform >= 1.0 installed
- AWS CLI configured (`aws sts get-caller-identity` returns your account)
- tflint installed
- An AWS key pair created in `eu-central-1`
- An Amazon Linux 2 AMI ID for `eu-central-1`
- Project 16 completed

---

## Project Structure

```
PBL/
├── main.tf
├── variables.tf
├── terraform.tfvars
├── internet_gateway.tf
├── natgateway.tf
├── route_tables.tf
├── roles.tf
├── security.tf
├── cert.tf                  # commented-out placeholder (no domain required)
├── cert_self_signed.tf      # self-signed cert for ALB HTTPS
├── alb.tf
├── asg-bastion-nginx.tf
├── asg-wordpress-tooling.tf
├── efs.tf
├── rds.tf
├── outputs.tf
├── bastion.sh
├── nginx.sh
├── wordpress.sh
├── tooling.sh
└── .gitignore
```

The `.gitignore` excludes:

```
*.tfstate
*.tfstate.backup
.terraform/
.terraform.lock.hcl
terraform.tfvars
crash.log
```

- `*.tfstate` → contains real infrastructure state including sensitive values. Never commit this.
- `terraform.tfvars` → contains your passwords and account number. Anyone cloning creates their own.
- `.terraform/` → provider plugins folder, auto-downloaded by `terraform init`, no need to track.

---

## Step 1 — Add Private Subnets

`main.tf`

Four private subnets are added below the existing public subnets from Project 16, spread across two availability zones. The `terraform {}` block is also added at the top of `main.tf` to declare the `tls` and `random` providers needed later in the project.

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
```

After adding new providers, run `terraform init` to download them:

```bash
terraform init
```

You will see `Installing hashicorp/tls` and `Installing hashicorp/random` in the output.

```hcl
resource "aws_subnet" "private" {
  count             = var.preferred_number_of_private_subnets == null ? length(data.aws_availability_zones.available.names) : var.preferred_number_of_private_subnets
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 2)
  availability_zone = data.aws_availability_zones.available.names[count.index % 2]

  tags = merge(
    var.tags,
    {
      Name = format("PrivateSubnet-%s", count.index)
    },
  )
}
```


**Code — Explanation**
- `count.index + 2` → public subnets already used CIDR indexes 0 and 1; private subnets start at 2 to avoid overlap.
- `count.index % 2` → cycles through 2 AZs (0, 1, 0, 1) so 4 subnets spread evenly for high availability.
- `cidrsubnet()` → automatically generates unique, non-overlapping CIDR blocks from the VPC range.
- `format("PrivateSubnet-%s", count.index)` → gives each subnet a clean unique name: PrivateSubnet-0, PrivateSubnet-1, etc.
- `merge(var.tags, {...})` → applies global tags plus the subnet-specific Name tag in one call.

---

## Step 2 — Create Internet Gateway

`internet_gateway.tf`

```hcl
resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = format("%s-%s!", aws_vpc.main.id, "IG")
    },
  )
}
```

<img width="1366" height="768" alt="internet gateway" src="https://github.com/user-attachments/assets/d9cfea50-52b7-4887-ad2a-e5edaf3e13d0" />

**Code — Explanation**
- Attaches an Internet Gateway to the VPC so public subnets can send and receive traffic from the internet.
- `format("%s-%s!", aws_vpc.main.id, "IG")` → generates a dynamic name using the actual VPC ID at runtime, e.g. `vpc-0abc1234-IG!`.

---

## Step 3 — Create NAT Gateway

`natgateway.tf`

The NAT Gateway allows private instances to initiate outbound internet connections without being reachable from the internet. It sits in a public subnet and uses an Elastic IP.

**Elastic IP**

```hcl
resource "aws_eip" "nat_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.ig]

  tags = merge(
    var.tags,
    {
      Name = format("%s-EIP", var.name)
    },
  )
}
```

**Code — Explanation**
- `domain = "vpc"` → allocates the EIP for use within a VPC (replaces the deprecated `vpc = true`).
- `depends_on` → explicitly tells Terraform the Internet Gateway must exist before the EIP is created.

**NAT Gateway**

```hcl
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = element(aws_subnet.public[*].id, 0)
  depends_on    = [aws_internet_gateway.ig]

  tags = merge(
    var.tags,
    {
      Name = format("%s-Nat", var.name)
    },
  )
}
```


**Code — Explanation**
- `allocation_id` → binds the NAT Gateway to the Elastic IP.
- `subnet_id` → places the NAT Gateway in the first public subnet (must be public to reach the internet).
- `depends_on` → ensures the Internet Gateway is ready before this is created.

---

## Step 4 — Create Route Tables

`route_tables.tf`

Two route tables are created: one for public subnets routing to the Internet Gateway, and one for private subnets routing to the NAT Gateway.

**Private Route Table**

```hcl
resource "aws_route_table" "private-rtb" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = format("%s-Private-Route-Table", var.name)
    },
  )
}

resource "aws_route" "private-rtb-route" {
  route_table_id         = aws_route_table.private-rtb.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private-subnets-assoc" {
  count          = length(aws_subnet.private[*].id)
  subnet_id      = element(aws_subnet.private[*].id, count.index)
  route_table_id = aws_route_table.private-rtb.id
}
```

**Public Route Table**

```hcl
resource "aws_route_table" "public-rtb" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = format("%s-Public-Route-Table", var.name)
    },
  )
}

resource "aws_route" "public-rtb-route" {
  route_table_id         = aws_route_table.public-rtb.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ig.id
}

resource "aws_route_table_association" "public-subnets-assoc" {
  count          = length(aws_subnet.public[*].id)
  subnet_id      = element(aws_subnet.public[*].id, count.index)
  route_table_id = aws_route_table.public-rtb.id
}
```


**Code — Explanation**
- Public subnets route `0.0.0.0/0` to the Internet Gateway — direct, bidirectional internet access.
- Private subnets route `0.0.0.0/0` to the NAT Gateway — outbound only, no inbound from the internet.
- `aws_route_table_association` with `count` links every subnet to its respective table in one block.

---

## Step 5 — IAM Roles and Instance Profile

`roles.tf`

EC2 instances need an IAM Role to interact with AWS services. The role is created, a policy is attached, and an Instance Profile wraps it for EC2 use.

```hcl
resource "aws_iam_role" "ec2_instance_role" {
  name = "ec2_instance_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = merge(var.tags, { Name = "aws assume role" })
}

resource "aws_iam_policy" "policy" {
  name   = "ec2_instance_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["ec2:Describe*"]
      Effect   = "Allow"
      Resource = "*"
    }]
  })

  tags = merge(var.tags, { Name = "aws assume policy" })
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = aws_iam_policy.policy.arn
}

resource "aws_iam_instance_profile" "ip" {
  name = "aws_instance_profile_test"
  role = aws_iam_role.ec2_instance_role.name
}
```


**Code — Explanation**
- **Trust Policy (AssumeRole)** → answers *who can use this role*. Here `ec2.amazonaws.com` is trusted to assume it.
- **Permission Policy** → answers *what the role can do*. Here: describe EC2 resources.
- **Instance Profile** → the wrapper EC2 requires to use an IAM Role. Roles cannot be attached to EC2 directly.
- `aws_iam_role_policy_attachment` → links the permission policy to the role.

---

## Step 6 — Security Groups

```
resource "aws_security_group" "ext-alb-sg" {
  name        = "ext-alb-sg"
  vpc_id      = aws_vpc.main.id
  description = "Allow TLS inbound traffic"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "ext-alb-sg"
    },
  )
}

resource "aws_security_group" "bastion_sg" {
  name        = "vpc_web_sg"
  vpc_id      = aws_vpc.main.id
  description = "Allow incoming HTTP connections."

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "Bastion-SG"
    },
  )
}

resource "aws_security_group" "nginx-sg" {
  name   = "nginx-sg"
  vpc_id = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "nginx-SG"
    },
  )
}

resource "aws_security_group_rule" "inbound-nginx-http" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ext-alb-sg.id
  security_group_id        = aws_security_group.nginx-sg.id
}

resource "aws_security_group_rule" "inbound-bastion-ssh" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion_sg.id
  security_group_id        = aws_security_group.nginx-sg.id
}

resource "aws_security_group" "int-alb-sg" {
  name   = "my-alb-sg"
  vpc_id = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "int-alb-sg"
    },
  )
}

resource "aws_security_group_rule" "inbound-ialb-https" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.nginx-sg.id
  security_group_id        = aws_security_group.int-alb-sg.id
}

resource "aws_security_group" "webserver-sg" {
  name   = "my-asg-sg"
  vpc_id = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "webserver-sg"
    },
  )
}

resource "aws_security_group_rule" "inbound-web-https" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.int-alb-sg.id
  security_group_id        = aws_security_group.webserver-sg.id
}

resource "aws_security_group_rule" "inbound-web-ssh" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion_sg.id
  security_group_id        = aws_security_group.webserver-sg.id
}

resource "aws_security_group" "datalayer-sg" {
  name   = "datalayer-sg"
  vpc_id = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "datalayer-sg"
    },
  )
}

resource "aws_security_group_rule" "inbound-nfs-port" {
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.webserver-sg.id
  security_group_id        = aws_security_group.datalayer-sg.id
}

resource "aws_security_group_rule" "inbound-mysql-bastion" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion_sg.id
  security_group_id        = aws_security_group.datalayer-sg.id
}

resource "aws_security_group_rule" "inbound-mysql-webserver" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.webserver-sg.id
  security_group_id        = aws_security_group.datalayer-sg.id
}
```

<img width="1366" height="768" alt="added securitytf" src="https://github.com/user-attachments/assets/4c56c25f-ef00-4bde-aac3-58e3f357acb7" />

**Code — Explanation**
- `source_security_group_id` → allows traffic from any resource in the referenced security group instead of a hardcoded IP range.
- Each layer only accepts traffic from the layer directly before it — defence in depth.
- `aws_security_group_rule` is used separately (not inline) when the source is another security group, to avoid circular dependency errors.

**Traffic flow:**
```
Internet → ext-alb-sg → nginx-sg → int-alb-sg → webserver-sg → datalayer-sg
                         bastion-sg ─────────────────────────────────────────↗

<img width="1366" height="768" alt="added securitytf" src="https://github.com/user-attachments/assets/7e2e6fc9-ca42-4970-af70-0bed0c71cf34" />



## Step 7 — ACM Certificate

`cert.tf` | `cert_self_signed.tf`

No domain is available for this project. `cert.tf` holds the full ACM + Route 53 configuration as a commented-out placeholder for when a domain is available. A self-signed certificate is generated in `cert_self_signed.tf` so the ALB HTTPS listeners work.

```hcl
resource "tls_private_key" "self_signed" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "self_signed" {
  private_key_pem = tls_private_key.self_signed.private_key_pem

  subject {
    common_name  = "example.com"
    organization = "ACS Dev"
  }

  validity_period_hours = 8760

  allowed_uses = ["key_encipherment", "digital_signature", "server_auth"]
}

resource "aws_acm_certificate" "self_signed" {
  private_key      = tls_private_key.self_signed.private_key_pem
  certificate_body = tls_self_signed_cert.self_signed.cert_pem
}
```

<img width="1366" height="768" alt="self signed" src="https://github.com/user-attachments/assets/bfd7add1-b362-4486-99d2-f11d858d67f9" />

**Code — Explanation**
- `tls_private_key` → generates an RSA key pair managed in Terraform state.
- `tls_self_signed_cert` → creates a certificate signed by the same key (no CA involved).
- `aws_acm_certificate` → imports the cert into ACM so ALB listeners can reference it via `aws_acm_certificate.self_signed.arn`.

---

## Step 8 — Application Load Balancers

`alb.tf`

Two ALBs are created: one external (internet-facing) routing to Nginx, and one internal routing to WordPress or Tooling based on host header.

**External ALB**

```hcl
resource "aws_lb" "ext-alb" {
  name               = "ext-alb"
  internal           = false
  security_groups    = [aws_security_group.ext-alb-sg.id]
  subnets            = [aws_subnet.public[0].id, aws_subnet.public[1].id]
  load_balancer_type = "application"
  ip_address_type    = "ipv4"

  tags = merge(var.tags, { Name = "ACS-ext-alb" })
}

resource "aws_lb_target_group" "nginx-tgt" {
  name        = "nginx-tgt"
  port        = 443
  protocol    = "HTTPS"
  target_type = "instance"
  vpc_id      = aws_vpc.main.id

  health_check {
    path                = "/healthstatus"
    protocol            = "HTTPS"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "nginx-listner" {
  load_balancer_arn = aws_lb.ext-alb.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.self_signed.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx-tgt.arn
  }
}
```

**Internal ALB**

```hcl
resource "aws_lb" "ialb" {
  name            = "ialb"
  internal        = true
  security_groups = [aws_security_group.int-alb-sg.id]
  subnets         = [aws_subnet.private[0].id, aws_subnet.private[1].id]
  load_balancer_type = "application"
  ip_address_type    = "ipv4"

  tags = merge(var.tags, { Name = "ACS-int-alb" })
}

resource "aws_lb_target_group" "wordpress-tgt" {
  name        = "wordpress-tgt"
  port        = 443
  protocol    = "HTTPS"
  target_type = "instance"
  vpc_id      = aws_vpc.main.id

  health_check {
    path                = "/healthstatus"
    protocol            = "HTTPS"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group" "tooling-tgt" {
  name        = "tooling-tgt"
  port        = 443
  protocol    = "HTTPS"
  target_type = "instance"
  vpc_id      = aws_vpc.main.id

  health_check {
    path                = "/healthstatus"
    protocol            = "HTTPS"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "web-listener" {
  load_balancer_arn = aws_lb.ialb.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.self_signed.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress-tgt.arn
  }
}

resource "aws_lb_listener_rule" "tooling-listener" {
  listener_arn = aws_lb_listener.web-listener.arn
  priority     = 99

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tooling-tgt.arn
  }

  condition {
    host_header {
      values = ["tooling.example.com"]
    }
  }
}
```


**Code — Explanation**
- `internal = false` → external ALB gets a public DNS name; `internal = true` → internal ALB is VPC-only.
- Target groups define where the ALB sends traffic and how it health-checks instances.
- The internal ALB listener rule uses `host_header` to route tooling traffic separately from WordPress.
- Three target groups are created: `nginx-tgt`, `wordpress-tgt`, and `tooling-tgt`.

---

## Step 9 — User Data Scripts

`bastion.sh` | `nginx.sh` | `wordpress.sh` | `tooling.sh`

Each launch template references a shell script via `user_data = filebase64("${path.module}/<script>.sh")`. These scripts run automatically on first boot when an EC2 instance is launched by its Auto Scaling Group.

**bastion.sh**

```bash
#!/bin/bash
yum update -y
yum install -y ansible git
```

**nginx.sh**

```bash
#!/bin/bash
yum update -y
yum install -y nginx
systemctl start nginx
systemctl enable nginx
```

**wordpress.sh**

```bash
#!/bin/bash
yum update -y
yum install -y httpd php php-mysqlnd
systemctl start httpd
systemctl enable httpd
```

**tooling.sh**

```bash
#!/bin/bash
yum update -y
yum install -y httpd php php-mysqlnd git
systemctl start httpd
systemctl enable httpd
```

<img width="1366" height="768" alt="bastion sh" src="https://github.com/user-attachments/assets/6c2dac0e-800b-43ad-9898-d4dea10755a6" />
<img width="1366" height="768" alt="nginxsh" src="https://github.com/user-attachments/assets/0350e8c6-a120-4bf2-8c5d-1d9a9e9f477d" />
<img width="1366" height="768" alt="toolingsh" src="https://github.com/user-attachments/assets/4ca5a6d9-3604-4c37-8a23-dd1a9b7032de" />
<img width="1366" height="768" alt="wordpresssh" src="https://github.com/user-attachments/assets/dbe0e09c-a46f-46ba-80f6-e900b91b51ae" />


**Code — Explanation**
- `filebase64()` → reads the `.sh` file and base64-encodes it. AWS decodes and runs it on instance startup.
- `${path.module}` → refers to the directory where your `.tf` files live so Terraform finds the scripts regardless of where you run the command from.
- Each script installs only what that server type needs — Bastion gets Ansible for configuration management, Nginx gets the reverse proxy, WordPress and Tooling get Apache and PHP.
- These are minimal bootstrap scripts for this project. In Project 19 they are replaced with fully configured AMIs built using Packer.

---

## Step 10 — Auto Scaling Groups and SNS

`asg-bastion-nginx.tf` | `asg-wordpress-tooling.tf`

An SNS topic is created first to handle notifications, followed by four Auto Scaling Groups — Bastion and Nginx in public subnets, WordPress and Tooling in private subnets. Each ASG has a Launch Template defining the instance configuration.

**SNS Topic and Notifications**

```hcl
resource "aws_sns_topic" "acs-sns" {
  name = "Default_CloudWatch_Alarms_Topic"
}

resource "aws_autoscaling_notification" "acs_notifications" {
  group_names = [
    aws_autoscaling_group.bastion-asg.name,
    aws_autoscaling_group.nginx-asg.name,
    aws_autoscaling_group.wordpress-asg.name,
    aws_autoscaling_group.tooling-asg.name,
  ]

  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
  ]

  topic_arn = aws_sns_topic.acs-sns.arn
}
```

**Code — Explanation**
- `aws_sns_topic` → creates a notification channel that AWS publishes ASG events to.
- `aws_autoscaling_notification` → subscribes all four ASGs to that topic so any launch, terminate, or error event triggers a notification.
- In production you would attach an email subscription or Lambda to the SNS topic to act on these events.

**Launch Templates and ASGs**

```hcl
resource "aws_launch_template" "bastion-launch-template" {
  image_id               = var.ami
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name               = var.keypair

  iam_instance_profile {
    name = aws_iam_instance_profile.ip.id
  }

  user_data = filebase64("${path.module}/bastion.sh")

  lifecycle {
    create_before_destroy = true
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "bastion-launch-template" })
  }
}

resource "aws_autoscaling_group" "bastion-asg" {
  name                      = "bastion-asg"
  min_size                  = 1
  max_size                  = 2
  desired_capacity          = 1
  health_check_grace_period = 300
  health_check_type         = "ELB"

  vpc_zone_identifier = [aws_subnet.public[0].id, aws_subnet.public[1].id]

  launch_template {
    id      = aws_launch_template.bastion-launch-template.id
    version = "$Latest"
  }
}

# Same pattern repeated for nginx, wordpress, and tooling
# wordpress and tooling ASGs use private subnets instead of public
```

Each ASG is then attached to its respective target group:

```hcl
resource "aws_autoscaling_attachment" "asg_attachment_nginx" {
  autoscaling_group_name = aws_autoscaling_group.nginx-asg.id
  lb_target_group_arn    = aws_lb_target_group.nginx-tgt.arn
}
```


**Code — Explanation**
- `launch_template` → defines the AMI, instance type, security group, key pair, and startup script for instances the ASG creates.
- `user_data = filebase64(...)` → encodes the shell script and passes it to the instance on first boot.
- `create_before_destroy` → Terraform creates the replacement before destroying the old one during updates, avoiding downtime.
- `lb_target_group_arn` in `aws_autoscaling_attachment` → registers ASG instances with the ALB target group automatically.
- `min_size / max_size / desired_capacity` → defines scaling boundaries. The ASG always maintains at least 1 instance.

---

## Step 11 — Elastic File System

`efs.tf`

WordPress and Tooling need shared storage so all instances in their ASGs read and write the same files. EFS is a managed NFS share that multiple EC2 instances can mount simultaneously.

```hcl
resource "aws_kms_key" "ACS-kms" {
  description             = "KMS key for EFS encryption"
  deletion_window_in_days = 10

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "Enable IAM User Permissions"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${var.account_no}:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })
}

resource "aws_kms_alias" "alias" {
  name          = "alias/acs-kms"
  target_key_id = aws_kms_key.ACS-kms.key_id
}

resource "aws_efs_file_system" "ACS-efs" {
  encrypted  = true
  kms_key_id = aws_kms_key.ACS-kms.arn

  tags = merge(var.tags, { Name = "ACS-efs" })
}

resource "aws_efs_mount_target" "subnet-1" {
  file_system_id  = aws_efs_file_system.ACS-efs.id
  subnet_id       = aws_subnet.private[2].id
  security_groups = [aws_security_group.datalayer-sg.id]
}

resource "aws_efs_mount_target" "subnet-2" {
  file_system_id  = aws_efs_file_system.ACS-efs.id
  subnet_id       = aws_subnet.private[3].id
  security_groups = [aws_security_group.datalayer-sg.id]
}

resource "aws_efs_access_point" "wordpress" {
  file_system_id = aws_efs_file_system.ACS-efs.id

  posix_user { gid = 0; uid = 0 }

  root_directory {
    path = "/wordpress"
    creation_info { owner_gid = 0; owner_uid = 0; permissions = 0755 }
  }
}

resource "aws_efs_access_point" "tooling" {
  file_system_id = aws_efs_file_system.ACS-efs.id

  posix_user { gid = 0; uid = 0 }

  root_directory {
    path = "/tooling"
    creation_info { owner_gid = 0; owner_uid = 0; permissions = 0755 }
  }
}
```

<img width="1366" height="768" alt="efs" src="https://github.com/user-attachments/assets/d1d64c88-1c71-4177-8d17-09e7b5e3c60b" />

**Code — Explanation**
- `aws_kms_key` → creates a customer-managed encryption key. All data on EFS is encrypted at rest.
- `aws_kms_alias` → gives the key a human-readable name for easier identification in the console.
- `encrypted = true` + `kms_key_id` → links the EFS volume to the KMS key.
- Two mount targets are created — one in private subnet 2 and one in private subnet 3 — one per AZ for redundancy.
- Access points for WordPress and Tooling create isolated directories (`/wordpress`, `/tooling`) — each app mounts only its own path.

---

## Step 12 — RDS Instance

`rds.tf`

```hcl
resource "aws_db_subnet_group" "ACS-rds" {
  name       = "acs-rds"
  subnet_ids = [aws_subnet.private[2].id, aws_subnet.private[3].id]

  tags = merge(var.tags, { Name = "ACS-rds" })
}

resource "aws_db_instance" "ACS-rds" {
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  db_name                = "acsdb"
  username               = var.master-username
  password               = var.master-password
  parameter_group_name   = "default.mysql8.0"
  db_subnet_group_name   = aws_db_subnet_group.ACS-rds.name
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.datalayer-sg.id]
  multi_az               = true
}
```


**Code — Explanation**
- `aws_db_subnet_group` → tells RDS which subnets it can use. Private subnets 2 and 3 keep the database in the data layer, unreachable from the internet.
- `multi_az = true` → AWS provisions a standby replica in a second AZ and fails over automatically if the primary has issues.
- `skip_final_snapshot = true` → allows `terraform destroy` to delete the instance without requiring a final backup snapshot.
- `sensitive = true` on the password variable → Terraform never prints it in plan or apply output.
- MySQL `8.0` and `db.t3.micro` are used instead of the guide's `5.7` and `db.t2.micro` — both are deprecated or unavailable in newer regions.

---

## Step 13 — Variables and Outputs

`variables.tf` declares all input variables. `terraform.tfvars` provides the actual values and is excluded from version control via `.gitignore`.

Key variables added in this project:

| Variable | Type | Purpose |
|---|---|---|
| `preferred_number_of_private_subnets` | number | How many private subnets to create |
| `ami` | string | AMI ID for launch templates |
| `keypair` | string | EC2 key pair name |
| `account_no` | string | AWS account number for KMS policy |
| `master-username` | string | RDS admin username |
| `master-password` | string (sensitive) | RDS admin password |
| `tags` | map(string) | Default tags applied to all resources |

`outputs.tf` prints useful values after apply:

```hcl
output "alb_dns_name" {
  description = "DNS name of the external Application Load Balancer"
  value       = aws_lb.ext-alb.dns_name
}

output "alb_target_group_arn" {
  description = "ARN of the Nginx target group"
  value       = aws_lb_target_group.nginx-tgt.arn
}

output "vpc_id" {
  description = "The ID of the main VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_ip" {
  description = "Public IP of the NAT Gateway"
  value       = aws_eip.nat_eip.public_ip
}
```


---

## Step 14 — Plan, Apply, Verify, Destroy

**Validate and plan:**

```bash
terraform fmt
terraform validate
tflint --init && tflint
terraform plan
```

The plan should show approximately 60+ resources to create. Take a screenshot of the summary line before applying.

**Apply:**

```bash
terraform apply
```

Type `yes` when prompted. Apply takes 10–20 minutes — RDS and NAT Gateway are the slowest.

**Verify in the AWS Console (`eu-central-1`):**

| Service | What to check |
|---|---|
| VPC | CIDR `172.16.0.0/16` present |
| Subnets | 2 public + 4 private = 6 total |
| Internet Gateway | Attached to VPC |
| NAT Gateway | Status: Available |
| Load Balancers | `ext-alb` and `ialb` |
| Target Groups | `nginx-tgt`, `wordpress-tgt`, `tooling-tgt` |
| Auto Scaling Groups | All 4 present |
| EFS | File system visible |
| RDS | Instance visible |

<img width="1366" height="768" alt="last plan" src="https://github.com/user-attachments/assets/51cc90e2-f7e2-45df-b427-5bba5db095aa" />
<img width="1366" height="768" alt="infra created" src="https://github.com/user-attachments/assets/aa87bd9a-6924-4ad1-89de-9a8799688993" />
<img width="1366" height="768" alt="vpc created" src="https://github.com/user-attachments/assets/8ef9cc41-89d0-4d47-b615-296f30f4b09e" />
<img width="1366" height="768" alt="confirmed infra" src="https://github.com/user-attachments/assets/25acb142-9afc-429c-b38a-2683fe3acb93" />
<img width="1366" height="768" alt="loadbalancers" src="https://github.com/user-attachments/assets/08193965-ba37-41a7-9019-47cb6e17506d" />
<img width="1366" height="768" alt="subnets created" src="https://github.com/user-attachments/assets/bcfbdf7a-f5e4-427b-ba6c-8530516ff4d4" />




**Destroy immediately after verification:**

```bash
terraform destroy
```
<img width="1366" height="768" alt="everything destroyed" src="https://github.com/user-attachments/assets/05262acc-45df-4251-918e-67392ca8b1ec" />

NAT Gateways and RDS are not free-tier. Leaving them running accumulates charges quickly.

---

## Conclusion

This project moves from manually creating individual resources to defining an entire multi-tier AWS architecture as reusable, version-controlled infrastructure code. Every component — networking, compute, security, storage, and database — is wired together through Terraform references rather than hardcoded values, making the setup reproducible across environments.

The next step (Project 18) refactors this flat file structure into Terraform Modules, eliminating repetition and making the codebase maintainable at scale.

---

*Tools used: Terraform · AWS · tflint · Git*
