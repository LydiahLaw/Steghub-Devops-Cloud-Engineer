# Ansible Refactoring & Static Assignments Project

## Table of Contents
1. [Project Overview](#project-overview)
2. [Prerequisites](#prerequisites)
3. [Part 1: Jenkins Job Enhancement](#part-1-jenkins-job-enhancement)
4. [Part 2: Refactor Ansible Code](#part-2-refactor-ansible-code)
5. [Part 3: Configure UAT Webservers with Roles](#part-3-configure-uat-webservers-with-roles)
6. [Part 4: Test and Deploy](#part-4-test-and-deploy)
7. [Blockers and Solutions](#blockers-and-solutions)
8. [Conclusion](#conclusion)

---

## Project Overview

This project focuses on refactoring Ansible code to improve maintainability and reusability. We reorganized playbooks using:
- **Static assignments**: Organized playbooks in a dedicated folder
- **Imports**: Reusing playbooks via `import_playbook`
- **Roles**: Packaging related tasks for specific server configurations
- **Jenkins optimization**: Centralizing build artifacts to save disk space

**Goal**: Transform messy, single-file Ansible code into a clean, modular, professional infrastructure-as-code structure.

---

## Prerequisites

- Jenkins-Ansible server (from Project 11) running
- GitHub repository: `ansible-config-mgt`
- VS Code with Remote-SSH extension
- AWS EC2 instances for UAT environment
- SSH key pair for EC2 access

---

## Part 1: Jenkins Job Enhancement

### 1.1 Create Artifact Storage Directory

Create a centralized location to store the latest code from every build:

```bash
sudo mkdir /home/ubuntu/ansible-config-artifact
```

### 1.2 Install Copy Artifact Plugin

Install the plugin that allows copying artifacts between Jenkins jobs:

* Go to Jenkins web console → `Manage Jenkins` → `Manage Plugins`
* Click `Available plugins` tab
* Search for `Copy Artifact` and install it without restarting

### 1.3 Create save_artifacts Jenkins Job

Create a new Jenkins job to automatically copy artifacts to the permanent location:

* From Jenkins dashboard, click `New Item`
* Name: `save_artifacts`
* Type: `Freestyle project`
* Click `OK`

**Configure the job:**

* **General Tab**: Check `Discard old builds`
  - Strategy: Log Rotation
  - Max # of builds to keep: `2` (saves disk space)

* **Build Triggers**: 
  - Check `Build after other projects are built`
  - Projects to watch: `ansible` (your existing project name)
  - Trigger only if build is stable

* **Build Steps**:
  - Add build step → `Copy artifacts from another project`
  - Project name: `ansible`
  - Which build: `Latest successful build`
  - Artifacts to copy: `**` (copies everything)
  - Target directory: `/home/ubuntu/ansible-config-artifact`

* Click `Save`

![Jenkins save_artifacts configuration](screenshots/jenkins-save-artifacts-config.png)

### 1.4 Update Existing ansible Job

Configure the original ansible job to also discard old builds:

* Go to your `ansible` job → `Configure`
* Under `General`, check `Discard old builds`
* Max # of builds to keep: `2`
* Click `Save`

### 1.5 Test the Setup

Make a change to verify the Jenkins pipeline works:

```bash
cd /home/ubuntu/ansible-config-mgt
echo "Testing Jenkins artifact saving - $(date)" >> README.md
git add README.md
git commit -m "Test Jenkins save_artifacts job"
git push origin main
```

Watch both Jenkins jobs execute automatically. Verify files appear in the artifact directory:

```bash
ls -la /home/ubuntu/ansible-config-artifact/
```

![Jenkins jobs completed successfully](screenshots/jenkins-both-jobs-success.png)

---

## Part 2: Refactor Ansible Code

### 2.1 Create Refactor Branch

Always work on a new branch for safety:

```bash
cd /home/ubuntu/ansible-config-mgt
git checkout main
git pull origin main
git checkout -b refactor
```

### 2.2 Create Directory Structure

Create a folder to organize child playbooks:

```bash
mkdir static-assignments
```

### 2.3 Move common.yml to static-assignments

If `common.yml` exists in the playbooks folder, move it:

```bash
mv playbooks/common.yml static-assignments/
```

If it doesn't exist, create it with basic configuration:

```bash
nano static-assignments/common.yml
```

Add this content to install Wireshark on all servers:

```yaml
---
- name: update web, nfs and db servers
  hosts: webservers, nfs, db
  remote_user: ec2-user
  become: yes
  become_user: root
  tasks:
  - name: ensure wireshark is at the latest version
    yum:
      name: wireshark
      state: latest

- name: update LB server
  hosts: lb
  remote_user: ubuntu
  become: yes
  become_user: root
  tasks:
  - name: Update apt repo
    apt:
      update_cache: yes

  - name: ensure wireshark is at the latest version
    apt:
      name: wireshark
      state: latest
```

### 2.4 Create site.yml Entry Point

Create the main playbook that imports all other playbooks:

```bash
nano playbooks/site.yml
```

Add this content:

```yaml
---
- hosts: all
- import_playbook: ../static-assignments/common.yml
```

**Why?** `site.yml` acts as the master control file. Instead of running individual playbooks, we run site.yml which executes all imported playbooks.

### 2.5 Create common-del.yml for Cleanup

Create a playbook to remove Wireshark (demonstrates deletion tasks):

```bash
nano static-assignments/common-del.yml
```

Add this content:

```yaml
---
- name: update web, nfs and db servers
  hosts: webservers, nfs, db
  remote_user: ec2-user
  become: yes
  become_user: root
  tasks:
  - name: delete wireshark
    yum:
      name: wireshark
      state: removed

- name: update LB server
  hosts: lb
  remote_user: ubuntu
  become: yes
  become_user: root
  tasks:
  - name: delete wireshark
    apt:
      name: wireshark-qt
      state: absent
      autoremove: yes
      purge: yes
      autoclean: yes
```

### 2.6 Update site.yml to Use common-del.yml

Modify site.yml to import the deletion playbook:

```bash
nano playbooks/site.yml
```

Update to:

```yaml
---
- hosts: all
- import_playbook: ../static-assignments/common-del.yml
```

### 2.7 Commit and Merge Changes

Push your refactored code to GitHub:

```bash
git add .
git commit -m "Refactor: Move common.yml to static-assignments and create site.yml"
git push origin refactor
```

Create a Pull Request on GitHub:
* Go to your repository on GitHub
* Click `Compare & pull request` button
* Add title and description
* Click `Create pull request`
* Click `Merge pull request` → `Confirm merge`

![GitHub Pull Request merged](screenshots/github-pr-merged.png)

Pull the merged changes back to your server:

```bash
git checkout main
git pull origin main
```

Wait for Jenkins jobs to complete automatically.

![Jenkins jobs after merge](screenshots/jenkins-after-merge.png)

### 2.8 Run Ansible Playbook Against Dev Environment

Navigate to the artifact directory and run the playbook:

```bash
cd /home/ubuntu/ansible-config-artifact/
ansible-playbook -i inventory/dev.yml playbooks/site.yml
```

Verify Wireshark was removed from a server:

```bash
ssh ec2-user@<Your-Dev-Server-IP>
wireshark --version  # Should show "command not found"
exit
```

![Ansible playbook execution output](screenshots/ansible-playbook-dev.png)

---

## Part 3: Configure UAT Webservers with Roles

### 3.1 Launch UAT EC2 Instances

Create two new RHEL 10 instances for UAT environment:

* Go to AWS Console → EC2 → Launch instances
* **Name**: `Web1-UAT` and `Web2-UAT`
* **OS**: Red Hat Enterprise Linux 10
* **Instance type**: t2.micro
* **Key pair**: Use your existing key
* **Security group**: Allow SSH (22) from Jenkins-Ansible, HTTP (80) from anywhere
* Note the **Private IP addresses**

![UAT instances running in AWS](screenshots/uat-instances-aws.png)

### 3.2 Create New Branch for UAT Work

```bash
cd /home/ubuntu/ansible-config-mgt
git checkout main
git pull origin main
git checkout -b uat-webservers
```

### 3.3 Create Webserver Role Structure

Use ansible-galaxy to generate the standard role directory structure:

```bash
mkdir -p roles
cd roles
ansible-galaxy init webserver
cd webserver
rm -rf tests files vars
```

This creates the following structure:
```
webserver/
├── README.md
├── defaults/
│   └── main.yml
├── handlers/
│   └── main.yml
├── meta/
│   └── main.yml
├── tasks/
│   └── main.yml
└── templates/
```

### 3.4 Update UAT Inventory

Edit the inventory file with your UAT server IPs:

```bash
cd /home/ubuntu/ansible-config-mgt
nano inventory/uat.yml
```

Replace with your actual Private IPs:

```yaml
[uat-webservers]
<Web1-UAT-Private-IP> ansible_ssh_user=ec2-user
<Web2-UAT-Private-IP> ansible_ssh_user=ec2-user
```

### 3.5 Configure SSH Agent

Allow Ansible to use your SSH key to connect to target servers:

```bash
eval `ssh-agent -s`
ssh-add ~/.ssh/your-key-name.pem
```

Verify the key was added:

```bash
ssh-add -l
```

### 3.6 Configure Ansible roles_path

Tell Ansible where to find roles:

```bash
sudo mkdir -p /etc/ansible
sudo nano /etc/ansible/ansible.cfg
```

Add this configuration:

```ini
[defaults]
roles_path = /home/ubuntu/ansible-config-mgt/roles
```

### 3.7 Create Webserver Role Tasks

Define what the webserver role should do:

```bash
nano /home/ubuntu/ansible-config-mgt/roles/webserver/tasks/main.yml
```

Add this content to install Apache and deploy the tooling website:

```yaml
---
- name: install apache
  become: true
  ansible.builtin.yum:
    name: "httpd"
    state: present

- name: install git
  become: true
  ansible.builtin.yum:
    name: "git"
    state: present

- name: clone a repo
  become: true
  ansible.builtin.git:
    repo: https://github.com/LydiahLaw/tooling.git
    dest: /var/www/html
    force: yes

- name: copy html content to one level up
  become: true
  command: cp -r /var/www/html/html/ /var/www/

- name: Start service httpd, if not started
  become: true
  ansible.builtin.service:
    name: httpd
    state: started

- name: recursively remove /var/www/html/html/ directory
  become: true
  ansible.builtin.file:
    path: /var/www/html/html
    state: absent
```

**Note**: First fork the tooling repository from `https://github.com/darey-io/tooling` to your GitHub account.

![Forked tooling repository](screenshots/tooling-repo-forked.png)

### 3.8 Create uat-webservers.yml Static Assignment

Create a playbook that references the webserver role:

```bash
nano static-assignments/uat-webservers.yml
```

Add this content:

```yaml
---
- hosts: uat-webservers
  roles:
     - webserver
```

### 3.9 Update site.yml

Update the main entry point to include UAT configuration:

```bash
nano playbooks/site.yml
```

Update to:

```yaml
---
- hosts: all
- import_playbook: ../static-assignments/common.yml

- hosts: uat-webservers
- import_playbook: ../static-assignments/uat-webservers.yml
```

![Final directory structure](screenshots/final-directory-structure.png)

---

## Part 4: Test and Deploy

### 4.1 Commit and Push Changes

```bash
git add .
git commit -m "Add webserver role and UAT webservers configuration"
git push origin uat-webservers
```

### 4.2 Create Pull Request and Merge

* Go to GitHub repository
* Click `Compare & pull request`
* Add descriptive title and comments
* Click `Create pull request` → `Merge pull request` → `Confirm merge`

### 4.3 Pull Changes to Server

```bash
cd /home/ubuntu/ansible-config-mgt
git checkout main
git pull origin main
```

Wait for Jenkins jobs to complete.

![Jenkins jobs completed](screenshots/jenkins-uat-jobs-complete.png)

### 4.4 Test SSH Connectivity

Before running Ansible, verify you can reach UAT servers:

```bash
ssh -i ~/.ssh/your-key-name.pem ec2-user@<Web1-UAT-Private-IP>
```

Type `exit` to disconnect. Repeat for Web2-UAT.

### 4.5 Run Ansible Playbook

Navigate to the artifact directory and execute the playbook:

```bash
cd /home/ubuntu/ansible-config-artifact
ansible-playbook -i inventory/uat.yml playbooks/site.yml
```

Watch the output as Ansible:
- Installs Apache
- Installs Git
- Clones the tooling repository
- Copies HTML files
- Starts the httpd service
- Cleans up temporary directories

Expected output:
```
PLAY RECAP *****************************************************
<Web1-UAT-IP>    : ok=6    changed=5    unreachable=0    failed=0
<Web2-UAT-IP>    : ok=6    changed=5    unreachable=0    failed=0
```

![Ansible playbook execution successful](screenshots/ansible-playbook-uat-success.png)

### 4.6 Verify Website is Live

Get the Public IP addresses of your UAT servers from AWS Console.

Open your browser and visit:
```
http://<Web1-UAT-Public-IP>/index.php
http://<Web2-UAT-Public-IP>/index.php
```

You should see the tooling website running on both servers!

![Tooling website on Web1-UAT](screenshots/web1-uat-browser.png)

![Tooling website on Web2-UAT](screenshots/web2-uat-browser.png)

### 4.7 Verify Apache Service

SSH into a UAT server and check Apache status:

```bash
ssh ec2-user@<Web1-UAT-Private-IP>
sudo systemctl status httpd
ls -la /var/www/html/
exit
```

![Apache status showing active](screenshots/apache-status-active.png)

---

## Blockers and Solutions

### Blocker 1: Permission Denied - save_artifacts Job Failed

**Problem**: The save_artifacts Jenkins job failed with `java.nio.file.AccessDeniedException` when trying to write to `/home/ubuntu/ansible-config-artifact`.

**Root Cause**: The directory was created by the ubuntu user but Jenkins runs as the jenkins user. Even with 777 permissions, Jenkins couldn't create subdirectories due to ownership mismatch.

**Solution**: Changed directory ownership to jenkins user:

```bash
sudo chown -R jenkins:jenkins /home/ubuntu/ansible-config-artifact
sudo chmod -R 755 /home/ubuntu/ansible-config-artifact
```

**Result**: Jenkins can now successfully copy artifacts to the directory.

![Jenkins error before fix](screenshots/jenkins-permission-error.png)

![Jenkins success after fix](screenshots/jenkins-permission-fixed.png)

### Blocker 2: SSH Connection Issues to UAT Servers

**Problem**: Ansible couldn't connect to UAT servers initially.

**Root Cause**: Security groups weren't configured to allow SSH from Jenkins-Ansible server, and ssh-agent wasn't properly configured with the private key.

**Solution**:
1. Updated UAT security groups to allow SSH (port 22) from Jenkins-Ansible security group
2. Configured ssh-agent with private key:
   ```bash
   eval `ssh-agent -s`
   ssh-add ~/.ssh/your-key-name.pem
   ```

**Result**: Ansible successfully connects to and configures UAT servers.

---

## Conclusion

This project successfully transformed a single-file Ansible configuration into a well-organized, modular infrastructure-as-code solution. Key achievements:

✅ **Jenkins Optimization**: Centralized artifact storage saves disk space and provides a reliable code location

✅ **Code Organization**: Separated playbooks into logical folders (static-assignments) with a clear entry point (site.yml)

✅ **Reusability**: Created a webserver role that can be applied to any environment (dev, UAT, production)

✅ **Automation**: Complete CI/CD pipeline from GitHub push to server configuration

✅ **Scalability**: Easy to add new roles, playbooks, and environments without disrupting existing code

**Final Architecture:**
```
site.yml (main entry point)
    ├── imports common.yml (general tasks)
    └── imports uat-webservers.yml
            └── uses webserver role (Apache + tooling deployment)
```

The refactored code is now maintainable, readable, and follows DevOps best practices. Team members can easily understand the structure, add new features, and confidently deploy to multiple environments.

---

## Project Structure

```
ansible-config-mgt/
├── inventory/
│   ├── dev.yml
│   ├── staging.yml
│   ├── uat.yml
│   └── prod.yml
├── playbooks/
│   └── site.yml
├── roles/
│   └── webserver/
│       ├── tasks/
│       │   └── main.yml
│       ├── handlers/
│       │   └── main.yml
│       ├── defaults/
│       │   └── main.yml
│       ├── meta/
│       │   └── main.yml
│       └── templates/
├── static-assignments/
│   ├── common.yml
│   ├── common-del.yml
│   └── uat-webservers.yml
└── README.md
```
