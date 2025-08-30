# CLIENT-SERVER ARCHITECTURE

## Table of Contents

- [Problem](#problem)
- [Solution](#solution)
- [Tech Stack](#tech-stack)
- [Architecture](#architecture)
- [Step-by-Step Implementation](#step-by-step-implementation)
  - [1. Install MySQL on the Server EC2](#1-install-mysql-on-the-server-ec2)
  - [2. Update MySQL Configuration](#2-update-mysql-configuration)
  - [3. Create a Remote MySQL User](#3-create-a-remote-mysql-user)
  - [4. Update Security Groups](#4-update-security-groups)
  - [5. Connect from the Client EC2](#5-connect-from-the-client-ec2)
- [Lessons Learned](#lessons-learned)
- [Conclusion](#conclusion)

## Problem

When applications run on different servers, one server may need to connect to a MySQL database hosted on another. By default, MySQL blocks external connections for security reasons. The challenge was to configure MySQL and AWS so that a client EC2 instance could connect remotely to a MySQL database running on another EC2.

## Solution

I configured MySQL to accept remote connections, created a dedicated user for the client EC2, and updated AWS security groups to allow communication on port 3306.

## Tech Stack

- AWS EC2 (Ubuntu 20.04)
- MySQL Server
- Linux CLI (Ubuntu terminal / Git Bash)

## Architecture

- **MySQL Server EC2**
  - Public IP: 34.203.194.118
  - Runs MySQL and listens on port 3306
- **Client EC2**
  - Connects remotely to the MySQL server
- **AWS Security Groups**
  - Allows inbound traffic on port 3306 from the client EC2's private IP

## Step-by-Step Implementation

### 1. Install MySQL on the Server EC2

```bash
sudo apt update
sudo apt install mysql-server -y
```

### 2. Update MySQL Configuration

Edit the MySQL config file:

```bash
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
```

Change the bind address:

```
bind-address = 0.0.0.0
```

Restart MySQL:

```bash
sudo systemctl restart mysql
```

### 3. Create a Remote MySQL User

Log into MySQL shell:

```bash
sudo mysql -u root -p
```

Create a user tied to the client EC2 private IP:

```sql
CREATE USER 'remoteuser'@'172.31.36.252' IDENTIFIED BY 'Devopslearn';
GRANT ALL PRIVILEGES ON *.* TO 'remoteuser'@'172.31.36.252' WITH GRANT OPTION;
FLUSH PRIVILEGES;
```

> **Note:** 172.31.36.252 is the private IP of the client EC2.

### 4. Update Security Groups

On the MySQL server EC2 security group, open port 3306 for inbound traffic from the client EC2's private IP.

### 5. Connect from the Client EC2

Run the following from the client EC2:

```bash
mysql -h 34.203.194.118 -P 3306 -u remoteuser -p
```

> **Note:** 34.203.194.118 is the MySQL server's public IP. Enter the password (Devopslearn) to connect.

## Lessons Learned

- MySQL requires the private IP of the client when creating the remote user
- The client connects using the server's public IP
- Both MySQL config and AWS security group rules must be correctly set for the connection to succeed

## Conclusion

I successfully connected one EC2 instance to a MySQL database hosted on another EC2. This project clarified the relationship between private IPs (for MySQL user creation), public IPs (for external connection), and the importance of correctly configuring AWS security groups and MySQL server settings.
