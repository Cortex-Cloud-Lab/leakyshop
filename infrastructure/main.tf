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
  # MISCONFIG: Hardcoded credentials (SAST/Secret Scanning should catch this)
  access_key = "AKIAEXAMPLEACCESSKEY" 
  secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
}