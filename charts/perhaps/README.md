# Perhaps Helm Chart

This Helm chart deploys Perhaps - a personal finance management application - on Kubernetes.

## Prerequisites

- Kubernetes 1.23+
- Helm 3.0+
- PostgreSQL database
- Redis instance

## Installation

```bash
# Install with default values
helm install perhaps ./charts/perhaps

# Install with custom values
helm install perhaps ./charts/perhaps -f my-values.yaml

# Production deployment
helm install perhaps ./charts/perhaps -f charts/perhaps/values-production.yaml

# Minimal deployment
helm install perhaps ./charts/perhaps -f charts/perhaps/values-minimal.yaml
```

## Configuration

See [values.yaml](values.yaml) for the complete list of configuration options.

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.image.repository` | Docker image repository | `ghcr.io/perhaps-finance/perhaps` |
| `global.image.tag` | Docker image tag | `latest` |
| `web.replicaCount` | Number of web replicas | `2` |
| `web.pdb.enabled` | Enable PodDisruptionBudget for web | `true` |
| `web.hpa.enabled` | Enable HorizontalPodAutoscaler for web | `false` |
| `worker.enabled` | Enable Sidekiq worker deployment | `true` |
| `worker.replicaCount` | Number of worker replicas | `2` |
| `database.host` | PostgreSQL host | `""` |
| `redis.url` | Redis URL | `""` |

### Example Values

- [values-production.yaml](values-production.yaml) - Production-ready configuration with high availability, HPA enabled, and proper resource limits
- [values-minimal.yaml](values-minimal.yaml) - Minimal resource configuration suitable for small deployments or testing

## Architecture

The chart deploys:

### 1. Web Deployment
- Rails web server pods
- Handles HTTP requests
- Runs database migrations (leader pod only)
- Exposes `/up` health endpoint
- Configurable horizontal scaling with HPA

### 2. Worker Deployment
- Sidekiq background job pods
- Processes background jobs
- Runs scheduled jobs (cron)
- Exposes `/health` and `/ready` endpoints on port 7433
- Graceful shutdown with TSTP signal handling

### 3. Supporting Infrastructure
- ClusterIP services for internal communication
- Optional Ingress for external access
- Pod Disruption Budgets (PDBs) for high availability
- Horizontal Pod Autoscalers (HPAs) for automatic scaling
- Pod anti-affinity rules for pod distribution across nodes

## High Availability

### Pod Disruption Budgets
PDBs ensure minimum pod availability during cluster maintenance:

```bash
# Check PDB status
kubectl get pdb
```

**Default Configuration:**
- Web: Minimum 1 pod available
- Worker: Minimum 1 pod available

Configure via values:
```yaml
web:
  pdb:
    enabled: true
    minAvailable: 2

worker:
  pdb:
    enabled: true
    minAvailable: 1
```

### Pod Anti-Affinity
By default, pods are spread across different nodes using preferred pod anti-affinity:

```yaml
web:
  defaultAntiAffinity: true  # Preferred (not required)

worker:
  defaultAntiAffinity: true
```

This helps distribute load and improves resilience to node failures.

## Autoscaling

### Horizontal Pod Autoscaler
Automatically scale web and worker pods based on CPU and memory utilization:

```bash
# Enable HPA and check status
kubectl get hpa
kubectl describe hpa <release-name>-web
```

**Configuration:**
```yaml
web:
  hpa:
    enabled: false          # Set to true to enable
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 80
```

## Health Checks

### Web Health Endpoint
- **Path:** `/up`
- **Port:** 3000
- **Purpose:** Rails application health check

### Worker Health Endpoints
- **Port:** 7433 (configurable via `worker.port`)
- **Paths:**
  - `/health` - Liveness probe (checks Redis connectivity)
  - `/ready` - Readiness probe (checks queue status)

## Graceful Shutdown

Workers are configured for graceful shutdown:
- **Grace Period:** 60 seconds (configurable)
- **Shutdown Signal:** TSTP to Sidekiq
- **Job Processing:** Allows 5 seconds for current jobs to complete

## Database Migrations

Database migrations run automatically on startup:
- Only the first/leader web pod runs migrations
- Configured via `PERHAPS_RUN_MIGRATIONS` and `PERHAPS_IS_LEADER` environment variables
- Controlled by `database.runMigrations` in values

## Upgrading

```bash
# Upgrade to a new chart version or values
helm upgrade perhaps ./charts/perhaps -f my-values.yaml

# Rollback if needed
helm rollback perhaps
```

## Monitoring

```bash
# Check deployment status
kubectl get deployments -l app.kubernetes.io/name=perhaps

# View pod status
kubectl get pods -l app.kubernetes.io/name=perhaps

# View logs
kubectl logs -f deployment/<release-name>-web
kubectl logs -f deployment/<release-name>-worker

# Check HPA status
kubectl get hpa
kubectl describe hpa <release-name>-web

# Check PDB status
kubectl get pdb
kubectl describe pdb <release-name>-web
```

## Uninstalling

```bash
helm uninstall perhaps
```

## Troubleshooting

### Pods stuck in pending state
Check node resources and pod anti-affinity:
```bash
kubectl describe pdb
kubectl describe nodes
```

### Slow HPA scaling
- Increase `targetCPUUtilizationPercentage` to be more aggressive
- Check Metrics Server: `kubectl get deployment metrics-server -n kube-system`

### Worker health check failures
- Verify Redis is accessible
- Check worker logs: `kubectl logs -l app.kubernetes.io/component=worker`
- Verify `SIDEKIQ_HEALTH_PORT` is correct

## Contributing

For issues or contributions, visit: https://github.com/perhaps-finance/perhaps
