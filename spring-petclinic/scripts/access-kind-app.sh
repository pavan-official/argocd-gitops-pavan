#!/bin/bash
# Script to access PetClinic application in KIND cluster
# This script sets up port-forwarding to access the application

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

CLUSTER_NAME="petclinic-cluster"
LOCAL_PORT=8080

echo "=========================================="
echo "Accessing PetClinic Application"
echo "=========================================="

# Check if cluster exists
if ! kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo -e "${RED}KIND cluster '$CLUSTER_NAME' does not exist${NC}"
    exit 1
fi

# Set kubectl context
kubectl config use-context kind-$CLUSTER_NAME > /dev/null

# Check if service exists
if ! kubectl get svc petclinic &> /dev/null; then
    echo -e "${RED}Service 'petclinic' does not exist${NC}"
    echo "Deploy the application first: ./scripts/deploy-kind-dockerhub.sh"
    exit 1
fi

# Check if pods are running
PODS_READY=$(kubectl get pods -l app=petclinic --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$PODS_READY" -eq 0 ]; then
    echo -e "${RED}No pods are running${NC}"
    echo "Check pod status: kubectl get pods -l app=petclinic"
    exit 1
fi

echo -e "${GREEN}✓${NC} Application is running ($PODS_READY pod(s))"
echo ""

# Check if port-forward is already running
if lsof -ti:$LOCAL_PORT &> /dev/null; then
    echo -e "${YELLOW}Port $LOCAL_PORT is already in use${NC}"
    read -p "Kill existing process and start new port-forward? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kill $(lsof -ti:$LOCAL_PORT) 2>/dev/null || true
        sleep 1
    else
        echo "Using existing port-forward"
        echo ""
        echo -e "${GREEN}Application is accessible at:${NC}"
        echo "  http://localhost:$LOCAL_PORT"
        echo ""
        echo "To stop port-forward:"
        echo "  kill \$(lsof -ti:$LOCAL_PORT)"
        exit 0
    fi
fi

echo -e "${YELLOW}Starting port-forward...${NC}"
echo "Port-forwarding service 'petclinic' to localhost:$LOCAL_PORT"
echo ""
echo -e "${GREEN}Application will be accessible at:${NC}"
echo "  Main: http://localhost:$LOCAL_PORT"
echo "  Health: http://localhost:$LOCAL_PORT/actuator/health"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop port-forward${NC}"
echo ""

# Start port-forward in background and capture PID
kubectl port-forward svc/petclinic $LOCAL_PORT:80 > /dev/null 2>&1 &
PF_PID=$!

# Wait a moment for port-forward to establish
sleep 2

# Test if port-forward is working
if curl -s http://localhost:$LOCAL_PORT/actuator/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Port-forward is active"
    echo ""
    echo "Testing health endpoint:"
    curl -s http://localhost:$LOCAL_PORT/actuator/health && echo ""
    echo ""
    echo -e "${GREEN}Open in browser: http://localhost:$LOCAL_PORT${NC}"
    echo ""
    echo "To stop port-forward:"
    echo "  kill $PF_PID"
    echo "  or press Ctrl+C"
    echo ""
    
    # Keep port-forward running
    wait $PF_PID
else
    echo -e "${RED}Failed to establish port-forward${NC}"
    kill $PF_PID 2>/dev/null || true
    exit 1
fi


