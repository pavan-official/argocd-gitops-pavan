# Spring PetClinic Deployment Guide

This guide provides step-by-step instructions for deploying the Spring PetClinic application locally, containerizing it, deploying to Minikube, integrating Datadog monitoring, and setting up ArgoCD for GitOps deployments.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Local Testing](#local-testing)
3. [Dockerization](#dockerization)
4. [Minikube Deployment](#minikube-deployment)
5. [Datadog Integration](#datadog-integration)
6. [ArgoCD Setup](#argocd-setup)
7. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Software

- **Java 17+**: Required for building and running the application
  ```bash
  java -version  # Verify installation
  ```

- **Maven**: Included via Maven wrapper (`mvnw`), but you can also install Maven separately
  ```bash
  ./mvnw --version
  ```

- **Docker**: For containerizing the application
  ```bash
  docker --version
  ```

- **Minikube**: For local Kubernetes cluster
  ```bash
  minikube version
  # Install: https://minikube.sigs.k8s.io/docs/start/
  ```

- **kubectl**: Kubernetes command-line tool
  ```bash
  kubectl version --client
  ```

- **Helm 3.x**: For installing Datadog agent
  ```bash
  helm version
  # Install: https://helm.sh/docs/intro/install/
  ```

- **ArgoCD CLI** (optional): For GitOps operations
  ```bash
  argocd version --client
  # Install: https://argo-cd.readthedocs.io/en/stable/cli_installation/
  ```

### Datadog Account

- Sign up for a free Datadog account at https://www.datadoghq.com/
- Get your API key and App key from the Datadog dashboard

## Local Testing

### Step 1: Test the Application Locally

Use the provided script to build and run the application:

```bash
cd spring-petclinic
chmod +x scripts/test-local.sh
./scripts/test-local.sh
```

Or manually:

```bash
# Build the application
./mvnw clean package -DskipTests

# Run the application
java -jar target/spring-petclinic-*.jar
```

The application will be available at:
- **Main Application**: http://localhost:8080
- **Actuator Endpoints**: http://localhost:8080/actuator
- **Health Check**: http://localhost:8080/actuator/health

### Step 2: Test with PostgreSQL (Optional)

```bash
# Start PostgreSQL using Docker Compose
docker compose up -d postgres

# Run application with PostgreSQL profile
SPRING_PROFILES_ACTIVE=postgres java -jar target/spring-petclinic-*.jar
```

## Dockerization

### Step 1: Build Docker Image

Use the provided script:

```bash
chmod +x scripts/build-docker.sh
./scripts/build-docker.sh
```

Or manually:

```bash
docker build -t petclinic:latest .
```

### Step 2: Test Docker Image Locally

```bash
# Run with default H2 database
docker run -p 8080:8080 petclinic:latest

# Run with PostgreSQL (if running locally)
docker run -p 8080:8080 \
  -e SPRING_PROFILES_ACTIVE=postgres \
  -e SPRING_DATASOURCE_URL=jdbc:postgresql://host.docker.internal:5432/petclinic \
  -e SPRING_DATASOURCE_USERNAME=petclinic \
  -e SPRING_DATASOURCE_PASSWORD=petclinic \
  petclinic:latest
```

### Step 3: Verify Health Checks

```bash
# Check container health
docker ps

# Test health endpoint
curl http://localhost:8080/actuator/health
```

## Minikube Deployment

### Step 1: Start Minikube

```bash
# Start Minikube (if not already running)
minikube start

# Verify Minikube is running
minikube status
```

### Step 2: Deploy to Minikube

Use the provided script:

```bash
chmod +x scripts/deploy-minikube.sh
./scripts/deploy-minikube.sh
```

Or manually:

```bash
# Use Minikube's Docker daemon
eval $(minikube docker-env)

# Build Docker image
docker build -t petclinic:latest .

# Deploy database
kubectl apply -f k8s/db.yml

# Wait for database to be ready
kubectl wait --for=condition=available --timeout=120s deployment/demo-db

# Deploy application
kubectl apply -f k8s/petclinic.yml

# Wait for application to be ready
kubectl wait --for=condition=available --timeout=120s deployment/petclinic
```

### Step 3: Access the Application

```bash
# Get service URL
minikube service petclinic

# Or get NodePort directly
NODE_PORT=$(kubectl get svc petclinic -o jsonpath='{.spec.ports[0].nodePort}')
NODE_IP=$(minikube ip)
echo "http://$NODE_IP:$NODE_PORT"
```

### Step 4: Verify Deployment

```bash
# Check pods
kubectl get pods

# Check services
kubectl get svc

# View logs
kubectl logs -f deployment/petclinic

# Describe deployment
kubectl describe deployment petclinic
```

## Datadog Integration

### Step 1: Configure Datadog Values

Edit `helm/datadog/values.yaml` and update:

```yaml
datadog:
  apiKey: "YOUR_DATADOG_API_KEY"  # Replace with your API key
  appKey: "YOUR_DATADOG_APP_KEY"  # Replace with your App key
```

### Step 2: Install Datadog Agent with Helm

Use the provided script:

```bash
chmod +x scripts/install-datadog-helm.sh
./scripts/install-datadog-helm.sh
```

Or manually:

```bash
# Add Datadog Helm repository
helm repo add datadog https://helm.datadoghq.com
helm repo update

# Install Datadog Agent
helm upgrade --install datadog-agent datadog/datadog \
  --namespace default \
  --values helm/datadog/values.yaml \
  --wait
```

### Step 3: Verify Datadog Installation

```bash
# Check Datadog pods
kubectl get pods | grep datadog

# View Datadog agent logs
kubectl logs -f -l app=datadog-agent

# Check Datadog agent status
kubectl exec -it $(kubectl get pod -l app=datadog-agent -o jsonpath='{.items[0].metadata.name}') -- agent status
```

### Step 4: Verify Java Application Monitoring

1. **Check Datadog Dashboard**: Log into your Datadog account and navigate to APM > Services
2. **Verify Traces**: Look for traces from the `petclinic` service
3. **Check Metrics**: Navigate to Metrics > Explorer and search for `petclinic.*`
4. **View Logs**: Navigate to Logs and filter by service `petclinic`

### Step 5: Understanding Java Issues with Datadog

Datadog APM provides insights into:

- **Performance Issues**: Slow endpoints, database queries, external API calls
- **Error Rates**: Application errors, exceptions, stack traces
- **Resource Usage**: CPU, memory, garbage collection metrics
- **Distributed Tracing**: Request flows across services
- **Database Performance**: Query performance, connection pool usage

#### Common Java Issues to Monitor:

1. **Memory Leaks**: Monitor heap usage over time
2. **GC Pauses**: Check garbage collection frequency and duration
3. **Slow Queries**: Database query performance
4. **Thread Pool Exhaustion**: Monitor thread pool metrics
5. **Connection Pool Issues**: Database connection pool exhaustion

#### Datadog APM Annotations:

The application is configured with Datadog annotations:
- `DD_SERVICE`: Service name (petclinic)
- `DD_ENV`: Environment (dev)
- `DD_VERSION`: Application version
- `DD_LOGS_INJECTION`: Enable log correlation
- `DD_TRACE_ENABLED`: Enable distributed tracing
- `DD_PROFILING_ENABLED`: Enable continuous profiling

## ArgoCD Setup

### Step 1: Install ArgoCD

Use the provided script:

```bash
chmod +x scripts/install-argocd.sh
./scripts/install-argocd.sh
```

Or manually:

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
```

### Step 2: Access ArgoCD UI

```bash
# Port forward to ArgoCD server
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

Access ArgoCD UI at: https://localhost:8080
- Username: `admin`
- Password: (from command above)

### Step 3: Configure ArgoCD CLI (Optional)

```bash
# Login to ArgoCD
argocd login localhost:8080 --insecure

# Update password (optional)
argocd account update-password
```

### Step 4: Deploy Applications via ArgoCD

**Before deploying, update the Git repository URL in `argocd/application.yaml`:**

```yaml
source:
  repoURL: https://github.com/YOUR_USERNAME/spring-boot-app.git  # Update this
```

Then deploy:

```bash
# Deploy PetClinic application
kubectl apply -f argocd/application.yaml

# Deploy Datadog agent (optional)
kubectl apply -f argocd/datadog-application.yaml
```

### Step 5: Verify ArgoCD Applications

```bash
# List applications
argocd app list

# Get application status
argocd app get petclinic-app

# View application in UI
# Open https://localhost:8080 and navigate to Applications
```

## Troubleshooting

### Local Testing Issues

**Problem**: Application fails to start
- **Solution**: Check Java version (requires Java 17+)
- **Solution**: Check port 8080 is not in use
- **Solution**: Review application logs

**Problem**: Build fails
- **Solution**: Run `./mvnw clean` and rebuild
- **Solution**: Check Maven wrapper permissions: `chmod +x mvnw`

### Docker Issues

**Problem**: Docker build fails
- **Solution**: Ensure Docker daemon is running
- **Solution**: Check Dockerfile syntax
- **Solution**: Review build logs for specific errors

**Problem**: Container exits immediately
- **Solution**: Check container logs: `docker logs <container-id>`
- **Solution**: Verify health check endpoint is accessible
- **Solution**: Check environment variables

### Minikube Issues

**Problem**: Pods not starting
- **Solution**: Check Minikube status: `minikube status`
- **Solution**: Check pod logs: `kubectl logs <pod-name>`
- **Solution**: Describe pod: `kubectl describe pod <pod-name>`

**Problem**: Cannot access service
- **Solution**: Verify service is running: `kubectl get svc`
- **Solution**: Check NodePort assignment
- **Solution**: Verify firewall rules

### Datadog Issues

**Problem**: Datadog agent not collecting metrics
- **Solution**: Verify API key is correct in `values.yaml`
- **Solution**: Check agent logs: `kubectl logs -l app=datadog-agent`
- **Solution**: Verify agent status: `kubectl exec -it <datadog-pod> -- agent status`

**Problem**: No traces in Datadog
- **Solution**: Verify Java agent is mounted: `kubectl describe pod <petclinic-pod>`
- **Solution**: Check `JAVA_TOOL_OPTIONS` environment variable
- **Solution**: Verify `DD_APM_ENABLED=true` in deployment

**Problem**: Java agent not found
- **Solution**: The init container pattern in `k8s/petclinic.yml` may need adjustment
- **Solution**: Consider using Datadog Admission Controller for automatic injection
- **Solution**: Manually copy agent JAR to shared volume

### ArgoCD Issues

**Problem**: Application stuck in "Progressing" state
- **Solution**: Check application logs: `argocd app logs petclinic-app`
- **Solution**: Verify Git repository is accessible
- **Solution**: Check sync policy settings

**Problem**: Cannot access ArgoCD UI
- **Solution**: Verify port-forward is running
- **Solution**: Check ArgoCD server pod is running: `kubectl get pods -n argocd`
- **Solution**: Try accessing via `kubectl port-forward` again

## Next Steps

1. **Set up CI/CD Pipeline**: Integrate with GitHub Actions or GitLab CI
2. **Configure Production Environment**: Set up production-grade Kubernetes cluster
3. **Implement Monitoring Alerts**: Configure Datadog alerts for critical metrics
4. **Set up Log Aggregation**: Configure centralized logging
5. **Performance Testing**: Run load tests and analyze with Datadog
6. **Security Hardening**: Implement network policies, RBAC, secrets management

## Additional Resources

- [Spring Boot Documentation](https://spring.io/projects/spring-boot)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Datadog Documentation](https://docs.datadoghq.com/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)

