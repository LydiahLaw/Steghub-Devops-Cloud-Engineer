# Tooling Website Deployment Automation with Continuous Integration (Jenkins 102)

## Table of Contents
- [Project Overview](#project-overview)
- [Step 1: Install Jenkins Server](#step-1-install-jenkins-server)
- [Step 2: Configure Jenkins to Retrieve Source Code from GitHub Using Webhooks](#step-2-configure-jenkins-to-retrieve-source-code-from-github-using-webhooks)
- [Step 3: Configure Jenkins to Copy Files to NFS Server via SSH](#step-3-configure-jenkins-to-copy-files-to-nfs-server-via-ssh)
- [Validation and Testing](#validation-and-testing)
- [Conclusion](#conclusion)

---

## Project Overview

This project implements a Continuous Integration (CI) setup using Jenkins to automate the process of retrieving source code from GitHub, building it, and transferring build artifacts to an NFS server.

**How it works:**
Every time code changes are pushed to the GitHub repository, Jenkins automatically detects the change, triggers a build, and deploys updated files to the shared NFS location.

---

## Step 1: Install Jenkins Server

### 1.1 Create Jenkins EC2 Instance

Launch a new EC2 instance with the following configuration:
- **AMI:** Ubuntu Server 20.04 LTS
- **Name:** Jenkins
- **Security Group:** Allow inbound traffic on ports 22 (SSH) and 8080 (Jenkins)

### 1.2 Install Java

Jenkins requires Java to run.

```bash
sudo apt update
sudo apt install default-jdk-headless -y
```

### 1.3 Install Jenkins

Add the Jenkins package repository and install Jenkins:

```bash
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -
sudo sh -c 'echo deb https://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
sudo apt update
sudo apt-get install jenkins -y
```

### 1.4 Start and Verify Jenkins Service

```bash
sudo systemctl status jenkins
```

Jenkins runs on port 8080 by default. Ensure this port is open in your EC2 Security Group.

### 1.5 Access Jenkins Web Console

Open your browser and navigate to:

```
http://<Jenkins-Public-IP>:8080
```

Retrieve the initial admin password:

```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Paste it into the setup page, install suggested plugins, and create an admin user.

---

## Step 2: Configure Jenkins to Retrieve Source Code from GitHub Using Webhooks

### 2.1 Enable Webhooks in GitHub Repository

1. Navigate to your GitHub repository (e.g., `tooling`)
2. Go to **Settings** → **Webhooks** → **Add webhook**
3. Configure the webhook:
   - **Payload URL:** `http://<jenkins_server_ip>:8080/github-webhook/`
   - **Content type:** `application/json`
   - **Events:** Just the push event
   - **Active:** ✓ Checked
4. Click **Add webhook**

### 2.2 Create a Freestyle Project in Jenkins

1. From Jenkins Dashboard, click **New Item**
2. Select **Freestyle project**, name it `tooling_github`, and click **OK**
3. Under **Source Code Management**, select **Git**
4. Paste your GitHub repository HTTPS URL
5. Add credentials if required
6. Save configuration

### 2.3 Run Manual Build

Click **Build Now** to verify Jenkins can pull code from GitHub. Check the console output to confirm success.

### 2.4 Configure Automatic Builds

1. Open your Jenkins project and click **Configure**
2. Under **Build Triggers**, enable:
   - ✓ **GitHub hook trigger for GITScm polling**
3. Under **Post-build Actions**, add:
   - **Archive the artifacts**
   - Set files to archive: `**`
4. Save changes

Now, when you push changes to GitHub, Jenkins will automatically trigger a new build.

---

## Step 3: Configure Jenkins to Copy Files to NFS Server via SSH

### 3.1 Install "Publish Over SSH" Plugin

1. Go to **Manage Jenkins** → **Manage Plugins** → **Available** tab
2. Search for **Publish Over SSH**
3. Install and restart Jenkins if prompted

### 3.2 Configure SSH Connection to NFS Server

1. Go to **Manage Jenkins** → **Configure System**
2. Scroll to **Publish over SSH** section
3. Add a new SSH server:
   - **Name:** `NFS_Server`
   - **Hostname:** Private IP of NFS server
   - **Username:** `ec2-user` (for RHEL-based NFS server)
   - **Remote Directory:** `/mnt/apps`
   - **Key:** Paste contents of your `.pem` private key file
4. Click **Test Configuration** and verify it shows **Success**

### 3.3 Add Post-Build Action to Copy Files

1. Go back to your Jenkins project configuration
2. Add **Post-build Action** → **Send build artifacts over SSH**
3. Configure:
   - **SSH Server Name:** `NFS_Server`
   - **Source files:** `**`
   - **Remove prefix:** (leave blank)
   - **Remote Directory:** `/mnt/apps`
4. Save configuration

---

## Validation and Testing

1. Modify `README.md` in your GitHub repository and push the change to the main branch
2. Jenkins will automatically trigger a new build
3. Check the console output for:
   ```
   SSH: Transferred <number> file(s)
   Finished: SUCCESS
   ```
4. Connect to your NFS server and verify the files:

```bash
ssh -i <your-key.pem> ec2-user@<NFS-server-public-IP>
cd /mnt/apps
cat README.md
```

If the updated content matches what you pushed to GitHub, the pipeline is working correctly.

---

## Conclusion

This project demonstrates a complete Continuous Integration pipeline using Jenkins. The automated workflow:

1. Retrieves the latest code using a webhook trigger
2. Builds the project and archives artifacts
3. Transfers files securely to the NFS server via SSH

This automation eliminates manual deployment steps, ensures consistent delivery of updated files, and introduces key CI/CD concepts including webhook triggers, artifact management, and remote deployment via SSH.
