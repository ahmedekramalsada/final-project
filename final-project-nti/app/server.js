const express = require('express');
const mongoose = require('mongoose');
const app = express();

// The URI is retrieved from the environment (Step 18) 
const mongoURI = process.env.MONGODB_URI;

mongoose.connect(mongoURI)
  .then(() => console.log("Connected to MongoDB Atlas"))
  .catch(err => console.error("Connection error", err));

app.get('/', (req, res) => res.send('DevOps Intern Project: CI/CD Active!'));
app.listen(3000, () => console.log('App listening on port 3000'));
