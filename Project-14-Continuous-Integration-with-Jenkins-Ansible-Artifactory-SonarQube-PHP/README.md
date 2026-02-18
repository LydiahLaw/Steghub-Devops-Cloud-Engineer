# Project 14: CI/CD Pipeline with Jenkins, Ansible & SonarCloud

![Jenkins Pipeline](screenshots/all%20stages%20added.png)

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

![Blue Ocean View](screenshots/blueocean.png)

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

![Infrastructure](screenshots/inventory%20assets.png)

**Ansible Inventory:**
```
inventory/
├── ci          # Jenkins, SonarQube (not used), Nginx
├── dev         # App servers, DB, Nginx
├── sit         # System Integration Testing
└── pentest     # Penetration testing
```

![Inventory Files](screenshots/nano%20ci.png)
![Dev Inventory](screenshots/nano%20dev.png)

---

## Implementation

### Jenkins Setup

**Plugins Installed:**
- Blue Ocean - Visual pipeline interface
- Ansible - Playbook execution
- SonarQube Scanner - Code analysis
- Plot - Metrics visualization
- GitHub Integration - Webhook support

![Blue Ocean Plugin](screenshots/blueocean%20feature.png)
![Ansible Config](screenshots/ansible%20configjenkins.png)

**Agents Configuration:**

![Jenkins Nodes](screenshots/nodes%20created.png)

Both agents configured with:
- Java 11
- Ansible
- PHP 8.3 + Composer
- SSH access to target servers

![SSH Key Added](screenshots/adding%20ssh%20to%20jenkins.png)

### GitHub Integration

**Repository Setup:**
- Forked php-todo application
- Created deploy/Jenkinsfile
- Configured webhook to Jenkins

![Forked Repository](screenshots/forkedtodo.png)
![Jenkins Branch Detection](screenshots/jenkins%20branch.png)

**Access Token:**

![GitHub Token](screenshots/new%20access%20token.png)
![Connect to Jenkins](screenshots/connect%20tojen.png)

### Jenkinsfile

**Initial Version (2 stages):**

![2 Stages](screenshots/2%20stages%20build%20and%20test.png)

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

![More Stages](screenshots/more%20stages%20added.png)
![All Stages](screenshots/all%20stages%20added.png)
![Script Path](screenshots/change%20script%20path.png)

### Database Configuration

**MySQL Setup on RHEL DB Server:**

![MySQL Started](screenshots/mysqlstarted%20ondbserver.png)

```sql
CREATE DATABASE homestead;
CREATE USER 'homestead'@'%' IDENTIFIED BY 'sePret^i';
GRANT ALL PRIVILEGES ON *.* TO 'homestead'@'%';
```

**Connection Test from Jenkins:**

![DB Connection](screenshots/logintodbfromjenkins.png)

**Migration Result:**

![Tables Created](screenshots/todo%20succesfulltables%20created.png)
![Homestead Tables](screenshots/homesteadtable.png)

### SonarCloud Integration

**Configuration:**

![SonarQube Scanner](screenshots/sonarqube%20downloaded%20in%20jenkins.png)
![Token Config](screenshots/configue%20sonartoken%20on%20jenkins.png)

**Analysis Results:**

![Analysis Success](screenshots/sonarqbue%20analysis%20succesfull.png)
![SonarCloud Summary](screenshots/sonarcloud%20summary.png)
![Code Smells](screenshots/sonarcloud%20codesmells.png)

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

![Ansible Installed](screenshots/ansible%20installed.png)
![Playbook Success 1](screenshots/ansible%20pipeline%20success1.png)
![Playbook Success 2](screenshots/ansible%20pipeline%20success2.png)

**Parameterized Deployment:**

![Build Parameters](screenshots/buildwith%20para.png)
![Deploy Config](screenshots/deployconfig.png)

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

![PHP Dependencies](screenshots/phpdependecies.png)

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

![Build Success](screenshots/build%20succesful.png)
![Feature Branch](screenshots/feature%20on%20jenkins.png)

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

![SonarQube Attempted](screenshots/sonaqube%20is%20running.png)
![Browser Access](screenshots/browsersonaqube.png)
![Logged In](screenshots/sonarqubeloggedin.png)

**SonarCloud Benefits:**
- Cloud-hosted, no infrastructure cost
- Free for open-source projects
- 5-minute setup vs 2+ hours
- Reliable performance
- Same analysis capabilities

**Implementation:** Simply connected Jenkins to SonarCloud.io with organization token

### No JFrog Artifactory

**Blocker:** JFrog changed signup to require company email addresses. Personal/student emails no longer accepted.

![Artifactory Attempted](screenshots/artifactory.png)

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

![CI Deployment Success](screenshots/deploytociserverssuccesful.png)
![Nginx Installed](screenshots/nginx%20installed.png)

**Infrastructure:**
- 6 EC2 instances managed
- 3 environments operational (dev, sit, ci)
- 2 agents distributing load
- Full automation achieved

![Dev Ansible Steps](screenshots/devansibleplaybookalsteps.png)

**Git Workflow:**

![Pull Request](screenshots/pullrequest.png)
![Merge Main](screenshots/merge%20with%20main.png)
![Jenkinsfile Updated](screenshots/updated%20jenkins%20file2.png)

---

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