# KIND Multi-Node Cluster Setup Guide

This guide explains how to set up a multi-node Kubernetes cluster using KIND that dynamically pulls images from Docker Hub.

## What is KIND?

KIND (Kubernetes in Docker) is a tool for running local Kubernetes clusters using Docker container "nodes". It's perfect for:
- Multi-node cluster testing
- CI/CD pipelines
- Local development with production-like setups

## Prerequisites

1. **Docker**: Must be installed and running
2. **KIND**: Install KIND:
   ```bash
   # macOS
   brew install kind
   
   # Linux
   curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
   chmod +x ./kind
   sudo mv ./kind /usr/local/bin/kind
   
   # Or visit: https://kind.sigs.k8s.io/docs/user/quick-start/#installation
   ```

3. **kubectl**: Kubernetes command-line tool
   ```bash
   # macOS
   brew install kubectl
   ```

## Quick Start

### 1. Set Up KIND Cluster

```bash
./scripts/setup-kind-cluster.sh
```

This creates a multi-node cluster with:
- 1 control plane node
- 2 worker nodes

### 2. Build and Push Image to Docker Hub

```bash
export DOCKERHUB_USERNAME=pavandoc1990
./scripts/build-and-push-dockerhub.sh latest pavandoc1990
```

### 3. Deploy to KIND Cluster

```bash
./scripts/deploy-kind-dockerhub.sh pavandoc1990 latest
```

## Cluster Architecture

```
┌─────────────────────────────────────┐
│  KIND Cluster: petclinic-cluster    │
├─────────────────────────────────────┤
│                                     │
│  ┌──────────────┐                   │
│  │ Control      │                   │
│  │ Plane Node   │                   │
│  └──────────────┘                   │
│                                     │
│  ┌──────────────┐  ┌──────────────┐│
│  │ Worker Node 1│  │ Worker Node 2││
│  │              │  │              ││
│  │ [PetClinic]  │  │ [PetClinic]  ││
│  │ Pod          │  │ Pod          ││
│  └──────────────┘  └──────────────┘│
│                                     │
└─────────────────────────────────────┘
```

## Dynamic Image Pulling

The deployment is configured to:
- **Always pull latest**: When using `latest` tag, `imagePullPolicy: Always`
- **Pull from Docker Hub**: Images are pulled directly from your Docker Hub repository
- **Automatic updates**: Each deployment pulls the newest image

## Workflow

### Initial Setup (One-time)

```bash
# 1. Create KIND cluster
./scripts/setup-kind-cluster.sh

# 2. Build and push image
export DOCKERHUB_USERNAME=pavandoc1990
./scripts/build-and-push-dockerhub.sh 1.0.0 pavandoc1990
```

### Deployment Workflow

```bash
# 1. Build and push new version
./scripts/build-and-push-dockerhub.sh 1.0.1 pavandoc1990

# 2. Deploy to KIND (pulls latest automatically)
./scripts/deploy-kind-dockerhub.sh pavandoc1990 latest
```

## Accessing the Application

### Option 1: Port Forward (Recommended)

```bash
kubectl port-forward svc/petclinic 8080:80
# Then open: http://localhost:8080
```

### Option 2: NodePort (if configured)

```bash
# Get NodePort
NODE_PORT=$(kubectl get svc petclinic -o jsonpath='{.spec.ports[0].nodePort}')
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "http://$NODE_IP:$NODE_PORT"
```

### Option 3: LoadBalancer (requires MetalLB)

For production-like access, install MetalLB:
```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.10/config/manifests/metallb-native.yaml
```

## Cluster Management

### Check Cluster Status

```bash
# List clusters
kind get clusters

# Get nodes
kubectl get nodes -o wide

# Check pod distribution
kubectl get pods -l app=petclinic -o wide
```

### View Pods Across Nodes

```bash
# See which node each pod is running on
kubectl get pods -l app=petclinic -o wide
```

### Delete Cluster

```bash
kind delete cluster --name petclinic-cluster
```

## Multi-Node Benefits

1. **High Availability**: Pods spread across multiple nodes
2. **Load Distribution**: Traffic distributed across worker nodes
3. **Testing**: Test production-like scenarios locally
4. **Learning**: Understand Kubernetes multi-node behavior

## Troubleshooting

### Cluster Not Starting

```bash
# Check Docker is running
docker ps

# Check KIND logs
kind logs petclinic-cluster

# Recreate cluster
kind delete cluster --name petclinic-cluster
./scripts/setup-kind-cluster.sh
```

### Image Pull Issues

```bash
# Verify image exists on Docker Hub
docker pull pavandoc1990/spring-petclinic:latest

# Load image manually into KIND
kind load docker-image pavandoc1990/spring-petclinic:latest --name petclinic-cluster

# Check pod events
kubectl describe pod -l app=petclinic
```

### Pods Not Distributed

```bash
# Check node labels
kubectl get nodes --show-labels

# Check pod distribution
kubectl get pods -l app=petclinic -o wide

# Force pod recreation
kubectl delete pod -l app=petclinic
```

## Comparison: KIND vs Minikube

| Feature | KIND | Minikube |
|---------|------|----------|
| Multi-node | ✅ Easy | ⚠️ More complex |
| Resource usage | ✅ Lightweight | ⚠️ Heavier |
| Docker Hub pull | ✅ Direct | ⚠️ Needs minikube image pull |
| CI/CD friendly | ✅ Excellent | ⚠️ Good |
| Windows support | ⚠️ Limited | ✅ Excellent |

## Next Steps

1. **Scale Application**: Test with more replicas
   ```bash
   kubectl scale deployment petclinic --replicas=4
   ```

2. **Add Ingress**: Configure ingress for external access

3. **Monitor**: Set up monitoring with Prometheus/Grafana

4. **CI/CD**: Integrate with GitHub Actions or GitLab CI

## Resources

- KIND Documentation: https://kind.sigs.k8s.io/
- Kubernetes Documentation: https://kubernetes.io/docs/
- Docker Hub: https://hub.docker.com/


