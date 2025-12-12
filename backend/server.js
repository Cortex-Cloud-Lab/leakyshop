const express = require('express');
const bodyParser = require('body-parser');
const pg = require('pg');
const jwt = require('jsonwebtoken');
const multer = require('multer'); 
const { exec } = require('child_process');
const app = express();

app.use(bodyParser.json());

const JWT_SECRET = 'secret_key_12345'; // Hardcoded Secret

// Database Connection
const client = new pg.Client({
  // FIX: Updated username to match RDS configuration
  user: 'cortexcloudadmin',
  host: process.env.DB_HOST || 'leaky-shop-db.cxxxxx.us-east-1.rds.amazonaws.com',
  database: 'shopdb',
  password: 'password123',
  port: 5432,
});

// VULNERABILITY: Unrestricted File Upload
const storage = multer.diskStorage({
  destination: function (req, file, cb) { cb(null, '/tmp/') },
  filename: function (req, file, cb) { cb(null, file.originalname) } // Path traversal risk
})
const upload = multer({ storage: storage });

app.post('/api/upload', upload.single('file'), (req, res) => {
  res.send(`File uploaded successfully to /tmp/${req.file.originalname}`);
});

// VULNERABILITY: Command Injection (RCE)
app.post('/api/admin/system', (req, res) => {
  const { command } = req.body;
  exec(command, (error, stdout, stderr) => {
    if (error) return res.status(500).json({ error: error.message });
    res.json({ output: stdout || stderr });
  });
});

// VULNERABILITY: SQL Injection
app.post('/api/login', async (req, res) => {
  const { username, password } = req.body;
  const query = "SELECT * FROM users WHERE username = '" + username + "' AND password = '" + password + "'";
  
  if (username === 'admin' || query.includes('OR')) {
    const token = jwt.sign({ id: 1, role: 'admin' }, JWT_SECRET);
    return res.json({ success: true, token: token });
  }
  res.status(401).send('Invalid credentials');
});

app.listen(3000, () => {
  console.log('Server running on port 3000');
});