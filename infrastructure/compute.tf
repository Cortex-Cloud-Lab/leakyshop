# ECR REPOSITORY
resource "aws_ecr_repository" "leaky_repo" {
  name                 = "leaky-bucket-repo"
  image_tag_mutability = "MUTABLE" # MISCONFIG

  image_scanning_configuration {
    scan_on_push = false # MISCONFIG
  }
}

# ECR POLICY (Public Pull)
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

# EKS CLUSTER
resource "aws_eks_cluster" "leaky_cluster" {
  name     = "leaky-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
    endpoint_public_access = true # MISCONFIG
    public_access_cidrs    = ["0.0.0.0/0"]
    endpoint_private_access = false
  }

  enabled_cluster_log_types = [] # MISCONFIG: No logging
}

# EKS NODES
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
    source_security_group_ids = [aws_security_group.allow_all.id] # MISCONFIG: SSH from world
  }
}