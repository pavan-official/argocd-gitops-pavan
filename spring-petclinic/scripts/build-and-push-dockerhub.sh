#!/bin/bash
# Script to build Docker image and push to Docker Hub
# Usage: ./build-and-push-dockerhub.sh [version] [dockerhub-username]
# Example: ./build-and-push-dockerhub.sh 1.0.0 myusername

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get version from argument or use timestamp
VERSION=${1:-$(date +%Y%m%d-%H%M%S)}
DOCKERHUB_USERNAME=${2:-${DOCKERHUB_USERNAME}}

echo "=========================================="
echo "Build and Push to Docker Hub"
echo "=========================================="

# Check if Docker Hub username is provided
if [ -z "$DOCKERHUB_USERNAME" ]; then
    echo -e "${RED}Error: Docker Hub username is required${NC}"
    echo "Usage: $0 [version] [dockerhub-username]"
    echo "Or set DOCKERHUB_USERNAME environment variable"
    echo ""
    echo "Example:"
    echo "  export DOCKERHUB_USERNAME=myusername"
    echo "  $0 1.0.0"
    exit 1
fi

echo -e "${GREEN}Docker Hub Username: $DOCKERHUB_USERNAME${NC}"
echo -e "${GREEN}Version: $VERSION${NC}"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    echo -e "${RED}Docker daemon is not running. Please start Docker.${NC}"
    exit 1
fi

# Check if user is logged in to Docker Hub
echo -n "Checking Docker Hub login... "
if docker info | grep -q "Username"; then
    LOGGED_IN_USER=$(docker info 2>/dev/null | grep "Username" | awk '{print $2}' || echo "")
    if [ "$LOGGED_IN_USER" != "$DOCKERHUB_USERNAME" ]; then
        echo -e "${YELLOW}⚠${NC} Logged in as different user: $LOGGED_IN_USER"
        echo -e "${YELLOW}Logging in as $DOCKERHUB_USERNAME...${NC}"
        docker login
    else
        echo -e "${GREEN}✓${NC} Already logged in as $DOCKERHUB_USERNAME"
    fi
else
    echo -e "${YELLOW}⚠${NC} Not logged in to Docker Hub"
    echo -e "${YELLOW}Please login to Docker Hub:${NC}"
    docker login
fi

# Build the JAR first (if not already built)
echo ""
echo -e "${YELLOW}Checking if JAR is built...${NC}"
if [ -z "$(find target -name 'spring-petclinic-*.jar' -not -name '*-sources.jar' -not -name '*-javadoc.jar' 2>/dev/null | head -1)" ]; then
    echo -e "${YELLOW}JAR not found. Building application...${NC}"
    ./mvnw clean package -DskipTests
else
    JAR_FILE=$(find target -name 'spring-petclinic-*.jar' -not -name '*-sources.jar' -not -name '*-javadoc.jar' 2>/dev/null | head -1)
    echo -e "${GREEN}✓${NC} JAR found: $JAR_FILE"
fi

# Build Docker image
IMAGE_NAME="$DOCKERHUB_USERNAME/spring-petclinic"
echo ""
echo -e "${YELLOW}Building Docker image: $IMAGE_NAME:$VERSION${NC}"
docker build -t "$IMAGE_NAME:$VERSION" -t "$IMAGE_NAME:latest" .

if [ $? -ne 0 ]; then
    echo -e "${RED}Docker build failed!${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Docker image built successfully"

# Push to Docker Hub
echo ""
echo -e "${YELLOW}Pushing to Docker Hub...${NC}"
echo "Pushing $IMAGE_NAME:$VERSION..."
docker push "$IMAGE_NAME:$VERSION"

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to push $IMAGE_NAME:$VERSION${NC}"
    exit 1
fi

echo "Pushing $IMAGE_NAME:latest..."
docker push "$IMAGE_NAME:latest"

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to push $IMAGE_NAME:latest${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓${NC} Successfully pushed to Docker Hub!"
echo ""
echo "Image details:"
echo "  - Versioned: $IMAGE_NAME:$VERSION"
echo "  - Latest: $IMAGE_NAME:latest"
echo ""
echo "View your image at:"
echo "  https://hub.docker.com/r/$DOCKERHUB_USERNAME/spring-petclinic"
echo ""
echo "To use in Minikube:"
echo "  export DOCKERHUB_USERNAME=$DOCKERHUB_USERNAME"
echo "  export IMAGE_VERSION=$VERSION"
echo "  ./scripts/deploy-minikube-dockerhub.sh"

