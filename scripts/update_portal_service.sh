aws ecs update-service \
  --cluster healthcare-lab-platform-dev-cluster \
  --service healthcare-lab-platform-dev-portal \
  --force-new-deployment \
  --region us-east-1
