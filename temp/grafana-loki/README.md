# PostgreSQL Pod - Industrial IoT Edition

<div align="center">

🔥 **Fireball Industries** 🔥

*Production-ready PostgreSQL for Kubernetes*

**Because your industrial IoT data deserves better than Excel spreadsheets**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.24%2B-blue.svg)](https://kubernetes.io/)
[![Helm](https://img.shields.io/badge/Helm-3.0%2B-blue.svg)](https://helm.sh/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16%2B-blue.svg)](https://www.postgresql.org/)

*Crafted with dark millennial humor and industrial automation expertise by Patrick Ryan*

</div>

---

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Configuration](#configuration)
- [High Availability](#high-availability)
- [Backup & Restore](#backup--restore)
- [Monitoring](#monitoring)
- [Performance Tuning](#performance-tuning)
- [Troubleshooting](#troubleshooting)
- [PowerShell Scripts](#powershell-scripts)
- [Security](#security)
- [Contributing](#contributing)
- [License](#license)

---

## 🎯 Overview

Welcome to the PostgreSQL Helm chart that actually understands industrial environments. This isn't your average database deployment – it's battle-tested against SCADA systems, IoT sensors, and production environments that never sleep (unlike us).

### What Makes This Different?

- **Industrial IoT First**: Pre-configured for SCADA, time-series, and manufacturing data
- **Actually Production-Ready**: HA, backups, monitoring – all the stuff you forget until 3 AM
- **5 Resource Presets**: From Raspberry Pi to data center (we don't judge your hardware)
- **TimescaleDB Integration**: Because time-series data is 90% of industrial IoT
- **Patrick Ryan's Humor**: Makes documentation actually readable (shocking, I know)

---

## ✨ Features

### Core Capabilities

- **🚀 Deployment Modes**: Standalone or High Availability (3+ node replication)
- **📊 TimescaleDB**: Native time-series support for SCADA historians
- **🗺️ PostGIS**: Spatial data for factory floor layouts and asset tracking
- **🔄 Connection Pooling**: PgBouncer sidecar for high-concurrency workloads
- **💾 Automated Backups**: S3, NFS, or PVC with configurable retention
- **📈 Prometheus Integration**: postgres_exporter + ServiceMonitor
- **🔐 Security**: TLS, SCRAM-SHA-256, NetworkPolicy, Pod Security Standards
- **📝 Compliance**: 21 CFR Part 11, ISO 9001, GDPR configurations

### Pre-Configured Databases

Out of the box, you get:

- `production_data` - Your bread and butter
- `quality_metrics` - Because ISO 9001 isn't optional
- `maintenance_logs` - Track when things break (and they will)
- `energy_consumption` - Monitor those kWh like your bonus depends on it
- `scada_historian` - Time-series nirvana for your sensors
- `audit_trail` - For when compliance asks "who changed what?"

### Resource Presets

| Preset | Use Case | Connections | CPU | Memory | Storage |
|--------|----------|-------------|-----|--------|---------|
| **edge** | Raspberry Pi, IoT Gateway | 100 | 500m | 1Gi | 10Gi |
| **small** | Dev/Test, Small Production | 200 | 2 | 4Gi | 50Gi |
| **medium** | Standard Production | 500 | 4 | 16Gi | 200Gi |
| **large** | High-Volume Production | 1000 | 8 | 32Gi | 500Gi |
| **xlarge** | Data Warehouse, Analytics | 2000 | 16 | 64Gi | 1Ti |

---

## 🚀 Quick Start

### Prerequisites

- Kubernetes 1.24+
- Helm 3.0+
- kubectl configured
- A sense of humor (optional but recommended)

### 30-Second Deployment

```bash
# Add the chart (when published) or use local path
helm install postgresql . \
  --namespace databases \
  --create-namespace

# Get your password
kubectl get secret postgresql -n databases \
  -o jsonpath="{.data.password}" | base64 -d

# Connect
kubectl run -it --rm psql --image=postgres:16 -- \
  psql -h postgresql.databases.svc.cluster.local \
  -U fireball -d production_data
```

**Done.** You now have a PostgreSQL instance. Was that so hard?

---

## 📦 Installation

### Using Default Values (Medium Preset)

```bash
helm install my-postgresql . \
  --namespace databases \
  --create-namespace
```

### Using a Specific Preset

```bash
helm install my-postgresql . \
  --namespace databases \
  --set resourcePreset=large \
  --set deploymentMode=ha
```

### With Custom Values File

```bash
# Generate a config for your scenario
.\scripts\generate-config.ps1 -Scenario factory-monitoring

# Deploy with it
helm install my-postgresql . \
  --namespace databases \
  -f factory-monitoring-values.yaml
```

### Using PowerShell (Because You're on Windows)

```powershell
.\scripts\manage-postgresql.ps1 `
  -Action deploy `
  -ReleaseName my-postgresql `
  -Namespace databases `
  -ValuesFile factory-monitoring-values.yaml
```

---

## ⚙️ Configuration

### Essential Values

```yaml
# Choose your deployment mode
deploymentMode: standalone  # or 'ha'

# Pick a resource preset
resourcePreset: medium  # edge, small, medium, large, xlarge

# Configure authentication
postgresql:
  auth:
    username: myapp
    database: myapp_data
    # password: auto-generated if not set

# Enable TimescaleDB for time-series
postgresql:
  extensions:
    timescaledb:
      enabled: true

# Set up backups (do this!)
backup:
  enabled: true
  schedule: "0 2 * * *"  # 2 AM daily
  retention: 30
```

### Available Scenarios

Use the config generator to create pre-built configurations:

```powershell
.\scripts\generate-config.ps1 -Scenario <scenario>
```

**Scenarios:**
- `dev-minimal` - Local development (relaxed security, minimal resources)
- `factory-monitoring` - Production with TimescaleDB, optimized for SCADA
- `ha-production` - 3-node HA with sync replication
- `edge-gateway` - Lightweight for edge devices
- `data-warehouse` - Analytics workload optimization
- `compliance` - FDA/ISO/GDPR compliance settings

---

## 🔄 High Availability

### Enabling HA Mode

```yaml
deploymentMode: ha

highAvailability:
  enabled: true
  replicas: 3
  
  replication:
    synchronous: true
    synchronousCommit: "remote_apply"
    numSynchronousReplicas: 1
```

### How It Works

1. **Primary (pod-0)**: Handles all writes
2. **Standbys (pod-1, pod-2+)**: Stream replication from primary
3. **Automatic Failover**: Requires external operator (Patroni/Stolon)
4. **Headless Service**: All pods accessible individually
5. **ClusterIP Service**: Routes to primary only

### Anti-Affinity (Recommended)

```yaml
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app.kubernetes.io/name: postgresql-pod
        topologyKey: kubernetes.io/hostname
```

This ensures replicas run on different nodes. Because having all your eggs in one basket is a terrible idea.

---

## 💾 Backup & Restore

### Automated Backups

Backups run as a CronJob using `pg_dump`:

```yaml
backup:
  enabled: true
  schedule: "0 2 * * *"  # Cron schedule
  retention: 30  # Days
  
  destination:
    type: pvc  # or 's3', 'nfs'
    pvc:
      size: 200Gi
```

### Manual Backup

```bash
# Using kubectl
kubectl create job --from=cronjob/postgresql-backup \
  manual-backup-$(date +%Y%m%d-%H%M%S) -n databases

# Using PowerShell script
.\scripts\manage-postgresql.ps1 -Action backup
```

### Restore from Backup

```bash
# Copy backup to pod
kubectl cp backup.dump databases/postgresql-0:/tmp/

# Restore
kubectl exec -it postgresql-0 -n databases -- bash
export PGPASSWORD=$(cat /run/secrets/postgresql/password)
pg_restore -h localhost -U fireball -d production_data -c -v /tmp/backup.dump
```

Or use the PowerShell script:

```powershell
.\scripts\manage-postgresql.ps1 `
  -Action restore `
  -BackupFile backup.dump `
  -Database production_data
```

---

## 📊 Monitoring

### Prometheus Integration

The chart includes `postgres_exporter` and optional ServiceMonitor:

```yaml
monitoring:
  enabled: true
  
  exporter:
    enabled: true
    port: 9187
  
  serviceMonitor:
    enabled: true
    interval: 30s
```

### Key Metrics

- **Connections**: `pg_stat_database_numbackends`
- **Transaction Rate**: `pg_stat_database_xact_commit_rate`
- **Replication Lag**: `pg_replication_lag_seconds`
- **Cache Hit Ratio**: `pg_stat_database_blks_hit / (pg_stat_database_blks_read + pg_stat_database_blks_hit)`
- **Deadlocks**: `pg_stat_database_deadlocks`

### Health Checks

```powershell
# Comprehensive health check
.\scripts\manage-postgresql.ps1 -Action health-check

# Replication status (HA only)
.\scripts\manage-postgresql.ps1 -Action replication-status
```

---

## ⚡ Performance Tuning

### Preset-Based Configuration

Each preset automatically configures:
- `max_connections`
- `shared_buffers`
- `effective_cache_size`
- `work_mem`
- `maintenance_work_mem`

### Custom Tuning

Override any PostgreSQL parameter:

```yaml
postgresql:
  config:
    max_connections: "500"
    shared_buffers: "4GB"
    effective_cache_size: "12GB"
    work_mem: "64MB"
    
    # For SSDs
    random_page_cost: "1.1"
    effective_io_concurrency: "200"
```

### Connection Pooling

Enable PgBouncer for high-concurrency workloads:

```yaml
pgbouncer:
  enabled: true
  poolMode: transaction  # session, transaction, statement
  maxClientConn: 1000
  defaultPoolSize: 25
```

### Maintenance

```powershell
# Vacuum (reclaim space, update statistics)
.\scripts\manage-postgresql.ps1 -Action vacuum -Database production_data

# Analyze (update query planner statistics)
.\scripts\manage-postgresql.ps1 -Action analyze -Database production_data
```

---

## 🔧 Troubleshooting

### Common Issues

#### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n databases

# Check events
kubectl describe pod postgresql-0 -n databases

# Check logs
kubectl logs postgresql-0 -n databases
```

#### Connection Refused

```bash
# Test from inside cluster
kubectl run -it --rm debug --image=postgres:16 -- \
  pg_isready -h postgresql.databases.svc.cluster.local -p 5432

# Check service
kubectl get svc -n databases
```

#### Replication Not Working

```bash
# Check replication status
kubectl exec postgresql-0 -n databases -- \
  psql -U postgres -c "SELECT * FROM pg_stat_replication;"

# Check standby status
kubectl exec postgresql-1 -n databases -- \
  psql -U postgres -c "SELECT pg_is_in_recovery();"
```

#### Out of Disk Space

```bash
# Check PVC usage
kubectl exec postgresql-0 -n databases -- df -h /var/lib/postgresql/data

# Expand PVC (if storage class supports it)
kubectl patch pvc postgresql-data-postgresql-0 -n databases \
  -p '{"spec":{"resources":{"requests":{"storage":"500Gi"}}}}'
```

### Performance Issues

```sql
-- Find slow queries
SELECT pid, now() - query_start AS duration, query
FROM pg_stat_activity
WHERE state = 'active' AND now() - query_start > interval '1 second'
ORDER BY duration DESC;

-- Check for locks
SELECT * FROM pg_locks WHERE NOT granted;

-- Check index usage
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
ORDER BY idx_scan ASC;
```

### Getting Help

1. Check logs: `.\scripts\manage-postgresql.ps1 -Action logs`
2. Run tests: `.\scripts\test-postgresql.ps1`
3. Check [SECURITY.md](SECURITY.md) for security issues
4. Review [QUICK_REFERENCE.md](QUICK_REFERENCE.md) for commands

---

## 🛠️ PowerShell Scripts

### manage-postgresql.ps1

Complete lifecycle management:

```powershell
# Deploy
.\scripts\manage-postgresql.ps1 -Action deploy -ValuesFile my-values.yaml

# Upgrade
.\scripts\manage-postgresql.ps1 -Action upgrade -ValuesFile my-values.yaml

# Health check
.\scripts\manage-postgresql.ps1 -Action health-check

# Backup
.\scripts\manage-postgresql.ps1 -Action backup

# Delete (with confirmation)
.\scripts\manage-postgresql.ps1 -Action delete
```

### test-postgresql.ps1

Comprehensive testing suite:

```powershell
# Run all tests
.\scripts\test-postgresql.ps1 -ReleaseName postgresql -Namespace databases

# Specific test
.\scripts\test-postgresql.ps1 -TestType connection
.\scripts\test-postgresql.ps1 -TestType crud
.\scripts\test-postgresql.ps1 -TestType performance
```

### generate-config.ps1

Generate scenario-based configurations:

```powershell
# Generate config
.\scripts\generate-config.ps1 -Scenario ha-production

# Output to specific file
.\scripts\generate-config.ps1 -Scenario factory-monitoring -OutputFile custom.yaml
```

---

## 🔐 Security

See [SECURITY.md](SECURITY.md) for comprehensive security guidance.

### Quick Security Checklist

- [ ] Change default passwords (or let Helm auto-generate)
- [ ] Enable TLS for client connections
- [ ] Use `scram-sha-256` authentication
- [ ] Enable NetworkPolicy
- [ ] Apply Pod Security Standards
- [ ] Enable audit logging for compliance
- [ ] Configure backup encryption
- [ ] Regularly update PostgreSQL version
- [ ] Review and restrict pg_hba.conf rules

---

## 📚 Additional Documentation

- **[SECURITY.md](SECURITY.md)** - Security best practices, compliance, encryption
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Command cheat sheet
- **[PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)** - Technical architecture overview
- **[examples/](examples/)** - Sample configurations for different scenarios

---

## 🤝 Contributing

Found a bug? Have a feature request? Think Patrick's jokes are terrible?

1. Check existing issues
2. Open a new issue with details
3. Submit a PR if you're feeling ambitious

### Code of Conduct

Be excellent to each other. We're all trying to keep databases running.

---

## 📄 License

MIT License - See [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **PostgreSQL Community** - For building the world's most advanced open-source database
- **TimescaleDB Team** - For making time-series not terrible
- **Kubernetes Community** - For container orchestration
- **Coffee** - For making 3 AM debugging sessions possible

---

## 📞 Support

- **Documentation**: You're reading it
- **Issues**: GitHub Issues
- **Email**: patrick.ryan@fireballindustries.com
- **Coffee**: Always accepted

---

<div align="center">

**Built with ☕ by Patrick Ryan**

*Fireball Industries - Making Industrial IoT Less Painful Since 2024*

**May your queries be fast and your indexes be used.**

</div>
