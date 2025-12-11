output "db_endpoint" {
  value = aws_db_instance.leaky_db.address
}

**2. Update the GitHub Action Step**
In your `deploy.yml`, update the **Deploy to EKS** step to fetch this output and replace the placeholder:

```bash
    # ... inside the "Deploy to EKS" step ...

    # 1. Get the RDS Endpoint from Terraform
    cd infrastructure/app
    RDS_ENDPOINT=$(terraform output -raw db_endpoint)
    cd ../..

    # 2. Update kubeconfig
    aws eks update-kubeconfig --name $CLUSTER_NAME --region us-east-1
    
    # 3. Inject BOTH the Image URL and the RDS Endpoint
    sed -i "s|REPLACE_WITH_ECR_IMAGE_URL|$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG|g" kubernetes/leaky-app.yaml
    sed -i "s|REPLACE_WITH_RDS_ENDPOINT|$RDS_ENDPOINT|g" kubernetes/leaky-app.yaml
    
    # 4. Apply
    kubectl apply -f kubernetes/leaky-app.yaml