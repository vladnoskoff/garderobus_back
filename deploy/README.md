# Deployment Guide

This folder contains reference configurations for running the Smart Closet API in containerized environments.

## Docker Compose

```
cp ../.env.example ../.env
cd deploy
docker compose up --build
```

* `docker-compose.yml` builds the API image, provisions PostgreSQL, Redis cache, and exposes the service via Nginx.
* The stack now includes observability components: Prometheus + Alertmanager (metrics/alerts), Grafana (dashboards), Jaeger (трассировки), и Elasticsearch + Kibana + Filebeat (централизованное логирование).
* Nginx проксирует трафик к пользовательскому API и, при необходимости, к выделенному админскому API (`/admin/` → порт 8100) и экспортирует метрики через `nginx-prometheus-exporter`.

После запуска Compose стеков доступны следующие интерфейсы:

| Сервис | URL | Назначение |
|--------|-----|------------|
| API | http://localhost:8080 | Пользовательские REST запросы |
| Prometheus | http://localhost:9090 | Метрики и правила алертинга |
| Alertmanager | http://localhost:9093 | Просмотр и маршрутизация алертов |
| Grafana | http://localhost:3000 (логин: admin / admin) | Готовый дашборд `Garderobus Overview` |
| Jaeger | http://localhost:16686 | Просмотр трассировок OpenTelemetry |
| Kibana | http://localhost:5601 | Анализ структурированных логов |
| Redis metrics | http://localhost:9121/metrics | Экспортер метрик Redis для Prometheus |

> **Важно:** в `observability/alertmanager/alertmanager.yml` указан демонстрационный webhook. Замените URL на корпоративный Slack/Teams/почтовый шлюз перед использованием в проде.

### Настройка метрик и алертов

Prometheus собирает метрики с API (`/metrics`), Nginx (`/nginx_status`), Redis и cadvisor. В файле `observability/prometheus/alert_rules.yml` определены пороги по RPS, ошибкам, латентности и ресурсоёмкости контейнера API. Alertmanager маршрутизирует события в соответствии с указанным webhook.

### Логи (EFK)

API пишет структурированные JSON-логи в `/var/log/garderobus/api.log`. Filebeat читает их и отправляет в Elasticsearch, после чего они доступны в Kibana (индекс `garderobus-logs-*`).

### Трассировки (Jaeger)

При активном `TRACING_ENABLED=true` приложение публикует спаны через OpenTelemetry SDK в Jaeger (агент `jaeger:6831`). В интерфейсе Jaeger можно анализировать цепочки вызовов, задержки и ошибки внешних запросов.

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
