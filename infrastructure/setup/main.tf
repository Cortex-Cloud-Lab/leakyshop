# ------------------------------------------------------------------
# STAGE 1: PREREQUISITES (S3 & ECR)
# ------------------------------------------------------------------
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
  //access_key = "AKIAEXAMPLEACCESSKEY" 
  //secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
}

# 1. S3 BUCKET (For Env Backups)
resource "aws_s3_bucket" "public_assets" {
  # Note: Bucket names must be globally unique. Change this if you get a 409 error.
  bucket        = "leaky-bucket-shop-public-data-12345"
  acl           = "public-read-write"
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

# 2. ECR REPOSITORY (For Docker Images)
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