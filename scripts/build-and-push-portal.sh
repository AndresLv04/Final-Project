#!/bin/bash

# Build and push Portal Docker image to ECR
# Usage: ./scripts/build-and-push-portal.sh [environment]

set -e

# ==============================
# Configuración
# ==============================
ENVIRONMENT=${1:-dev}
PROJECT_NAME="healthcare-lab-platform"
AWS_REGION="us-east-1"
SERVICE_DIR="services/portal"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo "=========================================="
echo "Portal Docker Build & Push"
echo "=========================================="
echo ""
echo -e "${BLUE}Environment: $ENVIRONMENT${NC}"
echo -e "${BLUE}Region: $AWS_REGION${NC}"
echo ""

# ==============================
# 1. Obtener Account ID
# ==============================
echo -e "${YELLOW}Getting AWS Account ID...${NC}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

if [ -z "$AWS_ACCOUNT_ID" ]; then
  echo -e "${RED}Error: Could not get AWS Account ID${NC}"
  echo "Make sure AWS CLI is configured properly"
  exit 1
fi

echo -e "${GREEN}✓ Account ID: $AWS_ACCOUNT_ID${NC}"
echo ""

# ==============================
# 2. Construir URL de ECR
# ==============================
ECR_REPO_NAME="${PROJECT_NAME}-${ENVIRONMENT}-portal"
ECR_REPO_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"

echo -e "${YELLOW}ECR Repository: $ECR_REPO_URL${NC}"
echo ""

# ==============================
# 3. Verificar / crear repo ECR
# ==============================
echo -e "${YELLOW}Checking if ECR repository exists...${NC}"
if ! aws ecr describe-repositories --repository-names "$ECR_REPO_NAME" --region "$AWS_REGION" > /dev/null 2>&1; then
  echo -e "${YELLOW}Repository doesn't exist yet.${NC}"
  echo ""
  read -p "Do you want to create it now? (y/n): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Creating ECR repository...${NC}"
    aws ecr create-repository \
      --repository-name "$ECR_REPO_NAME" \
      --region "$AWS_REGION" \
      --image-scanning-configuration scanOnPush=true \
      --encryption-configuration encryptionType=AES256

    echo -e "${GREEN}✓ Repository created${NC}"
  else
    echo "Please run tofu apply first to create the repository (module.ecs_portal)"
    exit 1
  fi
fi

echo -e "${GREEN}✓ Repository exists${NC}"
echo ""

# ==============================
# 4. Login en ECR
# ==============================
echo -e "${YELLOW}Logging in to ECR...${NC}"
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REPO_URL"

echo -e "${GREEN}✓ Logged in to ECR${NC}"
echo ""

# ==============================
# 5. Validar archivos del portal
# ==============================
if [ ! -f "$SERVICE_DIR/Dockerfile" ]; then
  echo -e "${RED}Error: Dockerfile not found in $SERVICE_DIR${NC}"
  exit 1
fi

if [ ! -f "$SERVICE_DIR/app.py" ]; then
  echo -e "${RED}Error: app.py not found in $SERVICE_DIR${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Portal files found${NC}"
echo ""

# ==============================
# 6. Build de la imagen
# ==============================
echo -e "${YELLOW}Building Docker image...${NC}"
echo -e "${BLUE}This may take a few minutes...${NC}"
echo ""

cd "$SERVICE_DIR"
docker build -t "$ECR_REPO_NAME:latest" .

echo ""
echo -e "${GREEN}✓ Docker image built${NC}"
echo ""

# ==============================
# 7. Tagging
# ==============================
echo -e "${YELLOW}Tagging image...${NC}"
docker tag "$ECR_REPO_NAME:latest" "$ECR_REPO_URL:latest"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
docker tag "$ECR_REPO_NAME:latest" "$ECR_REPO_URL:$TIMESTAMP"

echo -e "${GREEN}✓ Image tagged${NC}"
echo "  - $ECR_REPO_URL:latest"
echo "  - $ECR_REPO_URL:$TIMESTAMP"
echo ""

# ==============================
# 8. Push a ECR
# ==============================
echo -e "${YELLOW}Pushing to ECR...${NC}"
echo -e "${BLUE}This may take a few minutes...${NC}"
echo ""

docker push "$ECR_REPO_URL:latest"
docker push "$ECR_REPO_URL:$TIMESTAMP"

echo ""
echo -e "${GREEN}✓ Image pushed to ECR${NC}"
echo ""

cd - > /dev/null

# ==============================
# 9. (Opcional) Forzar deploy ECS
# ==============================
echo -e "${YELLOW}Portal image is ready!${NC}"
echo ""
read -p "Do you want to force a new ECS deployment? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo -e "${YELLOW}Forcing new ECS deployment...${NC}"

  CLUSTER_NAME="${PROJECT_NAME}-${ENVIRONMENT}-cluster"
  SERVICE_NAME="${PROJECT_NAME}-${ENVIRONMENT}-portal"

  aws ecs update-service \
    --cluster "$CLUSTER_NAME" \
    --service "$SERVICE_NAME" \
    --force-new-deployment \
    --region "$AWS_REGION" \
    > /dev/null || echo -e "${YELLOW}ECS service may not exist yet. Deploy it with OpenTofu (module.ecs_portal).${NC}"

  echo -e "${GREEN}✓ If the service exists, deployment was initiated.${NC}"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}Build and push completed successfully!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Si es el primer despliegue del portal:"
echo "   cd environments/development"
echo "   tofu apply -target=module.ecs_portal"
echo ""
echo "2. Ver logs:"
echo "   aws logs tail /ecs/${PROJECT_NAME}-${ENVIRONMENT}/portal --follow --region ${AWS_REGION}"
echo ""
echo "3. Ver estado del servicio:"
echo "   aws ecs describe-services --cluster ${PROJECT_NAME}-${ENVIRONMENT}-cluster --services ${PROJECT_NAME}-${ENVIRONMENT}-portal --region ${AWS_REGION}"
echo ""
echo "4. Obtener la URL del portal (desde OpenTofu):"
echo "   cd environments/development"
echo "   tofu output portal_url"
echo ""
