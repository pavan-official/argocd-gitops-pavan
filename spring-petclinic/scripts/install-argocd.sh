#!/bin/bash
# Script to install ArgoCD on Minikube
# This script installs ArgoCD and sets up port forwarding

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

NAMESPACE="argocd"

echo "=========================================="
echo "Installing ArgoCD on Minikube"
echo "=========================================="

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl is not installed. Please install kubectl first.${NC}"
    exit 1
fi

# Create namespace
echo -e "${YELLOW}Creating ArgoCD namespace...${NC}"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD
echo -e "${YELLOW}Installing ArgoCD...${NC}"
kubectl apply -n "$NAMESPACE" -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
echo -e "${YELLOW}Waiting for ArgoCD to be ready (this may take a few minutes)...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n "$NAMESPACE" || true
kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n "$NAMESPACE" || true
kubectl wait --for=condition=available --timeout=300s deployment/argocd-applicationset-controller -n "$NAMESPACE" || true

# Get initial admin password
echo -e "${YELLOW}Retrieving ArgoCD admin password...${NC}"
ARGOCD_PASSWORD=$(kubectl -n "$NAMESPACE" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo ""
echo -e "${GREEN}ArgoCD installed successfully!${NC}"
echo ""
echo "ArgoCD Access Information:"
echo "  Username: admin"
echo "  Password: $ARGOCD_PASSWORD"
echo ""
echo "To access ArgoCD UI, run:"
echo "  kubectl port-forward svc/argocd-server -n $NAMESPACE 8080:443"
echo ""
echo "Then open: https://localhost:8080"
echo ""
echo "To login via CLI:"
echo "  kubectl port-forward svc/argocd-server -n $NAMESPACE 8080:443"
echo "  argocd login localhost:8080 --insecure"
echo ""
echo "To deploy applications:"
echo "  kubectl apply -f argocd/application.yaml"

