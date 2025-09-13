# Project 06 — Web Solution with WordPress (RHEL 10)

## Table of Contents
- [Introduction](#introduction)  
- [Architecture](#architecture)  
- [Prerequisites](#prerequisites)  
- [Step 1 — Web Server Setup](#step-1--web-server-setup)  
- [Step 2 — Partitioning and LVM on Web Server](#step-2--partitioning-and-lvm-on-web-server)  
- [Step 3 — Apache, PHP, and WordPress Setup](#step-3--apache-php-and-wordpress-setup)  
- [Step 4 — Database Server Setup](#step-4--database-server-setup)  
- [Step 5 — MySQL Configuration](#step-5--mysql-configuration)  
- [Step 6 — Connect WordPress to Remote Database](#step-6--connect-wordpress-to-remote-database)  
- [Testing](#testing)  
- [Troubleshooting](#troubleshooting)  
- [Conclusion](#conclusion)

---

## Introduction

This project demonstrates a scalable web solution built on AWS using two RHEL 10 EC2 instances. The architecture separates the web and database layers for better performance, security, and maintainability.

**Key Features:**
- Web Server hosting Apache, PHP, and WordPress
- Separate Database Server running MySQL
- LVM-backed storage for both servers
- Proper security group configuration

---

## Architecture

```
┌─────────────────┐    ┌──────────────────┐
│   Web Server    │    │   Database       │
│   (App Layer)   │────│   Server         │
│                 │    │   (Data Layer)   │
│ - Apache        │    │ - MySQL          │
│ - PHP           │    │                  │
│ - WordPress     │    │                  │
└─────────────────┘    └──────────────────┘
```

### Network Configuration
- **Web Server Public IP:** `98.81.216.248`  
- **Web Server Private IP:** `172.31.30.108`  
- **Database Server Private IP:** `172.31.17.28`  

---

## Prerequisites

1. **AWS Region:** `us-east-1`  
2. **AMI:** RHEL 10  
3. **Instance Type:** `t3.micro`  
4. **Storage:** 3 additional 10GiB EBS volumes per instance  
5. **Security Groups:**
   - **Web Server:** SSH (your IP), HTTP 80 (0.0.0.0/0), HTTPS 443 (optional)  
   - **Database Server:** SSH (your IP), MySQL 3306 (Web Server private IP only)
     
<img width="1366" height="768" alt="instance created" src="https://github.com/user-attachments/assets/d7b9ab3e-74f2-43e8-bc40-eccfe6d85be8" />

<img width="1366" height="768" alt="attach volumes" src="https://github.com/user-attachments/assets/9dfc2123-5f13-4a29-b570-3817b9c3a108" />


---

## Step 1 — Web Server Setup

Connect to your Web Server instance:

```bash
ssh -i WebKey.pem ec2-user@98.81.216.248
lsblk
```
<img width="1366" height="768" alt="ssh" src="https://github.com/user-attachments/assets/3b42d2c4-29f5-4aaa-b7d9-b892b8444b91" />

Verify that three additional volumes appear as `nvme1n1`, `nvme2n1`, `nvme3n1`.
<img width="1366" height="768" alt="check vol" src="https://github.com/user-attachments/assets/8890bb5e-1c4f-44e0-9c90-723fcc6e6012" />

---

## Step 2 — Partitioning and LVM on Web Server

### Create partitions on each disk:
<img width="1366" height="768" alt="partitioning volumes" src="https://github.com/user-attachments/assets/ae3bcce7-2f2b-456d-8bd7-398907b78ecd" />
```bash
sudo fdisk /dev/nvme1n1
```

Follow these prompts for each disk:
- `n` → new partition
- `p` → primary partition  
- Accept defaults for partition number and sectors
- `t` → change partition type
- `8e` → Linux LVM
- `w` → write changes

Repeat for `/dev/nvme2n1` and `/dev/nvme3n1`.

### Configure LVM:

```bash
sudo dnf install -y lvm2
sudo pvcreate /dev/nvme1n1p1 /dev/nvme2n1p1 /dev/nvme3n1p1
sudo vgcreate webdata-vg /dev/nvme1n1p1 /dev/nvme2n1p1 /dev/nvme3n1p1
sudo lvcreate -n apps-lv -L 14G webdata-vg
sudo lvcreate -n logs-lv -L 14G webdata-vg
```
<img width="1366" height="768" alt="logical vols" src="https://github.com/user-attachments/assets/b80cab20-d94a-4a5d-a4a5-add11e5c5483" />

### Format and mount filesystems:
<img width="1366" height="768" alt="ext4" src="https://github.com/user-attachments/assets/3a26d54a-af55-4e26-a46a-1065dd3cc1e7" />


```bash
sudo mkfs.ext4 /dev/webdata-vg/apps-lv
sudo mkfs.ext4 /dev/webdata-vg/logs-lv

sudo mkdir -p /var/www/html
sudo mkdir -p /home/recovery/logs

sudo mount /dev/webdata-vg/apps-lv /var/www/html
sudo rsync -av /var/log/ /home/recovery/logs/
sudo mount /dev/webdata-vg/logs-lv /var/log
sudo rsync -av /home/recovery/logs/ /var/log
```

### Make mounts persistent:

```bash
sudo blkid
sudo vi /etc/fstab
```
<img width="1366" height="768" alt="munt varlogs" src="https://github.com/user-attachments/assets/7a49bcbf-fd32-4efa-a088-47fe5cd661e1" />
<img width="1366" height="768" alt="mounts verified" src="https://github.com/user-attachments/assets/b2f9ad5c-08b1-48c3-971c-600347f403ab" />

Add entries using UUIDs for `/var/www/html` and `/var/log` mount points.
<img width="1366" height="768" alt="UUIDs" src="https://github.com/user-attachments/assets/82c613c4-73ac-4656-8241-0f88d2486207" />

---

## Step 3 — Apache, PHP, and WordPress Setup

### Install web server components:

```bash
sudo dnf update -y
sudo dnf install -y httpd wget tar
sudo dnf install -y php php-mysqlnd php-fpm php-json php-gd php-xml php-mbstring php-zip php-curl
sudo systemctl enable --now httpd php-fpm
```
<img width="1366" height="768" alt="mysql webserver" src="https://github.com/user-attachments/assets/f7b05d5a-1c59-4fac-a69d-e60d3314c79c" />

### Download and configure WordPress:

```bash
cd /tmp
wget https://wordpress.org/latest.tar.gz
tar -xvzf latest.tar.gz
sudo cp -R wordpress /var/www/html/
sudo cp /var/www/html/wordpress/wp-config-sample.php /var/www/html/wordpress/wp-config.php
```
<img width="1366" height="768" alt="download wordpress" src="https://github.com/user-attachments/assets/548da226-5ae0-4e49-b853-3e7eccbdbff3" />

### Set permissions and SELinux contexts:

```bash
sudo chown -R apache:apache /var/www/html/wordpress
sudo semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/html/wordpress(/.*)?"
sudo restorecon -Rv /var/www/html/wordpress
sudo setsebool -P httpd_can_network_connect 1
```
<img width="1366" height="768" alt="restore log files" src="https://github.com/user-attachments/assets/26f19637-b7e1-44be-86cd-315472b390d2" />

---

## Step 4 — Database Server Setup

Repeat the LVM configuration steps from Step 2 on your database server, but mount the main logical volume at `/db` instead of `/var/www/html`.
<img width="1366" height="768" alt="db server cretaed" src="https://github.com/user-attachments/assets/a8835823-9b02-4108-a801-0d8d83a552dc" />

---

## Step 5 — MySQL Configuration
<img width="1366" height="768" alt="ssh db" src="https://github.com/user-attachments/assets/e8868f2d-481e-43b7-aaa0-7f108edcb2e0" />

### Install MySQL on the database server:

```bash
sudo dnf install -y https://dev.mysql.com/get/mysql80-community-release-el9-1.noarch.rpm
sudo dnf install -y mysql-community-server
sudo systemctl enable --now mysqld
```

### Secure MySQL installation:

```bash
sudo mysql_secure_installation
```

### Create database and user:

```sql
CREATE DATABASE wordpress;
CREATE USER 'myuser'@'172.31.30.108' IDENTIFIED BY 'Devopslearn12$%';
GRANT ALL PRIVILEGES ON wordpress.* TO 'myuser'@'172.31.30.108';
FLUSH PRIVILEGES;
```
<img width="1366" height="768" alt="mysql db" src="https://github.com/user-attachments/assets/19579137-7637-4b78-a44b-d348f7309cad" />

### Configure MySQL to accept remote connections:

Edit `/etc/my.cnf`:
```ini
[mysqld]
bind-address = 0.0.0.0
```

Restart MySQL:
```bash
sudo systemctl restart mysqld
```

---

## Step 6 — Connect WordPress to Remote Database

### Configure WordPress database connection:

Edit `/var/www/html/wordpress/wp-config.php`:

```php
define('DB_NAME', 'wordpress');
define('DB_USER', 'myuser');
define('DB_PASSWORD', 'Devopslearn12$%');
define('DB_HOST', '172.31.17.28');
```

### Test database connectivity:

```bash
sudo dnf install -y mysql
mysql -u myuser -p -h 172.31.17.28
```

In the MySQL prompt:
```sql
SHOW DATABASES;
```
<img width="1366" height="768" alt="Screenshot (940)" src="https://github.com/user-attachments/assets/2672ba1f-084d-436f-8d5b-2544701eb1a7" />

You should see the `wordpress` database listed.

### Complete WordPress installation:

Navigate to `http://98.81.216.248/wordpress/` and follow the WordPress installation wizard.
<img width="1366" height="768" alt="wordpress installation" src="https://github.com/user-attachments/assets/744144b6-c1bb-424a-af78-ab9df04ba4b9" />

<img width="1366" height="768" alt="wordpress setup" src="https://github.com/user-attachments/assets/e2f03aaa-7887-46f8-b0fe-2485f26258ee" />
<img width="1366" height="768" alt="success" src="https://github.com/user-attachments/assets/b01d1390-4051-4738-9530-3f599af0ac99" />



---

## Testing
<img width="1366" height="768" alt="login wordpress" src="https://github.com/user-attachments/assets/9391a0cf-abd1-43ac-acdd-e5902a0c75c0" />
<img width="1366" height="768" alt="wordpress dashboard" src="https://github.com/user-attachments/assets/a9b180eb-1d6e-4524-8421-4928a57a8d9e" />


Verify your setup:

1. **Storage:** `df -h` shows `/var/www/html` mounted on LVM
2. **Database:** `systemctl status mysqld` shows MySQL running
3. **Connectivity:** Remote MySQL connection from web server works
4. **Web Access:** WordPress loads successfully in browser

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| MySQL connection denied | Verify GRANT statement uses correct IP address |
| Apache permission errors | Check SELinux contexts with `restorecon` |
| MySQL secure installation hangs | Reset root password using init file |
| Partition type issues | Use `fdisk` for simplicity, `gdisk` for GPT requirements |

---

## Conclusion

This project demonstrates a production-like WordPress deployment with proper separation of concerns:

- **Scalability:** Web and database layers can be scaled independently
- **Security:** Database access restricted to web server only  
- **Storage Management:** LVM provides flexibility for future growth
- **Real-world Skills:** Covers AWS, Linux administration, web servers, and database management

The architecture mirrors enterprise environments where applications and databases run on separate servers for better performance, security, and maintainability.
