# LAMP Stack on AWS

## Table of Contents  
- [Introduction](#introduction)  
- [What Problem Does LAMP Stack Solve?](#what-problem-does-lamp-stack-solve)  
- [Deploying a LAMP Stack Manually on AWS](#deploying-a-lamp-stack-manually-on-aws)  
  - [Step 0 - Prepare Prerequisites](#step-0---prepare-prerequisites)  
  - [Step 1 - Install Apache and Update Firewall](#step-1---install-apache-and-update-firewall)  
  - [Step 2 - Install MySQL](#step-2---install-mysql)  
  - [Step 3 - Install PHP](#step-3---install-php)  
  - [Step 4 - Configure Apache Virtual Host](#step-4---configure-apache-virtual-host)  
  - [Step 5 - Enable PHP on the Website](#step-5---enable-php-on-the-website)  
  - [Step 6 - Create PHP Script to Test PHP Configuration](#step-6---create-php-script-to-test-php-configuration)  
- [Conclusion](#conclusion)

---

## Introduction  
In this project, I’ll walk through deploying a LAMP stack on an AWS Ubuntu EC2 instance from scratch. LAMP — Linux, Apache, MySQL, PHP — is a classic web development stack that powers many websites and web apps. The goal is to set up a reliable, functional environment that can serve dynamic web content with a database backend.

I’ll explain each step, the why and how, and share what I learned. Later, I’ll add screenshots to make it easy to follow visually.

---

## What Problem Does LAMP Stack Solve?  
LAMP is a foundational framework for hosting dynamic websites and web applications. It combines Linux (the OS), Apache (web server), MySQL (database), and PHP (server-side scripting) to deliver content that can change based on user input or data.

Despite newer frameworks and stacks, LAMP remains popular because it’s stable, well-supported, cost-effective, and versatile. It’s a great starting point for learning full-stack web development and deploying real-world apps.

---

## Deploying a LAMP Stack Manually on AWS  

### Step 0 - Prepare Prerequisites  
- Create an AWS account if you don’t have one.  
- Launch an Ubuntu EC2 instance (I chose t2.micro under the free tier).  
- Download the SSH private key and set permissions (`chmod 400 key.pem`).  
- Connect to your instance with SSH:  
```bash
ssh -i key.pem ubuntu@<your-ec2-public-ip>
Step 1 - Install Apache and Update Firewall
Apache serves web pages to users. First, update your package list:

bash
Copy
Edit
sudo apt update -y && sudo apt upgrade -y
sudo apt install apache2 -y
Check firewall status:

bash
Copy
Edit
sudo ufw status
If active, allow Apache:

bash
Copy
Edit
sudo ufw allow 'Apache Full'
Verify Apache is running:

bash
Copy
Edit
sudo systemctl status apache2
Open your browser to your EC2 public IP, and you should see the Apache default page.

Step 2 - Install MySQL
MySQL will store the data for your website. Install it with:

bash
Copy
Edit
sudo apt install mysql-server -y
Secure your installation:

bash
Copy
Edit
sudo mysql_secure_installation
Set a strong root password when prompted and follow the steps to remove anonymous users, disallow remote root login, remove test database, and reload privilege tables.

Step 3 - Install PHP
PHP runs dynamic code on your server and interacts with MySQL. Install PHP and related modules:

bash
Copy
Edit
sudo apt install php libapache2-mod-php php-mysql -y
Verify PHP version:

bash
Copy
Edit
php -v
Step 4 - Configure Apache Virtual Host
Set up a dedicated folder for your project:

bash
Copy
Edit
sudo mkdir /var/www/lamp_project
sudo chown -R $USER:$USER /var/www/lamp_project
Create a new Apache config file for your project:

bash
Copy
Edit
sudo nano /etc/apache2/sites-available/lamp_project.conf
Add:

bash
Copy
Edit
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/lamp_project
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
Enable your site and disable default:

bash
Copy
Edit
sudo a2ensite lamp_project.conf
sudo a2dissite 000-default.conf
sudo apache2ctl configtest
sudo systemctl reload apache2
Create a simple index.html to test:

bash
Copy
Edit
echo 'Hello from LAMP stack on AWS!' > /var/www/lamp_project/index.html
Open your EC2 IP in browser — you should see the message.

Step 5 - Enable PHP on the Website
Edit Apache’s dir.conf to prioritize index.php over index.html:

bash
Copy
Edit
sudo nano /etc/apache2/mods-enabled/dir.conf
Move index.php to the front in the DirectoryIndex line, save, and reload Apache:

bash
Copy
Edit
sudo systemctl reload apache2
Step 6 - Create PHP Script to Test PHP Configuration
Create an index.php file:

bash
Copy
Edit
nano /var/www/lamp_project/index.php
Add:

php
Copy
Edit
<?php
phpinfo();
?>
Save and visit your site. You should see the PHP info page showing your PHP configuration.

Conclusion
Setting up a LAMP stack on AWS manually helped me understand each component of the stack and how they work together to serve dynamic websites. It also gave me hands-on experience with Linux, Apache config, MySQL security, and PHP setup.

This environment can now host real web applications that interact with databases, and it’s a solid foundation for further learning.
