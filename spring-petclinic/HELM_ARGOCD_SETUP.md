# Helm + ArgoCD Setup Guide

This guide explains how to use Helm for Datadog and ArgoCD for GitOps deployments in your KIND cluster.

## Architecture Overview

```
┌─────────────────────────────────────────┐
│  KIND Multi-Node Cluster               │
├─────────────────────────────────────────┤
│                                         │
│  ┌──────────────────────────────────┐  │
│  │ ArgoCD (GitOps Controller)      │  │
│  │ - Watches Git Repository        │  │
│  │ - Auto-deploys on changes       │  │
│  └──────────────────────────────────┘  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │ Datadog Agent (Helm Chart)       │  │
│  │ - Installed via Helm             │  │
│  │ - Monitors Java Application      │  │
│  └──────────────────────────────────┘  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │ PetClinic App (ArgoCD Managed)   │  │
│  │ - Deployed via GitOps            │  │
│  │ - Pulls from Docker Hub          │  │
│  └──────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘
```

## Quick Start

### Option 1: Complete Setup (All at Once)

```bash
# Set your Datadog API keys (optional)
export DD_API_KEY=your-api-key
export DD_APP_KEY=your-app-key

# Run complete setup
./scripts/setup-complete-stack.sh "$DD_API_KEY" "$DD_APP_KEY"
```

### Option 2: Step by Step

#### 1. Install ArgoCD

```bash
./scripts/install-argocd-kind.sh
```

This will:
- Install ArgoCD in `argocd` namespace
- Wait for components to be ready
- Display admin credentials

#### 2. Install Datadog via Helm

```bash
# Get your Datadog API keys from: https://app.datadoghq.com/organization-settings/api-keys
./scripts/install-datadog-helm-kind.sh <api-key> <app-key>
```

Or set environment variables:
```bash
export DD_API_KEY=your-api-key
export DD_APP_KEY=your-app-key
./scripts/install-datadog-helm-kind.sh
```

#### 3. Deploy Applications via ArgoCD

```bash
# Update GitHub repo URL in argocd/petclinic-application.yaml first!
./scripts/deploy-argocd-apps.sh https://github.com/your-username/spring-boot-app.git
```

## Accessing ArgoCD UI

### 1. Start Port-Forward

```bash
kubectl port-forward svc/argocd-server -n argocd 8081:443
```

### 2. Open Browser

- URL: https://localhost:8081
- Accept the self-signed certificate warning
- Username: `admin`
- Password: Get it with:
  ```bash
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
  ```

### 3. Login via CLI (Optional)

```bash
# Start port-forward in background
kubectl port-forward svc/argocd-server -n argocd 8081:443 &

# Login
argocd login localhost:8081 --insecure --username admin --password <password>
```

## ArgoCD Application Management

### View Applications

```bash
# List all applications
kubectl get application -n argocd

# Get details
kubectl describe application petclinic-app -n argocd

# Check sync status
argocd app get petclinic-app
```

### Manual Sync

```bash
# Sync specific app
argocd app sync petclinic-app

# Sync all apps
argocd app sync --all
```

### Application States

ArgoCD applications can be in different states:
- **Synced**: Application matches Git repository
- **OutOfSync**: Git has changes not yet applied
- **Unknown**: ArgoCD can't reach Git repository
- **Degraded**: Application is unhealthy

## Helm Charts

### Datadog Helm Chart

The Datadog agent is installed using the official Helm chart:

```bash
# Chart repository
helm repo add datadog https://helm.datadoghq.com
helm repo update

# Values file
helm/datadog/values.yaml
```

**Key Features:**
- APM (Application Performance Monitoring)
- Log collection
- Process monitoring
- Network monitoring
- Kubernetes integration

### Customizing Helm Values

Edit `helm/datadog/values.yaml` to customize:

```yaml
datadog:
  apiKey: "YOUR_API_KEY"
  appKey: "YOUR_APP_KEY"
  site: "datadoghq.com"
  
  # Enable features
  apm:
    portEnabled: true
  logsEnabled: true
  processAgent:
    enabled: true
```

Then upgrade:
```bash
helm upgrade datadog-agent datadog/datadog \
  --namespace default \
  --values helm/datadog/values.yaml
```

## GitOps Workflow

### Current Setup

