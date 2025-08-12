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

### Step 3: Install MySQL Database

```bash
# Install MySQL server
sudo apt install mysql-server -y

# Secure the MySQL installation
sudo mysql_secure_installation
```

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

### Step 5: Configure Virtual Host

1. **Create Project Directory**
   ```bash
   sudo mkdir /var/www/lamp_project
   sudo chown -R $USER:$USER /var/www/lamp_project
   ```

2. **Create Virtual Host Configuration**
   ```bash
   sudo nano /etc/apache2/sites-available/lamp_project.conf
   ```

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

## Security Considerations

- Remove the PHP info file after testing (it exposes system information)
- Regularly update all packages: `sudo apt update && sudo apt upgrade`
- Configure SSL/TLS certificates for production use
- Implement proper database user permissions
- Consider using fail2ban for SSH protection

## Next Steps

With your LAMP stack operational, you can:

- Deploy actual web applications
- Set up additional virtual hosts for multiple sites
- Configure SSL certificates with Let's Encrypt
- Implement database backups
- Set up monitoring and logging
- Optimize performance settings

## Contributing

Feel free to submit issues, fork the repository, and create pull requests for any improvements.

## License

This project is open source and available under the MIT License.

---

**Note**: Remember to clean up AWS resources when not in use to avoid unnecessary charges.
