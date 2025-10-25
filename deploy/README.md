# Deployment Guide

This folder contains reference configurations for running the Smart Closet API in containerized environments.

## Docker Compose

```
cp ../.env.example ../.env
cd deploy
docker compose up --build
```

* `docker-compose.yml` builds the API image, provisions a PostgreSQL database, and exposes the service via Nginx.
* The API service is configured with two replicas (Swarm/Compose v2) and includes container health checks.
* Nginx proxies traffic to the API containers and provides a lightweight `/healthz` endpoint for external monitoring.

## Kubernetes

The manifests under `k8s/` provide a production-ready baseline:

1. `namespace.yaml`, `configmap.yaml`, and `secret.example.yaml` bootstrap configuration and secrets.
2. `deployment.yaml` runs two API pods with readiness and liveness probes pointed at `/healthz` and a graceful `preStop` hook for termination drain.
3. `service.yaml` and `ingress.yaml` expose the API behind the cluster ingress controller.
4. `hpa.yaml` enables CPU-based autoscaling and illustrates how to plug in a custom `http_requests_per_second` metric once it is available via Prometheus Adapter.

### Apply in a test cluster

```
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
# Create a real secret from your DATABASE_URL value
kubectl create secret generic garderobus-api-secrets \
  --namespace garderobus \
  --from-literal=DATABASE_URL="postgresql://USER:PASS@HOST:5432/DBNAME"

kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/hpa.yaml
```

After deployment you can validate the health endpoint and graceful shutdown by executing:

```
kubectl get pods -n garderobus
kubectl port-forward svc/garderobus-api 8080:80 -n garderobus
curl http://localhost:8080/healthz

# Trigger a rolling restart to confirm graceful termination
kubectl rollout restart deployment garderobus-api -n garderobus
kubectl describe pod <pod-name> -n garderobus | grep -i "PreStop"
```

These steps verify that probes succeed and that Kubernetes allows each pod to sleep for five seconds before termination so in-flight requests can drain.
