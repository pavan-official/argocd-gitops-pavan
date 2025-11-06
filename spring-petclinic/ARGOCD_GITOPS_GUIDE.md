# ArgoCD GitOps Workflow Guide

## Understanding ArgoCD's Real Purpose

ArgoCD is a **GitOps tool** that:
- ✅ Watches your Git repository for configuration changes
- ✅ Automatically syncs changes to Kubernetes
- ✅ Ensures cluster state matches Git state
- ✅ Provides audit trail of all changes
- ✅ Enables rollback to previous Git commits

**Key Point**: ArgoCD manages **configuration**, not just deployments. Docker Hub images are pulled dynamically, but the **manifests come from Git**.

## Architecture

```
┌─────────────────────────────────────────┐
│  Git Repository (Source of Truth)      │
│  - k8s/petclinic.yml                   │
│  - Configuration changes               │
└──────────────┬──────────────────────────┘
               │
               │ ArgoCD watches
               ▼
┌─────────────────────────────────────────┐
│  ArgoCD (GitOps Controller)            │
│  - Detects Git changes                  │
│  - Syncs to Kubernetes                  │
└──────────────┬──────────────────────────┘
               │
               │ Applies manifests
               ▼
┌─────────────────────────────────────────┐
│  Kubernetes Cluster (KIND)              │
│  - Pulls images from Docker Hub        │
│  - Uses config from Git                 │
└─────────────────────────────────────────┘
```

## GitOps Workflow

### 1. Configuration Changes (Real ArgoCD Use Case)

**Scenario**: You want to change replica count, resource limits, or environment variables.

```bash
# 1. Edit configuration in Git
vim k8s/petclinic.yml
# Change: replicas: 2 → replicas: 3
# Change: memory: "1Gi" → memory: "2Gi"

# 2. Commit and push
git add k8s/petclinic.yml
git commit -m "Scale to 3 replicas, increase memory"
git push

# 3. ArgoCD automatically:
#    - Detects Git change
#    - Syncs new configuration
#    - Updates deployment
#    - Pulls image from Docker Hub (if changed)
```

### 2. Image Updates (Still via Git)

**Scenario**: You built a new Docker image and want to deploy it.

```bash
# 1. Build and push new image
./scripts/build-and-push-dockerhub.sh 1.0.1 pavandoc1990

# 2. Update image tag in Git
vim k8s/petclinic.yml
# Change: image: pavandoc1990/spring-petclinic:latest
# To:     image: pavandoc1990/spring-petclinic:1.0.1

# 3. Commit and push
git add k8s/petclinic.yml
git commit -m "Deploy version 1.0.1"
git push

# 4. ArgoCD automatically:
#    - Detects Git change
#    - Pulls new image from Docker Hub
#    - Deploys new version
```

### 3. Using 'latest' Tag (Dynamic Pulls)

If you use `imagePullPolicy: Always` with `latest` tag:

```bash
# 1. Build and push new image (updates 'latest' tag)
./scripts/build-and-push-dockerhub.sh latest pavandoc1990

# 2. Trigger ArgoCD sync (no Git change needed for image)
argocd app sync petclinic-app

# ArgoCD will:
# - Pull latest image from Docker Hub
# - Deploy it
```

But the **real GitOps way** is to update the tag in Git, even if using 'latest'.

## Setting Up GitOps

### Step 1: Prepare Your Git Repository

```bash
# Make sure your manifests are in Git
git add k8s/petclinic.yml
git commit -m "Add PetClinic Kubernetes manifests"
git push
```

### Step 2: Configure ArgoCD Application

Update `argocd/petclinic-application.yaml`:

```yaml
source:
  repoURL: https://github.com/YOUR_USERNAME/spring-boot-app.git
  targetRevision: main
  path: spring-petclinic/k8s  # ArgoCD watches this path
```

### Step 3: Deploy ArgoCD Application

```bash
./scripts/deploy-argocd-apps.sh https://github.com/YOUR_USERNAME/spring-boot-app.git
```

### Step 4: Verify GitOps is Working

```bash
# Check application status
kubectl get application petclinic-app -n argocd

# View sync status
argocd app get petclinic-app
```

