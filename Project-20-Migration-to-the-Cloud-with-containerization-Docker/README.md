# project 20 — migration to the cloud with containerization (docker & docker compose)

**StegHub DevOps Cloud Engineer apprenticeship — project 20**

This project migrates two PHP web applications from VM-based deployments to Docker containers, implements Docker Compose for multi-container orchestration, and builds Jenkins CI/CD pipelines that automatically build, test, and push images to Docker Hub on every commit.

## project repositories

| repository | description | docker hub |
|---|---|---|
| [tooling-02](https://github.com/LydiahLaw/tooling-02) | PHP/MySQL Tooling web app | [lydiahlaw/tooling](https://hub.docker.com/r/lydiahlaw/tooling) |
| [php-todo-docker](https://github.com/LydiahLaw/php-todo-docker) | Laravel PHP Todo app | [lydiahlaw/php-todo](https://hub.docker.com/r/lydiahlaw/php-todo) |

## what was built

### part 1 — mysql in a container

Pulled the official MySQL Docker image and ran it as a container on a custom bridge network:

```bash
docker network create --subnet=172.20.0.0/24 tooling_app_network

docker run --network tooling_app_network \
  -h mysqlserverhost \
  --name=mysql-server \
  -e MYSQL_ROOT_PASSWORD=$MYSQL_PW \
  -d mysql/mysql-server:latest
```

Created a non-root MySQL user for application connections and loaded the Tooling app database schema into the running container.

### part 2 — containerizing the tooling app

Built a Docker image for the PHP Tooling web application using the provided Dockerfile based on `php:8-apache`. Key steps in the image:

- installs the `mysqli` PHP extension
- installs Composer for PHP dependency management
- copies application code into `/var/www`
- configures Apache with a custom virtual host
- suppresses PHP deprecation warnings via a custom `php.ini`

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

### part 3 — containerizing the php-todo laravel app

Wrote a Dockerfile from scratch for the Laravel 5.2 Todo application. Key differences from the Tooling app:

- uses `php:7.4-apache` (Laravel 5.2 requires PHP 7.x, not PHP 8)
- installs `pdo` and `pdo_mysql` extensions (Laravel uses PDO, not raw mysqli)
- runs `composer install` inside the image build
- generates a Laravel app key with `php artisan key:generate`
- sets Apache document root to `public/` (Laravel's web root)
- creates required cache and storage directories before Composer runs

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

### part 4 — docker hub

Both images pushed to Docker Hub with versioned tags:

```bash
docker tag tooling:0.0.1 lydiahlaw/tooling:0.0.1
docker push lydiahlaw/tooling:0.0.1

docker tag php-todo:0.0.1 lydiahlaw/php-todo:0.0.1
docker push lydiahlaw/php-todo:0.0.1
```

### part 5 — jenkins ci/cd pipelines

Set up Jenkins as a Docker container with access to the host Docker socket, enabling it to build and push images as part of the pipeline:

```bash
docker run -d \
  --name jenkins \
  -p 8080:8080 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts
```

Both apps have multibranch pipelines with five stages:

```
Initial Cleanup → Checkout → Build → Test → Push → Cleanup
```

**test stage approach:** the pipeline spins up the built image as a temporary container on `tooling_app_network`, then runs a `curlimages/curl` container on the same network to hit the app by container name. Docker's internal DNS resolves the container name automatically. The stage fails if the response is not HTTP 200 or 302.

```bash
STATUS=$(docker run --rm --network tooling_app_network curlimages/curl:latest \
  curl -s -o /dev/null -w "%{http_code}" http://test-container:80)
echo "$STATUS" | grep -E "200|302"
```

**branch-prefixed image tags:**

| branch | image tag |
|---|---|
| `main` | `lydiahlaw/tooling:main-0.0.1` |
| `feature/docker-pipeline` | `lydiahlaw/tooling:feature-docker-pipeline-0.0.1` |

### part 6 — docker compose

Refactored the Tooling app deployment into a single `tooling.yaml` Docker Compose file:

```bash
docker compose -f tooling.yaml up -d
```

This brings up both the PHP app and MySQL database with a single command. The full field-by-field documentation of the Compose file is in the [tooling-02 README](https://github.com/LydiahLaw/tooling-02).

## key troubleshooting solved

**php 8 + dotenv compatibility** — the app uses a version of the dotenv library incompatible with PHP 8, causing deprecation warnings on every page. Fixed by adding a custom `php.ini` that suppresses deprecated and warning-level errors.

**docker socket permissions** — Jenkins running inside Docker could not access the host Docker daemon. Fixed by adding the Jenkins user to the docker group with the correct GID matching the host socket.

**github api rate limiting** — Jenkins multibranch pipeline scan was sleeping for 40+ minutes due to anonymous GitHub API calls hitting rate limits. Fixed by adding a GitHub personal access token as a Jenkins credential and linking it to the pipeline branch source.

**curl from inside jenkins container** — the test stage initially tried to curl `localhost:8086` from inside Jenkins, which refers to the Jenkins container's own localhost, not the host machine. Solved by running the curl test from inside a `curlimages/curl` container on the same Docker network, using the app container's service name as the hostname.

**docker tag with branch slash** — branch name `feature/docker-pipeline` produced an invalid Docker tag `lydiahlaw/tooling:feature/docker-pipeline-0.0.1` because Docker tags cannot contain forward slashes. Fixed with `.replace('/', '-')` in the Jenkinsfile environment block.

**concurrent pipeline race condition** — both branch pipelines ran simultaneously and tried to create a container with the same name, causing a conflict. Fixed by naming the test container after the branch: `test-todo-${BRANCH_NAME.replace('/', '-')}`.

## screenshots

### tooling app dashboard
![Tooling Dashboard](screenshots/tooling-dashboard.png)

### php-todo task list
![PHP Todo App](screenshots/php-todo.png)

### docker hub repositories
![Docker Hub](screenshots/dockerhub.png)

### jenkins multibranch pipelines
![Jenkins Pipelines](screenshots/jenkins-pipelines.png)

## tools used

- Docker 29.2.1
- Docker Compose v5.0.2
- Jenkins LTS 2.541.3
- PHP 8 (Tooling app) / PHP 7.4 (Todo app)
- MySQL 8.0.32 / MySQL 5.7
- Apache 2
- WSL2 on Windows

## next

Project 21 — Orchestrating containers at scale with Kubernetes.
