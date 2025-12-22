# Ansible Dynamic Assignments (Include) and Community Roles

## Table of Contents
- [Project Overview](#project-overview)
- [Understanding Key Concepts](#understanding-key-concepts)
- [Prerequisites](#prerequisites)
- [Implementation Steps](#implementation-steps)
  - [Step 1: Prepare Your Environment](#step-1-prepare-your-environment)
  - [Step 2: Create Dynamic Assignments Structure](#step-2-create-dynamic-assignments-structure)
  - [Step 3: Configure Environment Variables](#step-3-configure-environment-variables)
  - [Step 4: Install MySQL Community Role](#step-4-install-mysql-community-role)
  - [Step 5: Setup Load Balancer Roles](#step-5-setup-load-balancer-roles)
  - [Step 6: Configure Conditional Load Balancing](#step-6-configure-conditional-load-balancing)
  - [Step 7: Update Main Playbook](#step-7-update-main-playbook)
  - [Step 8: Deploy to UAT Environment](#step-8-deploy-to-uat-environment)
- [Testing and Validation](#testing-and-validation)
- [Troubleshooting](#troubleshooting)
- [Conclusion](#conclusion)

---

## Project Overview

This project builds upon previous Ansible configurations by introducing **dynamic assignments** and leveraging **community roles** from Ansible Galaxy. The goal is to create a flexible, environment-specific infrastructure configuration system that can manage multiple environments (Dev, Staging, UAT, Production) with minimal code duplication.

**Key Objectives:**
- Implement dynamic variable assignments using the `include` module
- Utilize production-ready community roles for MySQL and Load Balancers
- Configure conditional role execution based on environment variables
- Manage multi-environment infrastructure efficiently

---
## Prerequisites

Before starting, ensure you have:

- [x] AWS account with running EC2 instances:
  - Jenkins-Ansible server (Ubuntu)
  - 2 Web servers (RHEL/CentOS)
  - 1 Load Balancer server (Ubuntu)
  - 1 Database server (RHEL/CentOS)
- [x] Ansible installed on Jenkins-Ansible server
- [x] GitHub repository: `ansible-config-mgt`
- [x] SSH access configured to all target servers
- [x] Basic knowledge of Ansible playbooks and roles

---

## Implementation Steps

### Step 1: Prepare Your Environment

**1.1 Start Your EC2 Instances**

Navigate to AWS Console and start all required instances (they must be running for Ansible to connect).

**1.2 SSH into Jenkins-Ansible Server**

```bash
ssh -i ~/.ssh/your-key.pem ubuntu@<Jenkins-Ansible-Public-IP>
```

**1.3 Configure SSH Agent**

Allow Ansible to use your SSH key to connect to target servers:

```bash
eval `ssh-agent -s`
ssh-add ~/.ssh/your-key.pem
```

Verify the key was added:

```bash
ssh-add -l
```


### Step 2: Create Dynamic Assignments Structure

**2.1 Create New Git Branch**

Navigate to your ansible configuration directory and create a feature branch:

```bash
cd ~/ansible-config-mgt
git checkout main
git pull origin main
git checkout -b dynamic-assignments
```

This creates an isolated branch for development without affecting the main codebase.

<img width="1366" height="768" alt="dynamic ass new checkout brnach" src="https://github.com/user-attachments/assets/e15a8ecc-1884-41ff-97c9-1f72bfab8f6b" />


**2.2 Create Directory Structure**

```bash
# Create dynamic-assignments folder for dynamic playbooks
mkdir -p dynamic-assignments

# Create env-vars folder for environment-specific variables
mkdir -p env-vars

# Create necessary files
touch dynamic-assignments/env-vars.yml
touch env-vars/dev.yml
touch env-vars/stage.yml
touch env-vars/uat.yml
touch env-vars/prod.yml
```
<img width="1366" height="768" alt="env vars files created" src="https://github.com/user-attachments/assets/ba1eff0b-8966-4e3e-b119-3059bd3d9eb9" />

**2.3 Configure Dynamic Variable Loader**

Edit the dynamic variable loader file:

```bash
nano dynamic-assignments/env-vars.yml
```

Add the following content:

```yaml
---
- name: Collate variables from environment specific file, if it exists
  hosts: all
  tasks:
    - name: Looping through list of available files
      include_vars: "{{ item }}"
      with_first_found:
        - files:
            - dev.yml
            - stage.yml
            - prod.yml
            - uat.yml
          paths:
            - "{{ playbook_dir }}/../env-vars"
      tags:
        - always
```

**What this does:**
- `include_vars`: Dynamically loads variables from YAML files
- `with_first_found`: Searches through the file list and uses the first match
- `{{ playbook_dir }}`: Special variable that resolves to the playbook's directory
- `tags: always`: Ensures this task runs regardless of tag filtering

<img width="1366" height="768" alt="dynamic-assignmentsenv-varsyml" src="https://github.com/user-attachments/assets/e36a5181-eba2-4cb4-94a0-24df53a63f95" />

---

### Step 3: Configure Environment Variables

**3.1 Setup UAT Environment Variables**

Edit the UAT environment variable file:

```bash
nano env-vars/uat.yml
```

Add environment-specific configurations:

```yaml
---
# Load Balancer Selection
enable_nginx_lb: true
enable_apache_lb: false
load_balancer_is_required: true

# Environment Identifier
environment: uat
```

**What this configures:**
- Enables Nginx load balancer for UAT
- Disables Apache (we can only use one at a time)
- Marks load balancer as required for this environment
- Sets environment identifier for logging/tracking

<img width="1366" height="768" alt="edit envvaruatyml" src="https://github.com/user-attachments/assets/f1fd506f-9a8c-4b3f-910a-eebcf5d0ea26" />
---

### Step 4: Install MySQL Community Role

**4.1 Navigate to Roles Directory**

```bash
cd ~/ansible-config-mgt
mkdir -p roles
cd roles
```

**4.2 Install MySQL Role from Ansible Galaxy**

Ansible Galaxy is a repository of pre-built roles. We'll download the MySQL role:

```bash
ansible-galaxy install geerlingguy.mysql
```

This downloads a production-ready MySQL role that handles:
- Package installation
- Service management
- Database creation
- User management
- Security configurations

**4.3 Rename for Consistency**

```bash
mv geerlingguy.mysql mysql
```

We rename it to `mysql` for cleaner, more intuitive references in our playbooks.

<img width="1366" height="768" alt="installgeerlingguysql" src="https://github.com/user-attachments/assets/296dfd16-8e04-43f3-8ee0-dba6ed306a5b" />

**4.4 Review Role Documentation**

```bash
cd mysql
cat README.md
```

Read through the available variables and configuration options.

**4.5 Configure MySQL for Tooling Application**

Edit the role's default variables:

```bash
nano defaults/main.yml
```

Add your database configurations:

```yaml
# MySQL Root Password
mysql_root_password: "secure_root_password_here"

# Databases to Create
mysql_databases:
  - name: tooling
    encoding: utf8mb4
    collation: utf8mb4_general_ci

# Database Users
mysql_users:
  - name: webaccess
    host: "172.31.%"  # Allow access from VPC subnet
    password: "secure_user_password"
    priv: "tooling.*:ALL"
```

**Configuration Explanation:**
- `mysql_root_password`: Administrator password for MySQL
- `mysql_databases`: List of databases to create automatically
- `mysql_users`: Application users with specific permissions
- `host: "172.31.%"`: Allows connections from any IP in the 172.31.x.x subnet (your VPC)

<img width="1366" height="768" alt="MySQL role configuration" src="https://github.com/user-attachments/assets/ef72a313-cd8d-456c-b0e4-231a60d65cba" />

---

### Step 5: Setup Load Balancer Roles

**5.1 Install Nginx Role**

```bash
cd ~/ansible-config-mgt/roles
ansible-galaxy install geerlingguy.nginx
mv geerlingguy.nginx nginx
```

**5.2 Install Apache Role**

```bash
ansible-galaxy install geerlingguy.apache
mv geerlingguy.apache apache
```

**5.3 Configure Nginx Role Defaults**

```bash
nano nginx/defaults/main.yml
```

Add at the top of the file:

```yaml
# Control Variables
enable_nginx_lb: false
load_balancer_is_required: false
```
<img width="1366" height="768" alt="MySQL role configuration" src="https://github.com/user-attachments/assets/1ffbc6d4-92ee-47d3-a166-3a43efd91edb" />

**5.4 Configure Apache Role Defaults**

```bash
nano apache/defaults/main.yml
```

Add at the top:

```yaml
# Control Variables
enable_apache_lb: false
load_balancer_is_required: false
```

**Why set to false by default?**
- Provides explicit control over which load balancer is active
- Prevents accidental deployment of both load balancers
- Allows environment-specific override via `env-vars/` files

<img width="1366" height="768" alt="edit apacheyml" src="https://github.com/user-attachments/assets/4976d07d-5739-40e3-83dd-4dd87692cf5a" />

---

### Step 6: Configure Conditional Load Balancing

**6.1 Create Load Balancer Assignment File**

```bash
nano static-assignments/loadbalancers.yml
```

Add conditional role execution:

```yaml
---
- hosts: lb
  become: yes
  roles:
    - { role: nginx, when: enable_nginx_lb and load_balancer_is_required }
    - { role: apache, when: enable_apache_lb and load_balancer_is_required }
```

**Understanding the `when` Conditions:**
- `role: nginx`: Specifies which role to execute
- `when: enable_nginx_lb and load_balancer_is_required`: Both conditions must be `true`
  - Only runs if Nginx is explicitly enabled
  - Only runs if a load balancer is required for this environment
- The same logic applies to Apache

This prevents both load balancers from running simultaneously.

<img width="1366" height="768" alt="addloadbalancerstositeyml" src="https://github.com/user-attachments/assets/2e5cd20c-406b-4ad7-8180-10fe4b6e79fa" />

---

### Step 7: Update Main Playbook

**7.1 Configure Ansible Settings**

```bash
nano ansible.cfg
```

Ensure it contains:

```ini
[defaults]
host_key_checking = False
roles_path = /home/ubuntu/ansible-config-mgt/roles
inventory = /home/ubuntu/ansible-config-mgt/inventory
```

**Configuration Breakdown:**
- `host_key_checking = False`: Disables SSH host key verification (for dynamic environments)
- `roles_path`: Tells Ansible where to find roles
- `inventory`: Default inventory directory

**7.2 Update Site Playbook**

```bash
nano playbooks/site.yml
```

Replace with:

```yaml
---
# Include environment-specific variables dynamically
- hosts: all
  name: Include dynamic variables 
  tasks:
    - include: ../dynamic-assignments/env-vars.yml
      tags:
        - always

# Import common configurations (packages, users, etc.)
- import_playbook: ../static-assignments/common.yml 

# Configure web servers
- import_playbook: ../static-assignments/webservers.yml

# Configure load balancers (conditional)
- import_playbook: ../static-assignments/loadbalancers.yml
  when: load_balancer_is_required
```

**Playbook Flow Explanation:**
1. **First play**: Loads environment-specific variables for all hosts
2. **Second play**: Applies common configurations to all servers
3. **Third play**: Configures web servers with application code
4. **Fourth play**: Sets up load balancer (only if required by environment)

<img width="1366" height="768" alt="updating my siteyml" src="https://github.com/user-attachments/assets/f6b31ce7-068c-4dbd-bde7-74e5ba46e79c" />

---

### Step 8: Deploy to UAT Environment

**8.1 Setup UAT Inventory**

```bash
nano inventory/uat
```

Add your UAT server details (using private IPs if running from same VPC):

```ini
[webservers]
172.31.79.75 ansible_ssh_user=ec2-user ansible_ssh_private_key_file=~/tooling.pem
172.31.66.68 ansible_ssh_user=ec2-user ansible_ssh_private_key_file=~/tooling.pem

[lb]
172.31.23.171 ansible_ssh_user=ubuntu ansible_ssh_private_key_file=~/tooling.pem

[db]
172.31.22.112 ansible_ssh_user=ec2-user ansible_ssh_private_key_file=~/tooling.pem
```

**Inventory Breakdown:**
- `[webservers]`: Group containing web application servers
- `[lb]`: Load balancer server (Ubuntu-based)
- `[db]`: Database server for MySQL
- `ansible_ssh_user`: User account for SSH connection
- `ansible_ssh_private_key_file`: Path to SSH private key

**Important:** Use **private IPs** when running Ansible from a server in the same VPC (faster, more secure).

<img width="1366" height="768" alt="uatinventory" src="https://github.com/user-attachments/assets/549ae158-23d2-43d4-ab44-008b6403673b" />

**8.2 Commit Changes to GitHub**

```bash
cd ~/ansible-config-mgt
git add .
git commit -m "Add dynamic assignments and community roles for UAT"
git push --set-upstream origin dynamic-assignments
```

**8.3 Create Pull Request and Merge**

1. Navigate to your GitHub repository
2. Click "Compare & pull request" for the `dynamic-assignments` branch
3. Review changes in the Files changed tab
4. Click "Create pull request"
5. Add description: "Implements dynamic assignments and community roles"
6. Merge pull request to `main` branch

<img width="1366" height="768" alt="rolesfeature pullrequest" src="https://github.com/user-attachments/assets/5109875c-ccc9-4728-a584-69fd9b71ec9f" />

**8.4 Pull Latest Changes**

```bash
git checkout main
git pull origin main
```

---

## Testing and Validation

**Step 1: Test Inventory Connectivity**

Verify Ansible can reach all UAT servers:

```bash
ansible all -i inventory/uat -m ping
```

**Expected Output:**

```
172.31.79.75 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
172.31.66.68 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
...
<img width="1366" height="768" alt="pingsunccessfull" src="https://github.com/user-attachments/assets/d47bb3fd-3801-41e5-b0ea-f5b3e0634fcc" />

```

**Step 2: Execute Full Deployment**

```bash
ansible-playbook -i inventory/uat playbooks/site.yml
```

**What happens during execution:**
1. Loads UAT-specific variables (`env-vars/uat.yml`)
2. Applies common configurations to all servers
3. Installs and configures MySQL on database server
4. Configures web servers with application
5. Installs and configures Nginx load balancer (since `enable_nginx_lb: true`)

<img width="1366" height="768" alt="playbook run successful3" src="https://github.com/user-attachments/assets/162df670-14fc-41c0-9127-9acb448d1243" />

**Step 3: Verify Nginx Load Balancer**

<img width="1366" height="768" alt="playbook run successful3" src="https://github.com/user-attachments/assets/526e5c29-ef07-478e-b58e-d6e11c5fbf24" />


**Step 4: Test Load Balancer Switching**

To switch from Nginx to Apache, edit the UAT variables:

```bash
nano env-vars/uat.yml
```

Change to:

```yaml
enable_nginx_lb: false
enable_apache_lb: true
load_balancer_is_required: true
```

Re-run the playbook:

```bash
ansible-playbook -i inventory/uat playbooks/site.yml
```

Ansible will:
1. Stop and remove Nginx
2. Install and configure Apache
3. Start Apache service

<img width="1366" height="768" alt="apache working" src="https://github.com/user-attachments/assets/8ac5dd00-fd21-4c4e-9ecc-a8562af04c75" />

---

## Additional Verification Commands

After successful deployment, use these commands to verify your infrastructure is working correctly:

### Verify Web Server Service Status

Check if Apache/httpd is running on web servers:
```bash
ansible webservers -i inventory/uat -m shell -a "systemctl status httpd"
```

**What this does:**
- Targets the `webservers` group in your inventory
- Executes `systemctl status httpd` on each server
- Returns the current status of the Apache service

<img width="1366" height="768" alt="httpd" src="https://github.com/user-attachments/assets/627453f5-e234-4e4f-b867-7e0560be5467" />

---

### Verify Apache Processes

Check running Apache processes on web servers:
```bash
ansible webservers -i inventory/uat -m shell -a "ps aux | grep httpd"
```

**What this does:**
- Lists all running processes and filters for httpd
- Confirms Apache is actively running in memory
- Shows parent and child worker processes

<img width="1366" height="768" alt="apache healthy" src="https://github.com/user-attachments/assets/48d696e3-535f-4172-890a-8824d2faf85e" />

---

### Verify Server Hostnames

Retrieve hostname information using Ansible facts:
```bash
ansible webservers -i inventory/uat -m setup -a "filter=ansible_hostname"
```

**Expected Output:**
```
172.31.79.75 | SUCCESS => {
    "ansible_facts": {
        "ansible_hostname": "ip-172-31-79-75",
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false
}
172.31.66.68 | SUCCESS => {
    "ansible_facts": {
        "ansible_hostname": "ip-172-31-66-68",
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false
}
```

**What this confirms:**
- Ansible can gather facts from each server successfully
- Python interpreter is properly configured
- Server hostnames are correctly identified
- **"SUCCESS"** status indicates proper server configuration

<img width="1366" height="768" alt="serverhostnames" src="https://github.com/user-attachments/assets/d39d70bf-32ae-4b24-b71c-a4b92eff2a01" />

---

### Debug Environment Variables

Test variable loading from environment files:
```bash
ansible webservers -i inventory/uat -m debug -a "var=env_name"
```

**Expected Output:**
```
172.31.79.75 | SUCCESS => {
    "env_name": "VARIABLE IS NOT DEFINED!"
}
172.31.66.68 | SUCCESS => {
    "env_name": "VARIABLE IS NOT DEFINED!"
}
```

**Output Interpretation:**
- **"SUCCESS"** = Command executed successfully, Ansible connected properly
- **"VARIABLE IS NOT DEFINED!"** = The variable `env_name` wasn't set in `env-vars/uat.yml` (this is expected if you didn't define it)
- The important part is the **"SUCCESS"** status, confirming proper communication

<img width="1366" height="768" alt="testvariablessuccess" src="https://github.com/user-attachments/assets/e99c175c-d951-49e8-9cb2-6b463ec1a774" />

---

---


## Troubleshooting

### Issue: "Invalid characters were found in group names"

**Problem:** Hyphens in inventory group names (e.g., `[uat-webservers]`)

**Solution:** Use underscores instead:
```ini
# Change from:
[uat-webservers]

# To:
[uat_webservers]
# OR simply:
[webservers]
```

---

## Conclusion

In this project, we successfully implemented dynamic variable management using Ansible's `include` module, allowing environment-specific configurations without code duplication. By leveraging community roles from Ansible Galaxy for MySQL, Nginx, and Apache, we significantly reduced development time while maintaining production-ready standards. The implementation of conditional role execution enables seamless switching between load balancers based on environment variables, demonstrating Infrastructure as Code best practices. This flexible, maintainable setup can now efficiently manage multiple environments (Dev, Staging, UAT, Production) from a single codebase, making infrastructure provisioning faster, more consistent, and scalable for real-world applications.

---

> **Note:** This project is part of the **StegHub DevOps/Cloud Engineering Bootcamp**.

## Project Repository

All project files and configurations are available in the GitHub repository:  
🔗 **[https://github.com/LydiahLaw/Ansible-config-mgt](https://github.com/LydiahLaw/Ansible-config-mgt)**
