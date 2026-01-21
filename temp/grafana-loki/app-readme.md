# PostgreSQL Pod - Industrial IoT Edition

**Fireball Industries** - *Making Industrial IoT Less Painful Since 2024*

> Production-ready PostgreSQL for Kubernetes. Because your industrial IoT data deserves better than Excel spreadsheets.

---

## 🔥 Overview

Comprehensive Helm chart for deploying PostgreSQL in Kubernetes environments, specifically optimized for industrial IoT, SCADA systems, and manufacturing data. Battle-tested against production environments that never sleep (unlike us).

**Perfect for:**
- 🏭 Factory production data and quality metrics
- 📊 SCADA historians and time-series data
- ⚡ Energy consumption monitoring
- 🔧 Maintenance logs and audit trails
- 📍 Asset tracking with spatial data (PostGIS)
- 🎯 Manufacturing analytics and reporting
- 🌐 Edge gateway data aggregation

---

## ✨ Key Features

### Deployment Flexibility
- **Standalone Mode**: Single instance for dev/test/edge deployments
- **HA Mode**: StatefulSet with streaming replication (3-7 replicas)
- **Resource Presets**: edge/small/medium/large/xlarge for different workloads

### Industrial IoT Optimizations
- **TimescaleDB**: Native time-series support for SCADA historians
- **PostGIS**: Spatial data for factory layouts and asset tracking
- **Pre-configured Databases**: production_data, quality_metrics, energy_consumption, scada_historian, audit_trail
- **Compliance Ready**: 21 CFR Part 11, ISO 9001, GDPR configurations

### Production Features
- 💾 **Automated Backups**: S3, NFS, or PVC with configurable retention
- 🔌 **Connection Pooling**: PgBouncer sidecar for high-concurrency
- 📊 **Prometheus Integration**: postgres_exporter + ServiceMonitor
- 🔐 **Security Hardening**: TLS, SCRAM-SHA-256, NetworkPolicy, Pod Security Standards
- 🔄 **Streaming Replication**: Synchronous or asynchronous for HA
- 📈 **Performance Tuned**: Optimized for each resource preset

---

## 🚀 Quick Start

### Minimal Deployment
```bash
helm install postgresql fireball/postgresql-pod \
  --namespace databases \
  --create-namespace
```

### Production HA Deployment
```bash
helm install postgresql fireball/postgresql-pod \
  --set deploymentMode=ha \
  --set resourcePreset=large \
  --set backup.enabled=true \
  --namespace databases \
  --create-namespace
```

### With TimescaleDB for SCADA
```bash
helm install postgresql fireball/postgresql-pod \
  --set postgresql.extensions.timescaledb.enabled=true \
  --set resourcePreset=medium \
  --namespace databases \
  --create-namespace
```

### Get Connection Info
```bash
# Get password
export POSTGRES_PASSWORD=$(kubectl get secret postgresql -n databases \
  -o jsonpath="{.data.password}" | base64 -d)

# Connect
kubectl run -it --rm psql --image=postgres:16 -- \
  psql -h postgresql.databases.svc.cluster.local \
  -U fireball -d production_data
```

---

## 📊 Resource Presets

| Preset | Connections | CPU | Memory | Storage | Use Case |
|--------|-------------|-----|--------|---------|----------|
| **edge** | 100 | 500m | 1Gi | 10Gi | Edge gateways, Raspberry Pi |
| **small** | 200 | 2 | 4Gi | 50Gi | Dev/test, small production |
| **medium** | 500 | 4 | 16Gi | 200Gi | Standard production ✅ |
| **large** | 1000 | 8 | 32Gi | 500Gi | High-volume production |
| **xlarge** | 2000 | 16 | 64Gi | 1Ti | Data warehouse, analytics |

---

## 🎯 Deployment Modes

### Standalone Mode
- Single Deployment with 1 replica
- One PersistentVolumeClaim
- Perfect for: Dev/test, edge deployments, non-critical workloads

### HA Mode (High Availability)
- StatefulSet with 3+ replicas
- Streaming replication (sync or async)
- Per-replica PVCs
- Headless service for direct pod access
- Anti-affinity to spread across nodes
- Pod Disruption Budget
- Recommended: 3 replicas with sync replication

---

## 🔍 Pre-Configured Databases

Created automatically on first deployment:

| Database | Purpose |
|----------|---------|
| **production_data** | Main application data |
| **quality_metrics** | ISO 9001 quality measurements |
| **maintenance_logs** | Equipment maintenance history |
| **energy_consumption** | Energy monitoring (7-year retention) |
| **scada_historian** | Time-series SCADA data (TimescaleDB) |
| **audit_trail** | Compliance audit logs (21 CFR Part 11) |

---

## 🔌 Extensions

### TimescaleDB
Time-series database extension for SCADA historians:
```yaml
postgresql:
  extensions:
    timescaledb:
      enabled: true
```

**Benefits:**
- Optimized for time-series data (sensor readings, metrics)
- Automatic partitioning by time
- Continuous aggregates for downsampling
- Compression for long-term storage
- Retention policies for data lifecycle

