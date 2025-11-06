# Docker Hub Setup Guide

This guide explains how to use your personal Docker Hub account to version builds and deploy dynamically to Minikube.

## Prerequisites

1. **Docker Hub Account**: Sign up at https://hub.docker.com/
2. **Docker Hub Login**: Login from command line:
   ```bash
   docker login
   ```

## Quick Start

### 1. Set Your Docker Hub Username

```bash
export DOCKERHUB_USERNAME=your-username
```

### 2. Build and Push to Docker Hub

```bash
# Build and push with auto-generated version (timestamp)
./scripts/build-and-push-dockerhub.sh

# Or specify a version
./scripts/build-and-push-dockerhub.sh 1.0.0

# Or specify both username and version
./scripts/build-and-push-dockerhub.sh 1.0.0 your-username
```

This will:
- Build the JAR (if not already built)
- Build Docker image with version tag and `latest` tag
- Push both tags to Docker Hub

### 3. Deploy to Minikube from Docker Hub

```bash
# Deploy using latest tag
./scripts/deploy-minikube-dockerhub.sh

# Or specify version
./scripts/deploy-minikube-dockerhub.sh your-username 1.0.0
```

This will:
- Pull the image from Docker Hub into Minikube
- Update the Kubernetes deployment manifest
- Deploy the application
- Show you access URLs

## Workflow

### Versioning Your Builds

Each build gets two tags:
1. **Version tag**: `your-username/spring-petclinic:1.0.0` (or timestamp)
2. **Latest tag**: `your-username/spring-petclinic:latest`

### Dynamic Deployment

The deployment script:
- Uses `imagePullPolicy: Always` for `latest` tag to always pull the newest version
- Uses `imagePullPolicy: IfNotPresent` for versioned tags
- Automatically updates the Kubernetes manifest with your Docker Hub image

### Example Workflow

```bash
# 1. Set your username (once per session)
export DOCKERHUB_USERNAME=myusername

# 2. Build and push version 1.0.0
./scripts/build-and-push-dockerhub.sh 1.0.0

# 3. Deploy to Minikube
./scripts/deploy-minikube-dockerhub.sh

# Later, when you make changes:

# 4. Build and push version 1.0.1
./scripts/build-and-push-dockerhub.sh 1.0.1

# 5. Deploy latest (will use 1.0.1)
./scripts/deploy-minikube-dockerhub.sh

# Or deploy specific version
./scripts/deploy-minikube-dockerhub.sh myusername 1.0.1
```

## Image URLs

Your images will be available at:
- `https://hub.docker.com/r/your-username/spring-petclinic`
- Pull command: `docker pull your-username/spring-petclinic:latest`

## Troubleshooting

### Authentication Issues
```bash
# Re-login to Docker Hub
docker login
```

### Minikube Can't Pull Image
```bash
# Pull image into Minikube manually
minikube image pull your-username/spring-petclinic:latest
```

### Check Current Deployment
```bash
# See what image is deployed
kubectl get deployment petclinic -o jsonpath='{.spec.template.spec.containers[0].image}'

# See all images in Minikube
minikube image ls
```

## Advanced Usage

### Using Specific Versions

```bash
# Build version 2.0.0
./scripts/build-and-push-dockerhub.sh 2.0.0

# Deploy version 2.0.0 (not latest)
./scripts/deploy-minikube-dockerhub.sh myusername 2.0.0
```

### CI/CD Integration

You can integrate these scripts into CI/CD pipelines:

```yaml
# Example GitHub Actions step
- name: Build and Push
  run: |
    export DOCKERHUB_USERNAME=${{ secrets.DOCKERHUB_USERNAME }}
    ./scripts/build-and-push-dockerhub.sh ${{ github.sha }}
```

## Notes

- The `latest` tag always points to your most recent build
- Version tags are immutable and good for production
- Minikube will pull images from Docker Hub automatically
- The deployment script updates the manifest dynamically


