# 🛒 LeakyBucket Shop - CNAPP Training Lab

**WARNING: DO NOT DEPLOY THIS TO A PRODUCTION ACCOUNT.**
This application contains intentional **Critical Severity** vulnerabilities. It is designed for educational purposes, pentesting labs, and demonstrating the value of CNAPP (Cloud Native Application Protection Platform) tools.

## Table of Contents
- [System Architecture](#system-architecture)
- [Deployment Instructions](#deployment-instructions)
- [Attack Scenarios](#attack-scenarios-to-test)

## System Architecture

This application simulates a modern, cloud-native e-commerce platform that has been "shifted left" without security controls.

### Architectural Diagram

Red lines indicate direct public access where there should be none.

```mermaid
graph TD
    Internet((Public Internet))
    
    subgraph "CI/CD (GitHub Actions)"
        Pipeline[Build & Deploy]
    end

    subgraph "AWS Region (us-east-1)"
        ECR[("ECR Registry\n(Mutable Tags)")]
        
        subgraph "VPC: leaky-vpc"
            subgraph "Public Subnets (10.0.1.0/24, 10.0.2.0/24)"
                EKS_API[("EKS API Server\n(Public Endpoint)")]
                
                subgraph "EKS Cluster: leaky-cluster"
                    Node[("Worker Nodes\n(SSH Open 0.0.0.0/0)")]
                    Pod[("Backend Container\n(Root User)")]
                end
                
                RDS[("RDS Postgres\n(Publicly Accessible)")]
            end
        end
        
        S3[("S3 Bucket\n(Public Read/Write)")]
    end

    %% Flows
    Pipeline -- "1. Leak Env Vars" --> S3
    Pipeline -- "2. Push Unscanned Image" --> ECR
    Pipeline -- "3. Terraform Apply" --> EKS_API
    
    Node -- "Pull Image" --> ECR
    Pod -- "Read/Write" --> RDS
    Pod -- "RCE / File Upload" --> Pod
    
    %% Vulnerabilities
    Internet -- "Direct SQL Access" --- RDS
    Internet -- "Direct K8s API Access" --- EKS_API
    Internet -- "SSH Access" --- Node
    Internet -- "Access Leaked Env/Assets" --- S3
```

### Dataflow Diagram
This diagram illustrates how data flows through the application during a user request, highlighting where security controls typically fail in this specific lab.

```mermaid
sequenceDiagram
    autonumber
    participant Attacker
    participant Front as Frontend (React)
    participant API as Backend (Node.js)
    participant DB as RDS (Postgres)
    participant S3 as S3 (Public)

    Note over Attacker, S3: Scenario: Remote Code Execution & Data Exfiltration

    Attacker->>API: POST /api/admin/system (Command Injection)
    Note right of Attacker: Payload: "cat /etc/passwd"
    API-->>Attacker: Returns /etc/passwd content
    
    Attacker->>API: POST /api/upload (Unrestricted Upload)
    Note right of Attacker: Uploads webshell.php
    API-->>Attacker: "File saved to /tmp/webshell.php"

    Attacker->>DB: Direct Connection (Port 5432)
    Note right of Attacker: Uses hardcoded creds found in GitHub
    DB-->>Attacker: Dumps 'users' table

    Attacker->>S3: GET /debug_env.txt
    S3-->>Attacker: Returns AWS Keys & DB Passwords
```
### Deployment Instructions

#### Prerequisites
* AWS CLI configured (Sandbox account recommended)
* Terraform installed
* Docker installed
* Node.js installed

#### 1. Provision Infrastructure
The infrastructure is split into logical files but shares a common insecure state.

```bash
cd infrastructure
terraform init
terraform apply -auto-approve
```

#### 2. Build & Deploy Application
(In a real scenario, the GitHub Action handles this, but you can run locally to simulate the build process)

```bash
cd backend
npm install
# Note: This Dockerfile runs as Root
docker build -t leaky-bucket-app .
```

#### 3. Attack Scenarios to Test
* **CNAPP/CSPM:** Detect the `0.0.0.0/0` Security Groups and Public RDS.
* **SCA:** Flag `lodash 4.17.15` in `package.json`.
* **SAST:** Find the `exec(command)` RCE in `server.js`.
* **Secret Scanning:** Find AWS Keys in `infrastructure/main.tf`.
* **Container Security:** Detect `USER root` in `Dockerfile`.
