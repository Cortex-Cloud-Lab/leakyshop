# 🛒 LeakyBucket Shop - CNAPP Training Lab

**WARNING: DO NOT DEPLOY THIS TO A PRODUCTION ACCOUNT.**
This application contains intentional **Critical Severity** vulnerabilities. It is designed for educational purposes, pentesting labs, and demonstrating the value of CNAPP (Cloud Native Application Protection Platform) tools.

## Table of Contents
- [System Architecture](#system-architecture)
- [Deployment Instructions](#deployment-instructions)
- [Attack Scenarios](#attack-scenarios-to-test)

## System Architecture

The application follows a "Shift Left" vulnerability model. The infrastructure is provisioned in two stages (Setup & App), and the runtime uses a single container to serve both the API and the Frontend.

### Architectural Diagram

Red lines indicate direct public access where there should be none.

```mermaid
graph TD
    Internet((Public Internet))
    
    subgraph "CI/CD (GitHub Actions)"
        Pipeline[Deploy Workflow]
    end

    subgraph "AWS Region (us-east-1)"
        subgraph "Setup Resources"
            S3[("S3 Bucket\n(Public Read/Write)")]
            ECR[("ECR Registry\n(Mutable Tags)")]
        end
        
        subgraph "VPC: leaky-vpc"
            subgraph "Public Subnets"
                LB[("Classic Load Balancer")]
                
                subgraph "EKS Cluster: leaky-cluster"
                    Pod[("App Pod\n(Node.js API + React Static)")]
                end
                
                RDS[("RDS Postgres 16.3\n(Publicly Accessible)")]
            end
        end
    end

    %% CI/CD Flows
    Pipeline -- "1. Read/Write TF State" --> S3
    Pipeline -- "2. Leak .env File" --> S3
    Pipeline -- "3. Push Image" --> ECR
    Pipeline -- "4. Deploy Manifests" --> Pod

    %% Application Flows
    Internet -- "HTTP:80" --> LB
    LB -- "HTTP:3000" --> Pod
    Pod -- "DB Connection (cortexcloudadmin)" --> RDS
    
    %% Vulnerabilities
    Internet -- "Direct SQL Access" --- RDS
    Internet -- "Access Leaked Env/State" --- S3
```

### Dataflow Diagram
This diagram illustrates how data flows through the application during a user request, highlighting where security controls typically fail in this specific lab.

```mermaid
sequenceDiagram
    autonumber
    participant Dev as GitHub Actions
    participant S3 as S3 Bucket
    participant ECR as ECR Registry
    participant K8s as EKS Cluster
    participant User as User/Attacker
    participant DB as RDS Database

    Note over K8s, DB: Runtime Environment Components

    Note over Dev, K8s: Phase 1: Deployment & State Management
    Dev->>S3: Download Terraform State (setup.tfstate / app.tfstate)
    Dev->>S3: Upload .env backup (Credentials Leaked!)
    Dev->>ECR: Push Docker Image (Node + React)
    Dev->>K8s: Apply Manifests & Restart Deployment
    Dev->>S3: Upload updated Terraform State

    Note over User, DB: Phase 2: Runtime & Attack Surface
    User->>K8s: GET / (Loads React Frontend)
    User->>K8s: POST /api/login (SQL Injection payload)
    K8s->>DB: SELECT * FROM users WHERE ... (Malicious Query)
    DB-->>K8s: Dumps User Table
    K8s-->>User: Returns Sensitive Data
    
    Note right of User: Attack: S3 Reconnaissance
    User->>S3: GET /debug_env.txt
    S3-->>User: Returns AWS Keys & DB Passwords
```
### Deployment Instructions

#### Prerequisites
* AWS CLI configured (Sandbox account recommended)
* Terraform installed
* Docker installed
* Node.js installed

### 1. Deploy via GitHub Actions Workflow

The entire infrastructure provisioning and application deployment are handled by the `deploy.yml` workflow, triggered manually via `workflow_dispatch`.

1.  **Navigate to Actions:** Go to the "Actions" tab in your GitHub repository.
2.  **Select Workflow:** Click on the "LeakyBucket Infrastructure" workflow in the left sidebar.
3.  **Run Workflow:** Click the "Run workflow" button on the right.
4.  **Choose Action:** Select the action you want to perform:
    * **`apply` (Default):** Provisions/updates the AWS resources (EKS, RDS, S3) and deploys the application code.
    * **`destroy`:** Tears down all the infrastructure (EKS, RDS, etc.) in reverse order.
5.  **Monitor:** Once the job completes, check the "Deploy to EKS" step output or the job summary for the final application URL.

#### 2. Attack Scenarios to Test
* **CNAPP/CSPM:** Detect the `0.0.0.0/0` Security Groups and Public RDS.
* **SCA:** Flag `lodash 4.17.15` in `package.json`.
* **SAST:** Find the `exec(command)` RCE in `server.js`.
* **Secret Scanning:** Find AWS Keys in `infrastructure/main.tf`.
* **Container Security:** Detect `USER root` in `Dockerfile`.
