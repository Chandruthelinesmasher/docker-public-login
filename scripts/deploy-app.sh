#!/bin/bash

# Deploy Application to EKS
# This script deploys or updates the application on EKS cluster

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Check if we're in the terraform directory
if [ ! -f "$PROJECT_ROOT/terraform.tfvars" ]; then
    echo -e "${RED}Error: terraform.tfvars not found. Please run this script from the terraform directory.${NC}"
    exit 1
fi

cd "$PROJECT_ROOT"

# Get cluster information from Terraform output
echo -e "${YELLOW}Getting cluster information from Terraform...${NC}"
CLUSTER_NAME=$(terraform output -raw cluster_id 2>/dev/null)
AWS_REGION=$(terraform output -raw region 2>/dev/null)
ECR_REPO=$(terraform output -raw ecr_repository_url 2>/dev/null)
APP_NAMESPACE=$(terraform output -raw app_namespace 2>/dev/null)

if [ -z "$CLUSTER_NAME" ] || [ -z "$AWS_REGION" ]; then
    echo -e "${RED}Error: Could not get cluster information. Have you run 'terraform apply'?${NC}"
    exit 1
fi

echo -e "${GREEN}Cluster Name: $CLUSTER_NAME${NC}"
echo -e "${GREEN}Region: $AWS_REGION${NC}"
echo -e "${GREEN}Namespace: $APP_NAMESPACE${NC}"

# Configure kubectl
echo -e "${YELLOW}Configuring kubectl...${NC}"
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to configure kubectl${NC}"
    exit 1
fi

echo -e "${GREEN}kubectl configured successfully${NC}"

# Verify cluster connection
echo -e "${YELLOW}Verifying cluster connection...${NC}"
kubectl cluster-info

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Cannot connect to cluster${NC}"
    exit 1
fi

# Check if namespace exists (if not default)
if [ "$APP_NAMESPACE" != "default" ]; then
    echo -e "${YELLOW}Checking namespace: $APP_NAMESPACE${NC}"
    kubectl get namespace "$APP_NAMESPACE" 2>/dev/null || {
        echo -e "${YELLOW}Namespace does not exist. Creating...${NC}"
        kubectl create namespace "$APP_NAMESPACE"
    }
fi

# Get image tag (default to latest if not provided)
IMAGE_TAG="${1:-latest}"
FULL_IMAGE="$ECR_REPO:$IMAGE_TAG"

echo -e "${YELLOW}Deploying image: $FULL_IMAGE${NC}"

# Update deployment image
echo -e "${YELLOW}Updating deployment...${NC}"
kubectl set image deployment/my-app my-app="$FULL_IMAGE" -n "$APP_NAMESPACE"

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to update deployment${NC}"
    exit 1
fi

# Wait for rollout to complete
echo -e "${YELLOW}Waiting for rollout to complete...${NC}"
kubectl rollout status deployment/my-app -n "$APP_NAMESPACE" --timeout=5m

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Rollout failed or timed out${NC}"
    echo -e "${YELLOW}Checking pod status:${NC}"
    kubectl get pods -n "$APP_NAMESPACE" -l app=my-app
    echo -e "${YELLOW}Checking recent events:${NC}"
    kubectl get events -n "$APP_NAMESPACE" --sort-by='.lastTimestamp' | tail -10
    exit 1
fi

echo -e "${GREEN}Deployment successful!${NC}"

# Show deployment status
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}Deployment Status${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
kubectl get deployment my-app -n "$APP_NAMESPACE"

echo ""
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}Pods Status${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
kubectl get pods -n "$APP_NAMESPACE" -l app=my-app

echo ""
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}Service Information${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
kubectl get service my-app -n "$APP_NAMESPACE"

# Get LoadBalancer URL
echo ""
echo -e "${YELLOW}Waiting for LoadBalancer to be ready...${NC}"
LOADBALANCER_URL=""
for i in {1..30}; do
    LOADBALANCER_URL=$(kubectl get service my-app -n "$APP_NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ -n "$LOADBALANCER_URL" ]; then
        break
    fi
    echo -e "${YELLOW}Waiting... ($i/30)${NC}"
    sleep 10
done

if [ -n "$LOADBALANCER_URL" ]; then
    echo -e "${GREEN}Application URL: http://$LOADBALANCER_URL${NC}"
else
    echo -e "${YELLOW}LoadBalancer URL not available yet. Check later with:${NC}"
    echo -e "kubectl get service my-app -n $APP_NAMESPACE"
fi

echo ""
echo -e "${GREEN}Deployment completed successfully!${NC}"
echo ""
echo -e "${BLUE}Useful commands:${NC}"
echo -e "  View logs:       kubectl logs -f deployment/my-app -n $APP_NAMESPACE"
echo -e "  Describe pods:   kubectl describe pods -n $APP_NAMESPACE -l app=my-app"
echo -e "  Scale:           kubectl scale deployment my-app --replicas=3 -n $APP_NAMESPACE"
echo -e "  Restart:         kubectl rollout restart deployment/my-app -n $APP_NAMESPACE"