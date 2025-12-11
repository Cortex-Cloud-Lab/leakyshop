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