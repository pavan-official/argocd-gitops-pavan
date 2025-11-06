# Quick Start Guide: Spring PetClinic SRE Setup

This is a quick reference guide for deploying Spring PetClinic with Docker, Kubernetes, Datadog, and ArgoCD.

## Prerequisites Check

```bash
# Check all required tools
java -version          # Java 17+
docker --version       # Docker installed
minikube version       # Minikube installed
kubectl version        # kubectl installed
helm version           # Helm 3.x installed
```

## Quick Commands

### 1. Test Locally
```bash
cd spring-petclinic
./scripts/test-local.sh
```

### 2. Build Docker Image
```bash
cd spring-petclinic
./scripts/build-docker.sh
```

### 3. Deploy to Minikube
```bash
cd spring-petclinic
./scripts/deploy-minikube.sh
```

### 4. Install Datadog
```bash
cd spring-petclinic
# First, edit helm/datadog/values.yaml and add your API keys
./scripts/install-datadog-helm.sh
```

### 5. Install ArgoCD
```bash
cd spring-petclinic
./scripts/install-argocd.sh
```

## Access Points

### Application
- **Local**: http://localhost:8080
- **Minikube**: `minikube service petclinic`
- **Actuator**: http://localhost:8080/actuator/health

### ArgoCD
- **URL**: https://localhost:8080 (after port-forward)
- **Username**: admin
- **Password**: Run `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`

### Datadog
- **Dashboard**: https://app.datadoghq.com (login required)
- **APM**: Navigate to APM > Services > petclinic

## Common Issues

### Minikube Docker
```bash
eval $(minikube docker-env)  # Use Minikube's Docker daemon
```

### Port Forwarding
```bash
# ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Application (if needed)
kubectl port-forward svc/petclinic 8080:80
```

### View Logs
```bash
# Application logs
kubectl logs -f deployment/petclinic

# Datadog logs
kubectl logs -f -l app=datadog-agent
```

## Next Steps

1. Read `spring-petclinic/DEPLOYMENT.md` for detailed instructions
2. Review `spring-petclinic/GAP_ANALYSIS.md` for what was created
3. Practice troubleshooting Java issues in Datadog dashboard
4. Experiment with ArgoCD sync and rollback

