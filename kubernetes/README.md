# Kubernetes Manifests

This directory contains all Kubernetes resource definitions for Carian Constellation applications.

## Directory Structure

### `namespaces/`
Namespace definitions with resource quotas and Pod Security Standards:
- `carian-apps` - Main applications (4 CPU / 8Gi RAM)
- `carian-data` - Data layer (2 CPU / 4Gi RAM)
- `carian-monitoring` - Observability stack (privileged)

Each namespace includes:
- ResourceQuotas (CPU, memory, PVC limits)
- LimitRanges (default resource requests/limits)
- NetworkPolicies (service isolation)
- Pod Security Standards labels

### `applications/`
Application deployments organized by service:

**`open-webui/`** - AI chat interface
- Deployment with resource limits
- Service (ClusterIP)
- PersistentVolumeClaim (EBS)
- ConfigMap for configuration

**`perplexica/`** - AI-powered search
- Perplexica deployment
- SearXNG deployment (search backend)
- Services for both components
- ConfigMaps for search configuration

**`authelia/`** - Authentication gateway
- Deployment with WebAuthn configuration
- Service (ClusterIP)
- ConfigMap for access control rules
- Redis StatefulSet for session storage

**`postgresql/`** - Database
- StatefulSet for persistence
- Service (headless for StatefulSet)
- PersistentVolumeClaim (EBS with snapshots)
- ConfigMap for database initialization

### `secrets/`
External Secrets configurations (synced from AWS Secrets Manager):
- `open-webui-secrets` - API keys for LLM providers
- `authelia-secrets` - Session secrets, encryption keys
- `postgresql-secrets` - Database passwords
- `monitoring-secrets` - Grafana admin password

**Note**: Uses External Secrets Operator with IRSA (no static AWS credentials)

### `ingress/`
ALB Ingress resources for service routing:
- `main-ingress.yaml` - Routes for all services
- Annotations for ALB configuration
- Health check paths
- SSL/TLS termination via cert-manager

Services exposed:
- `webui.yourdomain.com` → Open-WebUI
- `perplexica.yourdomain.com` → Perplexica
- `auth.yourdomain.com` → Authelia
- `monitoring.yourdomain.com` → Grafana
- `homepage.yourdomain.com` → Homepage

### `monitoring/`
ServiceMonitors and PrometheusRules:
- `servicemonitors.yaml` - Scrape configs for Prometheus
- `prometheusrules.yaml` - Alerting rules
- `grafana-dashboards.yaml` - ConfigMaps with dashboards

## Deployment Order

```bash
# 1. Create namespaces first (sets up quotas and security)
kubectl apply -f namespaces/

# 2. Set up External Secrets (syncs from AWS Secrets Manager)
kubectl apply -f secrets/

# Wait for secrets to sync
kubectl get externalsecret -A
# All should show READY=True

# 3. Deploy data layer (database needs to be ready first)
kubectl apply -f applications/postgresql/

# Wait for PostgreSQL to be ready
kubectl wait --for=condition=ready pod -l app=postgresql -n carian-data --timeout=300s

# 4. Deploy applications
kubectl apply -f applications/open-webui/
kubectl apply -f applications/perplexica/
kubectl apply -f applications/authelia/

# 5. Deploy ingress (after all services are running)
kubectl apply -f ingress/

# 6. Deploy monitoring (ServiceMonitors for running services)
kubectl apply -f monitoring/
```

## Namespace Architecture

### carian-apps (Main Applications)
**Pod Security**: Baseline (enforced), Restricted (audit/warn)
**Resource Quota**:
- CPU: 4 cores (requests), 8 cores (limits)
- Memory: 8Gi (requests), 16Gi (limits)
- PVCs: 10 max

**Services**:
- Open-WebUI (AI chat)
- Perplexica (AI search)
- Authelia (authentication)
- Homepage (dashboard)

### carian-data (Data Layer)
**Pod Security**: Baseline (enforced)
**Resource Quota**:
- CPU: 2 cores (requests), 4 cores (limits)
- Memory: 4Gi (requests), 8Gi (limits)
- PVCs: 5 max

**Services**:
- PostgreSQL (database)
- Redis (session storage)

### carian-monitoring (Observability)
**Pod Security**: Privileged (for node-exporter, cAdvisor)
**Resource Quota**: None (monitoring needs flexibility)

**Services**:
- Prometheus (metrics)
- Grafana (visualization)
- Loki (logs)
- Alertmanager (alerts)

## External Secrets Pattern

Instead of creating Kubernetes Secrets directly, we use External Secrets Operator:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secrets
  namespace: carian-apps
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: app-secrets  # Creates this Kubernetes Secret
    creationPolicy: Owner
  data:
    - secretKey: API_KEY
      remoteRef:
        key: constellation/app/api-key  # Path in AWS Secrets Manager
```

**Benefits**:
- Secrets stored centrally in AWS Secrets Manager
- No secrets committed to git
- IRSA for authentication (no AWS credentials in cluster)
- Automatic rotation when secrets change
- Audit trail via CloudTrail

## Ingress Configuration

ALB Ingress with cert-manager for TLS:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: main-ingress
  namespace: carian-apps
  annotations:
    # ALB-specific
    alb.ingress.kubernetes.io/scheme: internal  # Private ALB (Tailscale only)
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'

    # cert-manager
    cert-manager.io/cluster-issuer: letsencrypt-prod

    # Authelia forward auth
    nginx.ingress.kubernetes.io/auth-url: "https://auth.yourdomain.com/api/verify"
```

## Common Operations

### Check all pods status
```bash
kubectl get pods -A
```

### View External Secrets sync status
```bash
kubectl get externalsecret -A
kubectl describe externalsecret -n carian-apps open-webui-secrets
```

### View logs for a service
```bash
kubectl logs -n carian-apps -l app=open-webui -f
kubectl logs -n carian-data postgresql-0 -c postgresql -f
```

### Check resource usage
```bash
kubectl top nodes
kubectl top pods -n carian-apps
kubectl describe resourcequota -n carian-apps
```

### Port forward for local testing
```bash
kubectl port-forward -n carian-apps svc/open-webui 8080:80
kubectl port-forward -n carian-monitoring svc/grafana 3000:80
```

### Scale deployments
```bash
kubectl scale deployment -n carian-apps open-webui --replicas=2
```

### Restart deployments
```bash
kubectl rollout restart deployment -n carian-apps open-webui
kubectl rollout status deployment -n carian-apps open-webui
```

## Validation

### Dry-run (client-side)
```bash
kubectl apply --dry-run=client -f namespaces/
```

### Dry-run (server-side validation)
```bash
kubectl apply --dry-run=server -f applications/
```

### Check for deprecated APIs
```bash
kubectl-convert -f namespaces/namespaces.yaml
```

## Important Notes

- **Never commit** inline Kubernetes Secrets (use External Secrets Operator)
- **Always set** resource requests/limits for production workloads
- **Use** Pod Security Standards (baseline minimum, restricted preferred)
- **Enable** NetworkPolicies for namespace isolation
- **Test** manifests with dry-run before applying
- **Monitor** resource quotas to avoid pod eviction
