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

3. **Network Settings - Create Security Group:**
   ```
   Security Group Name: Nginx-LB-SG
   
   Inbound Rules:
   - Type: SSH,   Port: 22,  Source: Your IP (for management)
   - Type: HTTP,  Port: 80,  Source: 0.0.0.0/0 (anywhere)
   - Type: HTTPS, Port: 443, Source: 0.0.0.0/0 (anywhere)
   ```

4. **Storage:** Keep default (8 GB gp3)

5. **Launch Instance**

6. **Wait for instance to be in "Running" state**

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

3. **Save and exit:**
   - Press `Esc`
   - Type `:wq`
   - Press `Enter`

4. **Test DNS resolution:**
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
3. **Refresh multiple times** - Nginx is distributing requests between Web1 and Web2

**If you see Apache default page:**
- Clear browser cache (Ctrl + Shift + R or Ctrl + F5)
- Try incognito/private window
- Check that index.html was removed from web servers

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

3. **Update SSH connection** (use Elastic IP from now on):
   ```bash
   ssh -i /path/to/your-key.pem ubuntu@<your-elastic-ip>
   ```

4. **Verify the Elastic IP:**
   ```bash
   curl http://checkip.amazonaws.com
   ```
   Should return your Elastic IP.

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

**If connection refused:**
- Check Security Group has port 80 open (0.0.0.0/0)
- Verify Nginx is running: `sudo systemctl status nginx`

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
   **Replace `mytoolbox.mooo.com` with your actual domain.**

4. **Save, test, and restart:**
   ```bash
   sudo nginx -t
   sudo systemctl restart nginx
   ```

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

---

### Step 14: Test HTTPS Connection

1. **Visit:** `https://mytoolbox.mooo.com`

2. **Verify SSL certificate:**
   - You should see a **padlock icon 🔒** in the address bar
   - Click the padlock
   - View certificate details
   - Issued by: Let's Encrypt

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
   
   If prompted, select editor (choose nano or vim - nano is easier)

3. **Add this line at the end:**
   ```
   0 */12 * * * /usr/bin/certbot renew > /dev/null 2>&1
   ```
   
   This runs renewal check twice daily (at midnight and noon).

4. **Save and exit:**
   - **If using nano:** Press `Ctrl+X`, then `Y`, then `Enter`
   - **If using vim:** Press `Esc`, type `:wq`, press `Enter`

5. **Verify cronjob is set:**
   ```bash
   crontab -l
   ```
   
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
3. Try incognito window

### Issue: DNS Not Resolving

**Solution:**
1. Verify FreeDNS has correct Elastic IP
2. Wait 5-10 minutes for DNS propagation
3. Check: `nslookup your-domain.com`

### Issue: Certbot Fails

**Solution:**
1. Ensure domain resolves to your server
2. Check nginx.conf has correct server_name
3. Verify port 80 is accessible from internet
4. Test: `curl http://your-domain.com`

### Issue: Certificate Not Renewing

**Solution:**
1. Test renewal: `sudo certbot renew --dry-run`
2. Check cronjob: `crontab -l`
3. View renewal logs: `sudo tail -50 /var/log/letsencrypt/letsencrypt.log`

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

## Important Notes

1. **Let's Encrypt Certificates:**
   - Valid for 90 days
   - Auto-renewal configured for every 60 days
   - Renewal happens twice daily via cronjob

2. **Security Best Practices:**
   - Web servers should only allow traffic from Load Balancer security group
   - Keep software updated: `sudo apt update && sudo apt upgrade`
   - Monitor logs regularly

3. **Maintenance:**
   - Check certificate status: `sudo certbot certificates`
   - View Nginx logs: `sudo tail -f /var/log/nginx/access.log`
   - Monitor load distribution across web servers

---

## Resources Used

- **AWS Services:** EC2, Elastic IP, Security Groups
- **Software:** Nginx, Certbot, Snapd
- **Domain Registrar:** FreeDNS (afraid.org)
- **Certificate Authority:** Let's Encrypt
- **Operating Systems:** Ubuntu 20.04 LTS (Load Balancer), RHEL/CentOS (Web Servers)

---

## Project Completion

Congratulations! You have successfully:
- ✅ Configured Nginx as a Load Balancer
- ✅ Distributed traffic across multiple web servers
- ✅ Registered a domain name
- ✅ Secured your website with SSL/TLS certificate
- ✅ Automated certificate renewal
- ✅ Implemented high availability architecture

**Your tooling application is now accessible via:**
- `https://mytoolbox.mooo.com` (secured with SSL)

---

## Next Steps

Consider implementing:
- Health checks for web servers
- Session persistence (sticky sessions)
- Additional web servers for higher availability
- CloudWatch monitoring
- Automated backups
- WAF (Web Application Firewall)

---

**End of README**
