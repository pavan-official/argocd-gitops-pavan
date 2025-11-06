#!/bin/bash
# Complete setup script: KIND + Datadog (Helm) + ArgoCD
# Usage: ./setup-complete-stack.sh [datadog-api-key] [datadog-app-key]

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Complete Stack Setup: KIND + Datadog + ArgoCD"
echo "=========================================="
echo ""

# Step 1: KIND Cluster
echo "Step 1/4: Setting up KIND cluster..."
if kind get clusters | grep -q "^petclinic-cluster$"; then
    echo -e "${YELLOW}KIND cluster already exists, skipping...${NC}"
else
    ./scripts/setup-kind-cluster.sh
fi
echo ""

# Step 2: Deploy Application
echo "Step 2/4: Deploying PetClinic application..."
if [ -z "$DOCKERHUB_USERNAME" ]; then
    export DOCKERHUB_USERNAME=pavandoc1990
fi
./scripts/deploy-kind-dockerhub.sh "$DOCKERHUB_USERNAME" latest
echo ""

# Step 3: Install Datadog (optional)
if [ -n "$1" ] && [ -n "$2" ]; then
    echo "Step 3/4: Installing Datadog Agent with Helm..."
    ./scripts/install-datadog-helm-kind.sh "$1" "$2"
else
    echo -e "${YELLOW}Step 3/4: Skipping Datadog (provide API keys to install)${NC}"
    echo "  To install later: ./scripts/install-datadog-helm-kind.sh <api-key> <app-key>"
fi
echo ""

# Step 4: Install ArgoCD
echo "Step 4/4: Installing ArgoCD..."
if kubectl get namespace argocd &> /dev/null; then
    echo -e "${YELLOW}ArgoCD already installed, skipping...${NC}"
else
    ./scripts/install-argocd-kind.sh
fi
echo ""

echo -e "${GREEN}=========================================="
echo "Complete Stack Setup Finished!"
echo "==========================================${NC}"
echo ""
echo "What's running:"
echo "  ✓ KIND Multi-Node Cluster (3 nodes)"
echo "  ✓ PetClinic Application (2 replicas)"
echo "  ✓ PostgreSQL Database"
if [ -n "$1" ] && [ -n "$2" ]; then
    echo "  ✓ Datadog Agent (Helm)"
fi
echo "  ✓ ArgoCD (GitOps)"
echo ""
echo "Access Points:"
echo "  - PetClinic App: kubectl port-forward svc/petclinic 8080:80"
echo "  - ArgoCD UI: kubectl port-forward svc/argocd-server -n argocd 8081:443"
echo ""
echo "Next Steps:"
echo "  1. Deploy via ArgoCD: ./scripts/deploy-argocd-apps.sh"
echo "  2. Access ArgoCD UI and see GitOps in action"
echo ""


