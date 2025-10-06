# Apache Load Balancer with Two Web Servers on AWS

## Table of Contents
1. [Introduction](#1-introduction)
2. [Architecture](#2-architecture)
3. [Prerequisites](#3-prerequisites)
4. [Step 1: Launch EC2 Instances](#4-step-1-launch-ec2-instances)
5. [Step 2: Configure Security Groups](#5-step-2-configure-security-groups)
6. [Step 3: Set Up Web Servers](#6-step-3-set-up-web-servers)
7. [Step 4: Set Up Load Balancer Server](#7-step-4-set-up-load-balancer-server)
8. [Step 5: Configure VirtualHost for Load Balancing](#8-step-5-configure-virtualhost-for-load-balancing)
9. [Step 6: Update /etc/hosts](#9-step-6-update-etchosts)
10. [Step 7: Test the Setup](#10-step-7-test-the-setup)
11. [Verification and Troubleshooting](#11-verification-and-troubleshooting)
12. [Key Takeaways](#12-key-takeaways)
13. [Conclusion](#13-conclusion)

---

## 1. Introduction
In this project, I set up a simple load balancing solution on AWS using Apache. I created two web servers (Web1 and Web2) and a separate server acting as the load balancer. The goal was to distribute traffic between the two backend servers using Apache's mod_proxy and mod_proxy_balancer modules.

---

## 2. Architecture
- **Web1** and **Web2**: Apache web servers running unique index pages.  
- **Load Balancer (LB)**: Apache server configured with proxy and balancer modules to distribute requests.  
- **Clients**: Access the public IP of the Load Balancer.  

---

## 3. Prerequisites
- AWS account  
- Basic knowledge of EC2, SSH, and Linux commands  
- A key pair for SSH access  

---

## 4. Step 1: Launch EC2 Instances
- Launch **3 Ubuntu EC2 instances** in the same VPC and subnet:
  - Web1  
  - Web2  
  - Load Balancer  

- Make sure they all have public IPs for initial SSH access.  
<img width="1366" height="768" alt="instances created 1" src="https://github.com/user-attachments/assets/e02f0d1a-acfd-432e-a341-4262d65f70c2" />

---

## 5. Step 2: Configure Security Groups
I created and attached security groups as follows:

- **Web1 and Web2 Security Group**  
  - Inbound:  
    - HTTP (80) from **Load Balancer's private IP**  
    - SSH (22) from **my local IP**  

- **Load Balancer Security Group**  
  - Inbound:  
    - HTTP (80) from `0.0.0.0/0`  
    - SSH (22) from **my local IP**  
<img width="1366" height="768" alt="securitygroups created 2" src="https://github.com/user-attachments/assets/f36ca36f-727b-46bb-a411-98f86c93be37" />

This setup ensures only the load balancer can talk to the backend servers on port 80.

---

## 6. Step 3: Set Up Web Servers
On both **Web1** and **Web2**:  

```bash
sudo apt update -y
sudo apt install apache2 -y
```
<img width="1366" height="768" alt="web2 install apache" src="https://github.com/user-attachments/assets/f1ed32e4-fa7d-44b7-9789-87ab338971f3" />

Edit the index page to make each server unique:

```bash
sudo bash -c 'echo "This is Web1" > /var/www/html/index.html'
```

```bash
sudo bash -c 'echo "This is Web2" > /var/www/html/index.html'
```

Confirm Apache is running:

```bash
systemctl status apache2
```

---

## 7. Step 4: Set Up Load Balancer Server
On the Load Balancer EC2:

```bash
sudo apt update -y
sudo apt install apache2 -y
```

Enable Apache modules:

```bash
sudo a2enmod proxy
sudo a2enmod proxy_balancer
sudo a2enmod proxy_http
sudo a2enmod lbmethod_bytraffic
sudo a2enmod headers
sudo a2enmod slotmem_shm
```
<img width="1366" height="768" alt="enable apache modules in loadbalancer 14" src="https://github.com/user-attachments/assets/1951c914-8c84-4bf0-9214-cf3dab14726a" />

Then restart Apache:

```bash
sudo systemctl restart apache2
```

---

## 8. Step 5: Configure VirtualHost for Load Balancing
Edit the default VirtualHost config:

```bash
sudo vi /etc/apache2/sites-enabled/000-default.conf
```

Replace contents with:

```apache
<VirtualHost *:80>
    <Proxy "balancer://mycluster">
        BalancerMember http://172.31.20.112:80 loadfactor=5 timeout=1
        BalancerMember http://172.31.28.27:80 loadfactor=5 timeout=1
        ProxySet lbmethod=bytraffic
    </Proxy>

    ProxyPreserveHost On
    ProxyPass / balancer://mycluster/
    ProxyPassReverse / balancer://mycluster/

    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
```
<img width="1366" height="768" alt="loadbalancer configured 15" src="https://github.com/user-attachments/assets/cbc0af56-aed8-4ad2-9bfd-753aa958b68d" />

Check for syntax errors:

```bash
sudo apache2ctl configtest
```

Restart Apache:

```bash
sudo systemctl restart apache2
```

---

## 9. Step 6: Update /etc/hosts
On the Load Balancer, add backend mappings:

```bash
sudo vi /etc/hosts
```

Add:

```
172.31.20.112 Web1
172.31.28.27 Web2
```

Save and exit.
<img width="1366" height="768" alt="dns on loadbalancer 16" src="https://github.com/user-attachments/assets/18f84da2-2d96-4292-8764-b08c76284ac2" />

Test connectivity:

```bash
curl http://Web1
curl http://Web2
```

You should see the unique content from each backend.
<img width="1366" height="768" alt="dns test curl 18" src="https://github.com/user-attachments/assets/2e909356-8f3a-4692-a4f3-ce7d8c129cee" />

<img width="1366" height="768" alt="web1 login success" src="https://github.com/user-attachments/assets/8195d694-af76-4c3f-886f-ce8b3ec54ede" />


---

## 10. Step 7: Test the Setup
Open the Load Balancer's public IP in your browser.

Refresh multiple times, and you should see the responses alternate between Web1 and Web2.

Ensure Apache modules are enabled.

---
<img width="1366" height="768" alt="testing loadbalancer on web1" src="https://github.com/user-attachments/assets/3326157d-b486-4e6f-91cd-24dabfc90b0c" />

<img width="1366" height="768" alt="web2 texting load balancer" src="https://github.com/user-attachments/assets/17df6fc2-9e14-40ff-b11a-3f2a29eb0583" />

---

## 12. Key Takeaways
Learned how to configure an Apache load balancer on AWS.

Reinforced concepts of VPC networking, private vs public IPs, security groups, and proxy configuration.

Practiced troubleshooting using logs and config tests.

Built a working setup where traffic is distributed evenly between two web servers.

---

## 13. Conclusion
This project was a solid exercise in building a working load balancer from scratch using Apache on AWS. Setting up the web servers was straightforward, but configuring the load balancer pushed me to really understand private IPs, security group rules, and Apache modules.  

What this really means is I now know how to route traffic across multiple servers, troubleshoot when something doesn't connect, and make sure each layer — network, server, and application — is aligned. If I ever move to Nginx or a managed service like AWS ELB, I'll already have the fundamentals locked in.
