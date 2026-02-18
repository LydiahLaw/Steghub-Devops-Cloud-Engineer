# Project 14: CI/CD Pipeline with Jenkins, Ansible & SonarCloud


## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Technologies](#technologies)
- [Infrastructure](#infrastructure)
- [Implementation](#implementation)
- [Pipeline Stages](#pipeline-stages)
- [Key Features](#key-features)
- [Blockers & Solutions](#blockers--solutions)
- [Why Not Certain Tools](#why-not-certain-tools)
- [Results](#results)

---

## Overview

A complete CI/CD pipeline for a PHP Laravel application that automates testing, code analysis, and deployment across multiple environments. The pipeline uses GitHub webhooks to trigger builds, executes unit tests, performs code quality analysis via SonarCloud, and deploys to AWS infrastructure managed by Ansible.

**Pipeline Flow:**
```
Git Push → Jenkins → Tests → Code Analysis → Deploy
```

---

## Architecture

```
┌──────────┐      ┌──────────────┐      ┌─────────────┐
│  GitHub  │─────▶│   Jenkins    │─────▶│ SonarCloud  │
└──────────┘      │   Master +   │      └─────────────┘
   Webhook        │   2 Agents   │            ▲
                  └──────┬───────┘            │
                         │              Code Quality
                         ▼
                  ┌──────────┐
                  │ Ansible  │
                  └────┬─────┘
                       │
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼
    Dev Env        SIT Env        CI Env
```

---

## Technologies

| Tool | Purpose |
|------|---------|
| Jenkins + Blue Ocean | CI/CD automation |
| Ansible | Infrastructure as Code |
| SonarCloud | Code quality analysis |
| PHP 8.3 + Laravel 8 | Application stack |
| PHPUnit + phploc | Testing & metrics |
| MySQL | Database |
| AWS EC2 | Infrastructure |

---

## Infrastructure

**EC2 Instances:**
- jenkins-server (t2.medium) - Master + Ansible control
- jenkins-agent-1/2 (t2.micro) - Build executors
- todo-dev, nginx-dev, db-dev - Dev environment


**Ansible Inventory:**
```
inventory/
├── ci          # Jenkins, SonarQube (not used), Nginx
├── dev         # App servers, DB, Nginx
├── sit         # System Integration Testing
└── pentest     # Penetration testing
```

<img width="1366" height="768" alt="nano ci" src="https://github.com/user-attachments/assets/41e2f8b7-6b17-4d9d-9913-aff794685fb1" />
<img width="1366" height="768" alt="nano dev" src="https://github.com/user-attachments/assets/d5ddf709-63dd-4fe8-81ab-fffd4d60ff99" />


---

## Implementation

### Jenkins Setup

**Plugins Installed:**
- Blue Ocean - Visual pipeline interface
- Ansible - Playbook execution
- SonarQube Scanner - Code analysis
- Plot - Metrics visualization
- GitHub Integration - Webhook support

<img width="1366" height="768" alt="blueocean" src="https://github.com/user-attachments/assets/61e51ee0-ccc0-44ef-a136-48e635c7089d" />

<img width="1366" height="768" alt="ansible configjenkins" src="https://github.com/user-attachments/assets/a0baec19-5409-41a9-b65d-a6e1e5f0bb68" />


**Agents Configuration:**

![Uploading blueocean.png…]()

Both agents configured with:
- Java 11
- Ansible
- PHP 8.3 + Composer
- SSH access to target servers


### GitHub Integration

**Repository Setup:**
- Forked php-todo application
- Created deploy/Jenkinsfile
- Configured webhook to Jenkins

<img width="1366" height="768" alt="jenkinsfile found" src="https://github.com/user-attachments/assets/34570ed8-7282-4500-a451-26dacb0dd07f" />


**Access Token:**

<img width="1366" height="768" alt="connect tojen" src="https://github.com/user-attachments/assets/805f9f5e-177f-4536-8a60-136064e6e221" />


### Jenkinsfile

**Initial Version (2 stages):**


**Expanded Pipeline:**

```groovy
pipeline {
    agent any
    
    stages {
        stage('Initial cleanup') {
            steps {
                deleteDir()
            }
        }
        
        stage('Checkout SCM') {
            steps {
                git branch: 'main', 
                    url: 'https://github.com/<username>/php-todo.git'
            }
        }
        
        stage('Prepare Dependencies') {
            steps {
                sh 'cp .env.sample .env'
                sh 'composer install --no-interaction --prefer-dist'
                sh 'php artisan key:generate'
                sh 'php artisan config:clear'
            }
        }
        
        stage('Database Setup') {
            steps {
                sh 'php artisan migrate:fresh --force'
                sh 'php artisan db:seed --force'
            }
        }
        
        stage('Execute Unit Tests') {
            steps {
                sh './vendor/bin/phpunit'
            }
        }
        
        stage('Code Analysis') {
            steps {
                sh 'phploc app/ --log-csv build/logs/phploc.csv'
            }
        }
        
        stage('Plot Code Coverage Report') {
            steps {
                plot csvFileName: 'plot.csv',
                     csvSeries: [[file: 'build/logs/phploc.csv']],
                     group: 'phploc',
                     title: 'Code Metrics'
            }
        }
        
        stage('SonarCloud Quality Gate') {
            environment {
                scannerHome = tool 'SonarQubeScanner'
            }
            steps {
                withSonarQubeEnv('sonarcloud') {
                    sh "${scannerHome}/bin/sonar-scanner"
                }
            }
        }
    }
}
```

<img width="1366" height="768" alt="2 stages build and test" src="https://github.com/user-attachments/assets/05be5cef-92ca-404a-8dbc-ad296fd58eef" />
<img width="1366" height="768" alt="all stages added" src="https://github.com/user-attachments/assets/229f4d2a-c732-4004-9981-d3ae1072b116" />
<img width="1366" height="768" alt="change script path" src="https://github.com/user-attachments/assets/2e16bf80-b367-48d8-8505-f1d68fa4d41e" />



### Database Configuration

**MySQL Setup on RHEL DB Server:**

![MySQL Started](screenshots/mysqlstarted%20ondbserver.png)

```sql
CREATE DATABASE homestead;
CREATE USER 'homestead'@'%' IDENTIFIED BY 'sePret^i';
GRANT ALL PRIVILEGES ON *.* TO 'homestead'@'%';
```

**Connection Test from Jenkins:**

**Migration Result:**
<img width="1366" height="768" alt="todo succesfulltables created" src="https://github.com/user-attachments/assets/365f213b-740f-4470-a277-7f1e8defa0a6" />

<img width="1366" height="768" alt="todo succesfulltables created" src="https://github.com/user-attachments/assets/cb513b68-d9c7-4198-ba15-1d37a5c22cd1" />


### SonarCloud Integration

**Configuration:**

<img width="1366" height="768" alt="sonarqubeloggedin" src="https://github.com/user-attachments/assets/a5696826-706f-45c6-afde-e578240c6f0f" />


**Analysis Results:**

<img width="1366" height="768" alt="sonarcloud codesmells" src="https://github.com/user-attachments/assets/088953ba-f440-4f1c-a87c-a7029b35f527" />
<img width="1366" height="768" alt="sonarcloud summary" src="https://github.com/user-attachments/assets/d4c7c1c8-ba3b-4dff-82c3-4b3475db184e" />


### Ansible Deployment

**Playbook Structure:**
```yaml
---
- name: Deploy to environment
  hosts: all
  become: true
  
  tasks:
    - name: Test connection
      ping:
    
    - name: Display deployment target
      debug:
        msg: "Deploying to {{ inventory_hostname }}"
```

<img width="1366" height="768" alt="ansible installed" src="https://github.com/user-attachments/assets/3144bd89-1b5d-4d45-b5fa-e36c28e11744" />
<img width="1366" height="768" alt="ansible pipeline success1" src="https://github.com/user-attachments/assets/22750d2c-46d3-4521-9c60-569319056806" />
<img width="1366" height="768" alt="ansible pipeline success2" src="https://github.com/user-attachments/assets/23d2b0ef-3635-4054-b196-3f3f18874a02" />

**Parameterized Deployment:**

<img width="1366" height="768" alt="buildwith para" src="https://github.com/user-attachments/assets/fff13028-dff4-40eb-8b95-255f3e4fe3f2" />
<img width="1366" height="768" alt="deployconfig" src="https://github.com/user-attachments/assets/71534e9b-64bf-4ee9-80c0-ef91642c99bc" />

---

## Pipeline Stages

### 1. Initial Cleanup
Deletes previous workspace for clean builds.

### 2. Checkout SCM
Clones latest code from GitHub main branch.

### 3. Prepare Dependencies
- Copies environment configuration
- Installs Composer dependencies
- Generates Laravel application key
- Clears configuration cache

<img width="1366" height="768" alt="phpdependecies" src="https://github.com/user-attachments/assets/9c460799-1224-4386-9a06-3ece819e7c9c" />

### 4. Database Setup
- Runs migrations (drops and recreates tables)
- Seeds database with test data

### 5. Execute Unit Tests
Runs PHPUnit test suite against the application.

### 6. Code Analysis
Generates metrics using phploc:
- Lines of code
- Cyclomatic complexity
- Class/method counts
- Test coverage

### 7. Plot Code Coverage
Creates visual charts tracking code metrics over builds.

### 8. SonarCloud Quality Gate
Analyzes code for:
- Bugs
- Code smells
- Security vulnerabilities
- Technical debt
- Duplications

---

## Key Features

✅ **Automated Builds** - GitHub webhook triggers pipeline on every push  
✅ **Unit Testing** - PHPUnit executes automatically  
✅ **Code Quality** - SonarCloud analyzes every commit  
✅ **Code Metrics** - Visual plots track code health  
✅ **Automated Deployment** - Ansible deploys to dev environment  
✅ **Distributed Builds** - Jenkins agents load-balance execution  
✅ **Infrastructure as Code** - Full environment in Ansible  
✅ **Multi-Environment** - Deploy to dev, sit, ci via parameters  

<img width="1366" height="768" alt="phpdependecies" src="https://github.com/user-attachments/assets/c839f385-8982-4354-9539-ca23b2893769" />
<img width="1366" height="768" alt="feature on jenkins" src="https://github.com/user-attachments/assets/3b190c9b-af81-4407-810e-2a937dcfe34c" />

---

## Blockers & Solutions

### 1. PHP 8.3 Incompatibility with Laravel 5.8

**Problem:**
```
PHP Fatal error: Declaration of App\Exceptions\Handler::report(Exception $e) 
must be compatible with Handler::report(Throwable $e)
```

**Cause:** Ubuntu 24.04 ships with PHP 8.3, incompatible with Laravel 5.8

**Solution:** Upgraded to Laravel 8.x

```json
// composer.json updates
{
    "require": {
        "php": "^7.2|^8.0",
        "laravel/framework": "^8.75"
    },
    "require-dev": {
        "fakerphp/faker": "^1.23",
        "phpunit/phpunit": "^9.5"
    }
}
```

**Exception Handler Update:**
```php
use Throwable;  // Changed from Exception

class Handler extends ExceptionHandler
{
    public function register()
    {
        $this->reportable(function (Throwable $e) {
            //
        });
    }
}
```

### 2. Database Column Missing

**Problem:**
```
SQLSTATE[42S22]: Column not found: 'status'
```

**Cause:** Migration ran without status column, table already existed

**Solution:** 
- Updated migration to include status column
- Changed to `migrate:fresh` to drop/recreate tables each build

```php
// Migration update
Schema::create('tasks', function (Blueprint $table) {
    $table->id();
    $table->string('task');
    $table->integer('status')->default(0);  // Added
    $table->unsignedBigInteger('user_id');
    $table->timestamps();
});
```

### 3. Composer Security Advisories

**Problem:** Composer blocked packages with known vulnerabilities

**Solution:** Updated deprecated packages
```json
{
    "require-dev": {
        "fakerphp/faker": "^1.23",  // Replaced fzaninotto/faker
        "mockery/mockery": "^1.3.1"
    }
}
```

### 4. PHPUnit Configuration Warnings

**Problem:** Old Laravel 5 phpunit.xml incompatible with PHPUnit 9

**Solution:** Updated to Laravel 8 format
```xml
<phpunit bootstrap="vendor/autoload.php" colors="true">
    <testsuites>
        <testsuite name="Feature">
            <directory>./tests/Feature</directory>
        </testsuite>
    </testsuites>
    <php>
        <server name="APP_ENV" value="testing"/>
        <server name="DB_DATABASE" value="homestead"/>
    </php>
</phpunit>
```

---

## Why Not Certain Tools

### SonarCloud Instead of SonarQube

**SonarQube Issues:**
- Required t2.small instance (2GB RAM minimum)
- Installation needed PostgreSQL + Java 11
- Instance repeatedly crashed due to memory constraints
- Frequent stopping/starting made it unreliable
<img width="1366" height="768" alt="sonaqube is running" src="https://github.com/user-attachments/assets/4e321198-77d2-4c27-9d30-a2ba695c9b7c" />


**SonarCloud Benefits:**
- Cloud-hosted, no infrastructure cost
- Free for open-source projects
- 5-minute setup vs 2+ hours
- Reliable performance
- Same analysis capabilities

**Implementation:** Simply connected Jenkins to SonarCloud.io with organization token

### No JFrog Artifactory

**Blocker:** JFrog changed signup to require company email addresses. Personal/student emails no longer accepted.

**Alternative:** Direct deployment from Git acceptable for demonstration. In production, would use:
- AWS S3 for artifact storage
- Nexus Repository (free tier available)
- GitHub Packages

---

## Results

**Pipeline Metrics:**
- Build time: ~3-4 minutes
- Test execution: 15 seconds
- Deployment: 1 minute
- Success rate: 100% after fixes

**Code Quality:**
- Code smells: 15
- Bugs: 2
- Security vulnerabilities: 0
- Technical debt: 2h 30min

<img width="1366" height="768" alt="deploytociserverssuccesful" src="https://github.com/user-attachments/assets/b3bb932f-61a3-4d92-8a80-327ae772b9a4" />
<img width="1366" height="768" alt="nginx installed" src="https://github.com/user-attachments/assets/40721f05-4431-4811-9680-162b4f728670" />

**Infrastructure:**
- 6 EC2 instances managed
- 3 environments operational (dev, sit, ci)
- 2 agents distributing load
- Full automation achieved

<img width="1366" height="768" alt="devansibleplaybookalsteps" src="https://github.com/user-attachments/assets/e99ce300-05e3-4c5b-be1d-f4f27205b851" />

**Git Workflow:**

<img width="1366" height="768" alt="pullrequest" src="https://github.com/user-attachments/assets/123b24da-0c4d-4e98-a8f9-1fe85039f74f" />
<img width="1366" height="768" alt="merge with main" src="https://github.com/user-attachments/assets/7d761fb4-8d10-4161-a911-793280e6111c" />
<img width="1366" height="768" alt="updated jenkins file2" src="https://github.com/user-attachments/assets/a85a4849-0b5d-4493-9220-1538fb660a08" />

---
<img width="1366" height="768" alt="sonarqbue analysis succesfull" src="https://github.com/user-attachments/assets/1d5cd526-13ab-436a-955d-020bd9dadf15" />

## Key Takeaways

**What Worked:**
- Cloud services (SonarCloud) more reliable than self-hosted for small projects
- Laravel 8 migration solved all PHP 8.3 compatibility issues
- `migrate:fresh` ensures consistent database state
- Jenkins agents significantly reduced build times
- Ansible enables infrastructure reproducibility

**Lessons Learned:**
- Always verify framework compatibility with OS default packages
- Cloud alternatives exist for resource-intensive tools
- Infrastructure as Code pays off immediately
- Automated testing catches issues before deployment

---

## Repository Structure

```
.
├── ansible-config-mgt/
│   ├── deploy/
│   │   ├── Jenkinsfile
│   │   └── ansible.cfg
│   ├── inventory/
│   │   ├── ci
│   │   ├── dev
│   │   ├── sit
│   │   └── pentest
│   ├── playbooks/
│   │   ├── site.yml
│   │   └── dev.yml
│   └── roles/
└── php-todo/
    ├── app/
    ├── database/
    │   ├── migrations/
    │   └── seeders/
    ├── tests/
    ├── Jenkinsfile
    ├── composer.json
    └── phpunit.xml
```

---

**Technologies:** Jenkins | Ansible | SonarCloud | PHP 8.3 | Laravel 8 | AWS EC2  
**Achievement:** Full CI/CD automation with zero manual deployment
