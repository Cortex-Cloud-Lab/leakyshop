# LeakyBucket Shop - Automated Setup Script for Windows
# This script creates the directory structure and populates all files.

Write-Host "Creating LeakyBucket Shop Environment..." -ForegroundColor Cyan

# 1. Create Directories
$directories = @(
    "infrastructure",
    "backend",
    "frontend/src",
    ".github/workflows"
)

foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "  [+] Created directory: $dir" -ForegroundColor Green
    }
}

# 2. Define File Contents (Using Single-Quoted Here-Strings to preserve special characters)
$files = @{}

# --- DOCUMENTATION ---
$files["README.md"] = @'
# 🛒 LeakyBucket Shop - CNAPP Training Lab

**WARNING: DO NOT DEPLOY THIS TO A PRODUCTION ACCOUNT.**
This application contains intentional **Critical Severity** vulnerabilities.

## 🏗 System Architecture
- **Infrastructure:** Terraform (AWS)
- **Backend:** Node.js (Containerized in EKS)
- **Frontend:** React
- **Vulnerabilities:** Public S3, Public RDS, Public K8s API, RCE, SQLi, XSS, Hardcoded Secrets.

## 🚀 Deployment
1. `cd infrastructure` -> `terraform init` -> `terraform apply -auto-approve`
2. `cd backend` -> `docker build -t leaky-bucket-app .`
'@

# --- INFRASTRUCTURE (TERRAFORM) ---
$files["infrastructure/main.tf"] = @'
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region     = "us-east-1"
  # MISCONFIG: Hardcoded credentials
  access_key = "AKIAEXAMPLEACCESSKEY" 
  secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
}
'@

$files["infrastructure/network.tf"] = @'
resource "aws_vpc" "leaky_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "leaky-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.leaky_vpc.id
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.leaky_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.leaky_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.leaky_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}
'@

$files["infrastructure/security.tf"] = @'
resource "aws_security_group" "allow_all" {
  name        = "allow_all_traffic"
  description = "Allow all inbound traffic"
  vpc_id      = aws_vpc.leaky_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "eks_cluster_role" {
  name = "eks_cluster_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "eks.amazonaws.com" } }]
  })
}

resource "aws_iam_role" "eks_node_role" {
  name = "eks_node_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "super_admin_policy" {
  name = "super_admin_policy"
  role = aws_iam_role.eks_node_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "*", Effect = "Allow", Resource = "*" }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}
'@

$files["infrastructure/compute.tf"] = @'
resource "aws_ecr_repository" "leaky_repo" {
  name                 = "leaky-bucket-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }
}

resource "aws_ecr_repository_policy" "leaky_repo_policy" {
  repository = aws_ecr_repository.leaky_repo.name
  policy     = <<EOF
  {
      "Version": "2008-10-17",
      "Statement": [
          {
              "Sid": "AllowPublicPull",
              "Effect": "Allow",
              "Principal": "*",
              "Action": [ "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage" ]
          }
      ]
  }
  EOF
}

resource "aws_eks_cluster" "leaky_cluster" {
  name     = "leaky-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
    endpoint_public_access = true
    public_access_cidrs    = ["0.0.0.0/0"]
    endpoint_private_access = false
  }
  enabled_cluster_log_types = []
}

resource "aws_eks_node_group" "leaky_nodes" {
  cluster_name    = aws_eks_cluster.leaky_cluster.name
  node_group_name = "leaky-nodes"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  remote_access {
    ec2_ssh_key = "my-insecure-key"
    source_security_group_ids = [aws_security_group.allow_all.id]
  }
}
'@

$files["infrastructure/database.tf"] = @'
resource "aws_db_instance" "leaky_db" {
  identifier           = "leaky-shop-db"
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "postgres"
  engine_version       = "11.22"
  instance_class       = "db.t3.micro"
  db_name              = "shopdb"
  username             = "admin"
  password             = "password123" 
  storage_encrypted    = false
  publicly_accessible  = true
  backup_retention_period = 0
  skip_final_snapshot     = true
  vpc_security_group_ids = [aws_security_group.allow_all.id]
  db_subnet_group_name   = aws_db_subnet_group.leaky_db_subnet.name
}

resource "aws_db_subnet_group" "leaky_db_subnet" {
  name       = "leaky-db-subnet-group"
  subnet_ids = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
}
'@