1. **Git Repository**: Your code and manifests
2. **Docker Hub**: Container images
3. **ArgoCD**: Watches Git and deploys
4. **KIND Cluster**: Runs the applications

### Workflow

```
Developer → Push to Git → Docker Hub (new image) → ArgoCD detects → Auto-deploy
```

### Example Workflow

1. **Build and push new image:**
   ```bash
   ./scripts/build-and-push-dockerhub.sh 1.0.1 pavandoc1990
   ```

2. **Update Git (if using Helm values):**
   ```bash
   # Update image tag in values.yaml
   git add .
   git commit -m "Update to version 1.0.1"
   git push
   ```

3. **ArgoCD auto-syncs:**
   - ArgoCD detects Git changes
   - Pulls new image from Docker Hub
   - Updates deployment automatically

## ArgoCD Application Manifests

### PetClinic Application

**File**: `argocd/petclinic-application.yaml`

```yaml
source:
  repoURL: https://github.com/your-username/spring-boot-app.git
  targetRevision: main
  path: spring-petclinic/k8s
  helm:
    values: |
      image:
        repository: pavandoc1990/spring-petclinic
        tag: latest
        pullPolicy: Always
```

**Features:**
- Auto-sync enabled
- Self-healing enabled
- Pulls latest image dynamically

### Datadog Application

**File**: `argocd/datadog-helm-application.yaml`

```yaml
source:
  repoURL: https://charts.datadoghq.com
  chart: datadog
  targetRevision: 3.26.0
```

**Features:**
- Uses official Datadog Helm chart
- Managed via ArgoCD
- Auto-updates on chart version changes

## Troubleshooting

### ArgoCD Not Accessible

```bash
# Check ArgoCD pods
kubectl get pods -n argocd

# Check ArgoCD server logs
kubectl logs -n argocd deployment/argocd-server

# Restart port-forward
kubectl port-forward svc/argocd-server -n argocd 8081:443
```

### Application Not Syncing

```bash
# Check application status
kubectl describe application petclinic-app -n argocd

# Check for errors
argocd app get petclinic-app

# Manual sync
argocd app sync petclinic-app
```

### Datadog Not Collecting Data

```bash
# Check Datadog pods
kubectl get pods | grep datadog

# Check Datadog agent status
kubectl exec -it $(kubectl get pod -l app=datadog-agent -o jsonpath='{.items[0].metadata.name}') -- agent status

# View logs
kubectl logs -f -l app=datadog-agent
```

### Git Repository Not Accessible

```bash
# Update repository URL
kubectl edit application petclinic-app -n argocd

# Or update manifest and reapply
kubectl apply -f argocd/petclinic-application.yaml
```

## Best Practices

### 1. Use Secrets for Sensitive Data

```bash
# Create Kubernetes secret for Datadog
kubectl create secret generic datadog-secret \
  --from-literal=api-key=<api-key> \
  --from-literal=app-key=<app-key>

# Reference in Helm values
datadog:
  apiKeyExistingSecret: datadog-secret
  appKeyExistingSecret: datadog-secret
```

### 2. Use ArgoCD Projects

Create projects to organize applications:
```bash
argocd proj create petclinic-project \
  --description "PetClinic Application Project" \
  --src https://github.com/your-username/spring-boot-app.git
```

### 3. Use Application Sets (Advanced)

For multiple environments:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: petclinic-apps
spec:
  generators:
    - list:
        elements:
          - env: dev
          - env: staging
          - env: prod
  template:
    metadata:
      name: 'petclinic-{{env}}'
    spec:
      # ... application spec
```

## Resources

- **ArgoCD Docs**: https://argo-cd.readthedocs.io/
- **Datadog Helm Chart**: https://github.com/DataDog/helm-charts
- **KIND Docs**: https://kind.sigs.k8s.io/
- **Helm Docs**: https://helm.sh/docs/

## Summary

✅ **Helm**: Used for Datadog installation (package management)
✅ **ArgoCD**: Used for GitOps deployments (automated sync from Git)
✅ **KIND**: Local Kubernetes cluster
✅ **Docker Hub**: Image registry (dynamic pulls)

This setup demonstrates:
- Helm chart management
- GitOps workflows
- Automated deployments
- Infrastructure as Code
- Production-ready patterns


