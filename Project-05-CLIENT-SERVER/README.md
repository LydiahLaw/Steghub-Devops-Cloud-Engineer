# CLIENT-SERVER ARCHITECTURE

## Table of Contents
- [Problem](#problem)
- [Solution](#solution)
- [Tech Stack](#tech-stack)
- [Architecture](#architecture)
- [Step-by-Step Implementation](#step-by-step-implementation)
  - [1. Create EC2 Instances and Security Groups](#1-create-ec2-instances-and-security-groups)
  - [2. Install MySQL on the Server EC2](#2-install-mysql-on-the-server-ec2)
  - [3. Update MySQL Configuration](#3-update-mysql-configuration)
  - [4. Create a Remote MySQL User](#4-create-a-remote-mysql-user)
  - [5. Update Security Groups](#5-update-security-groups)
  - [6. Connect from the Client EC2](#6-connect-from-the-client-ec2)
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

### 1. Create EC2 Instances and Security Groups
- Launch two Ubuntu 20.04 EC2 instances:
  - Server A: **mysql server**
  - Server B: **mysql client**
- Ensure both are in the same VPC so they can communicate with each other.
- Create a **security group** for the mysql server with:
  - SSH access (port 22) from your IP
  - MySQL access (port 3306) allowed **only from the client EC2's private IP**
- Attach this security group to the mysql server EC2 instance.
<img width="1366" height="768" alt="instances running" src="https://github.com/user-attachments/assets/bd9ae011-04e8-49c6-bc47-ca04df629df2" />

<img width="1366" height="768" alt="security groups" src="https://github.com/user-attachments/assets/9b794061-1117-484f-b143-2f012d1c5f8b" />


### 2. Install MySQL on the Server EC2

```bash
sudo apt update
sudo apt install mysql-server -y
```
<img width="1366" height="768" alt="install mysl server" src="https://github.com/user-attachments/assets/cf315b3d-59b0-4aa7-97ab-85040911923b" />

<img width="1366" height="768" alt="install mysl server" src="https://github.com/user-attachments/assets/829ecb3d-399f-4df4-a8a1-b6031c9de885" />

### 3. Update MySQL Configuration
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
<img width="1366" height="768" alt="mysql running" src="https://github.com/user-attachments/assets/42cb121a-49f9-485f-a8c0-96bcfeddc187" />

### 4. Create a Remote MySQL User
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
<img width="1366" height="768" alt="user permissions" src="https://github.com/user-attachments/assets/421bcdb7-10bb-4a7c-9d2a-9978e023187e" />

> **Note:** 172.31.36.252 is the private IP of the client EC2.

### 5. Update Security Groups
On the MySQL server EC2 security group, confirm port 3306 allows inbound traffic from the client EC2's private IP only.
<img width="1366" height="768" alt="aurora inbound" src="https://github.com/user-attachments/assets/54f68ac9-5a08-40d1-95ba-d9232ff62957" />


### 6. Connect from the Client EC2
Run the following from the client EC2:

```bash
mysql -h 34.203.194.118 -P 3306 -u remoteuser -p
```
<img width="1366" height="768" alt="connection succedded" src="https://github.com/user-attachments/assets/451342d1-b54d-4173-939f-5cd31e392fee" />

> **Note:** 34.203.194.118 is the MySQL server's public IP. Enter the password (Devopslearn) to connect.
<img width="1366" height="768" alt="show databases" src="https://github.com/user-attachments/assets/0632b982-ae63-4ae4-8880-66869dc73a55" />

## Lessons Learned
- MySQL requires the private IP of the client when creating the remote user
- The client connects using the server's public IP
- Both MySQL config and AWS security group rules must be correctly set for the connection to succeed

## Conclusion
I successfully connected one EC2 instance to a MySQL database hosted on another EC2. This project clarified the relationship between private IPs (for MySQL user creation), public IPs (for external connection), and the importance of correctly configuring AWS security groups and MySQL server settings.
