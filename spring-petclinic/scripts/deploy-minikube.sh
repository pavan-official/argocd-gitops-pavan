#!/bin/bash
# Script to deploy Spring PetClinic to Minikube
# This script builds the Docker image, loads it into Minikube, and deploys the application

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

IMAGE_NAME="petclinic"
TAG="latest"
MINIKUBE_PROFILE=${MINIKUBE_PROFILE:-minikube}

echo "=========================================="
echo "Deploying to Minikube"
echo "=========================================="

# Check if Minikube is installed
if ! command -v minikube &> /dev/null; then
    echo -e "${RED}Minikube is not installed. Please install Minikube first.${NC}"
    echo "Install: https://minikube.sigs.k8s.io/docs/start/"
    exit 1
fi

# Check if Minikube is running
if ! minikube status --profile="$MINIKUBE_PROFILE" &> /dev/null; then
    echo -e "${YELLOW}Minikube is not running. Starting Minikube...${NC}"
    minikube start --profile="$MINIKUBE_PROFILE"
fi

echo -e "${GREEN}Minikube is running${NC}"

# Use Minikube's Docker daemon
echo -e "${YELLOW}Configuring Docker to use Minikube's daemon...${NC}"
eval $(minikube docker-env --profile="$MINIKUBE_PROFILE")

# Build Docker image
echo -e "${YELLOW}Building Docker image...${NC}"
docker build -t "$IMAGE_NAME:$TAG" .

if [ $? -ne 0 ]; then
    echo -e "${RED}Docker build failed!${NC}"
    exit 1
fi

echo -e "${GREEN}Docker image built and loaded into Minikube${NC}"

# Deploy database
echo -e "${YELLOW}Deploying PostgreSQL database...${NC}"
kubectl apply -f k8s/db.yml

# Wait for database to be ready
echo -e "${YELLOW}Waiting for database to be ready...${NC}"
kubectl wait --for=condition=available --timeout=120s deployment/demo-db || true

# Deploy application
echo -e "${YELLOW}Deploying PetClinic application...${NC}"
kubectl apply -f k8s/petclinic.yml

# Wait for application to be ready
echo -e "${YELLOW}Waiting for application to be ready...${NC}"
kubectl wait --for=condition=available --timeout=120s deployment/petclinic || true

# Get service URL
echo ""
echo -e "${GREEN}Deployment complete!${NC}"
echo ""
echo "Service Information:"
kubectl get svc petclinic
echo ""
echo "To access the application:"
echo "  minikube service petclinic --profile=$MINIKUBE_PROFILE"
echo ""
echo "Or get the NodePort URL:"
NODE_PORT=$(kubectl get svc petclinic -o jsonpath='{.spec.ports[0].nodePort}')
NODE_IP=$(minikube ip --profile="$MINIKUBE_PROFILE")
echo "  http://$NODE_IP:$NODE_PORT"
echo ""
echo "To view logs:"
echo "  kubectl logs -f deployment/petclinic"

