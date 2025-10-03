# Kubernetes Manifests - Carian Constellation

Complete Kubernetes manifests for deploying the Carian Constellation AI platform on AWS EKS.

## 📁 Directory Structure

```
kubernetes/
├── namespaces/
│   └── namespaces.yaml              # Namespaces, quotas, limits, network policies
├── applications/
│   ├── postgresql/
│   │   └── postgresql.yaml           # PostgreSQL StatefulSet with metrics
│   ├── open-webui/
│   │   └── open-webui.yaml           # Open WebUI deployment with HPA
│   └── perplexica/
│       └── perplexica.yaml           # Perplexica + SearXNG deployments
├── secrets/
│   ├── external-secrets.yaml         # ExternalSecret resources
│   └── create-secrets.sh             # Script to create secrets in AWS
├── ingress/
│   └── ingress.yaml                  # ALB Ingress for all services
├── monitoring/
│   └── servicemonitors.yaml          # Prometheus ServiceMonitors & alerts
└── README.md                         # This file
```

---

## 🚀 Quick Start

### Prerequisites

✅ EKS cluster deployed (via Terraform ephemeral module)  
✅ ALB Ingress Controller installed (via Terraform persistent module)  
✅ cert-manager installed (via Terraform persistent module)  
✅ External Secrets Operator installed (via Terraform persistent module)  
✅ Prometheus + Grafana installed (via Terraform persistent module)  
✅ kubectl configured to access cluster  
✅ AWS CLI configured with permissions

---

## 📋 Deployment Steps

### **Step 1: Create Secrets in AWS Secrets Manager**

```bash
cd kubernetes/secrets
chmod +x create-secrets.sh
./create-secrets.sh
```

This creates:
- ✅ PostgreSQL credentials (username + password)
- ✅ Open WebUI secrets (OpenAI API key, session secret, database URL)
- ✅ Perplexica secrets (OpenAI API key, SearXNG secret, search API key)
- ✅ Grafana admin password

**Important:** Save the generated passwords shown in the output!

---

### **Step 2: Deploy Namespaces**

```bash
kubectl apply -f namespaces/namespaces.yaml
```

This creates:
- ✅ `carian-apps` - Main application namespace
- ✅ `carian-data` - Database namespace  
- ✅ `carian-monitoring` - Monitoring namespace
- ✅ Resource quotas (4 CPU, 8GB RAM per namespace)
- ✅ Limit ranges (prevent resource abuse)
- ✅ Network policies (namespace isolation)

**Verify:**
```bash
kubectl get namespaces
kubectl get resourcequota -A
kubectl get limitrange -A
```

---

### **Step 3: Deploy External Secrets**

```bash
kubectl apply -f secrets/external-secrets.yaml
```

Wait for secrets to sync from AWS Secrets Manager (1-2 minutes):

```bash
# Watch sync status
kubectl get externalsecret -A -w

# Should show READY=True for all
# carian-data      postgresql-credentials    Ready   1m
# carian-apps      open-webui-secrets        Ready   1m
# carian-apps      perplexica-secrets        Ready   1m
```

**Verify secrets exist:**
```bash
kubectl get secret -n carian-data postgresql-credentials
kubectl get secret -n carian-apps open-webui-secrets
kubectl get secret -n carian-apps perplexica-secrets
```

---

### **Step 4: Deploy PostgreSQL Database**

```bash
kubectl apply -f applications/postgresql/postgresql.yaml
```

Wait for PostgreSQL to be ready (2-3 minutes):

```bash
# Watch pod status
kubectl get pods -n carian-data -w

# Should show:
# NAME           READY   STATUS    RESTARTS   AGE
# postgresql-0   2/2     Running   0          2m
```

**Verify database is healthy:**
```bash
# Check logs
kubectl logs -n carian-data postgresql-0 -c postgresql

# Test connection
kubectl exec -n carian-data postgresql-0 -c postgresql -- psql -U carianuser -d cariandb -c "SELECT version();"
```

---

### **Step 5: Deploy Applications**

#### Open WebUI

```bash
kubectl apply -f applications/open-webui/open-webui.yaml
```

Wait for pods to be ready:
```bash
kubectl get pods -n carian-apps -l app=open-webui -w
```

#### Perplexica (with SearXNG)

```bash
kubectl apply -f applications/perplexica/perplexica.yaml
```

Wait for pods to be ready:
```bash
kubectl get pods -n carian-apps -l app=perplexica -w
```

**Verify all applications are running:**
```bash
kubectl get pods -n carian-apps

# Should show:
# NAME                          READY   STATUS    RESTARTS   AGE
# open-webui-xxx                1/1     Running   0          3m
# open-webui-yyy                1/1     Running   0          3m
# perplexica-xxx                1/1     Running   0          2m
# perplexica-yyy                1/1     Running   0          2m
# searxng-xxx                   1/1     Running   0          2m
# searxng-yyy                   1/1     Running   0          2m
```

---

