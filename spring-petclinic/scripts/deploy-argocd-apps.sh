#!/bin/bash
# Script to deploy ArgoCD Applications
# This deploys both PetClinic app and Datadog via ArgoCD
# Usage: ./deploy-argocd-apps.sh [github-repo-url]

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

CLUSTER_NAME="petclinic-cluster"
GITHUB_REPO=${1:-${GITHUB_REPO}}

echo "=========================================="
echo "Deploying Applications via ArgoCD"
echo "=========================================="

# Check if KIND cluster exists
if ! kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo -e "${RED}KIND cluster '$CLUSTER_NAME' does not exist${NC}"
    exit 1
fi

# Set kubectl context
kubectl config use-context kind-$CLUSTER_NAME > /dev/null

# Check if ArgoCD is installed
if ! kubectl get namespace argocd &> /dev/null; then
    echo -e "${RED}ArgoCD is not installed${NC}"
    echo "Please install ArgoCD first: ./scripts/install-argocd-kind.sh"
    exit 1
fi

# Check if ArgoCD server is running
if ! kubectl get deployment argocd-server -n argocd &> /dev/null; then
    echo -e "${RED}ArgoCD server is not running${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} ArgoCD is installed"
echo ""

# Update GitHub repo URL if provided
if [ -n "$GITHUB_REPO" ]; then
    echo -e "${YELLOW}Updating GitHub repository URL...${NC}"
    # Update the application manifest
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|repoURL:.*|repoURL: $GITHUB_REPO|g" argocd/petclinic-application.yaml
        sed -i '' "s|# Update with your repo URL|# GitOps: ArgoCD watches this repo for config changes|g" argocd/petclinic-application.yaml
    else
        sed -i "s|repoURL:.*|repoURL: $GITHUB_REPO|g" argocd/petclinic-application.yaml
        sed -i "s|# Update with your repo URL|# GitOps: ArgoCD watches this repo for config changes|g" argocd/petclinic-application.yaml
    fi
    echo -e "${GREEN}✓${NC} Updated to: $GITHUB_REPO"
    echo ""
    echo -e "${BLUE}GitOps Setup:${NC}"
    echo "  ArgoCD will watch: $GITHUB_REPO/spring-petclinic/k8s"
    echo "  Any changes to k8s/*.yml will trigger auto-sync"
    echo ""
else
    echo -e "${YELLOW}⚠${NC} No GitHub repo URL provided"
    echo "Update argocd/petclinic-application.yaml manually with your repo URL"
    echo ""
fi

# Deploy PetClinic application
echo -e "${YELLOW}Deploying PetClinic application via ArgoCD...${NC}"
kubectl apply -f argocd/petclinic-application.yaml

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} PetClinic application created in ArgoCD"
else
    echo -e "${RED}Failed to create PetClinic application${NC}"
    exit 1
fi

# Wait a moment for ArgoCD to process
sleep 3

# Show application status
echo ""
echo -e "${GREEN}Application Status:${NC}"
kubectl get application -n argocd

echo ""
echo -e "${GREEN}✓${NC} Applications deployed via ArgoCD!"
echo ""
echo "To view applications in ArgoCD UI:"
echo "  1. Port-forward ArgoCD: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  2. Open: https://localhost:8080"
echo ""
echo "To check application status:"
echo "  kubectl get application -n argocd"
echo "  kubectl describe application petclinic-app -n argocd"
echo ""
echo "To sync manually:"
echo "  argocd app sync petclinic-app"
echo ""


