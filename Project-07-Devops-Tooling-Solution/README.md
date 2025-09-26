# DevOps Tooling Website Solution

A scalable 3-tier web infrastructure implementation demonstrating enterprise-level DevOps practices through Network File System (NFS) shared storage and centralized database management. This project solves the fundamental challenge of horizontal web server scaling by creating stateless servers that maintain data consistency across the infrastructure.
<img width="1024" height="678" alt="devops archi" src="https://github.com/user-attachments/assets/1ac06d3d-5896-4ffe-b05e-90ff74c32610" />

## Table of Contents

- [Introduction](#introduction)
- [Architecture Overview](#architecture-overview)
- [Technologies Used](#technologies-used)
- [Implementation Steps](#implementation-steps)
  - [Step 1: AWS Infrastructure Setup](#step-1-aws-infrastructure-setup)
  - [Step 2: NFS Server Configuration](#step-2-nfs-server-configuration)
  - [Step 3: Database Server Setup](#step-3-database-server-setup)
  - [Step 4: Web Servers Configuration](#step-4-web-servers-configuration)
- [Challenges and Solutions](#challenges-and-solutions)
- [Testing and Validation](#testing-and-validation)
- [Lessons Learned](#lessons-learned)
- [Conclusion](#conclusion)

## Introduction

In my previous projects, I worked with single web servers that stored both application code and data locally. While this approach works for development, it creates significant challenges when scaling applications to handle increased traffic. Each server maintains its own copy of files, leading to inconsistencies, and scaling requires complex data synchronization processes.

This project addresses these limitations by implementing a stateless web server architecture where application logic is separated from data storage. I designed a system where multiple web servers can be added or removed without affecting data integrity, enabling true horizontal scaling while maintaining consistency across the entire infrastructure.

## Architecture Overview

I implemented a 3-tier architecture that separates concerns and enables independent scaling of each component:

```
Internet → [Web Servers (3)] → [Database Server]
              ↓
          [NFS Server]
```

**Presentation Tier:** Three identical RHEL 10 web servers running Apache and PHP
**Storage Tier:** NFS server providing shared file storage with LVM-managed volumes  
**Data Tier:** MySQL database server managing persistent application data

This separation allows me to scale web servers horizontally while maintaining single sources of truth for both files and data.

## Technologies Used

| Technology | Role in Project | Why I Chose It |
|------------|----------------|----------------|
| **RHEL 10** | Operating system | Enterprise-grade stability required for production workloads |
| **Apache HTTP Server** | Web server | Industry-standard reliability and extensive PHP integration |
| **PHP 7.4** | Application runtime | Dynamic content generation for the tooling application |
| **MySQL** | Database system | Robust ACID compliance for data integrity |
| **NFS** | Shared storage | Real-time file synchronization across multiple servers |
| **LVM** | Storage management | Flexible volume management and future expansion capability |
| **AWS EC2** | Cloud infrastructure | Scalable, reliable hosting with security group controls |

## Implementation Steps

### Step 1: AWS Infrastructure Setup

I began by creating the foundational infrastructure in AWS, establishing five EC2 instances to support the 3-tier architecture.

**Instance Creation:**
- 1 NFS Server (RHEL 10): Centralized file storage
- 1 Database Server (RHEL 10): MySQL database hosting  
- 3 Web Servers (RHEL 10): Application servers
<img width="1366" height="768" alt="nfs server instance" src="https://github.com/user-attachments/assets/5c31dfe7-a177-4185-a1a5-f1e7848e8468" />

I configured security groups to control network access between tiers:
- Web servers: HTTP (80) and SSH (22) access
- NFS server: NFS ports (111, 2049, 20048) from web server subnet
- Database server: MySQL (3306) from web server subnet
<img width="1366" height="768" alt="add inbound rules" src="https://github.com/user-attachments/assets/a9a54379-7120-481b-8dcd-d1f2cc299a18" />

All instances were deployed in the same subnet (172.31.16.0/20) to simplify initial networking while maintaining proper security boundaries through security groups.

### Step 2: NFS Server Configuration  

The NFS server serves as the centralized storage solution, ensuring all web servers access identical files. I implemented LVM to provide flexible storage management.

**Storage Infrastructure Setup:**
I attached three EBS volumes to the NFS server and configured them using LVM:
<img width="1366" height="768" alt="volumes attached" src="https://github.com/user-attachments/assets/e677de0c-adf2-478f-820a-2c54127739d2" />


```bash
# Created physical volumes
sudo pvcreate /dev/xvdf1 /dev/xvdg1 /dev/xvdh1

# Created volume group  
sudo vgcreate nfs-vg /dev/xvdf1 /dev/xvdg1 /dev/xvdh1

# Created logical volumes
sudo lvcreate -n lv-apps -L 9.5G nfs-vg
sudo lvcreate -n lv-logs -L 9.5G nfs-vg  
sudo lvcreate -n lv-opt -L 9.5G nfs-vg
```
<img width="1366" height="768" alt="physical volumes created" src="https://github.com/user-attachments/assets/3dee46af-2d99-4325-b215-f49aa1479f85" />
<img width="1366" height="768" alt="volume grp and logical volumes created" src="https://github.com/user-attachments/assets/83e3fbdb-72f2-4f71-97f2-cb5503df0a8e" />


I formatted the volumes with XFS filesystem for better performance with large files:
```bash
sudo mkfs -t xfs /dev/nfs-vg/lv-apps
sudo mkfs -t xfs /dev/nfs-vg/lv-logs
sudo mkfs -t xfs /dev/nfs-vg/lv-opt
```
<img width="1366" height="768" alt="format with XFS" src="https://github.com/user-attachments/assets/e15d0ebe-10e9-471f-9a7f-b39f8c39dc43" />

**NFS Service Configuration:**
I installed and configured the NFS server to export the logical volumes:

```bash
sudo yum install nfs-utils -y
sudo systemctl start nfs-server
sudo systemctl enable nfs-server
```
<img width="1366" height="768" alt="nfs install" src="https://github.com/user-attachments/assets/db53d3c4-803f-460c-956a-dff3a2e203f5" />

I configured the exports to allow access from the web server subnet:
```bash
# /etc/exports
/mnt/apps 172.31.16.0/20(rw,sync,no_all_squash,no_root_squash)
/mnt/logs 172.31.16.0/20(rw,sync,no_all_squash,no_root_squash)
/mnt/opt 172.31.16.0/20(rw,sync,no_all_squash,no_root_squash)
```
<img width="1366" height="768" alt="exports configured" src="https://github.com/user-attachments/assets/782eb76f-55a5-4e9d-a88a-391328ab2ebb" />

I set appropriate permissions to ensure web servers could read, write, and execute files:
```bash
sudo chown -R nobody: /mnt/apps /mnt/logs /mnt/opt
sudo chmod -R 777 /mnt/apps /mnt/logs /mnt/opt
```
<img width="1366" height="768" alt="set permisions on the webservers" src="https://github.com/user-attachments/assets/5aa8f9cc-dc75-4600-88a4-dd7f292f7bef" />

### Step 3: Database Server Setup

I configured a centralized MySQL database to serve all web servers, ensuring data consistency across the application.

**MySQL Installation and Security:**
```bash
sudo yum install mysql-server -y
sudo systemctl start mysqld
sudo systemctl enable mysqld
```
<img width="1366" height="768" alt="sql mariadb installed" src="https://github.com/user-attachments/assets/46d8e19c-3017-442b-bd18-a8fd1c94f7c0" />

I created the application database and configured a dedicated user with subnet-based access:

```sql
CREATE DATABASE tooling;
CREATE USER 'webaccess'@'172.31.16.0/255.255.240.0' IDENTIFIED BY 'Devopslearn12$%';
GRANT ALL PRIVILEGES ON tooling.* TO 'webaccess'@'172.31.16.0/255.255.240.0';
FLUSH PRIVILEGES;
```
<img width="1366" height="768" alt="tooling db created" src="https://github.com/user-attachments/assets/7969b1da-908a-4d2a-a419-3d9d32514fcf" />

This configuration allows any web server in the subnet to access the database while maintaining security through network-based restrictions.

### Step 4: Web Servers Configuration

I configured three identical web servers to demonstrate the stateless architecture. Each server mounts the same NFS shares and connects to the same database.
<img width="1366" height="768" alt="webservers created" src="https://github.com/user-attachments/assets/a9029173-eb4c-4a6d-a968-5c749ed5c84b" />

**NFS Client Setup:**
On each web server, I installed NFS utilities and mounted the shared storage:

```bash
sudo yum install nfs-utils nfs4-acl-tools -y
sudo mkdir /var/www
sudo mount -t nfs -o rw,nosuid 172.31.26.173:/mnt/apps /var/www
```
<img width="1366" height="768" alt="nfs client packages installed on all webservers" src="https://github.com/user-attachments/assets/cff68267-2d49-4429-bd55-23a4154ce572" />

**LAMP Stack Installation (RHEL 10):**
I adapted the installation process for RHEL 10, which required different package management approaches:
<img width="1366" height="768" alt="rhel repo web1" src="https://github.com/user-attachments/assets/35df07cf-2cc5-48ec-8621-6f763bf54aee" />

```bash
sudo yum install httpd -y
sudo yum install php php-common php-opcache php-cli php-gd php-curl php-mysqlnd php-fpm -y
sudo dnf install mariadb -y  # MySQL client compatibility
```
<img width="1366" height="768" alt="mariadb tooling" src="https://github.com/user-attachments/assets/8914bce4-5c50-44f9-90ae-31f673186268" />

**Application Deployment:**
I deployed the tooling application to the shared NFS storage, ensuring all servers serve identical content:

```bash
git clone https://github.com/StegTechHub/tooling.git
sudo cp -R tooling/html/* /var/www/html/
```
<img width="1366" height="768" alt="gitclone web1" src="https://github.com/user-attachments/assets/908537e4-e36b-47a3-a299-0822fd8dcd59" />

**Database Integration:**
I configured the application to connect to the centralized database by updating the connection parameters in functions.php:

```php
$db = mysqli_connect('172.31.22.114', 'webaccess', 'Devopslearn12$%', 'tooling');
```

I applied the database schema from the first web server:
```bash
mysql -h 172.31.22.114 -u webaccess -p tooling < /var/www/html/tooling-db.sql
```
<img width="1366" height="768" alt="varww mounted" src="https://github.com/user-attachments/assets/edca95bf-efca-43c9-8ad5-14d8a03e6cef" />

## Challenges and Solutions

### Challenge 1: RHEL 10 Package Repository Compatibility

**Issue:** The original project instructions assumed RHEL 8, but I was using RHEL 10. The EPEL and Remi repositories specified weren't compatible, causing PHP installation failures.

**Solution:** I adapted the installation process to use native RHEL 10 packages:
- Replaced external repositories with system packages
- Used `dnf install mariadb` for MySQL client compatibility  
- Modified PHP installation commands to work with RHEL 10's package structure

**Learning:** Always verify OS compatibility when following documentation, and be prepared to adapt commands for different distributions.

I also verified security group rules allowed MySQL connections and restarted both PHP-FPM and Apache services.

**Learning:** Timeout issues often indicate configuration problems rather than code issues. System logs are invaluable for diagnosing such problems.

### Challenge 3: NFS Mount Persistence  

**Issue:** NFS mounts didn't survive server reboots, causing the web servers to lose access to shared content.

**Solution:** I added proper entries to `/etc/fstab` on each web server:
```
172.31.26.173:/mnt/apps /var/www nfs defaults 0 0
172.31.26.173:/mnt/logs /var/log/httpd nfs defaults 0 0
```
<img width="1366" height="768" alt="mounts" src="https://github.com/user-attachments/assets/30b1fd95-7ae1-4441-a11f-674118fac177" />
<img width="1366" height="768" alt="verified mount -a" src="https://github.com/user-attachments/assets/d7241d11-1b49-4e51-8f69-1d763f53f243" />


**Learning:** Persistent mounts require fstab configuration. Always test mount persistence by rebooting test systems.

### Challenge 2: SELinux Security Restrictions

**Issue:** Apache couldn't serve files from NFS-mounted directories due to SELinux policies blocking network file access.

**Solution:** I configured appropriate SELinux booleans:
```bash
sudo setsebool -P httpd_execmem 1
sudo setsebool -P httpd_use_nfs 1
sudo setsebool -P httpd_can_network_connect 1
```
<img width="1366" height="768" alt="configured databases connecteion vi" src="https://github.com/user-attachments/assets/1f48d6a2-e48d-459b-9a8f-68e1749cbbd0" />

**Learning:** SELinux provides important security but requires explicit configuration for non-standard setups like NFS-mounted web content.


## Testing and Validation

I conducted comprehensive testing to validate the stateless architecture and shared storage functionality.

**NFS Functionality Testing:**
I created test files on one web server and verified they appeared on all others:
```bash
# On webserver-01
sudo touch /var/www/test-from-server1.txt

# Verified presence on webserver-02 and webserver-03
ls -la /var/www/
```
<img width="1366" height="768" alt="testfile-testing connectinon" src="https://github.com/user-attachments/assets/b0d03ba3-f574-4c5d-8577-fe32a21329df" />

**Database Connectivity Testing:**
I verified all web servers could connect to the database:
```bash
mysql -h 172.31.22.114 -u webaccess -p tooling
```

**Application Testing:**  
I accessed the tooling application from each web server's public IP and verified:
- Successful login with admin/admin credentials
- Identical content served from all servers
- Database operations worked consistently across all servers
<img width="1366" height="768" alt="web3login page" src="https://github.com/user-attachments/assets/02380890-f9dd-4dd3-87e1-9fc7dc766f71" />


## Lessons Learned

### Infrastructure Design

**Stateless Architecture Benefits:** The stateless design significantly simplifies scaling operations. New web servers can be added without complex data synchronization, and failed servers can be replaced without data recovery concerns.

**Security Group Strategy:** Implementing network security through AWS security groups rather than host-based firewalls provides centralized, manageable security policies that are easier to audit and maintain.

## Conclusion

This project demonstrates the implementation of a scalable, stateless web infrastructure using NFS shared storage and centralized database management. I successfully separated application logic from data storage, creating a system where multiple web servers serve identical content while maintaining data consistency.

**Key Implementation Results:**
- Created three identical web servers sharing content via NFS
- Established centralized MySQL database accessible by all servers
- Configured proper network security through AWS security groups
- Adapted installation procedures for RHEL 10 compatibility

This architecture enables horizontal scaling of web servers without data synchronization concerns, providing a foundation for high-availability web applications.
