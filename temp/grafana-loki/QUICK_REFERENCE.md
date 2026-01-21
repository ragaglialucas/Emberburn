# PostgreSQL Pod - Quick Reference

**Fireball Industries Industrial IoT Edition**

*Your cheat sheet for when you need answers fast (and production is down)*

---

## Common Commands

### Deployment

```powershell
# Deploy with default values
helm install postgresql . -n databases --create-namespace

# Deploy with custom config
helm install postgresql . -n databases -f my-values.yaml

# Deploy using PowerShell script
.\scripts\manage-postgresql.ps1 -Action deploy -ValuesFile factory-database.yaml

# Generate config for scenario
.\scripts\generate-config.ps1 -Scenario ha-production
```

### Upgrading

```powershell
# Upgrade release
helm upgrade postgresql . -n databases -f my-values.yaml

# Using management script
.\scripts\manage-postgresql.ps1 -Action upgrade -ValuesFile my-values.yaml
```

### Getting Information

```bash
# Get release status
helm status postgresql -n databases

# Get values
helm get values postgresql -n databases

# List all releases
helm list -n databases

# Get password
kubectl get secret postgresql -n databases -o jsonpath="{.data.password}" | base64 -d
```

---

## Connection Strings

### From Inside Cluster

```bash
# Basic connection
psql -h postgresql.databases.svc.cluster.local -U fireball -d production_data

# With password from secret
export PGPASSWORD=$(kubectl get secret postgresql -n databases -o jsonpath="{.data.password}" | base64 -d)
psql -h postgresql.databases.svc.cluster.local -U fireball -d production_data
```

### Connection String Format

```
postgresql://fireball:PASSWORD@postgresql.databases.svc.cluster.local:5432/production_data
```

### From Application (Go)

```go
connStr := fmt.Sprintf(
    "host=postgresql.databases.svc.cluster.local port=5432 user=fireball password=%s dbname=production_data sslmode=disable",
    password,
)
db, err := sql.Open("postgres", connStr)
```

### From Application (Python)

```python
import psycopg2

conn = psycopg2.connect(
    host="postgresql.databases.svc.cluster.local",
    port=5432,
    user="fireball",
    password=password,
    database="production_data"
)
```

---

## Backup & Restore

### Manual Backup

```powershell
# Trigger backup job
.\scripts\manage-postgresql.ps1 -Action backup

# Using kubectl
kubectl create job --from=cronjob/postgresql-backup manual-backup-$(date +%Y%m%d) -n databases
```

### Restore from Backup

```powershell
.\scripts\manage-postgresql.ps1 -Action restore -BackupFile backup.dump -Database production_data
```

### Export Database

```bash
# Export single database
kubectl exec postgresql-0 -n databases -- \
  pg_dump -U fireball production_data > production_data.sql

# Export all databases
kubectl exec postgresql-0 -n databases -- \
  pg_dumpall -U postgres > all_databases.sql
```

---

## Monitoring

### Health Check

```powershell
# Full health check
.\scripts\manage-postgresql.ps1 -Action health-check

# Replication status (HA only)
.\scripts\manage-postgresql.ps1 -Action replication-status
```

### Logs

```bash
# View logs
kubectl logs postgresql-0 -n databases

# Follow logs
kubectl logs -f postgresql-0 -n databases

# Using script
.\scripts\manage-postgresql.ps1 -Action logs
```

### Metrics

```bash
# Check Prometheus metrics
kubectl port-forward svc/postgresql 9187:9187 -n databases
curl http://localhost:9187/metrics
```

---

## Testing

```powershell
# Run all tests
.\scripts\test-postgresql.ps1 -ReleaseName postgresql -Namespace databases

# Specific test types
.\scripts\test-postgresql.ps1 -TestType connection
.\scripts\test-postgresql.ps1 -TestType crud
.\scripts\test-postgresql.ps1 -TestType replication
.\scripts\test-postgresql.ps1 -TestType performance
```

---

## Maintenance

### Vacuum & Analyze

```powershell
# Vacuum database
.\scripts\manage-postgresql.ps1 -Action vacuum -Database production_data

# Analyze (update statistics)
.\scripts\manage-postgresql.ps1 -Action analyze -Database production_data
```

### Reindex

```bash
# Reindex database
kubectl exec postgresql-0 -n databases -- \
  reindexdb -U fireball production_data
```

### Check Database Size

```sql
-- Connect to PostgreSQL first
SELECT 
  pg_database.datname,
  pg_size_pretty(pg_database_size(pg_database.datname)) AS size
FROM pg_database
ORDER BY pg_database_size(pg_database.datname) DESC;
```

---

## Useful SQL Queries

### Connection Info

```sql
-- Current connections
SELECT * FROM pg_stat_activity;

-- Connection count by database
SELECT datname, count(*) 
FROM pg_stat_activity 
GROUP BY datname;
```

### Performance Queries

```sql
-- Slow queries
SELECT pid, now() - query_start AS duration, query
FROM pg_stat_activity
WHERE state = 'active' AND now() - query_start > interval '1 second'
ORDER BY duration DESC;

-- Table sizes
SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 20;

-- Index usage
SELECT
  schemaname,
  tablename,
  indexname,
  idx_scan,
  pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
ORDER BY idx_scan ASC
LIMIT 20;
```

