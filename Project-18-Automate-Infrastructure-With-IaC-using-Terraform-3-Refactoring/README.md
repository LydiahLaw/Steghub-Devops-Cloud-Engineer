# Automate Infrastructure With IaC Using Terraform Part 3 (Refactoring)

## Table of Contents

1. [Project Overview](#project-overview)
2. [Objectives](#objectives)
3. [Prerequisites](#prerequisites)
4. [Architecture](#architecture)
5. [Phase 1 — S3 Remote Backend and State Locking](#phase-1--s3-remote-backend-and-state-locking)
6. [Phase 2 — Advanced Terraform Concepts](#phase-2--advanced-terraform-concepts)
   - [Dynamic Blocks for Security Groups](#dynamic-blocks-for-security-groups)
   - [EC2 AMI Selection with Map and Lookup](#ec2-ami-selection-with-map-and-lookup)
   - [Conditional Expressions](#conditional-expressions)
7. [Phase 3 — Module Refactoring](#phase-3--module-refactoring)
   - [Module Structure](#module-structure)
   - [VPC Module](#vpc-module)
   - [Security Module](#security-module)
   - [ALB Module](#alb-module)
   - [Autoscaling Module](#autoscaling-module)
   - [EFS Module](#efs-module)
   - [RDS Module](#rds-module)
   - [Compute Module](#compute-module)
8. [Root Configuration](#root-configuration)
9. [Verification and Pro Tips](#verification-and-pro-tips)
10. [Key Decisions and Deviations](#key-decisions-and-deviations)
11. [How to Use](#how-to-use)
12. [Blockers and Known Limitations](#blockers-and-known-limitations)
13. [Conclusion](#conclusion)

---

## Project Overview

This project builds on the AWS infrastructure automated in Projects 16 and 17 using Terraform. The focus shifts from building infrastructure to improving how that infrastructure code is structured, stored, and maintained.

Three major improvements are made:

- Terraform state is moved from local storage to a remote S3 backend with DynamoDB state locking, enabling team collaboration
- The flat collection of `.tf` files is broken into a proper module structure, making the codebase reusable and easier to navigate
- Advanced Terraform features — dynamic blocks, map/lookup functions, and conditional expressions — are applied to reduce repetition and make the configuration region-aware

The infrastructure itself remains the same multi-tier AWS architecture from Project 17: VPC, public and private subnets, NAT Gateway, ALBs, Auto Scaling Groups, EFS, and RDS MySQL.

---

## Objectives

- Configure S3 as a remote Terraform backend with versioning and encryption
- Enable state locking using DynamoDB to prevent concurrent state corruption
- Refactor repetitive security group ingress rules using Terraform dynamic blocks
- Make AMI selection region-aware using Terraform map variables and the `lookup()` function
- Apply conditional expressions for dynamic resource counts
- Break all infrastructure resources into logical child modules
- Separate providers, backend, data sources, and outputs into dedicated root-level files

---

## Prerequisites

- Completed Project 17 (Terraform multi-tier AWS infrastructure)
- Terraform >= 1.0 installed
- AWS CLI configured with appropriate credentials
- AWS region: `eu-central-1`
- An existing key pair named `terraform` in AWS EC2
- tflint installed for linting

---

## Architecture

The refactored codebase provisions the same infrastructure as Project 17:

- **VPC** with CIDR `172.16.0.0/16`
- **2 public subnets** across 2 availability zones
- **4 private subnets** across 2 availability zones
- **Internet Gateway** for public subnet outbound traffic
- **NAT Gateway** with Elastic IP for private subnet outbound traffic
- **Route tables** for public and private subnets
- **6 security groups** with rules managed via dynamic blocks and `aws_security_group_rule` resources
- **External ALB** serving HTTPS traffic to Nginx
- **Internal ALB** routing traffic to WordPress and Tooling
- **Self-signed ACM certificate** (no domain available)
- **4 Auto Scaling Groups**: bastion, nginx, wordpress, tooling
- **EFS** with KMS encryption and access points for WordPress and Tooling
- **RDS MySQL 8.0** (`db.t3.micro`, Multi-AZ)
- **IAM role and instance profile** for EC2 instances

---

## Phase 1 — S3 Remote Backend and State Locking

### Why remote backend?

By default Terraform stores state locally in `terraform.tfstate`. This works for solo learning but breaks in a team — no one else can access your state, and two engineers running Terraform simultaneously can corrupt it.

Moving state to S3 solves both problems. Every engineer reads and writes the same state file. DynamoDB adds a lock so only one operation can modify state at a time.

### S3 bucket configuration

The bucket is created with three separate resources following AWS provider v4+ conventions — versioning, encryption, and public access block are each their own resource rather than nested blocks inside `aws_s3_bucket`:

```hcl
resource "aws_s3_bucket" "terraform_state" {
  bucket = "lydiah-dev-terraform-bucket"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

`prevent_destroy = true` protects the bucket from accidental deletion via `terraform destroy` — since the bucket holds the state file, losing it would mean losing all knowledge of what Terraform has provisioned.

<img width="1366" height="768" alt="s3 bucket being create" src="https://github.com/user-attachments/assets/4bebf61e-71f4-46f0-83dc-695e1ee0a043" />


### DynamoDB state locking

```hcl
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
```

When any Terraform operation that writes state begins, it creates a `LockID` entry in this table. Any other operation attempting to run simultaneously will see the lock and wait. The lock is released when the operation completes.
<img width="1366" height="768" alt="dynamodb created" src="https://github.com/user-attachments/assets/284f816f-cd58-4656-89a6-47a279822f99" />


### Backend configuration

The S3 bucket and DynamoDB table must exist before configuring the backend. The workflow is:

1. Add the S3 and DynamoDB resource blocks
2. Run `terraform apply` to create them
3. Add the `backend "s3"` block to the `terraform {}` block
4. Run `terraform init` — Terraform detects the backend change and migrates local state to S3

```hcl
terraform {
  backend "s3" {
    bucket         = "lydiah-dev-terraform-bucket"
    key            = "global/s3/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

After migration, the local `terraform.tfstate` file is empty. The real state lives in S3 at `global/s3/terraform.tfstate`.
<img width="1366" height="768" alt="object created" src="https://github.com/user-attachments/assets/f43ca16a-def7-48e6-8c1e-5caf2c7c7c91" />

---

## Phase 2 — Advanced Terraform Concepts

### Dynamic Blocks for Security Groups

The `ext-alb-sg` and `bastion_sg` security groups originally had repeated `ingress {}` blocks — one per port. Dynamic blocks replace this pattern by iterating over a list variable.

**Before (repetitive):**
```hcl
ingress {
  description = "HTTP"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

ingress {
  description = "HTTPS"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
```

**After (dynamic block):**
```hcl
dynamic "ingress" {
  for_each = var.ext_alb_ingress_rules
  content {
    description = ingress.value.description
    from_port   = ingress.value.from_port
    to_port     = ingress.value.to_port
    protocol    = ingress.value.protocol
    cidr_blocks = ingress.value.cidr_blocks
  }
}
```
<img width="1366" height="768" alt="dynamic" src="https://github.com/user-attachments/assets/ecb27be1-f8f9-4de3-8f3d-2505cbfe6b75" />

The rules are defined as a list of objects in `modules/security/variables.tf`:

```hcl
variable "ext_alb_ingress_rules" {
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = [
    {
      description = "HTTP"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "HTTPS"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}
```

Adding a new port in future only requires a new entry in the variable list — the resource block itself does not change.
<img width="1366" height="768" alt="dynamic added in variables" src="https://github.com/user-attachments/assets/6f519879-b306-4349-9ca6-fc388c6e208b" />


### EC2 AMI Selection with Map and Lookup

AMIs are regional — an AMI ID valid in `eu-central-1` does not exist in `us-east-1`. Hardcoding a single AMI means the configuration breaks if the region changes.

A `map` variable holds AMI IDs per region:

```hcl
variable "images" {
  type        = map(string)
  description = "AMI IDs per region"
  default = {
    eu-central-1 = "ami-0c42fad2ea005202d"
    us-east-1    = "ami-0c55b159cbfafe1f0"
    us-west-2    = "ami-0fcf52bcf5db7b003"
  }
}
```
<img width="1366" height="768" alt="ami added in variables" src="https://github.com/user-attachments/assets/9a5da641-4fc1-4578-8fde-fa4f8cf13c63" />


The `lookup()` function selects the correct AMI based on the current region, with `var.ami` as a fallback:

```hcl
ami = lookup(var.images, var.region, var.ami)
```

`lookup(map, key, default)` — if `var.region` exists as a key in `var.images`, use that value. If not, fall back to `var.ami`.
<img width="1366" height="768" alt="autoscaling module chnaged" src="https://github.com/user-attachments/assets/62b3c301-6351-41f4-8198-dcbfe3b2fe45" />


### Conditional Expressions

Conditional expressions use the ternary syntax: `condition ? true_val : false_val`

Applied in the subnet resources to make the count dynamic:

```hcl
count = var.preferred_number_of_public_subnets == null ? length(var.availability_zones) : var.preferred_number_of_public_subnets
```

If `preferred_number_of_public_subnets` is null, Terraform creates one subnet per available AZ. Otherwise it uses the specified number. This prevents hardcoding subnet counts while still allowing explicit control when needed.

---

## Phase 3 — Module Refactoring

### Module Structure

All resources from the flat Project 17 file structure are moved into logical child modules:

```
PBL/
├── modules/
│   ├── ALB/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── autoscaling/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── bastion.sh
│   │   ├── nginx.sh
│   │   ├── wordpress.sh
│   │   └── tooling.sh
│   ├── compute/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── EFS/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── RDS/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── security/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── VPC/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── main.tf
├── backend.tf
├── providers.tf
├── data.tf
├── outputs.tf
├── roles.tf
├── terraform.tfvars
└── variables.tf
```

The root `main.tf` contains only `module` blocks — no resource blocks. All resource blocks live inside their respective modules.

`roles.tf` remains at root level because IAM roles and instance profiles are cross-cutting — the instance profile is referenced directly by the autoscaling module call as `aws_iam_instance_profile.ip.name`.

### VPC Module

**Contains:** `aws_vpc`, `aws_subnet` (public and private), `aws_internet_gateway`, `aws_eip`, `aws_nat_gateway`, `aws_route_table` (public and private), `aws_route`, `aws_route_table_association`

**Key input variables:** `vpc_cidr`, `availability_zones`, `preferred_number_of_public_subnets`, `preferred_number_of_private_subnets`, `tags`, `name`

**Outputs:** `vpc_id`, `public_subnets-1`, `public_subnets-2`, `private_subnets-1` through `private_subnets-4`, `internet_gateway`, `nat_gateway_ip`

The `availability_zones` variable receives `data.aws_availability_zones.available.names` from the root — data sources live at root level and are passed into modules as variables rather than called inside modules.

<img width="1366" height="768" alt="vpc variables" src="https://github.com/user-attachments/assets/a966c275-a181-4004-8b73-094008d3aa83" />


### Security Module

**Contains:** All 6 `aws_security_group` resources and all `aws_security_group_rule` resources

**Dynamic blocks applied to:** `ext-alb-sg` (HTTP + HTTPS ingress) and `bastion_sg` (SSH ingress)

**Key input variables:** `vpc_id`, `tags`, `ext_alb_ingress_rules`, `bastion_ingress_rules`

**Outputs:** `ALB_sg`, `bastion_sg`, `nginx_sg`, `internal_alb_sg`, `webserver_sg`, `datalayer_sg`
<img width="1366" height="768" alt="moved sectf to securitymodules" src="https://github.com/user-attachments/assets/fd5c279a-7273-47df-98dc-4f8a37947fc1" />

### ALB Module

**Contains:** `tls_private_key`, `tls_self_signed_cert`, `aws_acm_certificate` (self-signed), both `aws_lb` resources (external and internal), all `aws_lb_target_group` resources, all `aws_lb_listener` resources, `aws_lb_listener_rule`

**Key input variables:** `vpc_id`, `public_subnets`, `private_subnets`, `ALB_sg`, `internal_alb_sg`, `tags`

**Outputs:** `alb_dns_name`, `alb_target_group_arn`, `wordpress_tgt_arn`, `tooling_tgt_arn`, `ext_alb_arn`, `int_alb_arn`
<img width="1366" height="768" alt="ALBmaintf" src="https://github.com/user-attachments/assets/515765bd-1283-48f6-8978-fefa1b8b168d" />

### Autoscaling Module

**Contains:** `aws_sns_topic`, `aws_autoscaling_notification`, `random_shuffle`, 4 `aws_launch_template` resources (bastion, nginx, wordpress, tooling), 4 `aws_autoscaling_group` resources, 3 `aws_autoscaling_attachment` resources

**Key input variables:** `ami`, `keypair`, `bastion_sg`, `nginx_sg`, `webserver_sg`, `public_subnets`, `private_subnets`, `nginx_alb_tgt`, `wordpress_alb_tgt`, `tooling_alb_tgt`, `instance_profile`, `availability_zones`, `tags`

Shell scripts (`bastion.sh`, `nginx.sh`, `wordpress.sh`, `tooling.sh`) are copied into this module directory so `filebase64("${path.module}/script.sh")` resolves correctly within the module context.
<img width="1366" height="768" alt="copied script files to autoscaling" src="https://github.com/user-attachments/assets/fe4f8629-815c-4f8f-8bfd-f7595b60e8a4" />

### EFS Module

**Contains:** `aws_kms_key`, `aws_kms_alias`, `aws_efs_file_system`, 2 `aws_efs_mount_target` resources (one per data layer subnet), 2 `aws_efs_access_point` resources (wordpress and tooling)

**Key input variables:** `subnet_ids`, `security_group`, `account_no`, `tags`

**Outputs:** `efs_id`, `efs_dns`
<img width="1366" height="768" alt="Screenshot (1583)" src="https://github.com/user-attachments/assets/0559ce85-bd81-4029-9e84-12c349a673be" />


### RDS Module

**Contains:** `aws_db_subnet_group`, `aws_db_instance`

**Key input variables:** `private_subnets`, `datalayer_sg`, `master_username`, `master_password`, `tags`

**Outputs:** `rds_endpoint`

### Compute Module

No standalone EC2 instances exist in this project — all compute is managed via Auto Scaling Groups in the autoscaling module. This module is scaffolded for future use.

---

## Root Configuration

| File | Purpose |
|---|---|
| `main.tf` | `terraform {}` block with backend config + all module calls |
| `backend.tf` | S3 bucket, versioning, encryption, public access block, DynamoDB table |
| `providers.tf` | AWS provider configuration |
| `data.tf` | `data.aws_availability_zones.available` |
| `variables.tf` | All root-level variable declarations |
| `terraform.tfvars` | Variable values (gitignored) |
| `outputs.tf` | Exposes module outputs at root level |
| `roles.tf` | IAM role, policy, attachment, and instance profile (stays at root) |

---

## Verification and Pro Tips

### Validate and format before applying

Always run these before `terraform plan`:
```bash
# Check for syntax errors and internal consistency
terraform validate

# Apply canonical formatting to all files including modules
terraform fmt -recursive

# Lint for best practice violations
tflint --recursive
```

### Confirm the plan before applying
```bash
terraform plan
```

Review the summary line — it should show resources to add with 0 unexpected destroys. Only proceed to apply when the plan matches your intent.

### Apply and verify in AWS Console
```bash
terraform apply
```

After apply completes, confirm the following in the AWS Console:
<img width="1366" height="768" alt="vpc confirmed" src="https://github.com/user-attachments/assets/18e5ac16-dbdd-49eb-9e96-3edd28f77149" />
<img width="1366" height="768" alt="loadbalancers creaeted" src="https://github.com/user-attachments/assets/93b95a15-f65c-4f1d-bc90-37424d8c467a" />
<img width="1366" height="768" alt="targetgroups" src="https://github.com/user-attachments/assets/dd4b6219-f7b8-49ea-bb22-6fbe8ae1596f" />
<img width="1366" height="768" alt="autoscaling groups" src="https://github.com/user-attachments/assets/1c0edd43-82da-4b4e-89ed-2dffbf0da359" />


## Key Decisions and Deviations

**AWS provider v4+ resource separation** — The project instructions use the old-style nested `versioning {}` and `server_side_encryption_configuration {}` blocks inside `aws_s3_bucket`. These were deprecated in provider v4. Since this project uses `~> 6.0`, these are implemented as separate resources (`aws_s3_bucket_versioning`, `aws_s3_bucket_server_side_encryption_configuration`, `aws_s3_bucket_public_access_block`).

**Self-signed certificate** — No domain is available, so `cert.tf` (ACM + Route 53) remains commented out. A self-signed TLS certificate is generated using the `tls` provider and imported into ACM via `aws_acm_certificate` with `certificate_body` and `private_key` arguments.

**`db.t3.micro` instead of `db.t2.micro`** — `db.t2.micro` is deprecated in MySQL 8.0. `db.t3.micro` is the current free-tier eligible replacement.

**MySQL 8.0 instead of 5.7** — MySQL 5.7 is near end-of-life. MySQL 8.0 is used throughout.

**`domain = "vpc"` on EIP** — The `vpc = true` argument on `aws_eip` is deprecated. `domain = "vpc"` is the current equivalent.

**`roles.tf` at root level** — IAM resources are cross-cutting and do not belong cleanly to any single module. Keeping them at root avoids circular dependencies and allows direct reference in module calls (`aws_iam_instance_profile.ip.name`).

---

## How to Use

**1. Clone the repository and navigate to the project:**
```bash
cd Project-18-Automate-Infrastructure-With-IaC-using-Terraform-3-Refactoring/PBL
```

**2. Create `terraform.tfvars` with your values (this file is gitignored):**
```hcl
region                              = "eu-central-1"
vpc_cidr                            = "172.16.0.0/16"
enable_dns_support                  = true
enable_dns_hostnames                = true
preferred_number_of_public_subnets  = 2
preferred_number_of_private_subnets = 4
name                                = "ACS"
ami                                 = "<your-ami-id>"
keypair                             = "<your-keypair-name>"
account_no                          = "<your-aws-account-id>"
master_username                     = "<db-username>"
master_password                     = "<db-password>"
tags = {
  Environment     = "production"
  Managed-By      = "Terraform"
}
```

**3. Initialize, validate, and apply:**
```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

**4. Destroy after verification:**
```bash
terraform destroy \
  -target=module.VPC \
  -target=module.security \
  -target=module.ALB \
  -target=module.autoscaling \
  -target=module.EFS \
  -target=module.RDS \
  -target=aws_iam_role.ec2_instance_role \
  -target=aws_iam_policy.policy \
  -target=aws_iam_role_policy_attachment.test-attach \
  -target=aws_iam_instance_profile.ip
```

> The S3 bucket and DynamoDB table are excluded from destroy because `prevent_destroy = true` protects the state bucket. These resources are intentionally kept for future projects.

---

## Blockers and Known Limitations

**Userdata scripts are not functional** — The `bastion.sh`, `nginx.sh`, `wordpress.sh`, and `tooling.sh` scripts passed to launch templates via `user_data` do not contain the actual EFS DNS endpoints, ALB DNS names, or RDS endpoints. These values are only known after `terraform apply` completes, creating a chicken-and-egg problem. The websites will not be reachable after deployment.

---

## Conclusion

This project demonstrates the progression from functional-but-messy Terraform code to production-grade IaC structure. The key shift is treating infrastructure code the same way you treat application code; modular, reusable, and maintainable by a team rather than a single person.

Moving state to S3 with DynamoDB locking removes the single biggest blocker to team collaboration in Terraform. The module refactoring means a new engineer can understand the entire codebase by reading seven focused `main.tf` files instead of one sprawling collection of flat files. The dynamic blocks and lookup functions reduce the surface area for mistakes when the infrastructure needs to change.

Project 19 will address the remaining gap — configuring the actual application layer using Packer and Ansible so the deployed infrastructure serves real traffic.

> **Author:** Lydiah Nganga  
> **Date:** March 10, 2026  
> **Program:** StegHub DevOps/Cloud Engineering Apprenticeship
