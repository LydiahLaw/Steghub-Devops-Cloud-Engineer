# DevOps Tooling Website Solution

A scalable web infrastructure implementing a 3-tier architecture with Network File System (NFS) for shared storage and centralized database management. This project demonstrates enterprise-level DevOps practices by creating stateless web servers that can be dynamically scaled while maintaining data consistency.

## Table of Contents

- [Introduction](#introduction)
- [Architecture Overview](#architecture-overview)
- [Technologies Used](#technologies-used)
- [Infrastructure Components](#infrastructure-components)
- [Implementation Steps](#implementation-steps)
  - [Step 1: NFS Server Configuration](#step-1-nfs-server-configuration)
  - [Step 2: Database Server Setup](#step-2-database-server-setup)
  - [Step 3: Web Servers Configuration](#step-3-web-servers-configuration)
- [Challenges and Solutions](#challenges-and-solutions)
- [Testing and Validation](#testing-and-validation)
- [Lessons Learned](#lessons-learned)
- [Conclusion](#conclusion)

## Introduction

Modern web applications require infrastructure that can handle varying loads while maintaining high availability and data consistency. Traditional monolithic approaches where each server maintains its own data create challenges in scaling and maintenance.

This project solves the scalability problem by implementing a stateless web server architecture where:
- **Web servers** handle HTTP requests but store no persistent data locally
- **Shared storage** (NFS) ensures all servers serve identical content
- **Centralized database** maintains data consistency across all servers

This design allows for horizontal scaling - web servers can be added or removed without affecting data integrity or user experience.

## Architecture Overview

The solution implements a 3-tier architecture:

```
[Users] → [Load Balancer] → [Web Servers (3)] → [Database Server]
                                ↓
                            [NFS Server]
```

**Tier 1 (Presentation):** Three identical web servers running Apache and PHP
**Tier 2 (Application):** NFS server providing shared file storage
**Tier 3 (Data):** MySQL database server for persistent data storage

This separation ensures that each tier can be scaled, maintained, or updated independently without affecting the others.

## Technologies Used

| Technology | Purpose | Benefits |
|------------|---------|----------|
| **RHEL 10** | Operating system for all servers | Enterprise-grade stability and security |
| **Apache HTTP Server** | Web server software | Industry-standard, reliable HTTP processing |
| **PHP 7.4** | Server-side scripting | Dynamic web content generation |
| **MySQL/MariaDB** | Database management system | Robust relational data storage |
| **NFS (Network File System)** | Shared storage solution | Centralized file management across servers |
| **LVM (Logical Volume Manager)** | Storage management | Flexible disk space allocation |
| **AWS EC2** | Cloud infrastructure | Scalable, reliable hosting platform |

## Infrastructure Components

### Server Specifications
- **1 NFS Server:** Centralized file storage with LVM-managed volumes
- **1 Database Server:** MySQL instance with tooling database
- **3 Web Servers:** Apache/PHP servers with NFS client configuration
- **Total: 5 EC2 instances**

### Network Configuration
- **Subnet:** 172.31.16.0/20
- **NFS Server:** 172.31.26.173
- **Database Server:** 172.31.22.114
- **Security Groups:** Configured for HTTP (80), SSH (22), NFS (2049), and MySQL (3306)

## Implementation Steps

### Step 1: NFS Server Configuration

**Objective:** Create centralized storage that all web servers can access simultaneously.

1. **LVM Setup:**
   - Created 3 logical volumes: `lv-apps`, `lv-logs`, `lv-opt`
   - Formatted volumes with XFS filesystem
   - Mounted to `/mnt/apps`, `/mnt/logs`, `/mnt/opt`

2. **NFS Configuration:**
   ```bash
   sudo yum install nfs-utils -y
   sudo systemctl start nfs-server
   sudo systemctl enable nfs-server
   ```

3. **Export Configuration:**
   ```bash
   # /etc/exports
   /mnt/apps 172.31.16.0/20(rw,sync,no_all_squash,no_root_squash)
   /mnt/logs 172.31.16.0/20(rw,sync,no_all_squash,no_root_squash)
   /mnt/opt 172.31.16.0/20(rw,sync,no_all_squash,no_root_squash)
   ```

4. **Security Configuration:**
   - Set ownership to `nobody:nobody`
   - Applied 777 permissions for full access
   - Configured security groups for NFS ports (111, 2049, 20048)

### Step 2: Database Server Setup

**Objective:** Establish centralized data storage accessible by all web servers.

1. **MySQL Installation and Configuration:**
   ```bash
   sudo yum install mysql-server -y
   sudo systemctl start mysqld
   sudo systemctl enable mysqld
   ```

2. **Database and User Creation:**
   ```sql
   CREATE DATABASE tooling;
   CREATE USER 'webaccess'@'172.31.16.0/255.255.240.0' IDENTIFIED BY 'Devopslearn12$%';
   GRANT ALL PRIVILEGES ON tooling.* TO 'webaccess'@'172.31.16.0/255.255.240.0';
   FLUSH PRIVILEGES;
   ```

3. **Security Group Configuration:**
   - Opened port 3306 for MySQL connections from web server subnet

### Step 3: Web Servers Configuration

**Objective:** Deploy three identical, stateless web servers that share content and data.

1. **NFS Client Setup:**
   ```bash
   sudo yum install nfs-utils nfs4-acl-tools -y
   sudo mkdir /var/www
   sudo mount -t nfs -o rw,nosuid 172.31.26.173:/mnt/apps /var/www
   ```

2. **LAMP Stack Installation (RHEL 10 specific):**
   ```bash
   sudo yum install httpd -y
   sudo yum install php php-common php-opcache php-cli php-gd php-curl php-mysqlnd php-fpm -y
   sudo dnf install mariadb -y  # MySQL client
   ```

3. **Service Configuration:**
   ```bash
   sudo systemctl start httpd php-fpm
   sudo systemctl enable httpd php-fpm
   sudo setsebool -P httpd_execmem 1
   ```

4. **Application Deployment:**
   - Cloned tooling application from GitHub
   - Deployed to `/var/www/html` (shared via NFS)
   - Configured database connection in `functions.php`

5. **Database Integration:**
   ```bash
   mysql -h 172.31.22.114 -u webaccess -p tooling < /var/www/html/tooling-db.sql
   ```

## Challenges and Solutions

### Challenge 1: RHEL 10 Package Compatibility
**Problem:** Original instructions used RHEL 8 package repositories that weren't compatible with RHEL 10.

**Solution:** 
- Replaced EPEL and Remi repositories with native RHEL 10 packages
- Used `dnf install mariadb` instead of MySQL client
- Modified PHP installation to use system packages rather than external repos

### Challenge 2: Database Connection Timeouts
**Problem:** Web servers experienced 504 Gateway Timeout errors when connecting to the database.

**Solution:**
- Added `request_terminate_timeout = 300` to PHP-FPM configuration
- Verified security group rules allowed MySQL connections (port 3306)
- Ensured database user had proper subnet permissions

### Challenge 3: NFS Mount Persistence
**Problem:** NFS mounts didn't survive server reboots.

**Solution:**
- Added proper entries to `/etc/fstab`:
  ```
  172.31.26.173:/mnt/apps /var/www nfs defaults 0 0
  172.31.26.173:/mnt/logs /var/log/httpd nfs defaults 0 0
  ```

### Challenge 4: SELinux Permission Issues
**Problem:** Apache couldn't serve files from NFS-mounted directories due to SELinux restrictions.

**Solution:**
- Applied `sudo setsebool -P httpd_execmem 1`
- Set proper file permissions: `sudo chmod -R 755 /var/www/html`
- Temporarily disabled SELinux for testing: `sudo setenforce 0`

### Challenge 5: MySQL Client Unavailability
**Problem:** Web servers needed MySQL client to run SQL scripts, but it wasn't installed by default.

**Solution:**
- Installed MariaDB package which provides MySQL-compatible client
- This wasn't explicitly mentioned in original instructions but was necessary for functionality

## Testing and Validation

### Functionality Tests
1. **NFS Sharing Verification:**
   - Created test files on one web server
   - Confirmed files appeared on all other servers via NFS

2. **Database Connectivity:**
   - Successfully connected from all web servers to database
   - Applied SQL schema and created admin user

3. **Web Application Testing:**
   - Accessed application from all three web server public IPs
   - Verified successful login with credentials: `admin/admin`
   - Confirmed shared session data across servers

### Load Balancing Readiness
- All three servers serve identical content
- Database connections work from all servers
- Shared file system ensures consistency
- Infrastructure ready for load balancer implementation

## Lessons Learned

### Technical Insights
1. **NFS Performance Considerations:** While NFS provides excellent file sharing, it can become a bottleneck under high load. Consider implementing caching strategies or CDN for static assets.

2. **Database Security:** Subnet-based MySQL user permissions provide good security while allowing necessary access. Avoid using wildcard permissions in production.

3. **OS Version Compatibility:** Always verify package availability and repository compatibility when working with specific OS versions. RHEL 10 required different approaches than documented RHEL 8 procedures.

### Infrastructure Design
1. **Stateless Architecture Benefits:** The stateless design significantly simplifies scaling operations. New web servers can be added without complex data synchronization.

2. **Single Points of Failure:** While web servers are now scalable, both NFS and database servers represent single points of failure. Production implementations should include clustering or replication for these components.

3. **Security Group Management:** Proper network segmentation through security groups is crucial. Each tier should only expose necessary ports to required sources.

### DevOps Practices
1. **Documentation Importance:** Thorough documentation of configuration changes and customizations is essential, especially when deviating from standard procedures.

2. **Testing Strategy:** Testing each component individually before integration saves significant debugging time.

3. **Infrastructure as Code:** Manual configuration works for learning, but production deployments should use tools like Terraform or CloudFormation for consistency and repeatability.

## Conclusion

This project successfully demonstrates the implementation of a scalable, stateless web infrastructure using enterprise DevOps practices. The solution addresses the fundamental challenge of horizontal scaling by separating compute (web servers) from storage (NFS and database).

**Key Achievements:**
- ✅ **Stateless Web Servers:** All three servers are identical and replaceable
- ✅ **Shared Storage:** NFS ensures content consistency across servers
- ✅ **Centralized Database:** Single source of truth for application data
- ✅ **Security Implementation:** Proper network segmentation and access controls
- ✅ **Scalability Foundation:** Infrastructure ready for load balancer integration

**Production Readiness Considerations:**
The current implementation provides an excellent foundation but would benefit from additional enterprise features for production use:
- Load balancer for traffic distribution
- NFS clustering or distributed storage (e.g., GlusterFS, EFS)
- Database replication and backup strategies  
- SSL/TLS termination
- Monitoring and logging solutions
- Infrastructure automation with IaC tools

This architecture pattern is widely used in enterprise environments and provides the foundation for understanding more complex distributed systems and microservices architectures.