### PostGIS
Spatial/geographic data extension:
```yaml
postgresql:
  extensions:
    postgis:
      enabled: true
```

**Use Cases:**
- Factory floor layouts
- Asset location tracking
- Delivery route optimization
- Warehouse management

### pg_stat_statements
Query performance monitoring:
```yaml
postgresql:
  extensions:
    pgStatStatements:
      enabled: true
```

Tracks execution statistics for all queries. Essential for production tuning.

---

## 💾 Backup & Restore

### Automated Backups
```yaml
backup:
  enabled: true
  schedule: "0 2 * * *"  # 2 AM daily
  retention: 30  # Keep 30 days
  destination:
    type: pvc  # or 's3', 'nfs'
    pvc:
      size: 200Gi
```

**Supported Destinations:**
- **PVC**: Simple cluster storage
- **S3**: AWS or S3-compatible (MinIO)
- **NFS**: Network file system

### Manual Backup
```bash
# Using kubectl
kubectl create job --from=cronjob/postgresql-backup \
  manual-backup-$(date +%Y%m%d) -n databases

# Using PowerShell script
.\scripts\manage-postgresql.ps1 -Action backup
```

### Restore
```bash
# Copy backup to pod
kubectl cp backup.dump databases/postgresql-0:/tmp/

# Restore database
kubectl exec -it postgresql-0 -n databases -- \
  pg_restore -h localhost -U postgres -d production_data \
  -c -v /tmp/backup.dump
```

---

## 🔐 Security Features

✅ **Authentication**: SCRAM-SHA-256 (modern, secure)  
✅ **TLS/SSL**: Encrypted client connections  
✅ **Network Policies**: Restrict traffic to/from database  
✅ **Pod Security Standards**: Restricted profile compliance  
✅ **RBAC**: Minimal permissions  
✅ **Secrets Management**: Auto-generated passwords  
✅ **Audit Logging**: Track all DDL/DML operations  
✅ **Compliance**: 21 CFR Part 11, ISO 9001, GDPR ready  

---

## 🔌 Connection Pooling

Enable PgBouncer for high-concurrency workloads:

```yaml
pgbouncer:
  enabled: true
  poolMode: transaction  # session, transaction, statement
  maxClientConn: 1000
  defaultPoolSize: 25
```

**Benefits:**
- Reduced connection overhead
- Better resource utilization
- Handle 1000s of connections with minimal resources
- Transaction-level pooling for most apps

---

## 📊 Monitoring

### Prometheus Integration
```yaml
monitoring:
  enabled: true
  exporter:
    enabled: true
  serviceMonitor:
    enabled: true
```

**Key Metrics:**
- Connection count and pool status
- Transaction rate and latency
- Replication lag (HA mode)
- Cache hit ratio
- Deadlocks and slow queries
- WAL generation rate
- Table/index sizes

### Health Checks
Built-in liveness and readiness probes:
- **Liveness**: `pg_isready` check
- **Readiness**: Connection test to primary database

---

## ⚡ Performance Tuning

### Automatic Tuning via Presets
Each preset configures:
- `max_connections`
- `shared_buffers` (25% of RAM)
- `effective_cache_size` (50-75% of RAM)
- `work_mem` (connection-specific)
- `maintenance_work_mem` (VACUUM, CREATE INDEX)

### Custom Tuning
Override any PostgreSQL parameter:
```yaml
postgresql:
  config:
    max_connections: "500"
    shared_buffers: "4GB"
    effective_cache_size: "12GB"
    work_mem: "64MB"
    random_page_cost: "1.1"  # For SSDs
    effective_io_concurrency: "200"
```

### Storage Optimization
```yaml
postgresql:
  config:
    # For SSDs (most cloud deployments)
    random_page_cost: "1.1"
    effective_io_concurrency: "200"
    
    # For HDDs (if you must)
    # random_page_cost: "4.0"
    # effective_io_concurrency: "2"
```

---

## 🏗️ High Availability

### Streaming Replication
```yaml
deploymentMode: ha
highAvailability:
  replicas: 3
  replication:
    synchronous: true
    synchronousCommit: "remote_apply"
    numSynchronousReplicas: 1
```

**Architecture:**
- **Primary (pod-0)**: Handles all writes
- **Standbys (pod-1, pod-2+)**: Stream replication from primary
- **Headless Service**: Access individual pods
- **ClusterIP Service**: Routes to primary only

**Synchronous Replication:**
- Waits for standby confirmation before commit
- Slower but zero data loss
- Recommended for critical data

**Asynchronous Replication:**
- Faster writes
- Small risk of data loss on primary failure
- Suitable for most workloads

---

## 📦 What's Included

- **15 Kubernetes Templates**: Deployment, StatefulSet, Services, ConfigMap, Secrets, Backup CronJob
- **6 Example Configurations**: Minimal, factory monitoring, HA, edge gateway, data warehouse, compliance
- **3 PowerShell Scripts**: Deployment management, testing, config generation
- **Comprehensive Documentation**: Security guide, quick reference, project summary

