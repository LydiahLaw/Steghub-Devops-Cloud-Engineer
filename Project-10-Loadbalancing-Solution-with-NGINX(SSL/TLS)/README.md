# Load Balancer Solution With Nginx and SSL/TLS - Complete README

## Project Overview
This project demonstrates how to configure Nginx as a load balancer to distribute traffic across multiple web servers and secure the connection using SSL/TLS certificates from Let's Encrypt.

---

## Architecture
- **3 EC2 Instances Total:**
  - 2 Web Servers (existing from previous project) - running Apache with Tooling application
  - 1 Nginx Load Balancer (new) - distributes traffic between web servers
- **1 Domain Name** - registered with FreeDNS
- **1 Elastic IP** - static IP for the load balancer

---

## Prerequisites
- AWS Account with EC2 access
- 2 existing web servers with Apache and Tooling application deployed
- SSH key pair for EC2 instances
- Basic knowledge of Linux commands and vi/nano text editor

---

## Part 1: Configure Nginx as a Load Balancer

### Step 1: Create Nginx Load Balancer EC2 Instance

1. **Login to AWS Console**
   - Navigate to EC2 Dashboard
   - Click "Launch Instance"

2. **Instance Configuration:**
   ```
   Name: Nginx-LB
   AMI: Ubuntu Server 20.04 LTS (free tier eligible)
   Instance Type: t2.micro
   Key Pair: Select your existing key pair
   ```
<img width="1366" height="768" alt="instances created" src="https://github.com/user-attachments/assets/0bc52c4c-c569-4cb3-8988-7aaabcb1c2b3" />

3. **Network Settings - Create Security Group:**
   ```
   Security Group Name: Nginx-LB-SG
   
   Inbound Rules:
   - Type: SSH,   Port: 22,  Source: Your IP (for management)
   - Type: HTTP,  Port: 80,  Source: 0.0.0.0/0 (anywhere)
   - Type: HTTPS, Port: 443, Source: 0.0.0.0/0 (anywhere)
   ```
<img width="1366" height="768" alt="security groups" src="https://github.com/user-attachments/assets/0db0e172-fef1-4d1d-8d66-f5a8653ed142" />
**Storage:** Keep default (8 GB gp3)
**Launch Instance**
**Wait for instance to be in "Running" state**

---

### Step 2: Gather Web Server Information

Before proceeding, collect this information:

1. **Web Server Private IPs:**
   - Go to EC2 Dashboard → Instances
   - Note the **Private IPv4 addresses** of both web servers
   - Example:
     ```
     Web Server 1: 172.31.x.x
     Web Server 2: 172.31.y.y
     ```

2. **Verify Web Servers are Running:**
   - SSH into each web server:
     ```bash
     ssh -i /path/to/your-key.pem ec2-user@<web-server-public-ip>
     ```
   
   - Check Apache status:
     ```bash
     sudo systemctl status httpd
     ```
   
   - Verify application files exist:
     ```bash
     ls -la /var/www/html/
     ```
   
   - **Remove any index.html files that block index.php:**
     ```bash
     sudo rm /var/www/html/index.html
     sudo systemctl restart httpd
     ```
   <img width="1366" height="768" alt="mountapps web1" src="https://github.com/user-attachments/assets/a2c2a3c7-43e2-4203-a93c-ce6d074734b0" />

   - Test in browser: `http://<web-server-public-ip>/`
   - You should see the tooling application login page

---

### Step 3: Connect to Nginx Load Balancer

```bash
ssh -i /path/to/your-key.pem ubuntu@<nginx-lb-public-ip>
```

---

### Step 4: Update /etc/hosts File

1. **Edit the hosts file:**
   ```bash
   sudo vi /etc/hosts
   ```

2. **Add these lines at the end** (replace with your actual private IPs):
   ```
   172.31.x.x Web1
   172.31.y.y Web2
   ```
**Save and exit:**
   - Press `Esc`
   - Type `:wq`
   - Press `Enter`
<img width="1366" height="768" alt="nginx add web1 and 2" src="https://github.com/user-attachments/assets/978fd3d3-070b-440e-9ed3-a07f1973bb94" />

 **Test DNS resolution:**
   ```bash
   ping -c 2 Web1
   ping -c 2 Web2
   ```
   Both should respond successfully.

