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

---

## Step 1 — Web Server Setup

Connect to your Web Server instance:

```bash
ssh -i WebKey.pem ec2-user@98.81.216.248
lsblk
```

Verify that three additional volumes appear as `nvme1n1`, `nvme2n1`, `nvme3n1`.

---

## Step 2 — Partitioning and LVM on Web Server

### Create partitions on each disk:

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

### Format and mount filesystems:

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

Add entries using UUIDs for `/var/www/html` and `/var/log` mount points.

---

## Step 3 — Apache, PHP, and WordPress Setup

### Install web server components:

```bash
sudo dnf update -y
sudo dnf install -y httpd wget tar
sudo dnf install -y php php-mysqlnd php-fpm php-json php-gd php-xml php-mbstring php-zip php-curl
sudo systemctl enable --now httpd php-fpm
```

### Download and configure WordPress:

```bash
cd /tmp
wget https://wordpress.org/latest.tar.gz
tar -xvzf latest.tar.gz
sudo cp -R wordpress /var/www/html/
sudo cp /var/www/html/wordpress/wp-config-sample.php /var/www/html/wordpress/wp-config.php
```

### Set permissions and SELinux contexts:

```bash
sudo chown -R apache:apache /var/www/html/wordpress
sudo semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/html/wordpress(/.*)?"
sudo restorecon -Rv /var/www/html/wordpress
sudo setsebool -P httpd_can_network_connect 1
```

---

## Step 4 — Database Server Setup

Repeat the LVM configuration steps from Step 2 on your database server, but mount the main logical volume at `/db` instead of `/var/www/html`.

---

## Step 5 — MySQL Configuration

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

You should see the `wordpress` database listed.

### Complete WordPress installation:

Navigate to `http://98.81.216.248/wordpress/` and follow the WordPress installation wizard.

---

## Testing

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