### Replication (HA Mode)

```sql
-- Replication status (run on primary)
SELECT * FROM pg_stat_replication;

-- Check if standby
SELECT pg_is_in_recovery();

-- Replication lag
SELECT
  client_addr,
  state,
  sync_state,
  CASE 
    WHEN pg_last_wal_receive_lsn() = pg_last_wal_replay_lsn() 
    THEN 0 
    ELSE EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp()))
  END AS lag_seconds
FROM pg_stat_replication;
```

---

## Troubleshooting

### Pod Not Starting

```bash
# Check pod status
kubectl get pods -n databases

# Describe pod
kubectl describe pod postgresql-0 -n databases

# Check events
kubectl get events -n databases --sort-by='.lastTimestamp'
```

### Can't Connect

```bash
# Test connectivity
kubectl run -it --rm debug --image=postgres:16 -- \
  pg_isready -h postgresql.databases.svc.cluster.local -p 5432

# Check service
kubectl get svc postgresql -n databases

# Check NetworkPolicy
kubectl get networkpolicy -n databases
```

### Out of Disk Space

```bash
# Check disk usage
kubectl exec postgresql-0 -n databases -- df -h /var/lib/postgresql/data

# Check PVC
kubectl get pvc -n databases

# Resize PVC (if storage class supports it)
kubectl patch pvc postgresql-data-postgresql-0 -n databases \
  -p '{"spec":{"resources":{"requests":{"storage":"500Gi"}}}}'
```

### High CPU/Memory

```sql
-- Find expensive queries
SELECT
  query,
  calls,
  total_exec_time,
  mean_exec_time,
  max_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 20;

-- Kill long-running query
SELECT pg_cancel_backend(pid);  -- Try to cancel
SELECT pg_terminate_backend(pid);  -- Force kill
```

---

## Resource Presets

| Preset | Connections | CPU | Memory | Storage | Use Case |
|--------|------------|-----|--------|---------|----------|
| edge | 100 | 500m | 1Gi | 10Gi | Raspberry Pi, IoT |
| small | 200 | 2 | 4Gi | 50Gi | Dev/Test |
| medium | 500 | 4 | 16Gi | 200Gi | Production |
| large | 1000 | 8 | 32Gi | 500Gi | High Volume |
| xlarge | 2000 | 16 | 64Gi | 1Ti | Data Warehouse |

---

## Configuration Scenarios

Generate pre-built configurations:

```powershell
.\scripts\generate-config.ps1 -Scenario <scenario>
```

**Available Scenarios:**
- `dev-minimal` - Development/testing
- `factory-monitoring` - Industrial IoT/SCADA
- `ha-production` - High availability
- `edge-gateway` - Edge computing
- `data-warehouse` - Analytics
- `compliance` - FDA/ISO/GDPR

---

## Emergency Procedures

### Isolate Database (Security Incident)

```bash
# Scale down applications
kubectl scale deployment myapp --replicas=0 -n production

# Block all ingress
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: postgresql-lockdown
  namespace: databases
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: postgresql-pod
  policyTypes:
  - Ingress
  ingress: []
EOF
```

### Change Password

```bash
# Generate new password
NEW_PASSWORD=$(openssl rand -base64 32)

# Update Kubernetes secret
kubectl patch secret postgresql -n databases \
  -p "{\"data\":{\"password\":\"$(echo -n $NEW_PASSWORD | base64)\"}}"

# Update PostgreSQL
kubectl exec postgresql-0 -n databases -- \
  psql -U postgres -c "ALTER USER fireball WITH PASSWORD '$NEW_PASSWORD';"

# Restart pods
kubectl rollout restart statefulset postgresql -n databases
```

### Failover (HA Mode)

```bash
# Promote replica to primary (manual)
kubectl exec postgresql-1 -n databases -- \
  psql -U postgres -c "SELECT pg_promote();"

# Update service to point to new primary
kubectl patch svc postgresql -n databases \
  -p '{"spec":{"selector":{"statefulset.kubernetes.io/pod-name":"postgresql-1"}}}'
```

---

## File Locations

### In Pod

- **Data Directory**: `/var/lib/postgresql/data/pgdata`
- **Config**: `/etc/postgresql/postgresql.conf`
- **HBA Config**: `/etc/postgresql/pg_hba.conf`
- **Logs**: `/var/lib/postgresql/data/pgdata/log/`
- **Init Scripts**: `/docker-entrypoint-initdb.d/`

### In Chart

- **Values**: `values.yaml`
- **Templates**: `templates/`
- **Examples**: `examples/`
- **Scripts**: `scripts/`

---

## Support Resources

- **Documentation**: [README.md](README.md)
- **Security**: [SECURITY.md](SECURITY.md)
- **Architecture**: [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)
- **PostgreSQL Docs**: https://www.postgresql.org/docs/
- **TimescaleDB Docs**: https://docs.timescale.com/

---

<div align="center">

**Keep this handy. You'll thank yourself at 3 AM.**

*- Patrick Ryan, Fireball Industries*

</div>