---

### Step 5: Install Nginx

```bash
# Update package index
sudo apt update

# Install Nginx
sudo apt install nginx -y

# Check Nginx status
sudo systemctl status nginx
```
<img width="1366" height="768" alt="nginx installed on nginx" src="https://github.com/user-attachments/assets/658a921e-ac42-4178-8139-e4a48c5ce7b0" />

You should see "active (running)" in green.

**Optional Test:** Visit `http://<nginx-lb-public-ip>/` - you should see Nginx welcome page.

---

### Step 6: Remove Apache if Present

If Apache was previously installed on this server:

```bash
# Stop and disable Apache
sudo systemctl stop apache2
sudo systemctl disable apache2

# Remove Apache
sudo apt remove apache2 -y
sudo apt autoremove -y

# Restart Nginx
sudo systemctl restart nginx
```

---

### Step 7: Configure Nginx as Load Balancer

1. **Backup original configuration:**
   ```bash
   sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
   ```

2. **Edit Nginx configuration:**
   ```bash
   sudo vi /etc/nginx/nginx.conf
   ```

3. **Replace the ENTIRE content with this configuration:**

```nginx
user www-data;
worker_processes auto;
pid /run/nginx.pid;
error_log /var/log/nginx/error.log;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
}

http {
    ##
    # Basic Settings
    ##
    sendfile on;
    tcp_nopush on;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    ##
    # SSL Settings
    ##
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    ##
    # Logging Settings
    ##
    access_log /var/log/nginx/access.log;

    ##
    # Gzip Settings
    ##
    gzip on;

    ##
    # Virtual Host Configs
    ##
    include /etc/nginx/conf.d/*.conf;
    #include /etc/nginx/sites-enabled/*;

    ##
    # Load Balancer Configuration
    ##
    upstream myproject {
        server Web1 weight=5;
        server Web2 weight=5;
    }

    server {
        listen 80;
        server_name www.domain.com;
        location / {
            proxy_pass http://myproject;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
    }
}
```
<img width="1366" height="768" alt="added web weights on nginx conf" src="https://github.com/user-attachments/assets/03c5a10c-fc5a-4149-b585-95901e11434a" />

4. **Save and exit:**
   - Press `Esc`
   - Type `:wq`
   - Press `Enter`

5. **Test Nginx configuration:**
   ```bash
   sudo nginx -t
   ```
   You should see:
   ```
   nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
   nginx: configuration file /etc/nginx/nginx.conf test is successful
   ```

6. **Restart Nginx:**
   ```bash
   sudo systemctl restart nginx
   sudo systemctl status nginx
   ```

---

### Step 8: Test Load Balancing

1. **Visit in browser:** `http://<nginx-lb-public-ip>/`
2. You should see your **tooling application login page**
---

## Part 2: Domain Name and SSL/TLS Certificate

### Step 9: Allocate and Associate Elastic IP

1. **In AWS Console:**
   - EC2 Dashboard → Network & Security → **Elastic IPs**
   - Click **"Allocate Elastic IP address"**
   - Click **"Allocate"**
   - **Note down the Elastic IP** (e.g., 13.223.128.124)

2. **Associate Elastic IP with Nginx LB:**
   - Select the newly allocated Elastic IP
   - Click **Actions** → **"Associate Elastic IP address"**
   - **Resource type:** Instance
   - **Instance:** Select your Nginx-LB instance
   - Click **"Associate"**
<img width="1366" height="768" alt="elastic ip allocated" src="https://github.com/user-attachments/assets/7288824d-0fa7-49b9-b1de-e07c0adb5e08" />

3. **Update SSH connection** (use Elastic IP from now on):
   ```bash
   ssh -i /path/to/your-key.pem ubuntu@<your-elastic-ip>
   ```

---

### Step 10: Register Free Domain with FreeDNS

1. **Go to:** https://freedns.afraid.org/

2. **Create Account:**
   - Click **"Setup Account"** (top right)
   - Fill in:
     - Username
     - Password
     - Email address
   - Complete registration
   - **Verify your email**

3. **Login to FreeDNS**

