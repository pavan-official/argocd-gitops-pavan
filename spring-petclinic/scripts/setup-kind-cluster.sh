#!/bin/bash
# Script to set up KIND multi-node Kubernetes cluster
# Usage: ./setup-kind-cluster.sh

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

CLUSTER_NAME="petclinic-cluster"
CONFIG_FILE="kind/cluster-config.yaml"

echo "=========================================="
echo "Setting up KIND Multi-Node Cluster"
echo "=========================================="

# Check if KIND is installed
if ! command -v kind &> /dev/null; then
    echo -e "${RED}KIND is not installed.${NC}"
    echo ""
    echo "Install KIND:"
    echo "  macOS: brew install kind"
    echo "  Linux: curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64 && chmod +x ./kind && sudo mv ./kind /usr/local/bin/"
    echo "  Or visit: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
    exit 1
fi

echo -e "${GREEN}✓${NC} KIND is installed: $(kind version)"
echo ""

# Check if cluster already exists
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo -e "${YELLOW}Cluster '$CLUSTER_NAME' already exists${NC}"
    read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Deleting existing cluster...${NC}"
        kind delete cluster --name "$CLUSTER_NAME"
    else
        echo "Using existing cluster"
        exit 0
    fi
fi

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Config file not found: $CONFIG_FILE${NC}"
    exit 1
fi

# Create cluster
echo -e "${YELLOW}Creating KIND cluster with multi-node configuration...${NC}"
kind create cluster --config "$CONFIG_FILE" --name "$CLUSTER_NAME"

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to create cluster${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Cluster created successfully"
echo ""

# Wait for cluster to be ready
echo -e "${YELLOW}Waiting for cluster to be ready...${NC}"
kubectl wait --for=condition=Ready nodes --all --timeout=300s || true

# Show cluster info
echo ""
echo -e "${GREEN}Cluster Information:${NC}"
kubectl cluster-info --context kind-$CLUSTER_NAME
echo ""
echo -e "${GREEN}Nodes:${NC}"
kubectl get nodes -o wide
echo ""
echo -e "${GREEN}✓${NC} KIND multi-node cluster is ready!"
echo ""
echo "Cluster name: $CLUSTER_NAME"
echo "Context: kind-$CLUSTER_NAME"
echo ""
echo "To use this cluster:"
echo "  kubectl cluster-info --context kind-$CLUSTER_NAME"
echo ""
echo "To delete cluster:"
echo "  kind delete cluster --name $CLUSTER_NAME"