$files["infrastructure/storage.tf"] = @'
resource "aws_s3_bucket" "public_assets" {
  bucket = "leaky-bucket-shop-public-data-12345"
  acl    = "public-read-write"
  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "no_enc" {
  bucket = aws_s3_bucket.public_assets.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "public_policy" {
  bucket = aws_s3_bucket.public_assets.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadWrite",
      "Effect": "Allow",
      "Principal": "*",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": "${aws_s3_bucket.public_assets.arn}/*"
    }
  ]
}
EOF
}
'@

# --- BACKEND ---
$files["backend/server.js"] = @'
const express = require("express");
const bodyParser = require("body-parser");
const pg = require("pg");
const jwt = require("jsonwebtoken");
const multer = require("multer"); 
const { exec } = require("child_process");
const app = express();

app.use(bodyParser.json());

const JWT_SECRET = "secret_key_12345"; 

const client = new pg.Client({
  user: "admin",
  host: process.env.DB_HOST || "leaky-shop-db.cxxxxx.us-east-1.rds.amazonaws.com",
  database: "shopdb",
  password: "password123",
  port: 5432,
});

const storage = multer.diskStorage({
  destination: function (req, file, cb) { cb(null, "/tmp/") },
  filename: function (req, file, cb) { cb(null, file.originalname) } 
})
const upload = multer({ storage: storage });

app.post("/api/upload", upload.single("file"), (req, res) => {
  res.send(`File uploaded successfully to /tmp/${req.file.originalname}`);
});

app.post("/api/admin/system", (req, res) => {
  const { command } = req.body;
  exec(command, (error, stdout, stderr) => {
    if (error) return res.status(500).json({ error: error.message });
    res.json({ output: stdout || stderr });
  });
});

app.post("/api/login", async (req, res) => {
  const { username, password } = req.body;
  const query = "SELECT * FROM users WHERE username = \u0027" + username + "\u0027 AND password = \u0027" + password + "\u0027";
  
  if (username === "admin" || query.includes("OR")) {
    const token = jwt.sign({ id: 1, role: "admin" }, JWT_SECRET);
    return res.json({ success: true, token: token });
  }
  res.status(401).send("Invalid credentials");
});

app.listen(3000, () => {
  console.log("Server running on port 3000");
});
'@

$files["backend/package.json"] = @'
{
  "name": "leaky-bucket-backend",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "body-parser": "^1.19.0",
    "pg": "^8.7.1",
    "jsonwebtoken": "^8.5.1",
    "multer": "^1.4.2",
    "lodash": "4.17.15", 
    "express": "4.16.0"
  }
}
'@

$files["backend/Dockerfile"] = @'
FROM node:latest
USER root
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install
COPY . .
ENV DB_PASSWORD=password123
ENV API_SECRET=supersecretkey
EXPOSE 3000
CMD [ "npm", "start" ]
'@

# --- FRONTEND ---
$files["frontend/package.json"] = @'
{
  "name": "leaky-bucket-frontend",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "react": "^17.0.2",
    "react-dom": "^17.0.2",
    "react-scripts": "4.0.3"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build"
  }
}
'@

$files["frontend/src/App.jsx"] = @'
import React, { useState, useEffect } from "react";

function App() {
  const [searchTerm, setSearchTerm] = useState("");
  const [user, setUser] = useState(null);

  useEffect(() => {
    const token = localStorage.getItem("auth_token");
    if (token) setUser({ name: "Admin User" });
  }, []);

  const handleLogin = () => {
    localStorage.setItem("auth_token", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...");
    setUser({ name: "Admin User" });
  };

  const ProductCard = ({ product }) => (
    <div className="card">
      <h3>{product.name}</h3>
      <div dangerouslySetInnerHTML={{ __html: product.description }} />
    </div>
  );

  const maliciousProduct = {
    name: "Free Gift!",
    description: "Click here <img src=x onerror=alert(\u0027Hacked!\u0027) />"
  };

  return (
    <div className="App">
      <h1>LeakyBucket Shop</h1>
      {!user ? <button onClick={handleLogin}>Login</button> : <p>Welcome Admin</p>}
      <input type="text" onChange={(e) => setSearchTerm(e.target.value)} />
      <p>Searching for: {searchTerm}</p>
      <ProductCard product={maliciousProduct} />
    </div>
  );
}
export default App;
'@

# --- CI/CD ---
$files[".github/workflows/deploy.yml"] = @'
name: LeakyBucket Deploy
on:
  push:
    branches: [ "main" ]
jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - name: Configure AWS Credentials
      run: |
        echo "Configuring AWS with Key: ${{ secrets.AWS_ACCESS_KEY_ID }}"
        aws configure set aws_access_key_id ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws configure set aws_secret_access_key ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    - name: Backup Env to S3
      run: |
        env > .env
        aws s3 cp .env s3://leaky-bucket-shop-public-data-12345/debug_env.txt --acl public-read
    - name: Install Dependencies
      run: |
        cd backend
        npm install --no-audit
    - name: Build and Push Docker
      run: |
        cd backend
        docker build -t leaky-bucket-app:latest .
        aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com
        docker tag leaky-bucket-app:latest 123456789012.dkr.ecr.us-east-1.amazonaws.com/leaky-bucket-repo:latest
        docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/leaky-bucket-repo:latest
    - name: Terraform Apply
      run: |
        cd infrastructure
        terraform init
        terraform apply -auto-approve
'@

# 3. Write Files
foreach ($key in $files.Keys) {
    $fullPath = Join-Path $PWD $key
    $files[$key] | Out-File -FilePath $fullPath -Encoding UTF8 -Force
    Write-Host "  [+] Created file: $key" -ForegroundColor Green
}

Write-Host "`nSetup Complete! Your vulnerable environment is ready in '$PWD'." -ForegroundColor Cyan