4. **Register a Subdomain:**
   - Click **"Subdomains"** in left menu
   - Click **"Add a subdomain"**
   - **Subdomain:** Enter your desired name (e.g., `mytoolbox`)
   - **Domain:** Select from free domains (e.g., `mooo.com`, `chickenkiller.com`)
   - **Type:** Select **A** (Address record)
   - **Destination:** Enter your **Elastic IP address**
   - Click **"Save!"**

5. **Your domain is now:** `your-subdomain.domain.com`
   - Example: `mytoolbox.mooo.com`

6. **Wait 2-5 minutes** for DNS propagation
<img width="1366" height="768" alt="dom name registered" src="https://github.com/user-attachments/assets/67cff62e-0c7b-47d6-afe2-a6aeed6631c0" />

---

### Step 11: Verify DNS Resolution

1. **Test DNS:**
   ```bash
   nslookup mytoolbox.mooo.com
   ```
   Should return your Elastic IP.

2. **Test connectivity:**
   ```bash
   ping mytoolbox.mooo.com
   ```

3. **Test in browser:**
   ```
   http://mytoolbox.mooo.com
   ```
   Should show your tooling application.
<img width="1366" height="768" alt="dom name registered" src="https://github.com/user-attachments/assets/9ac59977-3cd2-4af8-a550-ed3a3747f4fe" />

---

### Step 12: Update Nginx with Domain Name

1. **SSH into Nginx LB**

2. **Edit Nginx configuration:**
   ```bash
   sudo vi /etc/nginx/nginx.conf
   ```

3. **Find the `server` block and update `server_name`:**
   ```nginx
   server {
       listen 80;
       server_name www.mytoolbox.mooo.com mytoolbox.mooo.com;
       location / {
           proxy_pass http://myproject;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
       }
   }
   ```
   **Replace `mytoolbox.mooo.com` (this is mine) with your actual domain.** 

4. **Save, test, and restart:**
   ```bash
   sudo nginx -t
   sudo systemctl restart nginx
   ```
<img width="1366" height="768" alt="update Nginx Configuration with Domain Name" src="https://github.com/user-attachments/assets/2ffcdcf4-b15a-4abf-8197-8794f8e3a239" />

5. **Test:** `http://mytoolbox.mooo.com`

---

### Step 13: Install Certbot and Request SSL Certificate

1. **Check snapd is running:**
   ```bash
   sudo systemctl status snapd
   ```

   If not active:
   ```bash
   sudo apt install snapd -y
   sudo systemctl start snapd
   sudo systemctl enable snapd
   ```

2. **Install Certbot:**
   ```bash
   sudo snap install --classic certbot
   ```

3. **Create symbolic link:**
   ```bash
   sudo ln -s /snap/bin/certbot /usr/bin/certbot
   ```
<img width="1366" height="768" alt="snapd active" src="https://github.com/user-attachments/assets/fb732212-94c3-4d2e-aad1-4cc11c896ebd" />

4. **Request SSL Certificate:**
   ```bash
   sudo certbot --nginx
   ```

5. **Follow Certbot prompts:**
   - **Email address:** Enter your email (for urgent renewal notifications)
   - **Terms of Service:** Type `Y` and press Enter
   - **Share email with EFF:** Type `Y` or `N`
   - **Select domain:** Usually option `1` (your domain will be auto-detected from nginx.conf)
   - Certbot will automatically configure Nginx for HTTPS

6. **Wait for certificate to be issued** (takes 10-30 seconds)

<img width="1366" height="768" alt="certbot installed" src="https://github.com/user-attachments/assets/ff8bbf84-169e-4553-9586-42c4578c6ec2" />

---

### Step 14: Test HTTPS Connection

1. **Visit:** `https://mytoolbox.mooo.com`

2. **Verify SSL certificate:**
   - You should see a **padlock icon 🔒** in the address bar
   - Click the padlock
   - View certificate details
   - Issued by: Let's Encrypt
<img width="1366" height="768" alt="ssl working" src="https://github.com/user-attachments/assets/01347eab-0849-4f7d-820e-7e3bb1c34f5c" />

3. **Test HTTP redirect:**
   - Visit: `http://mytoolbox.mooo.com`
   - Should automatically redirect to `https://mytoolbox.mooo.com`

