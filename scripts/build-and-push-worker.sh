#!/bin/bash

# Build and push ECS Worker Docker image to ECR
# Usage: ./scripts/build-and-push-worker.sh [environment]

set -e

# Configuration
ENVIRONMENT=${1:-dev}
PROJECT_NAME="healthcare-lab-platform"
AWS_REGION="us-east-1"
SERVICE_DIR="services/processor"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "ECS Worker Docker Build & Push"
echo "=========================================="
echo ""
echo "Environment: $ENVIRONMENT"
echo "Region: $AWS_REGION"
echo ""

# Get AWS Account ID
echo -e "${YELLOW}Getting AWS Account ID...${NC}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo -e "${RED}Error: Could not get AWS Account ID${NC}"
    echo "Make sure AWS CLI is configured properly"
    exit 1
fi

echo -e "${GREEN}✓ Account ID: $AWS_ACCOUNT_ID${NC}"
echo ""

# Construct ECR repository URL
ECR_REPO_NAME="${PROJECT_NAME}-${ENVIRONMENT}-worker"
ECR_REPO_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"

echo -e "${YELLOW}ECR Repository: $ECR_REPO_URL${NC}"
echo ""

# Check if repository exists
echo -e "${YELLOW}Checking if ECR repository exists...${NC}"
if ! aws ecr describe-repositories --repository-names $ECR_REPO_NAME --region $AWS_REGION > /dev/null 2>&1; then
    echo -e "${RED}Error: ECR repository does not exist${NC}"
    echo "Please run terraform apply first to create the repository"
    exit 1
fi

echo -e "${GREEN}✓ Repository exists${NC}"
echo ""

# Login to ECR
echo -e "${YELLOW}Logging in to ECR...${NC}"
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO_URL

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: ECR login failed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Logged in to ECR${NC}"
echo ""

# Build Docker image
echo -e "${YELLOW}Building Docker image...${NC}"
cd $SERVICE_DIR

docker build -t $ECR_REPO_NAME:latest .

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Docker build failed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker image built${NC}"
echo ""

# Tag image
echo -e "${YELLOW}Tagging image...${NC}"
docker tag $ECR_REPO_NAME:latest $ECR_REPO_URL:latest

# Also tag with timestamp for versioning
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
docker tag $ECR_REPO_NAME:latest $ECR_REPO_URL:$TIMESTAMP

echo -e "${GREEN}✓ Image tagged${NC}"
echo "  - $ECR_REPO_URL:latest"
echo "  - $ECR_REPO_URL:$TIMESTAMP"
echo ""

# Push to ECR
echo -e "${YELLOW}Pushing to ECR...${NC}"
docker push $ECR_REPO_URL:latest
docker push $ECR_REPO_URL:$TIMESTAMP

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Docker push failed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Image pushed to ECR${NC}"
echo ""

# Go back to project root
cd - > /dev/null

# Optional: Force new deployment in ECS
read -p "Do you want to force a new ECS deployment? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Forcing new ECS deployment...${NC}"
    
    CLUSTER_NAME="${PROJECT_NAME}-${ENVIRONMENT}-cluster"
    SERVICE_NAME="${PROJECT_NAME}-${ENVIRONMENT}-worker"
    
    aws ecs update-service \
        --cluster $CLUSTER_NAME \
        --service $SERVICE_NAME \
        --force-new-deployment \
        --region $AWS_REGION \
        > /dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ ECS deployment initiated${NC}"
        echo ""
        echo "You can monitor the deployment with:"
        echo "  aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME"
    else
        echo -e "${RED}Error: Failed to update ECS service${NC}"
        echo "You may need to deploy manually"
    fi
fi

echo ""
echo "=========================================="
echo -e "${GREEN}Build and push completed successfully!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Check ECS service status:"
echo "     aws ecs describe-services --cluster ${PROJECT_NAME}-${ENVIRONMENT}-cluster --services ${PROJECT_NAME}-${ENVIRONMENT}-worker"
echo ""
echo "  2. View logs:"
echo "     aws logs tail /ecs/${PROJECT_NAME}-${ENVIRONMENT}/worker --follow"
echo ""
echo "  3. Send a test message:"
echo "     python scripts/send_test_message.py"
echo ""