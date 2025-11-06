#!/bin/bash
# Script to install Datadog Agent using Helm on KIND cluster
# Usage: ./install-datadog-helm-kind.sh [api-key] [app-key]
# Or set environment variables: DD_API_KEY and DD_APP_KEY

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

CLUSTER_NAME="petclinic-cluster"
NAMESPACE="default"
RELEASE_NAME="datadog-agent"

echo "=========================================="
echo "Installing Datadog Agent with Helm (KIND)"
echo "=========================================="

# Check if KIND cluster exists
if ! kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo -e "${RED}KIND cluster '$CLUSTER_NAME' does not exist${NC}"
    echo "Please create it first: ./scripts/setup-kind-cluster.sh"
    exit 1
fi

# Set kubectl context
kubectl config use-context kind-$CLUSTER_NAME > /dev/null

# Get API keys
DD_API_KEY=${1:-${DD_API_KEY}}
DD_APP_KEY=${2:-${DD_APP_KEY}}

# If API key provided but App key missing, prompt for it
if [ -n "$DD_API_KEY" ] && [ -z "$DD_APP_KEY" ]; then
    echo -e "${YELLOW}API key provided. App key is also required.${NC}"
    echo ""
    read -sp "Enter Datadog App Key: " DD_APP_KEY
    echo ""
    if [ -z "$DD_APP_KEY" ]; then
        echo -e "${RED}App key cannot be empty${NC}"
        exit 1
    fi
fi

if [ -z "$DD_API_KEY" ] || [ -z "$DD_APP_KEY" ]; then
    echo -e "${RED}Error: Datadog API key and App key are required${NC}"
    echo ""
    echo "Usage: $0 [api-key] [app-key]"
    echo "Or set environment variables:"
    echo "  export DD_API_KEY=your-api-key"
    echo "  export DD_APP_KEY=your-app-key"
    echo "  $0"
    echo ""
    echo "Get your keys from: https://app.datadoghq.com/organization-settings/api-keys"
    exit 1
fi

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

# Create a temporary values file with API keys
TEMP_VALUES=$(mktemp)
cp "$VALUES_FILE" "$TEMP_VALUES"

# Update API keys in temp values file
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/YOUR_DATADOG_API_KEY/$DD_API_KEY/g" "$TEMP_VALUES"
    sed -i '' "s/YOUR_DATADOG_APP_KEY/$DD_APP_KEY/g" "$TEMP_VALUES"
else
    sed -i "s/YOUR_DATADOG_API_KEY/$DD_API_KEY/g" "$TEMP_VALUES"
    sed -i "s/YOUR_DATADOG_APP_KEY/$DD_APP_KEY/g" "$TEMP_VALUES"
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
    --values "$TEMP_VALUES" \
    --wait

if [ $? -ne 0 ]; then
    echo -e "${RED}Datadog Agent installation failed!${NC}"
    rm "$TEMP_VALUES"
    exit 1
fi

# Clean up temp file
rm "$TEMP_VALUES"

echo ""
echo -e "${GREEN}✓${NC} Datadog Agent installed successfully!"
echo ""
echo "To verify installation:"
echo "  kubectl get pods -n $NAMESPACE | grep datadog"
echo ""
echo "To view Datadog Agent logs:"
echo "  kubectl logs -f -n $NAMESPACE -l app=datadog-agent"
echo ""
echo "To check Datadog Agent status:"
echo "  kubectl exec -it -n $NAMESPACE \$(kubectl get pod -l app=datadog-agent -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}') -- agent status"
echo ""
echo "To uninstall:"
echo "  helm uninstall $RELEASE_NAME -n $NAMESPACE"
echo ""
echo "View your metrics in Datadog:"
echo "  https://app.datadoghq.com"

