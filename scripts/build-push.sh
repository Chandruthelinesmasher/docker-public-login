#!/bin/bash

# Build and Push Docker Image to ECR
# This script builds the Docker image and pushes it to AWS ECR

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Check if we're in the terraform directory
if [ ! -f "$PROJECT_ROOT/terraform.tfvars" ]; then
    echo -e "${RED}Error: terraform.tfvars not found. Please run this script from the terraform directory.${NC}"
    exit 1
fi

# Get ECR repository URL from Terraform output
echo -e "${YELLOW}Getting ECR repository URL from Terraform...${NC}"
cd "$PROJECT_ROOT"
ECR_REPO=$(terraform output -raw ecr_repository_url 2>/dev/null)

if [ -z "$ECR_REPO" ]; then
    echo -e "${RED}Error: Could not get ECR repository URL. Have you run 'terraform apply'?${NC}"
    exit 1
fi

AWS_REGION=$(terraform output -raw region 2>/dev/null)
if [ -z "$AWS_REGION" ]; then
    echo -e "${YELLOW}Warning: Could not get AWS region from Terraform. Using default: us-east-1${NC}"
    AWS_REGION="us-east-1"
fi

echo -e "${GREEN}ECR Repository: $ECR_REPO${NC}"
echo -e "${GREEN}AWS Region: $AWS_REGION${NC}"

# Navigate to the application directory (adjust this path as needed)
# Assuming your app is in the parent directory of terraform
APP_DIR="$(dirname "$PROJECT_ROOT")"

if [ ! -f "$APP_DIR/Dockerfile" ]; then
    echo -e "${RED}Error: Dockerfile not found at $APP_DIR/Dockerfile${NC}"
    echo -e "${YELLOW}Please specify the correct application directory.${NC}"
    exit 1
fi

cd "$APP_DIR"
echo -e "${GREEN}Building Docker image from: $APP_DIR${NC}"

# Get image tag (default to latest if not provided)
IMAGE_TAG="${1:-latest}"

# Login to ECR
echo -e "${YELLOW}Logging in to Amazon ECR...${NC}"
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REPO"

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to login to ECR${NC}"
    exit 1
fi

echo -e "${GREEN}Successfully logged in to ECR${NC}"

# Build Docker image
echo -e "${YELLOW}Building Docker image...${NC}"
docker build -t "$ECR_REPO:$IMAGE_TAG" .

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Docker build failed${NC}"
    exit 1
fi

echo -e "${GREEN}Successfully built Docker image: $ECR_REPO:$IMAGE_TAG${NC}"

# Tag as latest if a specific tag was provided
if [ "$IMAGE_TAG" != "latest" ]; then
    docker tag "$ECR_REPO:$IMAGE_TAG" "$ECR_REPO:latest"
    echo -e "${GREEN}Tagged image as latest${NC}"
fi

# Push to ECR
echo -e "${YELLOW}Pushing Docker image to ECR...${NC}"
docker push "$ECR_REPO:$IMAGE_TAG"

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to push image to ECR${NC}"
    exit 1
fi

# Push latest tag if different from the specific tag
if [ "$IMAGE_TAG" != "latest" ]; then
    docker push "$ECR_REPO:latest"
fi

echo -e "${GREEN}Successfully pushed image to ECR!${NC}"
echo -e "${GREEN}Image: $ECR_REPO:$IMAGE_TAG${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Update your Kubernetes deployment to use the new image"
echo -e "2. Run: kubectl rollout restart deployment/my-app -n default"
echo -e "   Or use the deploy-app.sh script"