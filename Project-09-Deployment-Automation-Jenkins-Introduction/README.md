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

<img width="1366" height="768" alt="jenkins server" src="https://github.com/user-attachments/assets/5d19e5e2-4af0-4454-92d8-d60ceef2261d" />


### 1.2 Install Java

Jenkins requires Java to run.

```bash
sudo apt update
sudo apt install fontconfig openjdk-17-jre -y
java -version
```

### 1.3 Install Jenkins

Add the Jenkins package repository and install Jenkins:

```bash
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null

# Add the Jenkins repository using the new keyring
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt update
sudo apt install jenkins -y

```
<img width="1366" height="768" alt="install jenkins" src="https://github.com/user-attachments/assets/e623ee58-7cf8-44ef-ac15-b761770c413e" />

### 1.4 Start and Verify Jenkins Service

```bash
sudo systemctl status jenkins
```
<img width="1366" height="768" alt="ls jenkins" src="https://github.com/user-attachments/assets/87ff9148-4363-4625-bb5a-c50d31466098" />

Jenkins runs on port 8080 by default. Ensure this port is open in your EC2 Security Group.

### 1.5 Access Jenkins Web Console

Open your browser and navigate to:

```
http://<Jenkins-Public-IP>:8080
```
<img width="1366" height="768" alt="login jen" src="https://github.com/user-attachments/assets/d2d25363-1424-4816-80e5-585fc1de7bad" />
first ip was: 54.146.241.164 then next day the ip changed to 3.89.101.174

Retrieve the initial admin password:

```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```
<img width="1366" height="768" alt="getting started" src="https://github.com/user-attachments/assets/6e5b8d77-ec0f-4844-ac7d-b6e03d422545" />

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
<img width="1366" height="768" alt="add webhook" src="https://github.com/user-attachments/assets/fda85fea-6ebf-4c05-942b-f5e637a51a52" />

### 2.2 Create a Freestyle Project in Jenkins

1. From Jenkins Dashboard, click **New Item**
2. Select **Freestyle project**, name it `tooling_github`, and click **OK**
3. Under **Source Code Management**, select **Git**
4. Paste your GitHub repository HTTPS URL
5. Add credentials if required
6. Save configuration
<img width="1366" height="768" alt="add new item" src="https://github.com/user-attachments/assets/6bc1cde4-524d-40a7-84a2-f24bb5a7577b" />

### 2.3 Run Manual Build

Click **Build Now** to verify Jenkins can pull code from GitHub. Check the console output to confirm success.
<img width="1366" height="768" alt="build successfully" src="https://github.com/user-attachments/assets/2b63b848-f1cd-4a59-a4d2-2b7a4b6d5419" />

### 2.4 Configure Automatic Builds

1. Open your Jenkins project and click **Configure**
2. Under **Build Triggers**, enable:
   - ✓ **GitHub hook trigger for GITScm polling**
3. Under **Post-build Actions**, add:
   - **Archive the artifacts**
   - Set files to archive: `**`
4. Save changes

Now, when you push changes to GitHub, Jenkins will automatically trigger a new build.
<img width="1366" height="768" alt="automatic build by jenkins" src="https://github.com/user-attachments/assets/26dd8bc2-a103-43cf-8402-e78b703599a6" />

---

## Step 3: Configure Jenkins to Copy Files to NFS Server via SSH

### 3.1 Install "Publish Over SSH" Plugin

1. Go to **Manage Jenkins** → **Manage Plugins** → **Available** tab
2. Search for **Publish Over SSH**
3. Install and restart Jenkins if prompted
<img width="1366" height="768" alt="publish over ssh plugin" src="https://github.com/user-attachments/assets/18aa0a10-37d1-4420-9d27-17690f246199" />

### 3.2 Configure SSH Connection to NFS Server

1. Go to **Manage Jenkins** → **Configure System**
2. Scroll to **Publish over SSH** section
3. Add a new SSH server:
   - **Name:** `NFS_Server`
   - **Hostname:** Private IP of NFS server
   - **Username:** `ec2-user` (for RHEL-based NFS server)
   - **Remote Directory:** `/mnt/apps`
   - **Key:** Paste contents of your `.pem` private key file
     <img width="1366" height="768" alt="publish over ssh configured" src="https://github.com/user-attachments/assets/441c5e4a-a106-4db7-a7fe-9619f2c44281" />

4. Click **Test Configuration** and verify it shows **Success**
<img width="1366" height="768" alt="POS success" src="https://github.com/user-attachments/assets/1c597ac6-7913-4271-a617-8bb1cb4f3ce5" />


### 3.3 Add Post-Build Action to Copy Files

1. Go back to your Jenkins project configuration
2. Add **Post-build Action** → **Send build artifacts over SSH**
3. Configure:
   - **SSH Server Name:** `NFS_Server`
   - **Source files:** `**`
   - **Remove prefix:** (leave blank)
   - **Remote Directory:** `/mnt/apps`

<img width="1366" height="768" alt="POS success" src="https://github.com/user-attachments/assets/8a5e8825-0999-4691-8ebf-ad900a7eb407" />

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
   <img width="1366" height="768" alt="sucees update readme" src="https://github.com/user-attachments/assets/fe26c50f-83f2-44d0-b2ca-2022c0f9c1e5" />

4. Connect to your NFS server and verify the files:

```bash
ssh -i <your-key.pem> ec2-user@<NFS-server-public-IP>
cd /mnt/apps
cat README.md
```
<img width="1366" height="768" alt="nfs connected" src="https://github.com/user-attachments/assets/e8198df3-6154-41e4-94da-14d4cc262b53" />
<img width="1366" height="768" alt="matches with github" src="https://github.com/user-attachments/assets/178459db-a0c4-49ac-94f7-7a81dd7e40b4" />

If the updated content matches what you pushed to GitHub, the pipeline is working correctly.

---

## Conclusion

This project demonstrates a complete Continuous Integration pipeline using Jenkins. The automated workflow:

1. Retrieves the latest code using a webhook trigger
2. Builds the project and archives artifacts
3. Transfers files securely to the NFS server via SSH

This automation eliminates manual deployment steps, ensures consistent delivery of updated files, and introduces key CI/CD concepts including webhook triggers, artifact management, and remote deployment via SSH.