## Real-World GitOps Scenarios

### Scenario 1: Scale Application

```bash
# Edit k8s/petclinic.yml in Git
replicas: 2  →  replicas: 4

# Commit and push
git commit -am "Scale to 4 replicas"
git push

# ArgoCD auto-scales (no manual kubectl needed!)
```

### Scenario 2: Update Environment Variables

```bash
# Edit k8s/petclinic.yml in Git
env:
  - name: DD_ENV
    value: "dev"  →  value: "staging"

# Commit and push
git commit -am "Change environment to staging"
git push

# ArgoCD updates all pods automatically
```

### Scenario 3: Change Resource Limits

```bash
# Edit k8s/petclinic.yml in Git
resources:
  limits:
    memory: "1Gi"  →  memory: "2Gi"

# Commit and push
git commit -am "Increase memory limit"
git push

# ArgoCD applies new limits
```

### Scenario 4: Rollback Configuration

```bash
# Find previous commit
git log k8s/petclinic.yml

# Revert to previous commit
git revert <commit-hash>
git push

# Or use ArgoCD rollback
argocd app rollback petclinic-app <revision>
```

## ArgoCD Sync Modes

### Automated Sync (Current Setup)

```yaml
syncPolicy:
  automated:
    prune: true      # Delete resources removed from Git
    selfHeal: true   # Fix manual changes back to Git state
```

**Benefits:**
- Changes in Git → Auto-deployed
- Manual changes → Auto-reverted
- Deleted from Git → Auto-removed

### Manual Sync (More Control)

```yaml
syncPolicy:
  automated: {}  # Disable auto-sync
```

Then sync manually:
```bash
argocd app sync petclinic-app
```

## Best Practices

### 1. Use Git Branches for Environments

```
main → Production
staging → Staging
dev → Development
```

### 2. Use Image Tags, Not 'latest'

```yaml
# Good: Specific version
image: pavandoc1990/spring-petclinic:1.0.1

# Avoid: Latest tag (harder to track)
image: pavandoc1990/spring-petclinic:latest
```

### 3. Separate Config from Code

```
repo/
├── k8s/
│   ├── base/          # Base manifests
│   ├── overlays/
│   │   ├── dev/       # Dev configs
│   │   ├── staging/   # Staging configs
│   │   └── prod/      # Prod configs
```

### 4. Use Kustomize or Helm for Multi-Environment

ArgoCD supports:
- Raw YAML
- Kustomize
- Helm charts
- Ksonnet

## Monitoring GitOps

### Check Sync Status

```bash
# View application
kubectl get application petclinic-app -n argocd

# Detailed status
argocd app get petclinic-app

# Watch sync in real-time
argocd app get petclinic-app --watch
```

### View Sync History

```bash
# See all syncs
argocd app history petclinic-app

# Rollback to specific revision
argocd app rollback petclinic-app <revision>
```

## Troubleshooting

### Application Out of Sync

```bash
# Check what's different
argocd app diff petclinic-app

# Force sync
argocd app sync petclinic-app --force
```

### Git Repository Not Accessible

```bash
# Check repo connection
argocd repo get https://github.com/your-username/spring-boot-app.git

# Add repo credentials if needed
argocd repo add https://github.com/your-username/spring-boot-app.git \
  --username <git-user> \
  --password <git-token>
```

## Summary

**ArgoCD's Real Value:**
- ✅ **Configuration Management**: All config changes via Git
- ✅ **Audit Trail**: Every change tracked in Git history
- ✅ **Consistency**: Cluster always matches Git state
- ✅ **Automation**: No manual kubectl commands needed
- ✅ **Rollback**: Easy revert to previous Git commits

**Docker Hub Role:**
- Images are pulled from Docker Hub
- But image tags are managed in Git
- ArgoCD ensures Git → Kubernetes sync

**Workflow:**
1. Edit manifests in Git
2. Commit and push
3. ArgoCD detects change
4. ArgoCD syncs to cluster
5. Cluster pulls image from Docker Hub
6. Application updated

This is the **real GitOps workflow**!

