# Automate Infrastructure With IaC using Terraform

> **Project 16 | DevOps/Cloud Engineering | StegHub Apprenticeship**

This project demonstrates how to automate provisioning of AWS infrastructure using Terraform, focusing on:

- AWS IAM configuration with programmatic access
- VPC creation using Terraform
- Dynamic subnet creation using loops, data sources, and functions
- Refactoring from hardcoded values to reusable variables
- Best practices for structuring Infrastructure as Code (IaC)

This is the IaC version of the architecture previously built manually.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
   - [Create IAM User for Terraform](#1-create-an-iam-user-for-terraform)
   - [Configure AWS CLI](#2-configure-aws-cli)
   - [Install Python SDK (boto3)](#3-install-python-sdk-boto3)
   - [Create S3 Bucket for Terraform State](#4-create-an-s3-bucket-for-terraform-state)
   - [Install Terraform](#5-install-terraform)
2. [Project Setup](#project-setup)
   - [Create Project Directory](#step-1--create-project-directory)
   - [Configure Provider Block](#step-2--configure-terraform-provider)
3. [Part 102 - VPC Creation](#part-102---vpc-creation)
   - [Write VPC Resource](#step-3--create-vpc-resource)
   - [Initialize and Apply](#step-4--initialize-plan-and-apply)
4. [Part 103 - Subnet Creation (Hardcoded First)](#part-103---subnet-creation)
   - [Add Hardcoded Subnets](#step-5--add-subnets-hardcoded-version)
   - [Identify Problems](#step-6--observe-the-problems-with-hardcoded-values)
   - [Refactor with Variables and Loops](#step-7--refactor-fix-hardcoded-values)
   - [Use Data Sources for AZs](#step-8--use-data-sources-for-availability-zones)
   - [Dynamic CIDR with cidrsubnet()](#step-9--make-cidr-blocks-dynamic-with-cidrsubnet)
   - [Remove Hardcoded Count with length()](#step-10--remove-hardcoded-count-with-length)
   - [Add a Conditional](#step-11--add-a-conditional-to-control-subnet-count)
5. [Part 104 - File Structure Refactor](#part-104---file-structure-refactor)
   - [Create variables.tf](#step-12--create-variablestf)
   - [Create terraform.tfvars](#step-13--create-terraformtfvars)
   - [Clean Up main.tf](#step-14--final-maintf)
   - [Final File Structure](#step-15--verify-final-file-structure)
6. [Deprecated Features Note](#deprecated-features-note)
7. [Key Terraform Concepts Learned](#key-terraform-concepts-learned)
8. [Conclusion](#conclusion)

---

## Prerequisites

Before writing Terraform code, ensure the following are set up:

---

### 1. Create an IAM User for Terraform

> **Important Note:** AWS removed the old "Programmatic Access" checkbox during user creation. Access keys must now be created **after** the user is created.

**Step-by-step:**

Go to: **IAM -> Users -> Create User**

- Enter username:

```
terraform
```

- Do **NOT** enable console access — do not check "Provide user access to AWS Management Console". Terraform does not need console login.
- Under **Permissions**, choose **Attach policies directly**
- Select: `AdministratorAccess`
- Click **Create user**
- 
<img width="1366" height="768" alt="iamusercreated" src="https://github.com/user-attachments/assets/78cdd8e4-d014-4277-8d19-833b5b0c4394" />

**Now create Access Keys (Programmatic Access):**

- Click on the `terraform` user you just created
- Go to the **Security credentials** tab
- Scroll down to **Access Keys**
- Click **Create access key**
- Select: **Command Line Interface (CLI)**
- Check the confirmation checkbox, click **Next**, then **Create access key**
- Copy and save both values immediately:
  - `Access Key ID`
  - `Secret Access Key`

> You will **not** be able to view the Secret Access Key again after closing this page.

<img width="1366" height="768" alt="access keys created" src="https://github.com/user-attachments/assets/35e6956c-7dcd-4d83-a1d5-e67d5936b1ba" />

---

### 2. Configure AWS CLI

Install AWS CLI from [https://aws.amazon.com/cli/](https://aws.amazon.com/cli/), then run:

```bash
aws configure
```

Enter when prompted:

- `AWS Access Key ID` — paste your key
- `AWS Secret Access Key` — paste your secret
- `Default region name` — e.g. `eu-central-1`
- `Default output format` — `json`

This creates `~/.aws/credentials`, enabling Terraform to authenticate with AWS automatically.

<img width="1366" height="768" alt="aws configure" src="https://github.com/user-attachments/assets/5bffacb8-ec82-424c-9d3d-f67cbf9369eb" />

---

### 3. Install Python SDK (boto3)

Install boto3:

```bash
pip install boto3
```

Test AWS connectivity by running this in Python:

```python
import boto3
s3 = boto3.resource('s3')
for bucket in s3.buckets.all():
    print(bucket.name)
```

If you see your bucket names listed, authentication is working correctly.

<img width="1366" height="768" alt="bucket confirmed" src="https://github.com/user-attachments/assets/544e4ddb-545d-47b1-a354-dfdc12e69ac1" />

---

### 4. Create an S3 Bucket for Terraform State

> This bucket will be used from **Project 17 onwards** to store the Terraform remote state file.

Go to **AWS Console -> S3 -> Create bucket**

- Bucket name example:

```
lydiah-dev-terraform-bucket
```

- Bucket names must be **globally unique** and **lowercase**
- Select your region: `eu-central-1`
- Leave all other settings as default and click **Create bucket**

<img width="1366" height="768" alt="bucketcreated" src="https://github.com/user-attachments/assets/25ea0e04-998f-4cfd-b8a3-421ef692c5d8" />

---

### 5. Install Terraform

Download Terraform from:

```
https://developer.hashicorp.com/terraform/install
```

After installation, verify by running:

```bash
terraform --version
```

---

## Project Setup

### Step 1 — Create Project Directory

Open **VS Code**, create a new folder named:

```
Automate Infrastructure With IaC using Terraform 1
```

Inside that folder, create a subfolder called `PBL`. Then create the main Terraform config file inside it:

```
PBL/
└── main.tf
```
---

### Step 2 — Configure Terraform Provider

Open `main.tf` and add the provider block:

```hcl
provider "aws" {
  region = "eu-central-1"
}
```

> **Why not hardcode the region?**
> We start with a hardcoded value deliberately — to understand the problem first. Later we refactor this to use a variable, which makes the code reusable across environments (dev, test, prod) and portable across regions.

---

## Part 102 - VPC Creation

### Step 3 — Create VPC Resource

Add the VPC resource block to `main.tf`:

```hcl
provider "aws" {
  region = "eu-central-1"
}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = "172.16.0.0/16"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
}
```

> **Deprecated attributes excluded:** `enable_classiclink` and `enable_classiclink_dns_support` have been **removed** from the AWS Terraform provider. Do not include them. See the [Deprecated Features Note](#deprecated-features-note) section below.

---

### Step 4 — Initialize, Plan, and Apply

Open the terminal in VS Code, navigate into `PBL`, and run:

```bash
terraform init
```

This downloads the AWS provider plugin into a `.terraform/` directory.

<img width="1366" height="768" alt="first terrfaorm plan" src="https://github.com/user-attachments/assets/17f894ba-4fb6-4a12-a785-2c0d44aa2b39" />

Then check what Terraform intends to create:

```bash
terraform plan
```

If the plan looks correct, apply it:

```bash
terraform apply
```

Type `yes` when prompted.

<img width="1366" height="768" alt="first terraform init" src="https://github.com/user-attachments/assets/faeb2132-6c70-4cb0-b479-57911c4a8c70" />


> **New files Terraform created:**
> - `terraform.tfstate` — Terraform's "memory". It tracks everything it has built.
> - `terraform.tfstate.lock.info` — A temporary lock file that prevents two people from running Terraform at the same time. It gets deleted after the operation completes.

---

## Part 103 - Subnet Creation

### Step 5 — Add Subnets (Hardcoded Version)

Add the following two subnet resource blocks to `main.tf`, below the VPC block:

```hcl
# Create public subnet1
resource "aws_subnet" "public1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "172.16.0.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-central-1a"
}

# Create public subnet2
resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "172.16.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-central-1b"
}
```

Run:

```bash
terraform plan
terraform apply
```

<img width="1366" height="768" alt="hadcoded subnets" src="https://github.com/user-attachments/assets/7d807d5e-9e2a-4da1-bad6-6daa48c1843c" />

---

### Step 6 — Observe the Problems with Hardcoded Values

Looking at the code above, there are two clear problems:

| Problem | Why It's Bad |
|---|---|
| `availability_zone` is hardcoded | Ties the code to one region; breaks if deployed elsewhere |
| Two separate resource blocks | If you needed 10 subnets, you would need 10 blocks — not scalable |

We will fix both. First, destroy the current infrastructure:

```bash
terraform destroy
```

Type `yes` when prompted.

<img width="1366" height="768" alt="first terraform destroy" src="https://github.com/user-attachments/assets/bc42b80b-1a35-461c-ab52-5611ebddac50" />

---

### Step 7 — Refactor: Fix Hardcoded Values

We introduce **variables** to replace hardcoded values. Update `main.tf` to add variable declarations at the top:

```hcl
variable "region" {
  default = "eu-central-1"
}

variable "vpc_cidr" {
  default = "172.16.0.0/16"
}

variable "enable_dns_support" {
  default = "true"
}

variable "enable_dns_hostnames" {
  default = "true"
}

provider "aws" {
  region = var.region
}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames
}
```

> Variables are referenced using `var.<variable_name>`. The `default` value is used unless overridden.

---

### Step 8 — Use Data Sources for Availability Zones

Instead of hardcoding `"eu-central-1a"`, we use a **data source** to fetch the list of available AZs directly from AWS:

```hcl
# Get list of availability zones
data "aws_availability_zones" "available" {
  state = "available"
}
```

This returns a list like:

```
["eu-central-1a", "eu-central-1b", "eu-central-1c"]
```

We can then reference individual items using an index: `data.aws_availability_zones.available.names[0]`

---

### Step 9 — Make CIDR Blocks Dynamic with `cidrsubnet()`

We replace the two separate subnet blocks with a **single block** using `count` to loop, and the `cidrsubnet()` function to calculate a unique CIDR per subnet:

```hcl
# Create public subnets
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]
}
```

**How `cidrsubnet()` works:**

```
cidrsubnet(prefix, newbits, netnum)
```

- `prefix` — the base VPC CIDR (e.g. `"172.16.0.0/16"`)
- `newbits` — how many additional bits to add to the prefix (e.g. `4` turns `/16` into `/20`)
- `netnum` — which subnet number to generate (e.g. `0`, `1`, `2`...)

You can test this in the Terraform console:

```bash
terraform console
```

```
cidrsubnet("172.16.0.0/16", 4, 0)
cidrsubnet("172.16.0.0/16", 4, 1)
cidrsubnet("172.16.0.0/16", 4, 2)
```

Type `exit` to leave the console.

<img width="1366" height="768" alt="terraform console" src="https://github.com/user-attachments/assets/85e1dde4-1e12-4712-a56a-370af2044445" />

---

### Step 10 — Remove Hardcoded Count with `length()`

Instead of hardcoding `count = 2`, we use the `length()` function to dynamically count the number of AZs returned:

```hcl
count = length(data.aws_availability_zones.available.names)
```

Test in the Terraform console:

```bash
length(["eu-central-1a", "eu-central-1b", "eu-central-1c"])
```

> **New problem:** `length()` returns 3 (the number of AZs in the region), but our requirement is only 2 subnets. We need to control this.

---

### Step 11 — Add a Conditional to Control Subnet Count

We declare a new variable for the desired number of subnets, then use a **ternary conditional** to choose between the variable value and the AZ count:

```hcl
variable "preferred_number_of_public_subnets" {
  default = 2
}

# Create public subnets
resource "aws_subnet" "public" {
  count                   = var.preferred_number_of_public_subnets == null ? length(data.aws_availability_zones.available.names) : var.preferred_number_of_public_subnets
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]
}
```

**How the conditional works:**

```
condition ? value_if_true : value_if_false
```

- If `preferred_number_of_public_subnets` is `null` — use all available AZs
- If it has a value — use that value (in this case, `2`)

> Try changing `default = 2` to `default = null` and run `terraform plan` — notice it now plans to create 3 subnets (one per AZ). Change it back to `2` before continuing.

Run plan and apply to verify everything works:

```bash
terraform plan
terraform apply
```

<img width="1366" height="768" alt="refactored aply" src="https://github.com/user-attachments/assets/2e9cb9ef-e71d-43ff-91f2-179d0a3d132c" />

<img width="1366" height="768" alt="confirmed refatored subnets created" src="https://github.com/user-attachments/assets/01e2cddb-17e2-4526-bfcc-c160655e5263" />

---

## Part 104 - File Structure Refactor

Now we separate the code into 3 files for better organisation and readability. First, destroy what's running:

```bash
terraform destroy
```

---

### Step 12 — Create `variables.tf`

Create a new file: `PBL/variables.tf`

Move all variable declarations here:

```hcl
variable "region" {
  default = "eu-central-1"
}

variable "vpc_cidr" {
  default = "172.16.0.0/16"
}

variable "enable_dns_support" {
  default = "true"
}

variable "enable_dns_hostnames" {
  default = "true"
}

variable "preferred_number_of_public_subnets" {
  default = null
}
```

> Note that `preferred_number_of_public_subnets` has `default = null` here — the actual value will come from `terraform.tfvars`.

---
<img width="1366" height="768" alt="variablestf" src="https://github.com/user-attachments/assets/52b48356-adf2-46f5-8e33-144038457fb4" />


### Step 13 — Create `terraform.tfvars`

Create a new file: `PBL/terraform.tfvars`

This file sets the **actual values** for each variable:

```hcl
region = "eu-central-1"

vpc_cidr = "172.16.0.0/16"

enable_dns_support = "true"

enable_dns_hostnames = "true"

preferred_number_of_public_subnets = 2
```

> **Why separate `variables.tf` and `terraform.tfvars`?**
> Think of `variables.tf` as the **declaration** (saying "this variable exists"). Think of `terraform.tfvars` as the **assignment** (saying "here is the actual value I want to use"). This pattern means you can have different `.tfvars` files for different environments — `dev.tfvars`, `prod.tfvars` — without changing any code.

---

### Step 14 — Final `main.tf`

With variables moved out, `main.tf` is now clean and contains only infrastructure logic:

```hcl
# Get list of availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

provider "aws" {
  region = var.region
}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames
}

# Create public subnets
resource "aws_subnet" "public" {
  count                   = var.preferred_number_of_public_subnets == null ? length(data.aws_availability_zones.available.names) : var.preferred_number_of_public_subnets
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]
}
```

---

### Step 15 — Verify Final File Structure

Your `PBL` folder should now look like this:

```
PBL/
├── main.tf
├── variables.tf
├── terraform.tfvars
├── terraform.tfstate
├── terraform.tfstate.backup
└── .terraform/
```

Run the final plan and apply:

```bash
terraform plan
terraform apply
```

<img width="1366" height="768" alt="terraform plan new main" src="https://github.com/user-attachments/assets/79bfaf2f-889f-46ea-a64c-2a2416daa1b1" />

<img width="1366" height="768" alt="terraform apply new main" src="https://github.com/user-attachments/assets/f3442f70-c1ba-4c5e-978a-701181431730" />

Once you have all your screenshots and documentation, clean up to avoid AWS charges:

```bash
terraform destroy
```

<img width="1366" height="768" alt="final cleanup" src="https://github.com/user-attachments/assets/7f5f5725-a0f2-42f3-a07f-a023caaf0cae" />

---

## Deprecated Features Note

The original project instructions reference two Terraform arguments that have since been **removed** from the AWS provider and were **not implemented** in this project:

| Deprecated Argument | Reason Not Used |
|---|---|
| `enable_classiclink` | AWS Classic was retired. This attribute no longer exists in the AWS Terraform provider and will cause an error if included. |
| `enable_classiclink_dns_support` | Same as above — removed alongside Classic networking support. |

These were originally part of the `aws_vpc` resource block in the project instructions. The modern equivalent VPC block only requires `cidr_block`, `enable_dns_support`, and `enable_dns_hostnames`.

---

## Key Terraform Concepts Learned

| Concept | What It Does |
|---|---|
| `terraform init` | Downloads provider plugins — always run first |
| `terraform plan` | Shows what Terraform will do — always review before applying |
| `terraform apply` | Creates or updates the actual infrastructure |
| `terraform destroy` | Tears down all managed infrastructure |
| `terraform.tfstate` | Terraform's memory — tracks what currently exists |
| `variable` block | Declares a variable with an optional default value |
| `var.<n>` | References a declared variable |
| `data` source | Pulls live information from AWS (e.g. available AZs) |
| `count` | Creates a loop to build multiple resources from one block |
| `count.index` | The current loop number (0, 1, 2...) |
| `cidrsubnet()` | Calculates a unique CIDR block per subnet dynamically |
| `length()` | Returns the number of items in a list |
| Ternary conditional | `condition ? value_if_true : value_if_false` |
| `terraform.tfvars` | File where you set actual variable values |

---

## Conclusion

This project successfully demonstrates how to move from manually creating AWS infrastructure to fully automated Infrastructure as Code using Terraform.

Starting with hardcoded values — and deliberately identifying their limitations — was an important part of the learning process. The progressive refactoring from hardcoded strings to variables to data sources to loops to separate files mirrors how real-world Terraform projects evolve.

The final structure (`main.tf` + `variables.tf` + `terraform.tfvars`) is a clean, scalable pattern that makes infrastructure:

- **Reusable** — same code works across environments by swapping `.tfvars` files
- **Readable** — each file has a single clear purpose
- **Maintainable** — changes to values don't require touching infrastructure logic

The next project (Project 17) will expand this foundation further, introducing remote state storage using the S3 bucket created in the prerequisites, and building out the full multi-tier network architecture.

---

> *Project completed as part of the StegHub Cloud & DevOps Engineering Apprenticeship*
> *Tools used: Terraform, AWS (VPC, IAM, S3), VS Code, AWS CLI, Python/boto3*
