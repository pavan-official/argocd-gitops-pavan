#!/bin/bash
# Script to deploy Spring PetClinic to Minikube using Docker Hub image
# This script pulls the latest image from Docker Hub and deploys to Minikube
# Usage: ./deploy-minikube-dockerhub.sh [dockerhub-username] [version]
# If version is not provided, uses 'latest'

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

DOCKERHUB_USERNAME=${1:-${DOCKERHUB_USERNAME}}
VERSION=${2:-latest}
MINIKUBE_PROFILE=${MINIKUBE_PROFILE:-minikube}

echo "=========================================="
echo "Deploying to Minikube from Docker Hub"
echo "=========================================="

# Check if Docker Hub username is provided
if [ -z "$DOCKERHUB_USERNAME" ]; then
    echo -e "${RED}Error: Docker Hub username is required${NC}"
    echo "Usage: $0 [dockerhub-username] [version]"
    echo "Or set DOCKERHUB_USERNAME environment variable"
    echo ""
    echo "Example:"
    echo "  export DOCKERHUB_USERNAME=myusername"
    echo "  $0"
    exit 1
fi

IMAGE_NAME="$DOCKERHUB_USERNAME/spring-petclinic:$VERSION"

echo -e "${GREEN}Docker Hub Username: $DOCKERHUB_USERNAME${NC}"
echo -e "${GREEN}Image: $IMAGE_NAME${NC}"
echo ""

# Check if image exists on Docker Hub
echo -n "Checking if image exists on Docker Hub... "
if docker manifest inspect "$IMAGE_NAME" &> /dev/null; then
    echo -e "${GREEN}✓${NC} Image found on Docker Hub"
else
    echo -e "${RED}✗${NC} Image not found on Docker Hub"
    echo ""
    echo -e "${YELLOW}⚠ ERROR: The image '$IMAGE_NAME' does not exist on Docker Hub${NC}"
    echo ""
    echo "To fix this:"
    echo "  1. Build and push the image:"
    echo "     ./scripts/build-and-push-dockerhub.sh $VERSION $DOCKERHUB_USERNAME"
    echo ""
    echo "  2. Or login to Docker Hub if not authenticated:"
    echo "     docker login"
    echo ""
    echo "  3. Then try deploying again:"
    echo "     ./scripts/deploy-minikube-dockerhub.sh $DOCKERHUB_USERNAME $VERSION"
    echo ""
    exit 1
fi
echo ""

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

# Pull image from Docker Hub into Minikube
echo ""
echo -e "${YELLOW}Pulling image from Docker Hub into Minikube...${NC}"
if minikube image pull "$IMAGE_NAME" --profile="$MINIKUBE_PROFILE" 2>&1; then
    echo -e "${GREEN}✓${NC} Image pulled successfully into Minikube"
else
    echo -e "${RED}✗${NC} Failed to pull image from Docker Hub into Minikube"
    echo ""
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo "  1. Verify image exists: docker pull $IMAGE_NAME"
    echo "  2. Check Minikube is running: minikube status"
    echo "  3. Try pulling manually: minikube image pull $IMAGE_NAME"
    echo ""
    exit 1
fi

# Update Kubernetes manifest with the image
echo ""
echo -e "${YELLOW}Updating Kubernetes deployment with image: $IMAGE_NAME${NC}"

# Create a temporary manifest with the Docker Hub image
TEMP_MANIFEST=$(mktemp)
sed "s|image:.*petclinic.*|image: $IMAGE_NAME|g" k8s/petclinic.yml > "$TEMP_MANIFEST"

# Also set imagePullPolicy to Always for latest tag, or IfNotPresent for versioned tags
if [ "$VERSION" = "latest" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' 's/imagePullPolicy:.*/imagePullPolicy: Always/g' "$TEMP_MANIFEST"
    else
        sed -i 's/imagePullPolicy:.*/imagePullPolicy: Always/g' "$TEMP_MANIFEST"
    fi
else
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' 's/imagePullPolicy:.*/imagePullPolicy: IfNotPresent/g' "$TEMP_MANIFEST"
    else
        sed -i 's/imagePullPolicy:.*/imagePullPolicy: IfNotPresent/g' "$TEMP_MANIFEST"
    fi
fi

# Deploy database
echo -e "${YELLOW}Deploying PostgreSQL database...${NC}"
kubectl apply -f k8s/db.yml

# Wait for database to be ready
echo -e "${YELLOW}Waiting for database to be ready...${NC}"
kubectl wait --for=condition=available --timeout=120s deployment/demo-db || true

# Deploy application with updated image
echo -e "${YELLOW}Deploying PetClinic application...${NC}"
kubectl apply -f "$TEMP_MANIFEST"

# Clean up temp file
rm "$TEMP_MANIFEST"

# Wait for application to be ready
echo -e "${YELLOW}Waiting for application to be ready...${NC}"
if kubectl wait --for=condition=available --timeout=120s deployment/petclinic 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Deployment is ready"
else
    echo -e "${YELLOW}⚠${NC} Deployment not ready yet (this is normal, it may take a minute)"
    echo -e "${YELLOW}Checking pod status...${NC}"
    kubectl get pods -l app=petclinic
    echo ""
    echo -e "${YELLOW}If pods are in ImagePullBackOff or ErrImagePull:${NC}"
    echo "  1. Verify image was pushed: docker pull $IMAGE_NAME"
    echo "  2. Pull into Minikube: minikube image pull $IMAGE_NAME"
    echo "  3. Delete failed pods: kubectl delete pod -l app=petclinic"
    echo ""
fi

# Get service URL
echo ""
echo -e "${GREEN}Deployment complete!${NC}"
echo ""
echo "Service Information:"
kubectl get svc petclinic
echo ""
echo "Deployment Information:"
kubectl get deployment petclinic -o jsonpath='{.spec.template.spec.containers[0].image}' && echo ""
echo ""
echo "To access the application:"
echo "  minikube service petclinic --profile=$MINIKUBE_PROFILE"
echo ""
echo "Or get the NodePort URL:"
NODE_PORT=$(kubectl get svc petclinic -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")
NODE_IP=$(minikube ip --profile="$MINIKUBE_PROFILE" 2>/dev/null || echo "N/A")
if [ "$NODE_PORT" != "N/A" ] && [ "$NODE_IP" != "N/A" ]; then
    echo "  http://$NODE_IP:$NODE_PORT"
fi
echo ""
echo "To view logs:"
echo "  kubectl logs -f deployment/petclinic"
echo ""
echo "To check pod status:"
echo "  kubectl get pods -l app=petclinic"
echo ""
echo "To troubleshoot if pods are not starting:"
echo "  kubectl describe pod -l app=petclinic"
echo "  kubectl logs -l app=petclinic"

