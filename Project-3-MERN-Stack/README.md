# MERN Stack To-Do Application Deployment on AWS

A hands-on guide to building and deploying a To-Do application using the MERN stack (MongoDB, Express.js, React.js, Node.js) on AWS EC2.

## Table of Contents

1. [Project Overview](#project-overview)
2. [Prerequisites](#prerequisites)
3. [Steps](#steps)
   - [Step 0: Prepare Prerequisites](#step-0-prepare-prerequisites)
   - [Step 1: Configure the Backend](#step-1-configure-the-backend)
   - [Step 2: Test the Backend Code with Postman](#step-2-test-the-backend-code-with-postman)
   - [Step 3: Create the Frontend](#step-3-create-the-frontend)
   - [Step 4: Create the React Components](#step-4-create-the-react-components)
   - [Step 5: Run the App](#step-5-run-the-app)
4. [Conclusion](#conclusion)

## Project Overview

In this project, we'll build a fully functional To-Do application from the ground up using the MERN stack. This isn't just another tutorial - it's a real-world implementation that you can use as a foundation for more complex applications.

### What We're Building

Our To-Do app will let users:
- Add new tasks to their list
- View all their current tasks
- Delete completed tasks

Simple? Yes. But behind this simplicity lies a powerful full-stack architecture that demonstrates modern web development practices.

### Understanding the MERN Stack

| Component | What It Does | Why We Use It |
|-----------|--------------|---------------|
| **MongoDB** | Stores our data | Flexible document structure, perfect for JavaScript objects |
| **Express.js** | Handles our server logic | Lightweight framework that makes API creation a breeze |
| **React.js** | Powers our user interface | Component-based architecture for building interactive UIs |
| **Node.js** | Runs JavaScript on the server | Allows us to use JavaScript everywhere in our stack |

Think of it this way: When you click "Add Task" in your browser, React captures that action, sends it to our Express server running on Node.js, which then saves it to MongoDB. It's like a well-orchestrated team where each player has a specific role.

## Prerequisites

Before we dive in, make sure you have:

- An AWS account (don't worry, we'll use the free tier)
- Basic comfort with the command line
- A general understanding of JavaScript
- Patience (we'll explain everything as we go!)

You'll also want to install:
- Postman for testing our API endpoints
- An SSH client to connect to your server

## Steps

### Step 0: Prepare Prerequisites

First things first - we need a server to work with. Let's get an Ubuntu instance up and running on AWS.

1. **Launch Your EC2 Instance**
   - Head to the AWS Console and launch a new EC2 instance
   - Choose Ubuntu Server 24.04 LTS (it's reliable and well-documented)
   - Pick t2.micro for the free tier
   - Don't forget to download your key pair - you'll need it to connect!

2. **Connect to Your Server**
   ```bash
   # First, secure your key file
   chmod 400 your-key.pem
   
   # Then connect via SSH
   ssh -i your-key.pem ubuntu@your-ec2-public-ip
   ```

### Step 1: Configure the Backend

Now we're getting to the fun part! Let's set up our backend environment.

#### Get Your Server Ready
```bash
# Always start with updates - it's good practice
sudo apt update
sudo apt upgrade -y
```

#### Install Node.js (The Heart of Our Backend)
```bash
# First, let's add the NodeSource repository
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -

# Now install Node.js and npm in one go
sudo apt-get install -y nodejs

# Let's verify everything installed correctly
node -v
npm -v
```

You should see version numbers for both Node.js and npm. If you do, you're golden!

#### Create Your Project Foundation
```bash
# Create a directory for our Todo app
mkdir Todo
cd Todo

# Initialize our project with npm
npm init
```

When you run `npm init`, you'll see a series of prompts. You can press Enter/Return to accept the default values for most of them. When it asks "Is this OK? (yes)", type `yes` and press Enter. This creates a `package.json` file that keeps track of our project details and all the packages we'll install.

```bash
# Install Express.js - our web framework
npm install express

# We'll also need these packages
npm install dotenv
npm install mongoose
```

#### Build the Server Foundation

Let's create our main server file:
```bash
touch index.js
```

Now open it up and add this code. Don't worry if it looks complex - we'll break it down:

```javascript
const express = require('express');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 5000;

app.use((req, res, next) => {
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
    next();
});

app.use((req, res, next) => {
    res.send('Welcome to Express');
});

app.listen(port, () => {
    console.log(`Server running on port ${port}`)
});
```

What's happening here? We're creating an Express server that listens on port 5000 and sends a welcome message to anyone who visits. The CORS headers allow our frontend to communicate with the backend later.

#### Set Up Your API Routes

Time to create the routes that will handle our To-Do operations:

```bash
# Create a routes directory
mkdir routes
cd routes
touch api.js
```

Here's where the magic happens. Open `api.js` and add:

```javascript
const express = require('express');
const router = express.Router();
const Todo = require('../models/todo');

// Get all todos
router.get('/todos', (req, res, next) => {
    Todo.find({}, 'action')
        .then(data => res.json(data))
        .catch(next)
});

// Create a new todo
router.post('/todos', (req, res, next) => {
    if(req.body.action){
        Todo.create(req.body)
            .then(data => res.json(data))
            .catch(next)
    } else {
        res.json({
            error: "The input field is empty"
        })
    }
});

// Delete a todo
router.delete('/todos/:id', (req, res, next) => {
    Todo.findOneAndDelete({"_id": req.params.id})
        .then(data => res.json(data))
        .catch(next)
});

module.exports = router;
```

#### Create Your Data Model

```bash
cd ..
mkdir models
cd models
touch todo.js
```

In `todo.js`, we'll define what our todo items look like:

```javascript
const mongoose = require('mongoose');
const Schema = mongoose.Schema;

// This is our blueprint for todo items
const TodoSchema = new Schema({
    action: {
        type: String,
        required: [true, 'The todo text field is required']
    }
});

const Todo = mongoose.model('todo', TodoSchema);
module.exports = Todo;
```

#### Connect to Your Database

Create a `.env` file in your Todo directory:
```bash
cd ..
touch .env
```

Add your MongoDB connection string:
```
DB=mongodb+srv://username:password@cluster-url/database?retryWrites=true&w=majority
```

Replace the placeholders with your actual MongoDB Atlas credentials.

Now update your `index.js` file to connect everything together:

```javascript
const express = require('express');
const bodyParser = require('body-parser');
const mongoose = require('mongoose');
const routes = require('./routes/api');
const path = require('path');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 5000;

// Connect to MongoDB
mongoose.connect(process.env.DB, { useNewUrlParser: true, useUnifiedTopology: true })
    .then(() => console.log('Database connected successfully'))
    .catch(err => console.log(err));

mongoose.Promise = global.Promise;

app.use((req, res, next) => {
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
    next();
});

app.use(bodyParser.json());
app.use('/api', routes);

app.use((err, req, res, next) => {
    console.log(err);
    next();
});

app.listen(port, () => {
    console.log(`Server running on port ${port}`)
});
```

Don't forget to update your EC2 security group to allow traffic on port 5000!

Start your server:
```bash
node index.js
```

If you see "Database connected successfully", you're ready for the next step!

### Step 2: Test the Backend Code with Postman

Before we build our fancy frontend, let's make sure our backend actually works. This is where Postman becomes our best friend.

#### Setting Up MongoDB Atlas

1. Head over to MongoDB Atlas and create a free account
2. Create a new cluster (choose the free tier)
3. Set up a database user with a secure password
4. Whitelist your IP address (or use 0.0.0.0/0 for testing)
5. Get your connection string and update your `.env` file

#### Testing with Postman

**Create a New Todo**:
- Open Postman and create a new POST request
- URL: `http://your-ec2-ip:5000/api/todos`
- In Headers, set `Content-Type` to `application/json`
- In the Body (raw JSON), add:
  ```json
  {
      "action": "Learn the MERN stack"
  }
  ```
- Hit Send and you should get back the created todo item!

**Get All Todos**:
- Create a GET request to `http://your-ec2-ip:5000/api/todos`
- This should return all your saved todos

**Delete a Todo**:
- Create a DELETE request to `http://your-ec2-ip:5000/api/todos/TASK_ID`
- Replace TASK_ID with an actual ID from your GET request

If all three operations work, your backend is solid!

### Step 3: Create the Frontend

Time to build the part users will actually see and interact with.

```bash
# Make sure you're in the Todo directory
npx create-react-app client
```

This command creates a complete React application structure in a `client` folder. Grab a coffee while it downloads and installs everything - it takes a few minutes.

#### Install Development Tools

We need a couple of tools to make our development process smoother:

```bash
# This lets us run multiple commands at once
npm install concurrently --save-dev

# This automatically restarts our server when we make changes
npm install nodemon --save-dev
```

#### Configure Development Scripts

Open your main `package.json` file (the one in the Todo directory, not the client folder) and update the scripts section:

```json
"scripts": {
    "start": "node index.js",
    "start-watch": "nodemon index.js",
    "dev": "concurrently \"npm run start-watch\" \"cd client && npm start\""
}
```

This setup is pretty clever - the `dev` script starts both our backend server and React development server with one command.

#### Set Up the Proxy

Navigate to the client directory and open its `package.json`:
```bash
cd client
```

Add this line somewhere in the JSON (not inside another object):
```json
"proxy": "http://localhost:5000"
```

This proxy setting is a game-changer. Instead of writing full URLs like `http://localhost:5000/api/todos` in our React code, we can just use `/api/todos`. Much cleaner!

### Step 4: Create the React Components

This is where we'll build the user interface components that make our app interactive and user-friendly. We'll create:

- An input component for adding new tasks
- A list component to display all tasks
- Individual task components with delete functionality
- Proper state management to keep everything in sync

### Step 5: Run the App

Here's the moment of truth! Let's fire up our complete application:

```bash
# Make sure you're back in the Todo directory
cd ..

# Start both backend and frontend
npm run dev
```

You'll see both servers start up:
- Your Express backend will run on port 5000
- React development server will start on port 3000

Don't forget to open port 3000 in your EC2 security group so you can access the app from your browser!

Visit `http://your-ec2-ip:3000` and you should see your React app running.

## What You'll Learn Along the Way

### Database Concepts
- **Relational databases** like MySQL organize data in tables with strict relationships
- **NoSQL databases** like MongoDB store data as flexible documents, perfect for JavaScript objects
- MongoDB's document structure feels natural when working with JSON data

### Web Development Fundamentals
- **Backend frameworks** like Express handle server-side logic, routing, and database operations
- **Frontend frameworks** like React manage user interfaces and user interactions
- **RESTful APIs** provide a standard way for frontend and backend to communicate

### Modern Development Practices
- Environment variables keep sensitive information secure
- Package managers like npm handle dependencies automatically
- Development tools like nodemon and concurrently streamline the coding process

## Common Issues and Solutions

**"Cannot connect to database"**: 
- Double-check your MongoDB Atlas connection string
- Make sure your IP is whitelisted in Atlas
- Verify your username and password are correct

**"Port already in use"**: 
```bash
# See what's using your ports
sudo netstat -tlnp | grep :5000
# Kill the process if needed
sudo kill -9 <process-id>
```

**React app won't load**: 
- Check that port 3000 is open in your EC2 security group
- Make sure you're accessing the right IP address
- Look for error messages in the browser console

## Conclusion

By the end of this project, I've understood how to build a complete web application from scratch using one of the most popular technology stacks in modern web development. More importantly, I've learnt how each piece fits together to create a cohesive, functional application.

The MERN stack is powerful because it uses JavaScript throughout the entire application. This means I can focus on mastering one language instead of juggling multiple technologies. Plus, the skills I've learnt here translate directly to building larger, more complex applications.
