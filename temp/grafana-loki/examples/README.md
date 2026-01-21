# PostgreSQL Example Configurations

**Fireball Industries Industrial IoT Edition**

This directory contains pre-built configurations for common deployment scenarios. Each example is production-tested and ready to deploy with minimal customization.

---

## Available Examples

### 1. minimal-postgresql.yaml

**Use Case**: Development and testing

**Features**:
- Minimal resource allocation (small preset)
- No backups (save resources)
- No monitoring
- Relaxed security for easier debugging
- Single database: `dev_database`

**Deploy**:
```bash
helm install postgresql . -n databases -f examples/minimal-postgresql.yaml
```

**⚠️ WARNING**: DO NOT use in production!

---

### 2. factory-database.yaml

**Use Case**: Industrial IoT production deployment

**Features**:
- Medium resource preset
- TimescaleDB enabled for time-series data
- PostGIS enabled for spatial data
- 5 pre-configured industrial databases
- Daily backups (2 AM)
- PgBouncer connection pooling
- Prometheus monitoring
- NetworkPolicy enabled

**Databases**:
- scada_historian (time-series sensor data)
- production_data (application data)
- quality_metrics (QA records)
- energy_consumption (power monitoring)
- maintenance_logs (equipment tracking)

**Deploy**:
```bash
helm install postgresql . -n databases -f examples/factory-database.yaml
```

---

### 3. ha-postgresql.yaml

**Use Case**: High availability production

**Features**:
- 3-node StatefulSet with streaming replication
- Large resource preset (1000 connections)
- Synchronous replication for data safety
- 6 pre-configured databases
- Backups every 6 hours, 60-day retention
- TLS enabled (requires cert-manager)
- PodDisruptionBudget (minimum 2 replicas)
- Pod anti-affinity (spread across nodes)

**Requirements**:
- 3+ worker nodes
- cert-manager installed
- Fast SSD storage class

**Deploy**:
```bash
# Update storage class and cert-manager issuer first
helm install postgresql . -n databases -f examples/ha-postgresql.yaml \
  --set persistence.storageClass=fast-ssd \
  --set security.tls.certManager.issuerRef.name=your-issuer
```

---

### 4. edge-gateway.yaml

**Use Case**: Edge computing, IoT gateways, Raspberry Pi

**Features**:
- Edge resource preset (minimal footprint)
- TimescaleDB for local sensor buffering
- 2 databases: edge_data, sensor_buffer
- Daily backups (limited 7-day retention)
- Node selector for edge nodes
- Tolerations for edge node taints
- No connection pooling (save resources)

**Deploy on Edge Node**:
```bash
# Ensure edge nodes are labeled
kubectl label node edge-node-1 node-role.kubernetes.io/edge=

# Deploy
helm install postgresql . -n databases -f examples/edge-gateway.yaml
```

---

### 5. data-warehouse.yaml

**Use Case**: Analytics, reporting, data warehouse

**Features**:
- XLarge resource preset (2000 connections max)
- Large memory allocations for complex queries
- Parallel query execution enabled
- TimescaleDB and PostGIS
- Weekly backups (analytics = read-heavy)
- Long query timeout configurations
- Optimized for analytical workloads

**Key Settings**:
- work_mem: 128MB (large for complex joins)
- max_parallel_workers: 8
- shared_buffers: 16GB

**Deploy**:
```bash
helm install postgresql . -n databases -f examples/data-warehouse.yaml
```

---

### 6. compliance-postgresql.yaml

**Use Case**: Regulated industries (FDA, ISO 9001, GDPR)

**Features**:
- HA mode with 3 replicas
- **2 synchronous standbys** (extra safety)
- Comprehensive audit logging (all statements)
- TLS encryption required
- Encrypted storage class
- 7-year backup retention (FDA compliance)
- S3 backups for archival
- NetworkPolicy restricted to validated namespace
- All compliance flags enabled

**Compliance Standards**:
- 21 CFR Part 11 (FDA electronic records)
- ISO 9001 (quality management)
- GDPR (data protection)

**Deploy**:
```bash
# Update storage class, S3 config, and cert-manager first
helm install postgresql . -n databases -f examples/compliance-postgresql.yaml \
  --set persistence.storageClass=encrypted-ssd \
  --set backup.destination.s3.bucket=your-compliance-bucket \
  --set backup.destination.s3.existingSecret=s3-credentials
```

