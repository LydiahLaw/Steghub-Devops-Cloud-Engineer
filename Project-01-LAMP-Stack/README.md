# LAMP Stack Deployment on AWS

A comprehensive guide to manually deploying a LAMP (Linux, Apache, MySQL, PHP) stack on an AWS EC2 Ubuntu instance.

## Overview

This project demonstrates how to set up a complete LAMP stack from scratch on AWS infrastructure. The LAMP stack is a popular web development platform that combines four key technologies to create dynamic, database-driven websites and applications.

### What is LAMP?
- **Linux** - Operating System
- **Apache** - Web Server
- **MySQL** - Database Management System
- **PHP** - Server-side Scripting Language

## Why LAMP Stack?

The LAMP stack remains a cornerstone of web development because it offers:

- **Stability** - Battle-tested components with years of proven reliability
- **Cost-effectiveness** - All components are open-source and free
- **Community Support** - Extensive documentation and community resources
- **Flexibility** - Suitable for everything from simple websites to complex applications
- **Learning Value** - Perfect foundation for understanding full-stack development

## Prerequisites

Before starting, ensure you have:

- AWS account with appropriate permissions
- Basic understanding of Linux command line
- SSH client installed on your local machine
- A key pair for EC2 access

## Installation Guide

### Step 1: AWS Infrastructure Setup

1. **Launch EC2 Instance**
   - Choose Ubuntu Server (latest LTS version recommended)
   - Select `t2.micro` for free tier eligibility
   - Configure security group to allow HTTP (port 80) and SSH (port 22)
   - Download and securely store your key pair
  
     <img width="1366" height="768" alt="launch an instance" src="https://github.com/user-attachments/assets/6e9a6372-88ca-47a9-8bce-895a3251f4cb" />


2. **Connect to Your Instance**
   ```bash
   # Set appropriate permissions for your key file
   chmod 400 your-key-name.pem
   
   # Connect via SSH
   ssh -i your-key-name.pem ubuntu@your-ec2-public-ip
   ```
   <img width="1366" height="768" alt="ssh EC2 instance" src="https://github.com/user-attachments/assets/152a2e29-4c82-40c2-b2f3-818628546509" />


### Step 2: Install Apache Web Server

```bash
# Update package repositories
sudo apt update -y && sudo apt upgrade -y

# Install Apache
sudo apt install apache2 -y

# Configure firewall (if UFW is active)
sudo ufw allow 'Apache Full'

# Verify Apache is running
sudo systemctl status apache2
```

**Verification**: Navigate to `http://your-ec2-public-ip` in your browser. You should see the Apache default page.
<img width="1366" height="768" alt="install apache" src="https://github.com/user-attachments/assets/1dc2b794-bc7c-4c1f-aacd-9cf57cf436dc" />

### Step 3: Install MySQL Database

```bash
# Install MySQL server
sudo apt install mysql-server -y

# Secure the MySQL installation
sudo mysql_secure_installation
```
<img width="1366" height="768" alt="install mysql" src="https://github.com/user-attachments/assets/6ba342e7-e3d3-440d-afc6-3ff79bcd462f" />


During the secure installation process:
- Set a strong root password
- Remove anonymous users
- Disallow remote root login
- Remove test database
- Reload privilege tables

### Step 4: Install PHP

```bash
# Install PHP and required modules
sudo apt install php libapache2-mod-php php-mysql -y

# Verify PHP installation
php -v
```
<img width="1366" height="768" alt="instal php" src="https://github.com/user-attachments/assets/2a1c3ffa-09dc-40f1-ab53-3b47707f5675" />


### Step 5: Configure Virtual Host

1. **Create Project Directory**
   ```bash
   sudo mkdir /var/www/lamp_project
   sudo chown -R $USER:$USER /var/www/lamp_project
   ```
   <img width="1366" height="768" alt="projectlamp" src="https://github.com/user-attachments/assets/6b173e54-29ca-41f4-805b-0bf75b9dfd20" />


2. **Create Virtual Host Configuration**
   ```bash
   sudo nano /etc/apache2/sites-available/lamp_project.conf
   ```
<img width="1366" height="768" alt="project config" src="https://github.com/user-attachments/assets/6befdf4e-9fbb-410a-a293-bce024ce47ad" />

3. **Add Configuration Content**
   ```apache
   <VirtualHost *:80>
       ServerAdmin webmaster@localhost
       DocumentRoot /var/www/lamp_project
       ErrorLog ${APACHE_LOG_DIR}/error.log
       CustomLog ${APACHE_LOG_DIR}/access.log combined
   </VirtualHost>
   ```

4. **Enable Site and Reload Apache**
   ```bash
   # Enable new site
   sudo a2ensite lamp_project.conf
   
   # Disable default site
   sudo a2dissite 000-default.conf
   
   # Test configuration
   sudo apache2ctl configtest
   
   # Reload Apache
   sudo systemctl reload apache2
   ```
<img width="1366" height="768" alt="reload apache" src="https://github.com/user-attachments/assets/0c525fc1-5767-469e-92ca-786dd8b76df9" />

### Step 6: Configure PHP Priority

```bash
# Edit directory index configuration
sudo nano /etc/apache2/mods-enabled/dir.conf
```

Modify the DirectoryIndex line to prioritize PHP files:
```apache
DirectoryIndex index.php index.html index.cgi index.pl index.xhtml index.htm
```

```bash
# Reload Apache to apply changes
sudo systemctl reload apache2
```

### Step 7: Test Your LAMP Stack

1. **Create Test HTML File**
   ```bash
   echo 'Hello from LAMP stack on AWS!' > /var/www/lamp_project/index.html
   ```
   <img width="1366" height="768" alt="test" src="https://github.com/user-attachments/assets/16af4a2a-c63f-4a89-818b-bd7e436758fd" />


2. **Create PHP Info File**
   ```bash
   nano /var/www/lamp_project/index.php
   ```
   
   Add the following content:
   ```php
   <?php
   phpinfo();
   ?>
   ```

3. **Test Your Setup**
   - Visit `http://your-ec2-public-ip` to see the PHP info page
   - This confirms all LAMP components are working together

## Verification Checklist

- Apache is serving web pages
- MySQL is installed and secured
- PHP is processing server-side scripts
- Virtual host is configured correctly
- All components communicate properly

<img width="1366" height="768" alt="live test" src="https://github.com/user-attachments/assets/aa7cc755-5afe-4ad6-af2a-dae57ce9b604" />


## Troubleshooting

### Common Issues

**Apache not starting:**
```bash
sudo systemctl status apache2
sudo journalctl -u apache2.service
```

**Permission issues:**
```bash
sudo chown -R www-data:www-data /var/www/lamp_project
sudo chmod -R 755 /var/www/lamp_project
```

**Firewall blocking connections:**
```bash
sudo ufw status
sudo ufw allow 80/tcp
```

## Contributing

Feel free to submit issues, fork the repository, and create pull requests for any improvements.

## License

This project is open source and available under the MIT License.

---
