#!/bin/bash
# Script to demonstrate GitOps workflow with ArgoCD
# This shows how ArgoCD watches Git for configuration changes
# Usage: ./demo-argocd-gitops.sh [action]
# Actions: setup, update-config, update-image, status

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CLUSTER_NAME="petclinic-cluster"
ACTION=${1:-status}

echo "=========================================="
echo "ArgoCD GitOps Workflow Demo"
echo "=========================================="
echo ""

# Set kubectl context
kubectl config use-context kind-$CLUSTER_NAME > /dev/null 2>&1 || true

case "$ACTION" in
  setup)
    echo -e "${BLUE}Setting up ArgoCD GitOps workflow...${NC}"
    echo ""
    echo "1. Make sure your Git repository is accessible"
    echo "2. Update argocd/petclinic-application.yaml with your Git repo URL"
    echo "3. Deploy the ArgoCD application:"
    echo "   ./scripts/deploy-argocd-apps.sh <your-github-repo-url>"
    echo ""
    echo "4. ArgoCD will:"
    echo "   - Watch k8s/petclinic.yml in your Git repo"
    echo "   - Auto-deploy any changes"
    echo "   - Pull images from Docker Hub dynamically"
    ;;
    
  update-config)
    echo -e "${BLUE}Updating configuration via GitOps...${NC}"
    echo ""
    echo "To update configuration:"
    echo ""
    echo "1. Edit k8s/petclinic.yml in your Git repository:"
    echo "   - Change replicas"
    echo "   - Update environment variables"
    echo "   - Modify resource limits"
    echo "   - Change health check settings"
    echo ""
    echo "2. Commit and push:"
    echo "   git add k8s/petclinic.yml"
    echo "   git commit -m 'Update PetClinic configuration'"
    echo "   git push"
    echo ""
    echo "3. ArgoCD will automatically:"
    echo "   - Detect the Git change"
    echo "   - Sync the new configuration"
    echo "   - Update the deployment"
    echo ""
    echo "4. Check sync status:"
    echo "   kubectl get application petclinic-app -n argocd"
    echo "   argocd app get petclinic-app"
    ;;
    
  update-image)
    echo -e "${BLUE}Updating Docker image tag via GitOps...${NC}"
    echo ""
    echo "To update the Docker image:"
    echo ""
    echo "1. Build and push new image:"
    echo "   ./scripts/build-and-push-dockerhub.sh 1.0.1 pavandoc1990"
    echo ""
    echo "2. Update image tag in k8s/petclinic.yml in Git:"
    echo "   image: pavandoc1990/spring-petclinic:1.0.1"
    echo ""
    echo "3. Commit and push:"
    echo "   git add k8s/petclinic.yml"
    echo "   git commit -m 'Update to version 1.0.1'"
    echo "   git push"
    echo ""
    echo "4. ArgoCD will automatically:"
    echo "   - Detect the Git change"
    echo "   - Pull new image from Docker Hub"
    echo "   - Deploy the new version"
    echo ""
    echo "Note: If using 'latest' tag, ArgoCD will pull the newest image"
    echo "      on each sync due to imagePullPolicy: Always"
    ;;
    
  status)
    echo -e "${BLUE}Checking ArgoCD Application Status...${NC}"
    echo ""
    
    if kubectl get application petclinic-app -n argocd &> /dev/null; then
        echo -e "${GREEN}Application Status:${NC}"
        kubectl get application petclinic-app -n argocd
        echo ""
        
        echo -e "${GREEN}Sync Status:${NC}"
        kubectl get application petclinic-app -n argocd -o jsonpath='{.status.sync.status}' && echo ""
        
        echo -e "${GREEN}Health Status:${NC}"
        kubectl get application petclinic-app -n argocd -o jsonpath='{.status.health.status}' && echo ""
        echo ""
        
        echo -e "${GREEN}Current Image:${NC}"
        kubectl get deployment petclinic -o jsonpath='{.spec.template.spec.containers[0].image}' && echo ""
        echo ""
        
        echo "To see detailed status:"
        echo "  argocd app get petclinic-app"
    else
        echo -e "${YELLOW}ArgoCD application not found${NC}"
        echo "Deploy it first: ./scripts/deploy-argocd-apps.sh <github-repo-url>"
    fi
    ;;
    
  *)
    echo "Usage: $0 [setup|update-config|update-image|status]"
    echo ""
    echo "Commands:"
    echo "  setup         - Show setup instructions"
    echo "  update-config - Show how to update configuration via Git"
    echo "  update-image  - Show how to update Docker image via Git"
    echo "  status        - Check ArgoCD application status"
    exit 1
    ;;
esac

