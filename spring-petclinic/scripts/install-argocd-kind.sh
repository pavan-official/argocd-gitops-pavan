#!/bin/bash
# Script to install ArgoCD on KIND cluster
# Usage: ./install-argocd-kind.sh

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

CLUSTER_NAME="petclinic-cluster"
NAMESPACE="argocd"

echo "=========================================="
echo "Installing ArgoCD on KIND Cluster"
echo "=========================================="

# Check if KIND cluster exists
if ! kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo -e "${RED}KIND cluster '$CLUSTER_NAME' does not exist${NC}"
    echo "Please create it first: ./scripts/setup-kind-cluster.sh"
    exit 1
fi

# Set kubectl context
kubectl config use-context kind-$CLUSTER_NAME > /dev/null

echo -e "${GREEN}✓${NC} Using KIND cluster: $CLUSTER_NAME"
echo ""

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl is not installed. Please install kubectl first.${NC}"
    exit 1
fi

# Create namespace
echo -e "${YELLOW}Creating ArgoCD namespace...${NC}"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD
echo -e "${YELLOW}Installing ArgoCD (this may take a few minutes)...${NC}"
kubectl apply -n "$NAMESPACE" -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
echo -e "${YELLOW}Waiting for ArgoCD components to be ready...${NC}"
echo "This may take 2-3 minutes..."

# Wait for deployments
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n "$NAMESPACE" || true
kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n "$NAMESPACE" || true
kubectl wait --for=condition=available --timeout=300s deployment/argocd-applicationset-controller -n "$NAMESPACE" || true

# Get initial admin password
echo ""
echo -e "${YELLOW}Retrieving ArgoCD admin password...${NC}"
sleep 5  # Give it time to generate the secret
ARGOCD_PASSWORD=$(kubectl -n "$NAMESPACE" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "")

if [ -z "$ARGOCD_PASSWORD" ]; then
    echo -e "${YELLOW}⚠${NC} Password not ready yet. Wait a moment and run:"
    echo "  kubectl -n $NAMESPACE get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
else
    echo -e "${GREEN}✓${NC} ArgoCD password retrieved"
fi

echo ""
echo -e "${GREEN}✓${NC} ArgoCD installed successfully!"
echo ""
echo "=========================================="
echo "ArgoCD Access Information"
echo "=========================================="
echo "Username: admin"
if [ -n "$ARGOCD_PASSWORD" ]; then
    echo "Password: $ARGOCD_PASSWORD"
else
    echo "Password: (run command below to get it)"
fi
echo ""
echo "To access ArgoCD UI:"
echo "  1. Start port-forward:"
echo "     kubectl port-forward svc/argocd-server -n $NAMESPACE 8080:443"
echo ""
echo "  2. Open browser:"
echo "     https://localhost:8080"
echo ""
echo "  3. Accept the self-signed certificate warning"
echo ""
echo "To get password later:"
echo "  kubectl -n $NAMESPACE get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo ""
echo "To login via CLI:"
echo "  kubectl port-forward svc/argocd-server -n $NAMESPACE 8080:443"
echo "  argocd login localhost:8080 --insecure --username admin --password <password>"
echo ""
echo "ArgoCD is ready for GitOps deployments!"