---

## 📋 Requirements

- **Kubernetes**: 1.24+ (tested on k3s, k8s, RKE2)
- **Helm**: 3.0+
- **Persistent Storage**: StorageClass with dynamic provisioning
- **Resources**: Minimum 1Gi RAM, 500m CPU, 10Gi storage
- **Optional**: Prometheus Operator for ServiceMonitor

---

## 🎨 Example Configurations

Pre-built examples in `examples/` directory:

### Factory Monitoring
```bash
helm install postgresql fireball/postgresql-pod \
  -f examples/factory-monitoring.yaml
```

### High Availability
```bash
helm install postgresql fireball/postgresql-pod \
  -f examples/ha-postgresql.yaml
```

### Edge Gateway
```bash
helm install postgresql fireball/postgresql-pod \
  -f examples/edge-gateway.yaml
```

### Data Warehouse
```bash
helm install postgresql fireball/postgresql-pod \
  -f examples/data-warehouse.yaml
```

### Compliance (21 CFR Part 11)
```bash
helm install postgresql fireball/postgresql-pod \
  -f examples/compliance-postgresql.yaml
```

---

## 🔧 Post-Installation

After installation:

1. **Get passwords**:
   ```bash
   kubectl get secret postgresql -n databases \
     -o jsonpath="{.data.password}" | base64 -d
   ```

2. **Connect from pod**:
   ```bash
   kubectl run -it --rm psql --image=postgres:16 -- \
     psql -h postgresql.databases -U fireball -d production_data
   ```

3. **Port-forward for external access**:
   ```bash
   kubectl port-forward -n databases svc/postgresql 5432:5432
   ```

4. **Verify replication (HA mode)**:
   ```bash
   kubectl exec postgresql-0 -n databases -- \
     psql -U postgres -c "SELECT * FROM pg_stat_replication;"
   ```

---

## 🛡️ Production Checklist

Before going to production:

- ✅ Set `deploymentMode: ha` with 3+ replicas
- ✅ Choose appropriate `resourcePreset` (medium or larger)
- ✅ Enable automated backups with tested restore procedure
- ✅ Configure TLS for client connections
- ✅ Use SCRAM-SHA-256 authentication
- ✅ Enable network policies
- ✅ Set up monitoring (ServiceMonitor)
- ✅ Configure anti-affinity for replica spread
- ✅ Test failover procedures
- ✅ Review and tune PostgreSQL configuration
- ✅ Enable audit logging for compliance

---

## 🔄 Upgrade & Rollback

```bash
# Upgrade
helm upgrade postgresql fireball/postgresql-pod \
  --reuse-values \
  --set resourcePreset=large \
  --namespace databases

# Rollback
helm rollback postgresql --namespace databases
```

---

## 🗑️ Uninstall

```bash
# Uninstall (PVCs retained by default)
helm uninstall postgresql --namespace databases

# Delete PVCs (PERMANENT DATA LOSS)
kubectl delete pvc -n databases -l app.kubernetes.io/instance=postgresql
```

---

## 🛠️ PowerShell Scripts

### manage-postgresql.ps1
Complete lifecycle management:
```powershell
# Deploy
.\scripts\manage-postgresql.ps1 -Action deploy

# Health check
.\scripts\manage-postgresql.ps1 -Action health-check

# Backup
.\scripts\manage-postgresql.ps1 -Action backup

# Restore
.\scripts\manage-postgresql.ps1 -Action restore -BackupFile backup.dump
```

### test-postgresql.ps1
Comprehensive testing:
```powershell
# Run all tests
.\scripts\test-postgresql.ps1

# Specific test
.\scripts\test-postgresql.ps1 -TestType connection
.\scripts\test-postgresql.ps1 -TestType performance
```

### generate-config.ps1
Generate scenario-based configs:
```powershell
.\scripts\generate-config.ps1 -Scenario factory-monitoring
.\scripts\generate-config.ps1 -Scenario ha-production
```

---

## 📚 Documentation

- **[SECURITY.md](SECURITY.md)** - Security best practices and compliance
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Command cheat sheet
- **[PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)** - Technical architecture
- **[examples/](examples/)** - Sample configurations

---

## 🔥 About Fireball Industries

**Making Industrial IoT Less Painful Since 2024**

We're infrastructure engineers who've debugged PostgreSQL at 3 AM more times than we'd like. We build tools to prevent you from experiencing the same horrors.

- Security-hardened by default
- Production-tested configurations  
- Comprehensive documentation
- Automation-first approach
- Patrick Ryan's dark millennial humor included

**Website**: https://fireballindustries.com  
**Email**: patrick.ryan@fireballindustries.com

---

## 📄 License

MIT License - Copyright © 2026 Fireball Industries

---

**Built with ☕ by Patrick Ryan**

*May your queries be fast and your indexes be used.*

---

**Deploy in < 5 minutes:**

```bash
helm install postgresql fireball/postgresql-pod --namespace databases --create-namespace
```

Done. Go get coffee. ☕
