#!/bin/bash
# Script to deploy Spring PetClinic to KIND cluster using Docker Hub image
# This script pulls the latest image from Docker Hub and deploys to KIND
# Usage: ./deploy-kind-dockerhub.sh [dockerhub-username] [version]
# If version is not provided, uses 'latest'

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

DOCKERHUB_USERNAME=${1:-${DOCKERHUB_USERNAME}}
VERSION=${2:-latest}
CLUSTER_NAME="petclinic-cluster"

echo "=========================================="
echo "Deploying to KIND Cluster from Docker Hub"
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

# Check if KIND is installed
if ! command -v kind &> /dev/null; then
    echo -e "${RED}KIND is not installed. Please install KIND first.${NC}"
    echo "Install: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
    exit 1
fi

# Check if cluster exists
if ! kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo -e "${RED}KIND cluster '$CLUSTER_NAME' does not exist${NC}"
    echo "Please create it first:"
    echo "  ./scripts/setup-kind-cluster.sh"
    exit 1
fi

echo -e "${GREEN}✓${NC} KIND cluster '$CLUSTER_NAME' found"

# Set kubectl context
kubectl config use-context kind-$CLUSTER_NAME > /dev/null

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
    echo "     ./scripts/deploy-kind-dockerhub.sh $DOCKERHUB_USERNAME $VERSION"
    echo ""
    exit 1
fi
echo ""

# Load image into KIND cluster
# KIND can pull directly from Docker Hub, but loading locally ensures it's available
echo -e "${YELLOW}Loading image into KIND cluster...${NC}"
echo "Note: KIND will pull from Docker Hub automatically, but we'll ensure it's available"

# Pull image locally first
if ! docker images "$IMAGE_NAME" | grep -q "$DOCKERHUB_USERNAME/spring-petclinic"; then
    echo "Pulling image locally..."
    docker pull "$IMAGE_NAME"
fi

# Load image into KIND cluster
kind load docker-image "$IMAGE_NAME" --name "$CLUSTER_NAME"

if [ $? -ne 0 ]; then
    echo -e "${YELLOW}⚠${NC} Could not load image directly, but KIND can pull from Docker Hub"
    echo "The deployment will pull from Docker Hub automatically"
fi

echo -e "${GREEN}✓${NC} Image ready for deployment"

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
    echo "  2. Load into KIND: kind load docker-image $IMAGE_NAME --name $CLUSTER_NAME"
    echo "  3. Delete failed pods: kubectl delete pod -l app=petclinic"
    echo ""
fi

# Get service URL
echo ""
echo -e "${GREEN}Deployment complete!${NC}"
echo ""
echo "Cluster Information:"
kubectl cluster-info --context kind-$CLUSTER_NAME | head -1
echo ""
echo "Service Information:"
kubectl get svc petclinic
echo ""
echo "Deployment Information:"
kubectl get deployment petclinic -o jsonpath='{.spec.template.spec.containers[0].image}' && echo ""
echo ""
echo "Node Distribution:"
kubectl get pods -l app=petclinic -o wide
echo ""
echo "To access the application:"
echo "  kubectl port-forward svc/petclinic 8080:80"
echo "  Then open: http://localhost:8080"
echo ""
echo "Or use NodePort (if configured):"
NODE_PORT=$(kubectl get svc petclinic -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")
if [ "$NODE_PORT" != "N/A" ] && [ "$NODE_PORT" != "" ]; then
    # Get IP of any node
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "localhost")
    echo "  http://$NODE_IP:$NODE_PORT"
else
    echo "  Use port-forward: kubectl port-forward svc/petclinic 8080:80"
fi
echo ""
echo "To view logs:"
echo "  kubectl logs -f deployment/petclinic"
echo ""
echo "To check pod status:"
echo "  kubectl get pods -l app=petclinic -o wide"
echo ""
echo "To troubleshoot if pods are not starting:"
echo "  kubectl describe pod -l app=petclinic"
echo "  kubectl logs -l app=petclinic"


