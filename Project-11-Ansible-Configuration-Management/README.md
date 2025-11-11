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

<img width="1366" height="768" alt="jenkins-ansible" src="https://github.com/user-attachments/assets/d137333c-f2b0-4405-be79-9ef3376cf2b6" />


### 1.2 Create GitHub Repository

Created new repository: `ansible-config-mgt`

### 1.3 Install Ansible

```bash
sudo apt update
sudo apt install ansible -y
ansible --version
```

<img width="1115" height="742" alt="ansible install" src="https://github.com/user-attachments/assets/915f8c7c-1bbd-442d-8372-67c74531a5d9" />


### 1.4 Configure Jenkins Build Job

**Created Freestyle project:**
- Project name: `ansible`
- Source Code Management: Git
- Repository URL: `https://github.com/username/ansible-config-mgt.git`
- Branch: `*/main`
- Build Triggers: GitHub hook trigger for GITScm polling
- Post-build Actions: Archive artifacts (`**`)

<img width="1366" height="768" alt="build triggers" src="https://github.com/user-attachments/assets/04982bfe-9dd4-4db9-975c-c0acb7470698" />


### 1.5 Configure GitHub Webhook

- Payload URL: `http://<Jenkins-Public-IP>:8080/github-webhook/`
- Content type: `application/json`
- Events: Just the push event

<img width="1366" height="768" alt="add webhook" src="https://github.com/user-attachments/assets/17acb8e2-3143-4262-b635-fadd213722db" />


### 1.6 Test Setup

Modified README.md and verified:
- Jenkins build triggered automatically
- Artifacts saved to `/var/lib/jenkins/jobs/ansible/builds/<build_number>/archive/`

```bash
ls /var/lib/jenkins/jobs/ansible/builds/1/archive/
```

<img width="1366" height="768" alt="automatic build successful" src="https://github.com/user-attachments/assets/5d70eaa4-d4ce-48ff-9793-24afe2855eb6" />

---

## Step 2: Prepare Development Environment with Visual Studio Code

### 2.1 Install Remote-SSH Extension

Installed "Remote - SSH" extension in VSCode.

### 2.2 Configure SSH Connection

Created SSH config file:
```
Host Jenkins-Ansible
    HostName ec2-3-211-76-151.compute-1.amazonaws.com
    User ubuntu
    IdentityFile C:\path\to\tooling.pem
```

<img width="1366" height="768" alt="jenkins config" src="https://github.com/user-attachments/assets/b24e5f9c-070e-4118-ab63-a8ca2c060af4" />


### 2.3 Clone Repository

```bash
cd ~
git clone https://github.com/username/ansible-config-mgt.git
cd ansible-config-mgt
```
<img width="1366" height="768" alt="clone ansible" src="https://github.com/user-attachments/assets/c55d957e-7c3c-4813-863f-1f8145df1da3" />

---

## Step 3: Begin Ansible Development

### 3.1 Create Feature Branch

```bash
git checkout -b feature/prj-11-ansible-setup
```
<img width="1366" height="768" alt="feature branch" src="https://github.com/user-attachments/assets/f9ad2775-a9da-4884-a5cf-7e2c099f41f1" />


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

<img width="1366" height="768" alt="feature branch" src="https://github.com/user-attachments/assets/3422b1d0-39b5-4bb8-aa91-d3494fdd8683" />


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

<img width="1366" height="768" alt="feature branch" src="https://github.com/user-attachments/assets/9febccde-1502-40f0-a40f-1a0b4fa1a42e" />


---

## Step 6: Update Git with Latest Code

### 6.1 Commit Changes

```bash
git status
git add .
git commit -m "Initial ansible configuration with inventory and playbook"
git push origin feature/prj-11-ansible-setup
```


### 6.2 Create Pull Request

Created PR with title: "Initial Ansible Setup - Inventory and Common Playbook"
<img width="1366" height="768" alt="create pull request" src="https://github.com/user-attachments/assets/232ecdee-2060-4259-96ce-52a2083695f1" />


### 6.3 Merge to Main Branch

Reviewed and merged PR to main branch.
<img width="1366" height="768" alt="merge pull req" src="https://github.com/user-attachments/assets/4668f3fb-583d-4b76-bdd9-76e91c9d477d" />

### 6.4 Pull Latest Changes

```bash
git checkout main
git pull origin main
```

### 6.5 Verify Jenkins Build

Jenkins automatically triggered build and archived artifacts.

<img width="1366" height="768" alt="build from pull request" src="https://github.com/user-attachments/assets/046bdb62-0b4f-4c44-9a47-cf5f5499badf" />
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
ansible all -i inventory/dev.ini -m ping
```
<img width="1366" height="768" alt="inventory ping working" src="https://github.com/user-attachments/assets/4c785d75-fa31-4ecd-836b-81190d7efd91" />


### 7.3 Run Playbook

```bash
ansible-playbook -i inventory/dev.yml playbooks/common.yml
```
<img width="1366" height="768" alt="run playbook" src="https://github.com/user-attachments/assets/229461a8-919f-4ae8-bf0b-360b255f6131" />


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

<img width="1366" height="768" alt="which wireshrak" src="https://github.com/user-attachments/assets/376e2a2c-c98a-4f3f-b76d-553b271631b3" />

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
<img width="1366" height="768" alt="updated the common yml" src="https://github.com/user-attachments/assets/cceba720-8086-4dc6-80a9-93680cab7f21" />

**Verification:**
```bash
ssh ec2-user@172.31.25.139 "timedatectl"
ssh ec2-user@172.31.29.2 "ls -la /home/ec2-user/ansible_test/"
```
<img width="1366" height="768" alt="ssh agent with time" src="https://github.com/user-attachments/assets/2f217f36-5cfb-4195-bf70-7d4e7a857723" />


<img width="1366" height="768" alt="time change successfull" src="https://github.com/user-attachments/assets/beedabb6-88de-43b8-9ffd-b9ddeafefd2e" />


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

This project establishes a robust foundation for infrastructure automation, enabling efficient management of server fleets of any size with minimal manual intervention.
