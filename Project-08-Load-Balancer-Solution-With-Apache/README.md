Apache Load Balancer with Two Web Servers on AWSTable of ContentsIntroductionArchitecturePrerequisitesStep 1: Launch EC2 InstancesStep 2: Configure Security GroupsStep 3: Set Up Web ServersStep 4: Set Up Load Balancer ServerStep 5: Configure VirtualHost for Load BalancingStep 6: Update /etc/hostsStep 7: Test the SetupVerification and TroubleshootingKey TakeawaysConclusion1. IntroductionThis project details the setup of a simple load balancing solution on AWS using Apache. The configuration involves two backend web servers (Web1 and Web2) and a separate server acting as the Load Balancer (LB). Traffic is distributed using Apache’s mod_proxy and mod_proxy_balancer modules.2. ArchitectureWeb1 and Web2: Apache web servers running unique index pages.Load Balancer (LB): Apache server configured with proxy and balancer modules to distribute requests.Clients: Access the public IP of the Load Balancer.3. PrerequisitesAWS account.Basic knowledge of EC2, SSH, and Linux commands.A key pair for SSH access.4. Step 1: Launch EC2 InstancesLaunch 3 Ubuntu EC2 instances in the same VPC and subnet:Web1Web2Load BalancerEnsure all instances have public IPs for initial SSH access.5. Step 2: Configure Security GroupsSecurity groups must be configured to control traffic flow:Web1 and Web2 Security GroupInbound:HTTP (Port 80) from Load Balancer’s Private IP.SSH (Port 22) from Your Local IP (or jump host).Load Balancer Security GroupInbound:HTTP (Port 80) from 0.0.0.0/0 (Internet).SSH (Port 22) from Your Local IP (or jump host).This ensures only the load balancer can directly access the backend web servers on port 80.6. Step 3: Set Up Web ServersOn both Web1 and Web2, run the following commands to install Apache:sudo apt update -y
sudo apt install apache2 -y

Set unique index pages:On Web1:sudo bash -c 'echo "This is Web1" > /var/www/html/index.html'

On Web2:sudo bash -c 'echo "This is Web2" > /var/www/html/index.html'

Confirm Apache is running on both:systemctl status apache2

7. Step 4: Set Up Load Balancer ServerOn the Load Balancer EC2:sudo apt update -y
sudo apt install apache2 -y

Enable required Apache modules:sudo a2enmod proxy
sudo a2enmod proxy_balancer
sudo a2enmod proxy_http
sudo a2enmod lbmethod_bytraffic
sudo a2enmod headers
sudo a2enmod slotmem_shm

Restart Apache:sudo systemctl restart apache2

8. Step 5: Configure VirtualHost for Load BalancingEdit the default VirtualHost config:sudo vi /etc/apache2/sites-enabled/000-default.conf

Replace the contents with the following configuration. Update the BalancerMember IPs to match the private IP addresses of Web1 and Web2.<VirtualHost *:80>
    <Proxy "balancer://mycluster">
        # Replace IPs below with the *private* IPs of Web1 and Web2
        BalancerMember [http://172.31.20.112:80](http://172.31.20.112:80) loadfactor=5 timeout=1
        BalancerMember [http://172.31.28.27:80](http://172.31.28.27:80) loadfactor=5 timeout=1
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

Check for syntax errors:sudo apache2ctl configtest

Restart Apache:sudo systemctl restart apache2

9. Step 6: Update /etc/hostsOn the Load Balancer server, map the backend private IPs to hostnames. This is optional but helpful for managing the configuration.sudo vi /etc/hosts

Add the following lines (update IPs as necessary):172.31.20.112 Web1
172.31.28.27 Web2

Save and exit.Test connectivity from the Load Balancer to the Web Servers:curl http://Web1
curl http://Web2

You should see the unique content ("This is Web1", "This is Web2") from each backend.10. Step 7: Test the SetupOpen the Load Balancer’s public IP in your browser.Refresh the page multiple times, and you should see the responses alternate between "This is Web1" and "This is Web2", confirming successful load balancing.11. Verification and TroubleshootingCheck Apache logs on the Load Balancer if traffic isn't balancing correctly:tail -f /var/log/apache2/error.log
tail -f /var/log/apache2/access.log

Common Issues:If one server doesn’t respond, confirm its security group allows inbound HTTP traffic from the Load Balancer’s private IP.Ensure all required Apache modules (e.g., mod_proxy, mod_proxy_balancer) are enabled.12. Key TakeawaysThis project reinforces core concepts in networking and infrastructure setup:Configuring an Apache HTTP server to act as a reverse proxy load balancer.Understanding the role of private vs. public IPs in AWS networking.Implementing strict security group rules to protect backend resources.Using logs and config tests for effective troubleshooting.13. ConclusionThis project was a solid exercise in building a working load balancer from scratch using Apache on AWS. Setting up the web servers was straightforward, but configuring the load balancer pushed me to really understand private IPs, security group rules, and Apache modules.What this really means is I now know how to route traffic across multiple servers, troubleshoot when something doesn’t connect, and make sure each layer — network, server, and application — is aligned. If I ever move to Nginx or a managed service like AWS ELB, I’ll already have the fundamentals locked in.
