# Project 04 - MEAN Stack Deployment on AWS EC2 (Ubuntu)

## Table of Contents
1. [Introduction](#1-introduction)  
2. [Problem Statement](#2-problem-statement)  
3. [Solution Overview](#3-solution-overview)  
4. [Tech Stack](#4-tech-stack)  
5. [Architecture](#5-architecture)  
6. [Setup & Implementation Steps](#6-setup--implementation-steps)  
7. [Testing the Application](#7-testing-the-application)  
8. [Challenges & Lessons Learned](#8-challenges--lessons-learned)  
9. [Conclusion](#9-conclusion)  

---

## 1. Introduction
This project demonstrates how to deploy a full **MEAN stack application** (MongoDB, Express, AngularJS, Node.js) on an **Ubuntu EC2 instance** in AWS.  
The goal was to build a simple **Book Register web application** that supports adding, listing, and deleting books through a dynamic frontend connected to a backend API and database.

---

## 2. Problem Statement
Modern web applications often require a full stack setup that connects frontend, backend, and database seamlessly. The challenge is to configure and integrate these different technologies on a cloud-hosted server.  

---

## 3. Solution Overview
We provisioned an **EC2 Ubuntu server** and deployed a MEAN stack web app step by step:
- Installed Node.js and npm  
- Installed and configured MongoDB  
- Built backend routes with Express and Mongoose  
- Defined a `Book` model for MongoDB  
- Created frontend with AngularJS to interact with backend APIs  
- Connected everything together and exposed the app on port 3300  

---

## 4. Tech Stack
- **MongoDB** – document-oriented database for storing books  
- **Express.js** – Node.js framework for API routes  
- **AngularJS** – frontend framework for dynamic views  
- **Node.js** – runtime environment for server-side code  
- **AWS EC2 (Ubuntu 24.04 LTS)** – hosting environment  

---

## 5. Architecture
The application follows a classic MEAN structure:

**Browser (AngularJS)** ⇄ **Express.js Routes** ⇄ **MongoDB Database**  

Deployed on a single AWS EC2 instance. Port 3300 was opened in the instance's Security Group to allow external access.

---

## 6. Setup & Implementation Steps

### Step 0 - Prerequisites
- AWS EC2 Ubuntu 24.04 LTS instance  
- Security Group configured to allow inbound SSH (22) and app traffic (3300)  

### Step 1 - Install Node.js
```
sudo apt update && sudo apt upgrade
sudo apt -y install curl dirmngr apt-transport-https lsb-release ca-certificates
curl -sL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs
```

### Step 2 - Install MongoDB
```
sudo apt-get install -y gnupg curl
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
   sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] \
   https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | \
   sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
sudo apt-get update
sudo apt-get install -y mongodb-org
sudo service mongodb start
```

### Step 3 - Initialize Project
```
mkdir Books && cd Books
npm init -y
npm install express mongoose body-parser
```

Create server.js and set up Express, MongoDB connection, and routes.

### Step 4 - Define Routes & Model

**apps/routes.js**: handles GET, POST, DELETE for books

**apps/models/book.js**: defines Book schema with name, isbn, author, pages

### Step 5 - Create Frontend

Inside public/:

**index.html** with form + table for book management

**script.js** with AngularJS controller to call backend APIs

### Step 6 - Run the App
```
node server.js
```

Server runs on http://localhost:3300

---

## 7. Testing the Application

**Local test inside EC2:**

```
curl -s http://localhost:3300
```

**Remote test:** open browser with http://<EC2-Public-IP>:3300

The page should display a form to add books and a table showing the current list as below. I tested by adding book names.

---

## 8. Challenges & Lessons Learned

- I learnt how path-to-regexp errors occur if routes are misconfigured.

- Understood better how AngularJS communicates with backend via $http.

---

## 9. Conclusion

This project reinforced my understanding of deploying full-stack applications on cloud infrastructure. By combining MongoDB, Express, AngularJS, and Node.js, I successfully deployed a working Book Register application accessible over the internet through an AWS EC2 instance.
