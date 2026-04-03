# Migration to the Cloud with Containerization (Docker and Docker Compose)

## Table of contents

- [Overview](#overview)
- [Project repositories](#project-repositories)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Part 1 - MySQL in a container](#part-1---mysql-in-a-container)
- [Part 2 - Containerizing the Tooling app](#part-2---containerizing-the-tooling-app)
- [Part 3 - Containerizing the PHP-Todo Laravel app](#part-3---containerizing-the-php-todo-laravel-app)
- [Part 4 - Pushing images to Docker Hub](#part-4---pushing-images-to-docker-hub)
- [Part 5 - Jenkins CI/CD pipelines](#part-5---jenkins-cicd-pipelines)
- [Part 6 - Docker Compose](#part-6---docker-compose)
- [Key troubleshooting](#key-troubleshooting)
- [Tools used](#tools-used)
- [Screenshots](#screenshots)
- [Conclusion](#conclusion)

## Overview

This project migrates two PHP web applications from EC2 virtual machine deployments to Docker containers. Rather than spinning up a full OS per application, each app runs in a lightweight isolated container that carries only what it needs. The project covers writing Dockerfiles, running multi-container stacks with Docker Compose, and building Jenkins CI/CD pipelines that automatically build, test, and push images to Docker Hub on every commit.

The two applications containerized are the StegHub Tooling web app (PHP/MySQL) and a Laravel Todo app. Both were previously deployed on EC2 instances in earlier projects. The goal was to demonstrate that the same applications run identically in containers regardless of the underlying host.

## Project repositories

| Repository | Description | Docker Hub |
|---|---|---|
| [tooling-02](https://github.com/LydiahLaw/tooling-02) | PHP/MySQL Tooling web app | [lydiahlaw/tooling](https://hub.docker.com/r/lydiahlaw/tooling) |
| [php-todo-docker](https://github.com/LydiahLaw/php-todo-docker) | Laravel PHP Todo app | [lydiahlaw/php-todo](https://hub.docker.com/r/lydiahlaw/php-todo) |

## Architecture

```
browser → Apache (port 8085/5000) → PHP app container
                                          ↕
                                   tooling_app_network (bridge)
                                          ↕
                                   MySQL container
```

Both containers run on a shared Docker bridge network called `tooling_app_network`. This allows the PHP application to reach MySQL using the container hostname rather than an IP address, which Docker resolves automatically through its internal DNS.

## Prerequisites

- Docker Desktop installed and running
- Docker Compose v2+
- Git
- A Docker Hub account
- A GitHub account

Verify your installation:

```bash
docker --version
docker compose version
docker run hello-world
```

## Part 1 - MySQL in a container

### Step 1 - Pull the MySQL image

```bash
docker pull mysql/mysql-server:latest
docker images
```
<img width="1366" height="768" alt="sqlpull image1" src="https://github.com/user-attachments/assets/91fd044b-18a5-4e7e-b380-c061768fbc33" />

### Step 2 - Create a custom Docker network

A custom network allows containers to reach each other by hostname rather than IP address.

```bash
docker network create --subnet=172.20.0.0/24 tooling_app_network
docker network ls
```

### Step 3 - Set the root password as an environment variable

```bash
export MYSQL_PW=yourpassword
echo $MYSQL_PW
```

### Step 4 - Run the MySQL container

```bash
docker run --network tooling_app_network \
  -h mysqlserverhost \
  --name=mysql-server \
  -e MYSQL_ROOT_PASSWORD=$MYSQL_PW \
  -d mysql/mysql-server:latest

docker ps -a
```

### Step 5 - Create a non-root database user

Create a SQL script that sets up a user the application will use to connect:

```sql
CREATE USER 'webaccess'@'%' IDENTIFIED BY 'yourpassword';
GRANT ALL PRIVILEGES ON * . * TO 'webaccess'@'%';
```

Run the script against the container:

```bash
docker exec -i mysql-server mysql -uroot -p$MYSQL_PW < create_user.sql
```

### Step 6 - Verify the user from a client container

```bash
docker run --network tooling_app_network \
  --name mysql-client \
  -it --rm \
  mysql \
  mysql -h mysqlserverhost -u webaccess -p
```

Once connected run `SHOW DATABASES;` to confirm the connection works, then `exit`.

<img width="1366" height="768" alt="mysql client 4" src="https://github.com/user-attachments/assets/26875d2c-3d7c-4785-8577-62846b504618" />


### Step 7 - Clone the Tooling app and load the schema

```bash
git clone https://github.com/StegTechHub/tooling-02.git
cd tooling-02

export tooling_db_schema=./html/tooling_db_schema.sql
docker exec -i mysql-server mysql -uroot -p$MYSQL_PW < $tooling_db_schema
```
<img width="1366" height="768" alt="tooling cloned 5" src="https://github.com/user-attachments/assets/bde81296-61bb-48fe-8893-9229b3dce0a6" />


## Part 2 - Containerizing the Tooling app

### Step 1 - Understand the Dockerfile

Before building, read the Dockerfile to understand what it does:

```bash
cat Dockerfile
```

Key instructions in the Dockerfile:
- `FROM php:8-apache` - base image with PHP 8 and Apache pre-installed
- `ENV MYSQL_*` - declares environment variables the app reads at runtime
- `docker-php-ext-install mysqli` - installs the PHP MySQL extension
- `echo "ServerName localhost"` - suppresses an Apache hostname warning
- `curl ... composer` - installs PHP's dependency manager
- `COPY apache-config.conf` - applies a custom Apache virtual host configuration
- `a2enmod rewrite` - enables URL rewriting required by the app
- `COPY html /var/www` - copies the application code into the image
- `chown -R www-data` - sets Apache as the owner of the app files
- `CMD ["apache2-foreground"]` - keeps Apache running in the foreground so the container stays alive

### Step 2 - Create the .env file

The app uses dotenv to read database credentials. Create the file inside the `html/` directory:

```bash
cat > html/.env << 'EOF'
MYSQL_IP=mysqlserverhost
MYSQL_USER=webaccess
MYSQL_PASS=yourpassword
MYSQL_DBNAME=toolingdb
EOF
```
<img width="1366" height="768" alt="create env file 11" src="https://github.com/user-attachments/assets/a2484525-b093-4b49-a581-1e2d51f2ce82" />

### Step 3 - Add a php.ini to suppress deprecation warnings

```bash
cat > php-config.ini << 'EOF'
error_reporting = E_ALL & ~E_DEPRECATED & ~E_NOTICE & ~E_WARNING
display_errors = Off
output_buffering = On
EOF
```

### Step 4 - Build the image

```bash
docker build -t tooling:0.0.1 .
docker images
```

### Step 5 - Run the container

```bash
docker run --network tooling_app_network \
  -p 8085:80 \
  -e MYSQL_IP=mysqlserverhost \
  -e MYSQL_USER=webaccess \
  -e MYSQL_PASS=yourpassword \
  -e MYSQL_DBNAME=toolingdb \
  -it tooling:0.0.1
```
<img width="1366" height="768" alt="todo build complete 14" src="https://github.com/user-attachments/assets/13ef66a3-bb73-4d60-9073-06716b464772" />

Open `http://localhost:8085` in your browser. Log in with `test@gmail.com` / `12345`.
<img width="1366" height="768" alt="tooling dashboard 10" src="https://github.com/user-attachments/assets/9459fa3b-1869-4f65-8e99-ae15a327e7f6" />


## Part 3 - Containerizing the PHP-Todo Laravel app

### Step 1 - Clone the repo

```bash
git clone https://github.com/StegTechHub/php-todo.git
cd php-todo
```

### Step 2 - Create the database

```bash
docker exec -i mysql-server mysql -uroot -p$MYSQL_PW -e "CREATE DATABASE tododb;"
```

### Step 3 - Create the .env file

Laravel reads its configuration from a `.env` file in the project root:

```bash
cat > .env << 'EOF'
APP_ENV=local
APP_DEBUG=true
APP_KEY=SomeRandomString
APP_URL=http://localhost

DB_CONNECTION=mysql
DB_HOST=mysqlserverhost
DB_PORT=3306
DB_DATABASE=tododb
DB_USERNAME=webaccess
DB_PASSWORD=yourpassword

CACHE_DRIVER=file
SESSION_DRIVER=file
QUEUE_DRIVER=sync
EOF
```

### Step 4 - Write the Dockerfile

This Dockerfile was written from scratch. Key decisions differed from the Tooling app because Laravel has specific requirements:

```dockerfile
FROM php:7.4-apache

RUN apt-get update && apt-get install -y \
    zip unzip git curl \
    && docker-php-ext-install mysqli pdo pdo_mysql \
    && echo "ServerName localhost" >> /etc/apache2/apache2.conf

RUN curl -sS https://getcomposer.org/installer | php -- \
    --install-dir=/usr/local/bin \
    --filename=composer

RUN a2enmod rewrite

WORKDIR /var/www/html

COPY . /var/www/html

RUN mkdir -p bootstrap/cache storage/framework/sessions \
    storage/framework/views storage/framework/cache storage/logs \
    && chmod -R 775 bootstrap/cache storage

RUN composer install --no-interaction --prefer-dist --optimize-autoloader

RUN php artisan key:generate

RUN sed -i 's|/var/www/html|/var/www/html/public|g' \
    /etc/apache2/sites-available/000-default.conf

RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html/storage

COPY php-config.ini /usr/local/etc/php/conf.d/custom.ini

EXPOSE 80

CMD ["apache2-foreground"]
```
<img width="1366" height="768" alt="todo dockerfile 13" src="https://github.com/user-attachments/assets/a540f86f-efa6-4fb9-b6c7-4cb137bcc2e7" />


Why `php:7.4-apache` and not PHP 8 - Laravel 5.2 requires PHP 7.x. PHP 8 breaks compatibility with this version of the framework.

Why `pdo` and `pdo_mysql` - Laravel uses PDO as its database abstraction layer, not raw mysqli like the Tooling app.

Why `composer install` inside the build - dependencies are bundled into the image so the container is fully self-contained. No internet access needed at runtime.

Why `sed` to change the document root - Laravel serves requests from `public/` not the project root. Without this Apache would expose the entire Laravel directory including sensitive config files.

Why create directories before `composer install` - Laravel's post-install Artisan scripts write to `bootstrap/cache/`. If those directories do not exist the build fails.

### Step 5 - Build and run

```bash
docker build -t php-todo:0.0.1 .

docker run --network tooling_app_network \
  -p 8090:80 \
  -e DB_HOST=mysqlserverhost \
  -e DB_DATABASE=tododb \
  -e DB_USERNAME=webaccess \
  -e DB_PASSWORD=yourpassword \
  -it php-todo:0.0.1
```

Run migrations in a second terminal to create the database tables:

```bash
docker exec -it $(docker ps -q --filter ancestor=php-todo:0.0.1) php artisan migrate --force
```

Open `http://localhost:8090` to access the Task List.
<img width="1366" height="768" alt="todo app browser 16" src="https://github.com/user-attachments/assets/f721225b-6d29-4db6-9ac7-e19c76912c22" />


## Part 4 - Pushing images to Docker Hub

### Step 1 - Create a Docker Hub account

Sign up at `https://hub.docker.com` and create two public repositories named `tooling` and `php-todo`.

### Step 2 - Log in from the terminal

```bash
docker login
```

### Step 3 - Tag and push both images

```bash
docker tag tooling:0.0.1 lydiahlaw/tooling:0.0.1
docker push lydiahlaw/tooling:0.0.1

docker tag php-todo:0.0.1 lydiahlaw/php-todo:0.0.1
docker push lydiahlaw/php-todo:0.0.1
```

Verify both images are visible at `https://hub.docker.com/u/lydiahlaw`.
<img width="1366" height="768" alt="tags in dockerhub" src="https://github.com/user-attachments/assets/6121d4aa-0312-464a-a0f5-45183612e118" />


## Part 5 - Jenkins CI/CD pipelines

### Step 1 - Run Jenkins as a Docker container

Jenkins is run as a container with the host Docker socket mounted. This gives Jenkins the ability to run `docker build` and `docker push` commands as part of the pipeline.

```bash
docker run -d \
  --name jenkins \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts
```

### Step 2 - Get the initial admin password

```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

Open `http://localhost:8080`, paste the password, click Install suggested plugins, create an admin user, and click Start using Jenkins.

### Step 3 - Install Docker CLI inside Jenkins

Jenkins needs Docker CLI to run build and push commands:

```bash
docker exec -u root jenkins bash -c "apt-get update && apt-get install -y docker.io"
```

Grant Jenkins access to the Docker socket by matching the group ID:

```bash
docker exec -u root jenkins bash -c "groupmod -g 1001 docker && usermod -aG docker jenkins"
docker restart jenkins
```

Verify Jenkins can reach Docker:

```bash
docker exec -u jenkins jenkins docker ps
```

### Step 4 - Install required Jenkins plugins

Go to Manage Jenkins → Plugins → Available plugins and install:

- Docker Pipeline
- Blue Ocean (optional, for better pipeline visualization)

### Step 5 - Add Docker Hub credentials

Go to Manage Jenkins → Credentials → (global) → Add Credentials:

- Kind: Username with password
- Username: your Docker Hub username
- Password: your Docker Hub password
- ID: `dockerhub-credentials`
- Description: Docker Hub Credentials

### Step 6 - Add GitHub credentials

Go to Manage Jenkins → Credentials → (global) → Add Credentials:

- Kind: Username with password
- Username: your GitHub username
- Password: your GitHub Personal Access Token (created at github.com/settings/tokens with `repo` and `read:org` scopes)
- ID: `github-username-token`
- Description: GitHub Username Token

### Step 7 - Configure the GitHub server

Go to Manage Jenkins → System → GitHub section:

- Click Add GitHub Server
- Add the token credential created above
- Click Test connection — confirm it says "Credentials verified"
- Save

This prevents Jenkins from hitting GitHub API rate limits during repository scans.
docker restart jenkins

### Step 8 - Write the Jenkinsfile

Each repository has a Jenkinsfile at the root defining five pipeline stages. The image tag is automatically prefixed with the branch name so every push is traceable to its source.

```groovy
pipeline {
    agent any

    environment {
        DOCKER_REGISTRY = "lydiahlaw"
        IMAGE_NAME = "tooling"
        IMAGE_TAG = "${env.BRANCH_NAME.replace('/', '-')}-0.0.1"
    }

    stages {

        stage('Initial Cleanup') {
            steps {
                dir("${WORKSPACE}") {
                    deleteDir()
                }
            }
        }

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                sh """
                    docker build -t ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} .
                """
            }
        }

        stage('Test') {
            steps {
                sh """
                    docker rm -f test-container || true
                    docker run --name test-container \
                        --network tooling_app_network \
                        -e MYSQL_IP=mysqlserverhost \
                        -e MYSQL_USER=webaccess \
                        -e MYSQL_PASS=yourpassword \
                        -e MYSQL_DBNAME=toolingdb \
                        -d ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                    sleep 15
                    STATUS=\$(docker run --rm --network tooling_app_network curlimages/curl:latest \
                        curl -s -o /dev/null -w "%{http_code}" http://test-container:80)
                    echo "HTTP Status: \$STATUS"
                    echo "\$STATUS" | grep -E "200|302"
                """
            }
            post {
                always {
                    sh 'docker rm -f test-container || true'
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-credentials',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh '''
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push ''' + "${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}" + '''
                    '''
                }
            }
        }

        stage('Cleanup Images') {
            steps {
                sh """
                    docker rmi ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} || true
                """
            }
        }
    }

    post {
        always {
            sh 'docker logout'
        }
    }
}
```

### Step 9 - Create the multibranch pipeline in Jenkins

Go to Jenkins → New Item:

- Name: `tooling-app`
- Type: Multibranch Pipeline
- Click OK

In the configuration:

- Branch Sources → Add source → GitHub
- Credentials: select the GitHub token credential
- Repository HTTPS URL: `https://github.com/LydiahLaw/tooling-02.git`
- Click Validate
- Scan Multibranch Pipeline Triggers → Periodically → 15 minutes
- Save

Jenkins scans the repository and discovers all branches automatically. A build starts for each branch immediately after the scan.

### Step 10 - Create feature branch and simulate CI

```bash
git checkout -b feature/docker-pipeline
git push origin feature/docker-pipeline
```
<img width="1366" height="768" alt="php branches" src="https://github.com/user-attachments/assets/c43b589d-0583-45d2-b6e6-6c535ca7ef47" />


Jenkins detects the new branch and triggers a build automatically. The image tag for this branch becomes `lydiahlaw/tooling:feature-docker-pipeline-0.0.1`.

Branch-based image tags across both pipelines:

| Branch | Tooling image tag | PHP-Todo image tag |
|---|---|---|
| `main` | `lydiahlaw/tooling:main-0.0.1` | `lydiahlaw/php-todo:main-0.0.1` |
| `feature/docker-pipeline` | `lydiahlaw/tooling:feature-docker-pipeline-0.0.1` | `lydiahlaw/php-todo:feature-docker-pipeline-0.0.1` |

### Step 11 - Verify images on Docker Hub

After successful pipeline runs, verify all four tags are visible at:

- `https://hub.docker.com/r/lydiahlaw/tooling/tags`
- `https://hub.docker.com/r/lydiahlaw/php-todo/tags`

The same pipeline was replicated for the PHP-Todo app in the `php-todo-docker` repository with a separate multibranch pipeline named `php-todo-app` in Jenkins.

## Part 6 - Docker Compose

The Tooling app stack was refactored into a single `tooling.yaml` Docker Compose file, replacing the individual `docker run` commands with a declarative configuration.

```bash
docker compose -f tooling.yaml up -d
docker compose -f tooling.yaml ps
```

Load the schema on first run:

```bash
docker compose -f tooling.yaml exec -T db mysql -uwebaccess -pyourpassword toolingdb < html/tooling_db_schema.sql
```
<img width="1366" height="768" alt="docker compose tooling yaml 20" src="https://github.com/user-attachments/assets/c60cf4b7-e21e-4a4b-ad8f-01ce0e871c50" />

Access the app at `http://localhost:5000`.

Full field-by-field documentation of every line in `tooling.yaml` is in the [tooling-02 README](https://github.com/LydiahLaw/tooling-02).

To stop the stack:

```bash
docker compose -f tooling.yaml down
```

## Key troubleshooting

**PHP 8 and dotenv compatibility** - the Tooling app uses an older dotenv library that produces deprecation warnings on every page under PHP 8. Fixed by adding a custom `php.ini` that suppresses deprecated and warning-level output.

**Docker socket permissions** - Jenkins running inside Docker could not access the host Docker daemon, causing all `docker build` commands to fail with a permission denied error. Fixed by modifying the docker group GID inside the Jenkins container to match the host socket's group ID, then restarting Jenkins.

**GitHub API rate limiting** - the multibranch pipeline scan was sleeping for 40 minutes between attempts due to anonymous GitHub API calls hitting rate limits. Fixed by adding a GitHub personal access token as a Jenkins credential and linking it to the pipeline branch source configuration.

**Curl from inside Jenkins container** - the test stage initially tried to curl `localhost:8086` from inside Jenkins, which targets the Jenkins container's own loopback rather than the host or the app container. Solved by running the curl test from a `curlimages/curl` container on the same Docker network, using the app container's service name as the hostname.

**Docker tag with branch slash** - the branch name `feature/docker-pipeline` produced an invalid Docker tag because Docker tags cannot contain forward slashes. Fixed using `.replace('/', '-')` in the Jenkinsfile environment block, converting the slash to a hyphen before the tag is constructed.

**Concurrent pipeline race condition** - both branch pipelines ran simultaneously and tried to create a test container with the same name, causing a conflict. Fixed by naming the test container after the branch so each pipeline gets its own unique container name.

**Laravel bootstrap cache directory missing** - the `composer install` post-install scripts try to write to `bootstrap/cache/` which does not exist in a fresh container build. Fixed by creating all required Laravel directories with the correct permissions before running `composer install`.

## Tools used

- Docker 29.2.1
- Docker Compose v5.0.2
- Jenkins LTS 2.541.3
- PHP 8 (Tooling app) / PHP 7.4 (Todo app)
- MySQL 8.0.32 / MySQL 5.7
- Apache 2
- WSL2 on Windows

## Screenshots

Screenshots are in the [screenshots](./screenshots/) folder.

## Conclusion

This project established the foundation for container-based application deployment. Moving from EC2 instances to Docker containers removed the overhead of managing full operating systems per application and made the deployment process reproducible across any machine running Docker. The Jenkins pipelines ensure every code change is automatically built, tested against a live container, and published to Docker Hub without manual intervention. Docker Compose simplified the multi-container workflow into a single declarative file. These patterns scale directly into Kubernetes orchestration, which is the focus of the next project.
