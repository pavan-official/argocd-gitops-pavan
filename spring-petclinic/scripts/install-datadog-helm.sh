#!/bin/bash
# Script to install Datadog Agent using Helm
# Prerequisites: Helm 3.x, kubectl, Minikube running

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

NAMESPACE=${NAMESPACE:-default}
RELEASE_NAME="datadog-agent"

echo "=========================================="
echo "Installing Datadog Agent with Helm"
echo "=========================================="

# Check if Helm is installed
if ! command -v helm &> /dev/null; then
    echo -e "${RED}Helm is not installed. Please install Helm 3.x first.${NC}"
    echo "Install: https://helm.sh/docs/intro/install/"
    exit 1
fi

echo -e "${GREEN}Helm found: $(helm version --short)${NC}"

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl is not installed. Please install kubectl first.${NC}"
    exit 1
fi

# Check if values file exists
VALUES_FILE="helm/datadog/values.yaml"
if [ ! -f "$VALUES_FILE" ]; then
    echo -e "${RED}Values file not found: $VALUES_FILE${NC}"
    exit 1
fi

# Check if API key is set
if grep -q "YOUR_DATADOG_API_KEY" "$VALUES_FILE"; then
    echo -e "${YELLOW}WARNING: Please update Datadog API key and App key in $VALUES_FILE${NC}"
    echo ""
    read -p "Do you want to continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Add Datadog Helm repository
echo -e "${YELLOW}Adding Datadog Helm repository...${NC}"
helm repo add datadog https://helm.datadoghq.com
helm repo update

# Create namespace if it doesn't exist
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Install Datadog Agent
echo -e "${YELLOW}Installing Datadog Agent...${NC}"
helm upgrade --install "$RELEASE_NAME" datadog/datadog \
    --namespace "$NAMESPACE" \
    --values "$VALUES_FILE" \
    --wait

if [ $? -ne 0 ]; then
    echo -e "${RED}Datadog Agent installation failed!${NC}"
    exit 1
fi

echo -e "${GREEN}Datadog Agent installed successfully!${NC}"
echo ""
echo "To verify installation:"
echo "  kubectl get pods -n $NAMESPACE | grep datadog"
echo ""
echo "To view Datadog Agent logs:"
echo "  kubectl logs -f -n $NAMESPACE -l app=datadog-agent"
echo ""
echo "To uninstall:"
echo "  helm uninstall $RELEASE_NAME -n $NAMESPACE"