---

## Customization Guide

### Option 1: Use as Base

```bash
# Copy example to your values file
cp examples/factory-database.yaml my-production-values.yaml

# Edit as needed
nano my-production-values.yaml

# Deploy
helm install postgresql . -n databases -f my-production-values.yaml
```

### Option 2: Override with --set

```bash
helm install postgresql . -n databases \
  -f examples/factory-database.yaml \
  --set resourcePreset=large \
  --set backup.retention=60
```

### Option 3: Merge Multiple Files

```bash
helm install postgresql . -n databases \
  -f examples/factory-database.yaml \
  -f my-overrides.yaml
```

---

## Common Customizations

### Change Storage Class

```yaml
persistence:
  storageClass: "your-storage-class"
  
  wal:
    storageClass: "your-fast-storage-class"
```

### Add Custom Databases

```yaml
postgresql:
  initialDatabases:
    - name: my_custom_db
      owner: myuser
      encoding: UTF8
      locale: en_US.utf8
```

### Configure S3 Backups

```yaml
backup:
  destination:
    type: s3
    s3:
      bucket: "my-backup-bucket"
      region: "us-east-1"
      endpoint: "https://s3.amazonaws.com"
      existingSecret: "s3-backup-credentials"
```

Create S3 secret:
```bash
kubectl create secret generic s3-backup-credentials \
  --from-literal=access-key-id=YOUR_ACCESS_KEY \
  --from-literal=secret-access-key=YOUR_SECRET_KEY \
  -n databases
```

### Enable TLS

```yaml
security:
  tls:
    enabled: true
    source: cert-manager
    certManager:
      issuerRef:
        name: letsencrypt-prod
        kind: ClusterIssuer
```

---

## Scenario Selection Guide

| Scenario | Use When | Don't Use When |
|----------|----------|----------------|
| **minimal** | Local dev, testing | Production, any real data |
| **factory-database** | Production IoT, SCADA | Need HA, compliance required |
| **ha-production** | Mission-critical production | Single node cluster, dev/test |
| **edge-gateway** | Raspberry Pi, edge devices | Central data center |
| **data-warehouse** | Analytics, BI, reporting | Real-time transactional workload |
| **compliance** | FDA, ISO, GDPR requirements | No regulatory needs |

---

## Testing Your Configuration

After deployment, run tests:

```powershell
# Test connection
.\scripts\test-postgresql.ps1 -TestType connection

# Test CRUD operations
.\scripts\test-postgresql.ps1 -TestType crud

# Full test suite
.\scripts\test-postgresql.ps1
```

---

## Migration Between Scenarios

### Dev to Production

```bash
# 1. Backup from dev
kubectl exec postgresql-0 -n databases -- \
  pg_dumpall -U postgres > dev-backup.sql

# 2. Deploy production config
helm install postgresql-prod . -n production -f examples/factory-database.yaml

# 3. Restore to production
kubectl cp dev-backup.sql production/postgresql-prod-0:/tmp/
kubectl exec postgresql-prod-0 -n production -- \
  psql -U postgres -f /tmp/dev-backup.sql
```

### Standalone to HA

```bash
# 1. Backup existing data
.\scripts\manage-postgresql.ps1 -Action backup

# 2. Deploy HA version
helm install postgresql-ha . -n databases-ha -f examples/ha-postgresql.yaml

# 3. Restore data
.\scripts\manage-postgresql.ps1 -Action restore -BackupFile backup.dump
```

---

## Pro Tips

1. **Start Small**: Begin with minimal config, scale up as needed
2. **Test Backups**: Always verify backup/restore before production
3. **Monitor First**: Enable monitoring even in dev
4. **Document Changes**: Keep your values.yaml in version control
5. **Use Presets**: Don't manually tune unless you know what you're doing
6. **Enable Backups**: Even in dev (trust me on this one)

---

## Need Help?

- **Quick Commands**: See [QUICK_REFERENCE.md](../QUICK_REFERENCE.md)
- **Security Guide**: See [SECURITY.md](../SECURITY.md)
- **Full Documentation**: See [README.md](../README.md)

---

<div align="center">

**Pick the right config, deploy with confidence**

*Because choosing the wrong database config at 3 AM is a bad idea*

**- Patrick Ryan, Fireball Industries**

</div>
