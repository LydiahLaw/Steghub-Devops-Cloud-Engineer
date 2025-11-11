# Ansible Configuration Management Project

## Table of Contents
1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Step 1: Install and Configure Ansible on EC2 Instance](#step-1-install-and-configure-ansible-on-ec2-instance)
5. [Step 2: Prepare Development Environment with Visual Studio Code](#step-2-prepare-development-environment-with-visual-studio-code)
6. [Step 3: Begin Ansible Development](#step-3-begin-ansible-development)
7. [Step 4: Set Up Ansible Inventory](#step-4-set-up-ansible-inventory)
8. [Step 5: Create Common Playbook](#step-5-create-common-playbook)
9. [Step 6: Update Git with Latest Code](#step-6-update-git-with-latest-code)
10. [Step 7: Run First Ansible Test](#step-7-run-first-ansible-test)
11. [Optional: Enhanced Playbook Tasks](#optional-enhanced-playbook-tasks)
12. [Conclusion](#conclusion)

---

## Project Overview

This project automates server configuration management using Ansible. It demonstrates Infrastructure as Code (IaC) principles by managing multiple servers through a centralized Jenkins-Ansible server integrated with GitHub for continuous integration.

**Key Objectives:**
- Install and configure Ansible as a Jump Server/Bastion Host
- Create Ansible playbooks to automate server configuration
- Integrate Jenkins with GitHub for automated deployments
- Manage inventory for multiple environments (Dev, Staging, UAT, Production)

---

## Architecture

**Infrastructure Components:**
- 1 Jenkins-Ansible server (Ubuntu) - Control node
- 1 NFS Server (RHEL-based)
- 2 Web Servers (RHEL-based)
- 1 Database Server (RHEL-based)
- 1 Load Balancer (Ubuntu)

**Workflow:**
```
Developer → GitHub → Jenkins → Ansible → Target Servers
```

[Screenshot: Architecture diagram]

---

## Prerequisites

- AWS EC2 instances (6 total)
- GitHub account
- SSH key pair (tooling.pem)
- Visual Studio Code
- Git installed locally
- Basic knowledge of Linux commands

**Server Details:**
| Server | Private IP | OS | User |
|--------|------------|-----|------|
| Jenkins-Ansible | 172.31.21.15 | Ubuntu | ubuntu |
| NFS Server | 172.31.25.139 | RHEL | ec2-user |
| Web Server 1 | 172.31.29.2 | RHEL | ec2-user |
| Web Server 2 | 172.31.19.174 | RHEL | ec2-user |
| Database Server | 172.31.22.112 | RHEL | ec2-user |
| Load Balancer | 172.31.23.171 | Ubuntu | ubuntu |

---

## Step 1: Install and Configure Ansible on EC2 Instance

### 1.1 Update EC2 Instance Name Tag

Renamed Jenkins EC2 instance to `Jenkins-Ansible`.

[Screenshot: AWS EC2 console showing renamed instance]

### 1.2 Create GitHub Repository

Created new repository: `ansible-config-mgt`

[Screenshot: GitHub repository created]

### 1.3 Install Ansible

```bash
sudo apt update
sudo apt install ansible -y
ansible --version
```

[Screenshot: Ansible version output]

### 1.4 Configure Jenkins Build Job

**Created Freestyle project:**
- Project name: `ansible`
- Source Code Management: Git
- Repository URL: `https://github.com/username/ansible-config-mgt.git`
- Branch: `*/main`
- Build Triggers: GitHub hook trigger for GITScm polling
- Post-build Actions: Archive artifacts (`**`)

[Screenshot: Jenkins project configuration]

### 1.5 Configure GitHub Webhook

- Payload URL: `http://<Jenkins-Public-IP>:8080/github-webhook/`
- Content type: `application/json`
- Events: Just the push event

[Screenshot: GitHub webhook configuration]

### 1.6 Test Setup

Modified README.md and verified:
- Jenkins build triggered automatically
- Artifacts saved to `/var/lib/jenkins/jobs/ansible/builds/<build_number>/archive/`

```bash
ls /var/lib/jenkins/jobs/ansible/builds/1/archive/
```

[Screenshot: Jenkins build success and archived files]

---

## Step 2: Prepare Development Environment with Visual Studio Code

### 2.1 Install Remote-SSH Extension

Installed "Remote - SSH" extension in VSCode.

[Screenshot: VSCode with Remote-SSH extension]

### 2.2 Configure SSH Connection

Created SSH config file:
```
Host Jenkins-Ansible
    HostName ec2-3-211-76-151.compute-1.amazonaws.com
    User ubuntu
    IdentityFile C:\path\to\tooling.pem
```

[Screenshot: VSCode connected to remote server]

### 2.3 Clone Repository

```bash
cd ~
git clone https://github.com/username/ansible-config-mgt.git
cd ansible-config-mgt
```

[Screenshot: Repository cloned]

---

## Step 3: Begin Ansible Development

### 3.1 Create Feature Branch

```bash
git checkout -b feature/prj-ansible-setup
```

[Screenshot: Git branch creation]

### 3.2 Create Directory Structure

Created directories and files:
```
ansible-config-mgt/
├── playbooks/
│   └── common.yml
├── inventory/
│   ├── dev.yml
│   ├── staging.yml
│   ├── uat.yml
│   └── prod.yml
└── README.md
```

[Screenshot: Directory structure in VSCode]

---

## Step 4: Set Up Ansible Inventory

### 4.1 Configure SSH Agent

```bash
eval `ssh-agent -s`
ssh-add ~/tooling.pem
ssh-add -l
```

### 4.2 Connect with Agent Forwarding

```bash
ssh -A ubuntu@<Jenkins-Ansible-Public-IP>
```

### 4.3 Update Inventory File

**inventory/dev.yml:**
```ini
[nfs]
172.31.25.139 ansible_ssh_user=ec2-user

[webservers]
172.31.29.2 ansible_ssh_user=ec2-user
172.31.19.174 ansible_ssh_user=ec2-user

[db]
172.31.22.112 ansible_ssh_user=ec2-user

[lb]
172.31.23.171 ansible_ssh_user=ubuntu
```

[Screenshot: inventory/dev.yml file]

---

## Step 5: Create Common Playbook

**playbooks/common.yml:**
```yaml
---
- name: update web, nfs and db servers
  hosts: webservers, nfs, db
  become: yes
  tasks:
    - name: ensure wireshark is at the latest version
      yum:
        name: wireshark
        state: latest

- name: update LB server
  hosts: lb
  become: yes
  tasks:
    - name: Update apt repo
      apt: 
        update_cache: yes

    - name: ensure wireshark is at the latest version
      apt:
        name: wireshark
        state: latest
```

[Screenshot: common.yml playbook]

---

## Step 6: Update Git with Latest Code

### 6.1 Commit Changes

```bash
git status
git add .
git commit -m "Initial ansible configuration with inventory and playbook"
git push origin feature/prj-ansible-setup
```

[Screenshot: Git commit]

### 6.2 Create Pull Request

Created PR with title: "Initial Ansible Setup - Inventory and Common Playbook"

[Screenshot: GitHub Pull Request]

### 6.3 Merge to Main Branch

Reviewed and merged PR to main branch.

[Screenshot: PR merged]

### 6.4 Pull Latest Changes

```bash
git checkout main
git pull origin main
```

### 6.5 Verify Jenkins Build

Jenkins automatically triggered build and archived artifacts.

[Screenshot: Jenkins automatic build after merge]

---

## Step 7: Run First Ansible Test

### 7.1 Create Ansible Configuration

```bash
cd ~/ansible-config-mgt
nano ansible.cfg
```

**ansible.cfg:**
```ini
[defaults]
host_key_checking = False
```

### 7.2 Test Connectivity

```bash
ansible all -i inventory/dev.yml -m ping
```

[Screenshot: Ansible ping test successful]

### 7.3 Run Playbook

```bash
ansible-playbook -i inventory/dev.yml playbooks/common.yml
```

[Screenshot: Playbook execution output]

### 7.4 Verify Installation

Checked Wireshark installation on all servers:

```bash
ssh ec2-user@172.31.25.139 "which wireshark"
ssh ec2-user@172.31.29.2 "which wireshark"
ssh ec2-user@172.31.19.174 "which wireshark"
ssh ec2-user@172.31.22.112 "which wireshark"
ssh ubuntu@172.31.23.171 "which wireshark"
```

**Output:** `/usr/bin/wireshark` on all servers

[Screenshot: Wireshark verification on all servers]

---

## Optional: Enhanced Playbook Tasks

### Enhanced common.yml with Additional Tasks

Added timezone configuration and directory creation:

```yaml
---
- name: update web, nfs and db servers
  hosts: webservers, nfs, db
  become: yes
  tasks:
    - name: ensure wireshark is at the latest version
      yum:
        name: wireshark
        state: latest

    - name: create a directory
      file:
        path: /home/ec2-user/ansible_test
        state: directory
        mode: '0755'
        owner: ec2-user
        group: ec2-user

    - name: create a file inside the directory
      file:
        path: /home/ec2-user/ansible_test/test_file.txt
        state: touch
        mode: '0644'
        owner: ec2-user
        group: ec2-user

    - name: set timezone to Africa/Nairobi
      timezone:
        name: Africa/Nairobi

- name: update LB server
  hosts: lb
  become: yes
  tasks:
    - name: Update apt repo
      apt: 
        update_cache: yes

    - name: ensure wireshark is at the latest version
      apt:
        name: wireshark
        state: latest

    - name: create a directory
      file:
        path: /home/ubuntu/ansible_test
        state: directory
        mode: '0755'
        owner: ubuntu
        group: ubuntu

    - name: create a file inside the directory
      file:
        path: /home/ubuntu/ansible_test/test_file.txt
        state: touch
        mode: '0644'
        owner: ubuntu
        group: ubuntu

    - name: set timezone to Africa/Nairobi
      timezone:
        name: Africa/Nairobi
```

**Verification:**
```bash
ssh ec2-user@172.31.25.139 "timedatectl"
ssh ec2-user@172.31.29.2 "ls -la /home/ec2-user/ansible_test/"
```

[Screenshot: Enhanced playbook execution and verification]

---

## Conclusion

Successfully implemented Ansible configuration management with the following achievements:

✅ **Automated Infrastructure Management:** Configured 5 servers simultaneously with single command execution

✅ **CI/CD Integration:** Integrated Jenkins with GitHub for automated build triggers and artifact archiving

✅ **Infrastructure as Code:** Managed server configurations through version-controlled playbooks

✅ **Git Workflow:** Implemented professional development workflow with feature branches, pull requests, and code reviews

✅ **Scalable Architecture:** Established foundation for managing infrastructure at scale across multiple environments (Dev, Staging, UAT, Production)

**Key Skills Demonstrated:**
- Ansible playbook creation and execution
- Jenkins CI/CD pipeline configuration
- Git version control and collaboration
- SSH agent forwarding for secure multi-hop connections
- Linux system administration across RHEL and Ubuntu systems

**Future Enhancements:**
- Implement Ansible roles for better code organization
- Add more environments (Staging, UAT, Production)
- Create dynamic inventories
- Implement Ansible Vault for secrets management
- Add more complex automation tasks (application deployment, database configuration, etc.)

This project establishes a robust foundation for infrastructure automation, enabling efficient management of server fleets of any size with minimal manual intervention.