---

### Step 15: Setup Automatic Certificate Renewal

1. **Test renewal in dry-run mode:**
   ```bash
   sudo certbot renew --dry-run
   ```
   
   You should see:
   ```
   Congratulations, all simulated renewals succeeded
   ```

2. **Setup Cronjob for automatic renewal:**
   ```bash
   crontab -e
   ```
   <img width="1366" height="768" alt="automatic cert renewal" src="https://github.com/user-attachments/assets/a414c0c8-5c8d-4806-aa5d-f3f4dbc51342" />


3. **Add this line at the end:**
   ```
   0 */12 * * * /usr/bin/certbot renew > /dev/null 2>&1
   ```
   
   This runs renewal check twice daily (at midnight and noon).
<img width="1366" height="768" alt="cronjob for automatic renewal" src="https://github.com/user-attachments/assets/5318d1f6-9bf2-4da1-a39c-1d4cfc627976" />

4. **Save and exit:**
   - **If using nano:** Press `Ctrl+X`, then `Y`, then `Enter`
   - **If using vim:** Press `Esc`, type `:wq`, press `Enter`

5. **Verify cronjob is set:**
   ```bash
   crontab -l
   ```
   <img width="1366" height="768" alt="crot jobs" src="https://github.com/user-attachments/assets/94134cdc-1d43-4a92-b739-edfae789b7e1" />

   Should display your renewal job.

---

## Final Verification Checklist

✅ **HTTP Access:** `http://mytoolbox.mooo.com` redirects to HTTPS  
✅ **HTTPS Access:** `https://mytoolbox.mooo.com` works with padlock  
✅ **Load Balancing:** Refresh page multiple times - traffic distributed  
✅ **Certificate Valid:** Padlock shows certificate issued by Let's Encrypt  
✅ **Auto-renewal:** Cronjob configured (`crontab -l` shows the entry)  
✅ **Elastic IP:** Static IP associated with load balancer  
✅ **Security Groups:** Ports 22, 80, 443 properly configured  

---

## Troubleshooting Guide

### Issue: Connection Refused

**Solution:**
1. Check Security Group has port 80/443 open to 0.0.0.0/0
2. Verify Nginx is running: `sudo systemctl status nginx`
3. Check port: `sudo ss -tulpn | grep :80`

### Issue: Seeing Apache Default Page

**Solution:**
1. Remove index.html from web servers:
   ```bash
   sudo rm /var/www/html/index.html
   sudo systemctl restart httpd
   ```
2. Clear browser cache (Ctrl + Shift + R)
3. Try incognito window`

### Issue: Certbot Fails

**Solution:**
1. Ensure domain resolves to your server
2. Check nginx.conf has correct server_name
3. Verify port 80 is accessible from internet
4. Test: `curl http://your-domain.com`

---

## Project Architecture Summary

```
Internet (HTTPS)
        ↓
    [Port 443]
        ↓
Nginx Load Balancer (Elastic IP)
    [SSL/TLS Termination]
        ↓
    [Port 80]
        ↓
    ┌───────┴───────┐
    ↓               ↓
Web Server 1    Web Server 2
[Apache]        [Apache]
[172.31.x.x]    [172.31.y.y]
    ↓               ↓
    └───────┬───────┘
            ↓
        Database Server
        [MySQL]
```

---

## Resources Used

- **AWS Services:** EC2, Elastic IP, Security Groups
- **Software:** Nginx, Certbot, Snapd
- **Domain Registrar:** FreeDNS (afraid.org)
- **Certificate Authority:** Let's Encrypt
- **Operating Systems:** Ubuntu 20.04 LTS (Load Balancer), RHEL/CentOS (Web Servers)

---

## Conclusion
In this project, I set up Nginx as a load balancer for two Apache web servers hosting my tooling application. I configured EC2 instances with proper security, implemented weighted round-robin balancing, registered a custom domain, and secured traffic with a Let’s Encrypt SSL certificate. I automated certificate renewal to maintain continuous security. This setup made my application accessible at https://mytoolbox.mooo.com
 with improved availability, secure communications, and the ability to scale horizontally, reflecting production-ready practices in load balancing, SSL/TLS, DNS management, and DevOps automation.
