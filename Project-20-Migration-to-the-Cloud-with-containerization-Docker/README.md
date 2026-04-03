# Migration to the Cloud with Containerization (Docker & Docker Compose)

## Table of Contents
- [Introduction](#introduction)
- [Project Repositories](#project-repositories)
- [What Was Built](#what-was-built)
  - [MySQL in a Container](#mysql-in-a-container)
  - [Containerizing the Tooling App](#containerizing-the-tooling-app)
  - [Containerizing the PHP-Todo Laravel App](#containerizing-the-php-todo-laravel-app)
  - [Docker Hub](#docker-hub)
  - [Jenkins CI/CD Pipelines](#jenkins-cicd-pipelines)
  - [Docker Compose](#docker-compose)
- [Key Troubleshooting](#key-troubleshooting)
- [Tools Used](#tools-used)
- [Screenshots](#screenshots)
- [Conclusion](#conclusion)

---

## Introduction

Up to this point, every application in this apprenticeship has been deployed on EC2 virtual machines — each running a full guest OS, configured manually or via Ansible and Terraform. That approach works, but it does not scale well when you need to run many small applications with different runtimes and conflicting dependencies. Spinning up a new VM for every service becomes expensive and difficult to maintain.

This project introduces Docker as the solution. Unlike a VM, a Docker container packages only what the application needs — not a full OS — making it lighter, faster, and consistent across any environment that runs the Docker engine. The same container that runs on a developer's laptop will behave identically on a production server. No more "it works on my machine."

The project migrates two PHP web applications — the StegHub Tooling site and a Laravel Todo app — from VM-based deployments into Docker containers. It then implements Docker Compose for single-command multi-container orchestration and Jenkins CI/CD pipelines that automatically build, test, and push versioned images to Docker Hub on every commit.

---

## Project Repositories

| Repository | Description | Docker Hub |
|---|---|---|
| [tooling-02](https://github.com/LydiahLaw/tooling-02) | PHP/MySQL Tooling web app | [lydiahlaw/tooling](https://hub.docker.com/r/lydiahlaw/tooling) |
| [php-todo-docker](https://github.com/LydiahLaw/php-todo-docker) | Laravel PHP Todo app | [lydiahlaw/php-todo](https://hub.docker.com/r/lydiahlaw/php-todo) |

---

## What Was Built

### MySQL in a Container

Rather than installing MySQL directly on a server, a dedicated Docker network was created and MySQL was run as a container on that network:

```bash
docker network create --subnet=172.20.0.0/24 tooling_app_network

docker run --network tooling_app_network \
  -h mysqlserverhost \
  --name=mysql-server \
  -e MYSQL_ROOT_PASSWORD=$MYSQL_PW \
  -d mysql/mysql-server:latest
```

A non-root MySQL user was created for application connections, and the Tooling app database schema was loaded into the running container. Both the database and the PHP app containers communicate over `tooling_app_network` using Docker's internal DNS — the app reaches MySQL by hostname (`mysqlserverhost`), not by IP.

---

### Containerizing the Tooling App

The Tooling app image was built from the provided Dockerfile based on `php:8-apache`. The image installs the `mysqli` PHP extension, Composer, and configures Apache with a custom virtual host. A custom `php.ini` was added to suppress PHP 8 deprecation warnings that were leaking into the browser output.

```bash
docker build -t tooling:0.0.1 .

docker run --network tooling_app_network \
  -p 8085:80 \
  -e MYSQL_IP=mysqlserverhost \
  -e MYSQL_USER=webaccess \
  -e MYSQL_PASS=YourPassword \
  -e MYSQL_DBNAME=toolingdb \
  -it tooling:0.0.1
```

---

### Containerizing the PHP-Todo Laravel App

A Dockerfile was written from scratch for the Laravel 5.2 Todo application. Laravel has a different structure from plain PHP — it requires PDO instead of raw mysqli, uses a `public/` document root, and needs Composer to install dependencies and `php artisan` to generate an application key.

Key decisions in the Dockerfile:
- `php:7.4-apache` base image — Laravel 5.2 requires PHP 7.x, not PHP 8
- `pdo` and `pdo_mysql` extensions installed alongside `mysqli`
- `bootstrap/cache/` and `storage/` directories created before `composer install` runs to prevent post-install script failures
- Apache document root rewritten to `/var/www/html/public` via `sed`

```bash
docker build -t php-todo:0.0.1 .

docker run --network tooling_app_network \
  -p 8090:80 \
  -e DB_HOST=mysqlserverhost \
  -e DB_DATABASE=tododb \
  -e DB_USERNAME=webaccess \
  -e DB_PASSWORD=YourPassword \
  -it php-todo:0.0.1
```

---

### Docker Hub

Both images were tagged with the Docker Hub username and pushed to public repositories:

```bash
docker tag tooling:0.0.1 lydiahlaw/tooling:0.0.1
docker push lydiahlaw/tooling:0.0.1

docker tag php-todo:0.0.1 lydiahlaw/php-todo:0.0.1
docker push lydiahlaw/php-todo:0.0.1
```

---

### Jenkins CI/CD Pipelines

Jenkins was run as a Docker container with access to the host Docker socket, giving it the ability to build and push images as part of the pipeline:

```bash
docker run -d \
  --name jenkins \
  -p 8080:8080 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts
```

Multibranch pipelines were created for both applications with five stages:

```
Initial Cleanup → Checkout → Build → Test → Push → Cleanup
```

The test stage spins up the built image as a temporary container, then runs a `curlimages/curl` container on the same Docker network to hit the app by container name. Docker's internal DNS resolves the name automatically. The stage fails if the HTTP response is not 200 or 302.

```bash
STATUS=$(docker run --rm --network tooling_app_network curlimages/curl:latest \
  curl -s -o /dev/null -w "%{http_code}" http://test-container:80)
echo "$STATUS" | grep -E "200|302"
```

Images are tagged with the branch name as a prefix, ensuring every push is traceable to its source branch:

| Branch | Image Tag |
|---|---|
| `main` | `lydiahlaw/tooling:main-0.0.1` |
| `feature/docker-pipeline` | `lydiahlaw/tooling:feature-docker-pipeline-0.0.1` |

After a successful push, the cleanup stage removes the image from the Jenkins server to keep disk usage in check.

---

### Docker Compose

The Tooling app stack was refactored into a single `tooling.yaml` Docker Compose file, bringing up both the PHP app and MySQL database with one command:

```bash
docker compose -f tooling.yaml up -d
```

Full field-by-field documentation of every Compose directive is in the [tooling-02 README](https://github.com/LydiahLaw/tooling-02).

---

## Key Troubleshooting

**PHP 8 and dotenv compatibility** — the Tooling app uses a version of the dotenv library incompatible with PHP 8, causing deprecation warnings rendered directly in the browser. Fixed by adding a custom `php.ini` that sets `error_reporting` to exclude deprecated and warning-level errors.

**Docker socket permissions** — Jenkins running inside Docker could not access the host Docker daemon due to a group ID mismatch on the socket file. Fixed by modifying the docker group GID inside the Jenkins container to match the host socket's group ID.

**GitHub API rate limiting** — the Jenkins multibranch pipeline scan was sleeping for 40+ minutes because anonymous GitHub API calls were hitting rate limits. Fixed by creating a GitHub personal access token and linking it to the pipeline branch source configuration.

**Curl from inside the Jenkins container** — the test stage initially tried to curl `localhost:8086` from Jenkins, which resolves to the Jenkins container itself, not the host. Solved by running the curl test from a `curlimages/curl` container on the same Docker network, reaching the app container by its service name.

**Docker tag with branch slash** — branch name `feature/docker-pipeline` produced an invalid Docker tag because tags cannot contain forward slashes. Fixed with `.replace('/', '-')` in the Jenkinsfile environment block.

**Concurrent pipeline race condition** — both branch pipelines ran simultaneously and tried to create a test container with the same name, causing a conflict error. Fixed by naming each test container after its branch: `test-todo-${BRANCH_NAME.replace('/', '-')}`.

---

## Tools Used

- Docker 29.2.1
- Docker Compose v5.0.2
- Jenkins LTS 2.541.3
- PHP 8 (Tooling app) / PHP 7.4 (Todo app)
- MySQL 8.0.32 / MySQL 5.7
- Apache 2
- WSL2 on Windows

---

## Screenshots

Screenshots are in the [screenshots](./screenshots/) folder.

---

## Conclusion

This project marked a significant shift in how applications are packaged and delivered. Moving from EC2 instances to containers removes the dependency on a specific OS or server configuration — the container carries its own environment everywhere it goes.

The hands-on troubleshooting in this project was as valuable as the implementation itself. Debugging the Docker socket permissions, working through the WSL network isolation issue, and solving the concurrent pipeline race condition built real intuition for how containers communicate, how Docker networks work, and how CI systems interact with the Docker daemon.

With containerization in place, the natural next step is orchestration — managing containers at scale across multiple nodes. That is what Project 21 addresses with Kubernetes.