### **Step 6: Configure Ingress**

**⚠️ Before deploying ingress, update the certificate ARN!**

1. Get your ACM certificate ARN:
```bash
aws acm list-certificates --region us-east-1
```

2. Edit `ingress/ingress.yaml` and replace:
```yaml
alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:REGION:ACCOUNT:certificate/CERT_ID"
```

3. Deploy ingress:
```bash
kubectl apply -f ingress/ingress.yaml
```

Wait for ALB to be provisioned (3-5 minutes):
```bash
kubectl get ingress -A -w

# Get ALB DNS name
kubectl get ingress -n carian-apps carian-apps-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

4. Update Route53 DNS records to point to the ALB:
```bash
# Example CNAME records:
# webui.yourdomain.com      -> ALIAS -> ALB-DNS-NAME
# perplexica.yourdomain.com -> ALIAS -> ALB-DNS-NAME
# monitoring.yourdomain.com -> ALIAS -> ALB-DNS-NAME
```

---

### **Step 7: Deploy Monitoring**

```bash
kubectl apply -f monitoring/servicemonitors.yaml
```

**Verify ServiceMonitors are created:**
```bash
kubectl get servicemonitor -A

# Should show monitors for:
# - open-webui
# - perplexica
# - searxng
# - postgresql
```

**Check Prometheus targets:**
```bash
# Port-forward to Prometheus
kubectl port-forward -n carian-monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Open browser: http://localhost:9090/targets
# All targets should show as "UP"
```

---

## ✅ Verification Checklist

After deployment, verify everything is working:

### Namespace Health
```bash
kubectl get all -n carian-apps
kubectl get all -n carian-data
kubectl get all -n carian-monitoring
```

### Secret Sync
```bash
kubectl get externalsecret -A
# All should show READY=True
```

### Pod Health
```bash
kubectl get pods -A | grep -E "carian-apps|carian-data"
# All should show Running
```

### Service Endpoints
```bash
kubectl get endpoints -n carian-apps
# All services should have endpoints
```

### Ingress
```bash
kubectl get ingress -A
# Should show ALB address
```

### SSL Certificates
```bash
kubectl get certificate -n carian-apps
# Should show READY=True
```

### Monitoring
```bash
# Check Prometheus targets
kubectl port-forward -n carian-monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Check Grafana dashboards
kubectl port-forward -n carian-monitoring svc/kube-prometheus-stack-grafana 3000:80
```

---

## 🌐 Access Services

After DNS propagation (5-10 minutes):

| Service | URL | Purpose |
|---------|-----|---------|
| **Open WebUI** | https://webui.yourdomain.com | AI chat interface |
| **Perplexica** | https://perplexica.yourdomain.com | AI-powered search |
| **Grafana** | https://monitoring.yourdomain.com | Metrics & dashboards |

**Get Grafana password:**
```bash
kubectl get secret -n carian-monitoring kube-prometheus-stack-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

---

## 📊 Monitoring & Observability

### Grafana Dashboards

Pre-configured dashboards available:
- **Kubernetes Cluster** - Overall cluster health
- **Kubernetes Pods** - Pod metrics and logs
- **PostgreSQL** - Database performance
- **Node Exporter** - System metrics
- **Loki** - Log aggregation

### Prometheus Alerts

Configured alerts:
- ✅ Application downtime (5min threshold)
- ✅ High memory usage (>90%)
- ✅ High CPU usage (>90%)
- ✅ Database connection issues
- ✅ SLO violations (99.9% availability)

**View active alerts:**
```bash
kubectl port-forward -n carian-monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Navigate to: http://localhost:9090/alerts
```

---

## 🔧 Common Operations

### Scale Applications

```bash
# Scale Open WebUI
kubectl scale deployment -n carian-apps open-webui --replicas=3

# Scale Perplexica
kubectl scale deployment -n carian-apps perplexica --replicas=3
```

### Restart Applications

```bash
# Restart Open WebUI
kubectl rollout restart deployment -n carian-apps open-webui

# Restart Perplexica
kubectl rollout restart deployment -n carian-apps perplexica
```

### View Logs

```bash
# Open WebUI logs
kubectl logs -n carian-apps -l app=open-webui -f

# Perplexica logs
kubectl logs -n carian-apps -l app=perplexica,component=frontend -f

# PostgreSQL logs
kubectl logs -n carian-data postgresql-0 -c postgresql -f
```

### Database Access

```bash
# Connect to PostgreSQL
kubectl exec -it -n carian-data postgresql-0 -c postgresql -- psql -U carianuser -d cariandb

# Backup database
kubectl exec -n carian-data postgresql-0 -c postgresql -- \
  pg_dump -U carianuser cariandb > backup.sql

# Restore database
kubectl exec -i -n carian-data postgresql-0 -c postgresql -- \
  psql -U carianuser cariandb < backup.sql
```

---

## 🔐 Security Best Practices

