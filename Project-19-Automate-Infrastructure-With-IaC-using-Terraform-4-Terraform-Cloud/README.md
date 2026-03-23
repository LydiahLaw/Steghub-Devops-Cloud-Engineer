# Automate Infrastructure With IaC Using Terraform — Terraform Cloud

This project builds on the modular Terraform architecture from the previous project by migrating infrastructure management to Terraform Cloud, introducing Packer for custom AMI builds, and using Ansible for post-provisioning configuration.

> Private module registry and reusable Terraform components: [Terraform-Cloud](https://github.com/LydiahLaw/Terraform-Cloud)

## Architecture overview

The infrastructure is the same multi-tier AWS setup from the previous project — VPC, public and private subnets, external and internal ALBs, autoscaling groups for bastion, nginx, wordpress and tooling, EFS with access points per application, and RDS MySQL 8.0. What changed is how it gets built and managed:

- **Packer** builds custom RHEL 8.10 AMIs with software pre-installed, replacing the userdata script approach
- **Terraform Cloud** runs Terraform remotely, manages state, and integrates with GitHub for automated plan/apply workflows
- **Ansible** handles post-provisioning configuration that depends on runtime values — RDS endpoints, EFS access points, internal ALB DNS

## Repository structure

```
terraform-cloud/
├── AMI/                          # Packer AMI build definitions
│   ├── plugins.pkr.hcl           # AWS plugin declaration
│   ├── variables.pkr.hcl         # Shared variables (region)
│   ├── locals.pkr.hcl            # Computed values (timestamp)
│   ├── bastion.pkr.hcl
│   ├── nginx.pkr.hcl
│   ├── wordpress.pkr.hcl
│   ├── tooling.pkr.hcl
│   ├── bastion.sh                # Provisioning scripts
│   ├── nginx.sh
│   ├── wordpress.sh
│   └── tooling.sh
├── ansible/
│   ├── ansible.cfg
│   ├── inventories/aws/hosts
│   ├── group_vars/
│   │   ├── nginx.yml
│   │   ├── wordpress.yml
│   │   └── tooling.yml
│   ├── playbooks/site.yml
│   └── roles/
│       ├── bastion/tasks/main.yml
│       ├── nginx/tasks/main.yml
│       ├── wordpress/tasks/main.yml
│       └── tooling/tasks/main.yml
├── modules/
│   ├── VPC/
│   ├── security/
│   ├── ALB/
│   ├── autoscaling/
│   ├── EFS/
│   ├── RDS/
│   └── compute/
├── backend.tf
├── main.tf
├── variables.tf
├── terraform.tfvars
├── outputs.tf
├── providers.tf
├── roles.tf
└── data.tf
```

## Phase 1: Packer AMI builds

Instead of relying on userdata scripts to configure instances at boot, Packer bakes custom AMIs so instances launch already configured. Each server type gets its own AMI.

All four templates use RHEL 8.10 as the base image (owner `309956199498`, Red Hat's official AWS account). The correct AMI name for `eu-central-1` is:

```
RHEL-8.10.0_HVM-20251002-x86_64-1918-Hourly2-GP3
```

The original project instructions referenced a 2020 RHEL 8.2 AMI that no longer exists in this region. To find the current available RHEL AMIs in your region:

```bash
aws ec2 describe-images \
  --owners 309956199498 \
  --filters "Name=name,Values=RHEL-8*" \
             "Name=root-device-type,Values=ebs" \
             "Name=virtualization-type,Values=hvm" \
             "Name=architecture,Values=x86_64" \
  --query "Images[*].[Name,ImageId]" \
  --output table \
  --region eu-central-1
```

Each shell script installs the software that server type needs:

- **bastion.sh** — system updates, chronyd, net-tools, vim, wget
- **nginx.sh** — same base packages, nginx enabled at boot
- **wordpress.sh** — base packages, httpd, PHP with mysql and fpm modules
- **tooling.sh** — same as wordpress

<img width="1366" height="768" alt="amibuild" src="https://github.com/user-attachments/assets/e130a704-b1f5-411d-b0a2-5ac01ba18e70" />


Build all four AMIs in one command from the `AMI/` directory:

```bash
packer init .
packer build .
```

Packer spins up a temporary `t2.micro` EC2 per template, runs the shell script, snapshots it into an AMI, and terminates the instance. The four AMI IDs printed at the end go into Terraform Cloud as workspace variables.
<img width="1366" height="768" alt="amiconfirmed" src="https://github.com/user-attachments/assets/0a1ad9f1-1910-42cf-a012-f2491108b7ad" />


## Phase 2: Terraform Cloud setup

### Create an organisation

After creating a Terraform Cloud account at app.terraform.io, select **Start from scratch** and create an organisation. This project uses the organisation `Lydiah-devops`.
<img width="1366" height="768" alt="create org" src="https://github.com/user-attachments/assets/bbffb86e-95c8-4295-b977-73db5137140f" />

### Create workspaces

Three workspaces are created, one per environment. For each:

1. Click **New Workspace** → **Version control workflow**
2. Connect to GitHub and select the `terraform-cloud` repository
3. Under **Advanced options**, set the VCS branch to match the environment
4. Name the workspace and click **Create workspace**

<img width="1366" height="768" alt="ceate new workspace" src="https://github.com/user-attachments/assets/e0c08364-28af-4668-b03d-55d8430eb5e4" />


| Workspace | Branch | Apply behaviour |
|-----------|--------|-----------------|
| `terraform-cloud-dev` | `dev` | Auto-apply on push |
| `terraform-cloud-test` | `test` | Manual approval required |
| `terraform-cloud-prod` | `prod` | Manual approval required |

<img width="1366" height="768" alt="branches created" src="https://github.com/user-attachments/assets/9fc54942-83a1-4efd-a77a-b8525c6faeaa" />


Auto-apply is enabled only for `dev` under **Settings → General → Apply Method**. Pushing to `dev` triggers plan and apply automatically. Pushing to `test` or `prod` triggers a plan but requires operator approval before apply.

### Configure workspace variables

Since `terraform.tfvars` is gitignored and never reaches Terraform Cloud, all values are set directly in each workspace under the **Variables** tab.

**Environment variables** (mark both as Sensitive):

| Variable | Value |
|----------|-------|
| `AWS_ACCESS_KEY_ID` | your AWS access key |
| `AWS_SECRET_ACCESS_KEY` | your AWS secret key |

**Terraform variables**:

| Variable | Sensitive |
|----------|-----------|
| `ami` | No |
| `keypair` | No |
| `account_no` | No |
| `master_username` | Yes |
| `master_password` | Yes |
| `ami_bastion` | No |
| `ami_nginx` | No |
| `ami_wordpress` | No |
| `ami_tooling` | No |

<img width="1366" height="768" alt="addedvariables" src="https://github.com/user-attachments/assets/f6b98d00-4c41-41e8-ba3c-92e49be2842b" />


### Migrate the backend

The S3 backend from the previous project is replaced with Terraform Cloud's managed state. The `backend.tf` `cloud {}` block replaces the `backend "s3" {}` block entirely:

```hcl
terraform {
  cloud {
    organization = "Lydiah-devops"
    workspaces {
      name = "terraform-cloud-dev"
    }
  }
}
```

Each branch has its own `backend.tf` with the matching workspace name. Authenticate locally then re-initialise:

```bash
terraform login
terraform init
```

### Triggering and approving runs

Pushing to GitHub triggers a plan automatically in the connected workspace. Go to the **Runs** tab to monitor progress.

For workspaces with manual apply, click on the active run → **Confirm and apply** → add a comment → **Confirm plan**.

To trigger a run manually without a push: **New run → Plan and apply → Start run**.

To destroy from Terraform Cloud: **Settings → Destruction and Deletion → Queue destroy plan**.
<img width="1366" height="768" alt="Screenshot (1652)" src="https://github.com/user-attachments/assets/75dc95bd-a8d9-4c34-b8b7-7dfbe648823a" />


### Email notifications

In each workspace → **Settings → Notifications → Create a notification**:

- Choose **Email**
- Enter your email address
- Select events: **Plan errored**, **Run errored**, **Apply errored**, **Plan complete**
- Click **Create notification**
<img width="1366" height="768" alt="email not" src="https://github.com/user-attachments/assets/ff79e9a8-ef77-4780-a629-b83493c5c068" />

## Phase 3: Environment branches

```bash
git checkout -b dev && git push origin dev
git checkout main && git checkout -b test && git push origin test
git checkout main && git checkout -b prod && git push origin prod
git checkout dev
```
<img width="1366" height="768" alt="dev branch" src="https://github.com/user-attachments/assets/f04c06a5-a5fa-49e4-875b-4b63da30d5db" />


On each branch, update `backend.tf` to point to the correct workspace name before pushing.

## Phase 4: AMI variable changes

Each server type now has its own AMI variable rather than the single `var.ami` used in previous projects. The autoscaling module's launch templates reference `var.ami_bastion`, `var.ami_nginx`, `var.ami_wordpress`, and `var.ami_tooling` respectively. This was updated in both `modules/autoscaling/variables.tf` and `modules/autoscaling/main.tf`.
<img width="1366" height="768" alt="amis added in variables" src="https://github.com/user-attachments/assets/a1fd1c45-2609-474c-9907-ffda9bfc6cf7" />

<img width="1366" height="768" alt="amis aded on autoscaling" src="https://github.com/user-attachments/assets/0b12a4ce-b1fb-40ce-87cf-be6ae567208f" />


## Phase 5: Ansible post-provisioning

Ansible runs after Terraform apply to configure the infrastructure with values that only exist at runtime. These values cannot be baked into AMIs because they change every time the infrastructure is provisioned:

- Internal ALB DNS name → nginx reverse proxy config
- RDS endpoint → wordpress and tooling database connections
- EFS access point IDs → application storage mounts

Collect Terraform outputs after apply:

```bash
terraform output
```
<img width="1366" height="768" alt="terraform output" src="https://github.com/user-attachments/assets/ab6e2376-e974-47da-b7c6-39794fc85999" />

The inventory uses ProxyJump through the bastion to reach private instances:

```ini
[bastion]
<bastion-public-ip> ansible_user=ec2-user

[nginx]
<nginx-private-ip> ansible_user=ec2-user ansible_python_interpreter=/usr/bin/python3.11 ansible_ssh_common_args='-o ProxyJump=ec2-user@<bastion-public-ip>'

[wordpress]
<wordpress-private-ip> ansible_user=ec2-user ansible_python_interpreter=/usr/bin/python3.11 ansible_ssh_common_args='-o ProxyJump=ec2-user@<bastion-public-ip>'

[tooling]
<tooling-private-ip> ansible_user=ec2-user ansible_python_interpreter=/usr/bin/python3.11 ansible_ssh_common_args='-o ProxyJump=ec2-user@<bastion-public-ip>'
```

Update `group_vars/` with real values from `terraform output`, then run:

```bash
cd ansible
eval $(ssh-agent -s)
ssh-add ~/.ssh/terraform.pem
ansible all -m ping -i inventories/aws/hosts
ansible-playbook -i inventories/aws/hosts playbooks/site.yml
```

Playbook output:

```
PLAY [Configure Bastion host]
TASK [bastion : Ensure chronyd is running] ........... ok

PLAY [Configure Nginx reverse proxy]
TASK [nginx : Ensure nginx is running] ............... ok
TASK [nginx : Update nginx config with internal ALB DNS] ... changed

PLAY [Configure WordPress servers]
TASK [wordpress : Ensure httpd is running] ........... ok
TASK [wordpress : Ensure PHP-FPM is running] ......... ok

PLAY [Configure Tooling servers]
TASK [tooling : Ensure httpd is running] ............. ok
TASK [tooling : Ensure PHP-FPM is running] ........... ok
```
<img width="1366" height="768" alt="ansible playbook working" src="https://github.com/user-attachments/assets/9701faba-a640-4e49-9138-a2edb9c7662a" />

## Practice Task 1: Environment configuration

Three workspaces configured in Terraform Cloud with separate state, variables, and apply policies per environment. Runs on `dev` trigger automatically on push. Runs on `test` and `prod` require manual approval. Email notifications configured on all three workspaces.

## Practice Task 2: Private Module Registry

A reusable compute module was published to Terraform Cloud's Private Registry. The module follows the required naming convention `terraform-<PROVIDER>-<MODULE_NAME>`:

**Module repo:** `terraform-aws-compute`
<img width="1366" height="768" alt="terraform compute" src="https://github.com/user-attachments/assets/bb73c73f-dbe4-4a27-ae08-308348370170" />


The module wraps `aws_instance` with configurable AMI, instance type, name, and tags. It is versioned with git tags (`v1.0.0`) which Terraform Cloud uses to manage module versions in the registry.

To publish: Terraform Cloud → **Registry → Publish → Module** → connect to VCS → select `terraform-aws-compute` → **Publish module**.

A separate consumer repo (`terraform-module-test`) references the module from the private registry:

```hcl
module "compute" {
  source  = "app.terraform.io/Lydiah-devops/compute/aws"
  version = "1.0.0"

  ami           = var.ami
  instance_type = "t2.micro"
  instance_name = "private-registry-test"
  tags          = var.tags
}
```
<img width="1366" height="768" alt="module test" src="https://github.com/user-attachments/assets/578b9a2f-afa5-4bfe-a8f7-e7dfe10d556e" />


A dedicated workspace (`terraform-module-test`) was created for the consumer configuration, connected to the `terraform-module-test` repo. Infrastructure was deployed, verified in AWS Console, then destroyed.

## Key decisions and lessons

**RHEL 8.2 AMI unavailability** — the project instructions reference a 2020 RHEL 8.2 AMI that no longer exists in `eu-central-1`. Use the AMI discovery command above to find current available images rather than hardcoding AMI names from documentation.

**Python interpreter on RHEL 8.10** — Ansible's auto-discovery fails on RHEL 8.10 instances because the default `python3` package installs Python 3.6, which is below Ansible 2.20's minimum requirement. Always specify `ansible_python_interpreter=/usr/bin/python3.11` explicitly and bootstrap with:

```bash
ansible all -i inventories/aws/hosts -m raw -a "sudo yum install -y python3.11" --limit nginx,wordpress,tooling
```

**Terraform Cloud vs S3 backend** — Terraform Cloud provides managed state storage, remote execution, and team workflow features that the S3 backend requires you to build yourself. Sensitive variables must be configured in the Terraform Cloud UI rather than a local `terraform.tfvars` file since the tfvars file is gitignored and never reaches the remote runner.

**`backend-resources.tf` conflict** — the S3 bucket and DynamoDB table created in the previous project conflict with Terraform Cloud's attempt to recreate them. The clean solution is to remove `backend-resources.tf` from this project since those resources are managed separately.

**Packer AMI cleanup** — Terraform does not manage resources created by Packer. After destroying infrastructure, manually deregister AMIs and delete their associated EBS snapshots:

```
AWS Console → EC2 → AMIs → select owned AMIs → Deregister
AWS Console → EC2 → Snapshots → delete associated snapshots
```
## Conclusion

This project completes the Terraform maturity progression that started with flat `.tf` files in Project 16, through a full multi-tier architecture in Project 17, module refactoring in Project 18, and now remote execution and team workflows in Project 19. The shift to Terraform Cloud moves infrastructure management from a local machine dependency to a centralised, auditable system where every plan and apply is logged, state is managed remotely, and runs are triggered automatically from version control.

Packer solves a real limitation of the userdata script approach scripts run at boot every time an instance launches, adding startup latency and creating a window where the instance is live but not yet configured. Baked AMIs eliminate that window entirely. Ansible bridges the gap between what Packer can pre-install and what can only be known at runtime, keeping configuration flexible without sacrificing repeatability.

The combination of Terraform Cloud for provisioning, Packer for image builds, and Ansible for configuration management reflects how production DevOps teams actually manage infrastructure at scale.

## Related repositories

Private module registry and reusable Terraform components: [Terraform-Cloud](https://github.com/LydiahLaw/Terraform-Cloud)
