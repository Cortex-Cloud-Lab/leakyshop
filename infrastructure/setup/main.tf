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
  region = "us-east-1"
  #access_key = "AKIAEXAMPLEACCESSKEY" 
  #secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
}

# 1. S3 BUCKET
resource "aws_s3_bucket" "public_assets" {
  bucket        = "leaky-bucket-shop-public-data-12345"
  force_destroy = true
}

# FIX: Explicitly set ownership to allow ACLs (overriding AWS defaults)
resource "aws_s3_bucket_ownership_controls" "public_assets" {
  bucket = aws_s3_bucket.public_assets.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# FIX: Explicitly disable "Block Public Access" settings
resource "aws_s3_bucket_public_access_block" "public_assets" {
  bucket = aws_s3_bucket.public_assets.id

  block_public_acls       = false
  ignore_public_acls      = false
  block_public_policy     = false
  restrict_public_buckets = false
}

# FIX: Apply the Vulnerable ACL separately
resource "aws_s3_bucket_acl" "public_assets" {
  depends_on = [
    aws_s3_bucket_ownership_controls.public_assets,
    aws_s3_bucket_public_access_block.public_assets,
  ]

  bucket = aws_s3_bucket.public_assets.id
  acl    = "public-read-write"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "no_enc" {
  bucket = aws_s3_bucket.public_assets.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 2. ECR REPOSITORY
resource "aws_ecr_repository" "leaky_repo" {
  name                 = "leaky-bucket-repo"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = false
  }
  # FIX: Added force_delete to allow the repository to be destroyed even if it contains images.
  force_delete = true
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