### Secret Management
- ✅ Secrets stored in AWS Secrets Manager (encrypted at rest)
- ✅ Auto-refresh every 1 hour via External Secrets Operator
- ✅ Never commit secrets to git
- ✅ Rotate secrets every 90 days

### Network Security
- ✅ Network policies enforce namespace isolation
- ✅ Internal ALB (not publicly accessible)
- ✅ Access via Tailscale VPN only
- ✅ TLS/SSL for all ingress traffic

### Pod Security
- ✅ Non-root containers
- ✅ Read-only root filesystem where possible
- ✅ Dropped capabilities
- ✅ Resource limits enforced
- ✅ Pod security standards (baseline/restricted)

### RBAC
- ✅ ServiceAccounts for all applications
- ✅ Least privilege access
- ✅ Namespace-scoped permissions

---

## 🐛 Troubleshooting

### Secrets Not Syncing

```bash
# Check External Secrets Operator logs
kubectl logs -n external-secrets-system -l app.kubernetes.io/name=external-secrets

# Check ExternalSecret status
kubectl describe externalsecret -n carian-apps open-webui-secrets

# Manually trigger sync
kubectl annotate externalsecret -n carian-apps open-webui-secrets \
  force-sync="$(date +%s)" --overwrite
```

### Pods Not Starting

```bash
# Check pod events
kubectl describe pod -n carian-apps <pod-name>

# Check pod logs
kubectl logs -n carian-apps <pod-name> --previous

# Check resource constraints
kubectl top pods -n carian-apps
kubectl describe resourcequota -n carian-apps
```

### Database Connection Issues

```bash
# Verify PostgreSQL is running
kubectl get pods -n carian-data

# Check PostgreSQL logs
kubectl logs -n carian-data postgresql-0 -c postgresql

# Test connection from app pod
kubectl exec -n carian-apps <app-pod> -- \
  nc -zv postgresql-client.carian-data.svc.cluster.local 5432
```

### Ingress Not Working

```bash
# Check ALB Ingress Controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Verify ALB exists in AWS
aws elbv2 describe-load-balancers --region us-east-1

# Check ingress status
kubectl describe ingress -n carian-apps carian-apps-ingress
```

### High Resource Usage

```bash
# Check pod resource usage
kubectl top pods -A

# Check node resource usage
kubectl top nodes

# Describe pod for resource limits
kubectl describe pod -n carian-apps <pod-name> | grep -A 10 "Limits"
```

---

## 🗑️ Cleanup

### Delete Applications Only
```bash
kubectl delete -f applications/perplexica/
kubectl delete -f applications/open-webui/
kubectl delete -f applications/postgresql/
```

### Delete Everything
```bash
kubectl delete -f monitoring/
kubectl delete -f ingress/
kubectl delete -f applications/perplexica/
kubectl delete -f applications/open-webui/
kubectl delete -f applications/postgresql/
kubectl delete -f secrets/external-secrets.yaml
kubectl delete -f namespaces/namespaces.yaml
```

**Note:** Persistent volumes with `Retain` policy will not be deleted. Clean them up manually:
```bash
kubectl get pv
kubectl delete pv <pv-name>
```

---

## 📚 Additional Resources

- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [External Secrets Operator](https://external-secrets.io/)
- [ALB Ingress Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [cert-manager](https://cert-manager.io/)
- [Prometheus Operator](https://prometheus-operator.dev/)

---

## 🎯 Architecture Summary

```
┌─────────────────────────────────────────────────────────────┐
│                    Internet (via Tailscale)                  │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
                   ┌─────────────────────┐
                   │   Internal ALB      │
                   │  (AWS Load Balancer)│
                   └──────────┬──────────┘
                              │
                ┌─────────────┼─────────────┐
                │             │             │
                ▼             ▼             ▼
          ┌─────────┐   ┌──────────┐   ┌──────────┐
          │Open WebUI│   │Perplexica│   │ Grafana  │
          │ Pods (2) │   │ Pods (2) │   │          │
          └────┬─────┘   └────┬─────┘   └────┬─────┘
               │              │              │
               │         ┌────┴─────┐        │
               │         │ SearXNG  │        │
               │         │ Pods (2) │        │
               │         └──────────┘        │
               │                             │
               └─────────┬───────────────────┘
                         │
                         ▼
                  ┌──────────────┐
                  │  PostgreSQL  │
                  │ StatefulSet  │
                  │   (1 pod)    │
                  └──────┬───────┘
                         │
                         ▼
                   ┌──────────┐
                   │ EBS gp3  │
                   │ 20GB PV  │
                   └──────────┘

External Services:
├── AWS Secrets Manager (secret storage)
├── Route53 (DNS)
├── ACM (SSL certificates)
└── S3 (backups, logs)

Monitoring:
├── Prometheus (metrics collection)
├── Grafana (visualization)
├── Loki (log aggregation)
└── Alertmanager (alerting)
```

---

**Status:** ✅ Ready for production deployment

**Last Updated:** October 2025

**Maintained By:** Carian Constellation Team
