#!/bin/bash
# Script to build Docker image for Spring PetClinic
# Usage: ./build-docker.sh [tag]

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get tag from argument or use default
TAG=${1:-latest}
IMAGE_NAME="petclinic"

echo "=========================================="
echo "Building Docker Image: $IMAGE_NAME:$TAG"
echo "=========================================="

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

echo -e "${GREEN}Docker found${NC}"

# Build the Docker image
echo -e "${YELLOW}Building Docker image...${NC}"
docker build -t "$IMAGE_NAME:$TAG" .

if [ $? -ne 0 ]; then
    echo -e "${RED}Docker build failed!${NC}"
    exit 1
fi

echo -e "${GREEN}Docker image built successfully!${NC}"
echo ""
echo "Image details:"
docker images "$IMAGE_NAME:$TAG"
echo ""
echo "To run the container:"
echo "  docker run -p 8080:8080 $IMAGE_NAME:$TAG"
echo ""
echo "To test locally with PostgreSQL:"
echo "  1. Start PostgreSQL: docker compose up -d postgres"
echo "  2. Run app: docker run -p 8080:8080 -e SPRING_PROFILES_ACTIVE=postgres -e SPRING_DATASOURCE_URL=jdbc:postgresql://host.docker.internal:5432/petclinic -e SPRING_DATASOURCE_USERNAME=petclinic -e SPRING_DATASOURCE_PASSWORD=petclinic $IMAGE_NAME:$TAG"

