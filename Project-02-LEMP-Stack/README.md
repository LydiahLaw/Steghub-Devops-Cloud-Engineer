# LEMP Stack Deployment on Cloud Server

A complete guide to deploying a LEMP (Linux, Nginx, MySQL, PHP) stack on a virtual server for hosting dynamic web applications.

## Project Overview

This project demonstrates the deployment of a LEMP stack from scratch on a cloud-based Ubuntu server. The LEMP stack is a powerful alternative to LAMP, utilizing Nginx's high performance and efficient resource usage to serve dynamic web content.

## Architecture Components

| Component | Purpose | Technology |
|-----------|---------|------------|
| **Linux** | Operating System | Ubuntu Server |
| **Nginx** | Web Server | High-performance HTTP server |
| **MySQL** | Database | Relational database management |
| **PHP** | Backend Logic | Server-side scripting language |


## Prerequisites

- Cloud server account (AWS, DigitalOcean, etc.)
- Basic Linux command line knowledge
- SSH access to the server
- Domain name (optional)

## Implementation Steps

### Step 1: Server Initialization

```bash
# Connect to your server
ssh username@your-server-ip

# Update system packages
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install curl wget unzip -y
```
<img width="1366" height="768" alt="ssh gitbassh" src="https://github.com/user-attachments/assets/6053c781-abdd-40c8-b0cd-f3ae7396041b" />

### Step 2: Nginx Installation & Configuration

```bash
# Install Nginx
sudo apt install nginx -y

# Start and enable Nginx
sudo systemctl start nginx
sudo systemctl enable nginx


# Verify installation
sudo systemctl status nginx
```
<img width="1366" height="768" alt="install nginx" src="https://github.com/user-attachments/assets/154664e1-8cf7-4e06-9d75-e520e21fa8ce" />

**Verification**: Visit `http://your-server-ip` to see the Nginx welcome page.

<img width="1366" height="768" alt="Nginx webpage" src="https://github.com/user-attachments/assets/87143045-dd9e-48bb-9a39-7bc3707cf42f" />

### Step 3: MySQL Database Setup

```bash
# Install MySQL server
sudo apt install mysql-server -y

# Secure MySQL installation
sudo mysql_secure_installation

# Access MySQL shell
sudo mysql
```
<img width="1366" height="768" alt="install mysql" src="https://github.com/user-attachments/assets/a50b686a-888a-4829-b100-a5329715ee79" />

**Database Configuration**:
```sql
# Create database
CREATE DATABASE sample_db;

# Create user with privileges
CREATE USER 'webuser'@'localhost' IDENTIFIED BY 'secure_password';
GRANT ALL PRIVILEGES ON sample_db.* TO 'webuser'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

### Step 4: PHP Installation & PHP-FPM Configuration

```bash
# Install PHP and required modules
sudo apt install php-fpm php-mysql php-cli php-curl php-gd php-mbstring php-xml -y

# Check PHP version
php -v

# Start and enable PHP-FPM
sudo systemctl start php8.1-fpm
sudo systemctl enable php8.1-fpm
```
<img width="1366" height="768" alt="install php" src="https://github.com/user-attachments/assets/81db464c-c334-491b-9b55-9894b45344f3" />

### Step 5: Nginx-PHP Integration

Create a new server block configuration:

```bash
sudo nano /etc/nginx/sites-available/lemp_project
```

**Server Block Configuration**:
```nginx
server {
    listen 80;
    server_name your_domain_or_ip;
    root /var/www/lemp_project;
    index index.php index.html index.htm;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
```
<img width="1366" height="768" alt="testing php" src="https://github.com/user-attachments/assets/6a9ba0c4-3900-41f5-b095-8f61ec9eee06" />

**Enable the Site**:
```bash
# Create project directory
sudo mkdir -p /var/www/lemp_project

# Set proper ownership
sudo chown -R $USER:$USER /var/www/lemp_project

# Enable site configuration
sudo ln -s /etc/nginx/sites-available/lemp_project /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```
<img width="1366" height="768" alt="php webpage" src="https://github.com/user-attachments/assets/ee892940-2bdd-46f9-bd31-24453e023879" />

### Step 6: Testing & Validation

**Create Test Files**:

1. **HTML Test File**:
```bash
echo "<h1>LEMP Stack Successfully Deployed!</h1>" | sudo tee /var/www/lemp_project/index.html
```

2. **PHP Info File**:
```bash
echo "<?php phpinfo(); ?>" | sudo tee /var/www/lemp_project/info.php
```

3. **Database Connection Test**:
```bash
sudo nano /var/www/lemp_project/db_test.php
```

```php
<?php
$servername = "localhost";
$username = "webuser";
$password = "secure_password";
$dbname = "sample_db";

try {
    $pdo = new PDO("mysql:host=$servername;dbname=$dbname", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    echo "Database connection successful!";
} catch(PDOException $e) {
    echo "Connection failed: " . $e->getMessage();
}
?>
```

## Testing Results

- **Nginx**: `http://your-server-ip` displays welcome page
- **PHP**: `http://your-server-ip/info.php` shows PHP configuration
- **Database**: `http://your-server-ip/db_test.php` confirms MySQL connectivity

<img width="1366" height="768" alt="lemp todolist" src="https://github.com/user-attachments/assets/1c114a4e-7bef-472d-9800-3ff4a79abe18" />


## Security Hardening

```bash
# Remove PHP info file (security risk)
sudo rm /var/www/lemp_project/info.php

# Set proper file permissions
sudo chmod -R 755 /var/www/lemp_project
sudo chown -R www-data:www-data /var/www/lemp_project

# Configure fail2ban (optional)
sudo apt install fail2ban -y
```

## Performance Optimization

**Nginx Optimization**:
```nginx
# Add to /etc/nginx/nginx.conf
worker_processes auto;
worker_connections 1024;
keepalive_timeout 65;
gzip on;
gzip_vary on;
gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
```
<img width="1366" height="768" alt="Nginx webpage" src="https://github.com/user-attachments/assets/c9eae267-512f-4308-89a2-f79257b3e7b0" />


**PHP-FPM Tuning**:
```bash
# Edit PHP-FPM pool configuration
sudo nano /etc/php/8.1/fpm/pool.d/www.conf


### Nginx-PHP Communication

- Nginx doesn't have built-in PHP support like Apache
- Uses **PHP-FPM** (FastCGI Process Manager) for PHP processing
- Communication via Unix socket or TCP connection
- Better isolation and resource management

## Troubleshooting Guide

**Common Issues & Solutions**:

```bash
# Nginx configuration errors
sudo nginx -t
sudo systemctl status nginx

# PHP-FPM issues
sudo systemctl status php8.1-fpm
sudo tail -f /var/log/php8.1-fpm.log

# Permission problems
sudo chown -R www-data:www-data /var/www/lemp_project
sudo chmod -R 755 /var/www/lemp_project

# Database connection issues
sudo systemctl status mysql
mysql -u webuser -p sample_db
```

## Project Structure

```
lemp-stack-deployment/
├── README.md
├── nginx/
│   └── lemp_project.conf
├── php/
│   ├── info.php
│   └── db_test.php
├── scripts/
│   └── setup.sh
└── screenshots/
    
```

## Learning Outcomes

- **Web Server Architecture**: Understanding Nginx's event-driven model
- **Database Management**: MySQL user management and security practices  
- **PHP Configuration**: PHP-FPM pool management and optimization
- **System Administration**: Linux server management and security hardening
- **Performance Tuning**: Web stack optimization techniques
