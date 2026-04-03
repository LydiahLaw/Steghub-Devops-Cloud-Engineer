# Migration to the Cloud with Containerization (Docker and Docker Compose)

## Table of contents

- [Overview](#overview)
- [Project repositories](#project-repositories)
- [Architecture](#architecture)
- [What was built](#what-was-built)
  - [MySQL in a container](#mysql-in-a-container)
  - [Containerizing the Tooling app](#containerizing-the-tooling-app)
  - [Containerizing the PHP-Todo Laravel app](#containerizing-the-php-todo-laravel-app)
  - [Pushing to Docker Hub](#pushing-to-docker-hub)
  - [Jenkins CI/CD pipelines](#jenkins-cicd-pipelines)
  - [Docker Compose](#docker-compose)
- [Key troubleshooting](#key-troubleshooting)
- [Tools used](#tools-used)
- [Screenshots](#screenshots)
- [Conclusion](#conclusion)

## Overview

This project migrates two PHP web applications from EC2 virtual machine deployments to Docker containers. Rather than spinning up a full OS per application, each app runs in a lightweight isolated container that carries only what it needs. The project covers writing Dockerfiles, running multi-container stacks with Docker Compose, and building Jenkins CI/CD pipelines that automatically build, test, and push images to Docker Hub on every commit.

The two applications containerized here are the StegHub Tooling web app (PHP/MySQL) and a Laravel Todo app. Both were previously deployed on EC2 instances in earlier projects. The goal was to demonstrate that the same applications can run identically in containers regardless of the underlying host.

## Project repositories

| Repository | Description | Docker Hub |
|---|---|---|
| [tooling-02](https://github.com/LydiahLaw/tooling-02) | PHP/MySQL Tooling web app | [lydiahlaw/tooling](https://hub.docker.com/r/lydiahlaw/tooling) |
| [php-todo-docker](https://github.com/LydiahLaw/php-todo-docker) | Laravel PHP Todo app | [lydiahlaw/php-todo](https://hub.docker.com/r/lydiahlaw/php-todo) |

## Architecture

```
browser → Apache (port 8085/5000) → PHP app container
                                          ↕
                                   tooling_app_network
                                          ↕
                                   MySQL container
```

Both containers run on a shared Docker bridge network called `tooling_app_network`. This allows the PHP application to reach MySQL using the container hostname rather than an IP address, which Docker resolves automatically through its internal DNS.

## What was built

### MySQL in a container

The database layer was set up first since the PHP application depends on it. A custom Docker network was created to give both containers a shared namespace, then MySQL was started on that network with a hostname the app could reference by name.

```bash
docker network create --subnet=172.20.0.0/24 tooling_app_network

docker run --network tooling_app_network \
  -h mysqlserverhost \
  --name=mysql-server \
  -e MYSQL_ROOT_PASSWORD=$MYSQL_PW \
  -d mysql/mysql-server:latest
```

A dedicated non-root MySQL user was created via a SQL script and the Tooling app database schema was loaded into the running container.

### Containerizing the Tooling app

The Tooling app image was built from the existing Dockerfile using `php:8-apache` as the base image. The image installs the `mysqli` PHP extension, installs Composer, copies application code into `/var/www`, and configures Apache with a custom virtual host. A custom `php.ini` was added to suppress PHP 8 deprecation warnings that were rendering on every page.

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

### Containerizing the PHP-Todo Laravel app

A Dockerfile was written from scratch for the Laravel 5.2 Todo application. Several decisions differed from the Tooling app Dockerfile because Laravel has specific requirements.

`php:7.4-apache` was used as the base image instead of PHP 8 because Laravel 5.2 requires PHP 7.x. The `pdo` and `pdo_mysql` extensions were installed since Laravel uses PDO rather than raw mysqli. `composer install` runs inside the image build to bundle all dependencies. The Apache document root was repointed from `/var/www/html` to `/var/www/html/public` since Laravel serves from its `public/` folder. Required cache and storage directories were created before Composer ran to prevent post-install script failures.

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

### Pushing to Docker Hub

Both images were tagged with the Docker Hub username and pushed to public repositories.

```bash
docker tag tooling:0.0.1 lydiahlaw/tooling:0.0.1
docker push lydiahlaw/tooling:0.0.1

docker tag php-todo:0.0.1 lydiahlaw/php-todo:0.0.1
docker push lydiahlaw/php-todo:0.0.1
```

### Jenkins CI/CD pipelines

Jenkins was run as a Docker container with the host Docker socket mounted, giving it the ability to build and push images as part of pipeline execution. Both applications have multibranch pipelines with five stages.

```
Initial Cleanup → Checkout → Build → Test → Push → Cleanup
```

The test stage spins up the built image as a temporary container on `tooling_app_network`, then runs a `curlimages/curl` container on the same network to hit the app by container name. Docker's internal DNS resolves the name automatically. The stage fails if the response is not HTTP 200 or 302.

```bash
STATUS=$(docker run --rm --network tooling_app_network curlimages/curl:latest \
  curl -s -o /dev/null -w "%{http_code}" http://test-container:80)
echo "$STATUS" | grep -E "200|302"
```

Image tags are prefixed with the branch name so every push is traceable to its source branch.

| Branch | Image tag |
|---|---|
| `main` | `lydiahlaw/tooling:main-0.0.1` |
| `feature/docker-pipeline` | `lydiahlaw/tooling:feature-docker-pipeline-0.0.1` |

The cleanup stage removes the image from the Jenkins server after every successful push, keeping disk usage in check.

### Docker Compose

The Tooling app stack was refactored into a single `tooling.yaml` Docker Compose file, bringing up both the PHP app and MySQL database with one command. Full field-by-field documentation of the Compose file is in the [tooling-02 README](https://github.com/LydiahLaw/tooling-02).

```bash
docker compose -f tooling.yaml up -d
```

## Key troubleshooting

**PHP 8 and dotenv compatibility** — the Tooling app uses an older dotenv library that produces deprecation warnings on every page when running under PHP 8. Fixed by adding a custom `php.ini` that suppresses deprecated and warning-level output.

**Docker socket permissions** — Jenkins running inside Docker could not access the host Docker daemon, causing all `docker build` commands to fail with a permission denied error. Fixed by modifying the docker group GID inside the Jenkins container to match the host socket's group ID, then restarting Jenkins.

**GitHub API rate limiting** — the multibranch pipeline scan was sleeping for 40 minutes between attempts due to anonymous GitHub API calls hitting rate limits. Fixed by adding a GitHub personal access token as a Jenkins credential and linking it to the pipeline branch source configuration.

**Curl from inside Jenkins container** — the test stage initially tried to curl `localhost:8086` from inside Jenkins, which targets the Jenkins container's own loopback, not the host or the app container. Solved by running the curl test from a `curlimages/curl` container on the same Docker network, using the app container's service name as the hostname.

**Docker tag with branch slash** — the branch name `feature/docker-pipeline` produced an invalid Docker tag because Docker tags cannot contain forward slashes. Fixed using `.replace('/', '-')` in the Jenkinsfile environment block, converting the slash to a hyphen.

**Concurrent pipeline race condition** — both branch pipelines ran simultaneously and tried to create a test container with the same name, causing a conflict. Fixed by naming the test container after the branch so each pipeline gets its own unique container name.

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

This project established the foundation for container-based application deployment. Moving from EC2 instances to Docker containers removed the overhead of managing full operating systems per application and made the deployment process reproducible across any machine running Docker. The Jenkins pipelines ensure every code change is automatically built, tested, and published without manual intervention. Docker Compose simplified the multi-container workflow into a single declarative file. These patterns scale directly into Kubernetes orchestration, which is the focus of the next project.
