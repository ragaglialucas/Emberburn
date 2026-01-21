# Security Guide - PostgreSQL Pod

**Fireball Industries Industrial IoT Edition**

*Because a data breach at 3 AM is nobody's idea of a good time*

---

## Table of Contents

- [Overview](#overview)
- [Authentication](#authentication)
- [Encryption](#encryption)
- [Network Security](#network-security)
- [RBAC & Access Control](#rbac--access-control)
- [Compliance](#compliance)
- [Security Hardening](#security-hardening)
- [Audit Logging](#audit-logging)
- [Incident Response](#incident-response)

---

## Overview

### Security Principles

1. **Defense in Depth**: Multiple layers of security
2. **Least Privilege**: Minimal permissions necessary
3. **Encryption Everywhere**: Data at rest and in transit
4. **Audit Everything**: Know who did what and when
5. **Fail Securely**: Errors should not compromise security

### Threat Model

**What we protect against:**
- Unauthorized database access
- Man-in-the-middle attacks
- Data exfiltration
- Insider threats
- Compliance violations

**What we don't protect against:**
- Physical access to nodes (that's your cloud provider's job)
- Kubernetes API compromise (secure your cluster first)
- Social engineering (train your users)

---

## Authentication

### Password Management

**Auto-Generated Passwords (Recommended)**

```yaml
postgresql:
  auth:
    postgresPassword: ""  # Empty = auto-generated
    password: ""          # Empty = auto-generated
```

Helm generates strong random passwords and stores them in Kubernetes Secrets.

**Custom Passwords**

```yaml
postgresql:
  auth:
    postgresPassword: "your-secure-password-here"
    password: "app-user-password"
```

⚠️ **Warning**: Use strong passwords (20+ chars, mixed case, numbers, symbols)

### Authentication Methods

**SCRAM-SHA-256 (Recommended)**

```yaml
postgresql:
  auth:
    authMethod: "scram-sha-256"
```

- Modern, secure authentication
- Stronger than MD5
- Required for compliance

**MD5 (Legacy)**

```yaml
postgresql:
  auth:
    authMethod: "md5"
```

⚠️ Only use for legacy application compatibility

### pg_hba.conf Configuration

The chart automatically generates pg_hba.conf. Custom rules:

```yaml
customPgHba:
  - "host    all    all    10.0.0.0/8    scram-sha-256"
  - "hostssl all    all    0.0.0.0/0     scram-sha-256"
```

**Best Practices:**
- Restrict by IP range when possible
- Use `hostssl` to require TLS
- Avoid `trust` authentication in production
- Use `scram-sha-256` over `md5`

---

## Encryption

### TLS/SSL (In Transit)

**Enable TLS**

```yaml
security:
  tls:
    enabled: true
    source: secret
    secretName: postgresql-tls
    certFile: tls.crt
    certKeyFile: tls.key
    caFile: ca.crt
```

**Using cert-manager**

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

**Generate Self-Signed Cert (Development Only)**

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=postgresql.databases.svc.cluster.local"

kubectl create secret generic postgresql-tls \
  --from-file=tls.key=tls.key \
  --from-file=tls.crt=tls.crt \
  --from-file=ca.crt=tls.crt \
  -n databases
```

### Encryption at Rest

**Storage-Level Encryption**

Use an encrypted storage class:

```yaml
persistence:
  storageClass: "encrypted-ssd"
```

Check with your cloud provider:
- **AWS**: gp3 with encryption
- **Azure**: Premium_LRS with encryption
- **GCP**: pd-ssd with encryption

**PostgreSQL Transparent Data Encryption (TDE)**

Requires PostgreSQL Enterprise Edition or pgcrypto extension.

```sql
-- Encrypt specific columns
CREATE EXTENSION pgcrypto;

CREATE TABLE sensitive_data (
  id SERIAL PRIMARY KEY,
  encrypted_field BYTEA
);

-- Insert encrypted data
INSERT INTO sensitive_data (encrypted_field)
VALUES (pgp_sym_encrypt('secret data', 'encryption-key'));

-- Query encrypted data
SELECT pgp_sym_decrypt(encrypted_field, 'encryption-key')
FROM sensitive_data;
```

---

## Network Security

### NetworkPolicy

Restrict network access to PostgreSQL:

```yaml
networkPolicy:
  enabled: true
  
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: production
  
  egress:
    - to:
        - namespaceSelector: {}
```

**Example: Allow only from app namespace**

```yaml
networkPolicy:
  enabled: true
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              app: myapp
        - podSelector:
            matchLabels:
              role: backend
      ports:
        - protocol: TCP
          port: 5432
```

### Service Configuration

**ClusterIP (Recommended)**

```yaml
service:
  type: ClusterIP
```

Only accessible within the cluster. Safest option.

**NodePort (Caution)**

```yaml
service:
  type: NodePort
  nodePort: 30432
```

Accessible from outside cluster. Use NetworkPolicy to restrict access.

**LoadBalancer (Not Recommended)**

```yaml
service:
  type: LoadBalancer
  loadBalancerSourceRanges:
    - "203.0.113.0/24"  # Your office IP range
```

Only use with strict IP whitelisting.

---

## RBAC & Access Control

### Kubernetes RBAC

The chart creates minimal RBAC permissions:

```yaml
rbac:
  create: true

serviceAccount:
  create: true
  name: postgresql
```

**What it can do:**
- Read ConfigMaps/Secrets (for configuration)
- Create Events (for logging)
- Read Pods/Endpoints (for HA coordination)

**What it cannot do:**
- Modify other resources
- Access other namespaces
- Escalate privileges

### PostgreSQL Roles

**Create Application User**

```sql
-- Connect as postgres
CREATE ROLE app_user WITH LOGIN PASSWORD 'secure-password';

-- Grant database access
GRANT CONNECT ON DATABASE production_data TO app_user;

-- Grant schema usage
GRANT USAGE ON SCHEMA public TO app_user;

-- Grant table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user;

-- Grant sequence permissions (for SERIAL columns)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_user;

-- Set default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_user;
```

**Read-Only User**

```sql
CREATE ROLE readonly WITH LOGIN PASSWORD 'readonly-password';
GRANT CONNECT ON DATABASE production_data TO readonly;
GRANT USAGE ON SCHEMA public TO readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT ON TABLES TO readonly;
```

### Row-Level Security (RLS)

```sql
-- Enable RLS on table
ALTER TABLE sensitive_data ENABLE ROW LEVEL SECURITY;

-- Create policy
CREATE POLICY tenant_isolation ON sensitive_data
  FOR ALL
  TO app_user
  USING (tenant_id = current_setting('app.current_tenant')::INTEGER);

-- Set tenant context
SET app.current_tenant = '123';
```

---

## Compliance

### 21 CFR Part 11 (FDA)

**Requirements:**
- Electronic signatures
- Audit trails
- Data integrity
- Access controls

**Configuration:**

```yaml
compliance:
  cfrPart11:
    enabled: true
    auditLogging: true
    electronicSignatures: true
    dataIntegrity: true

postgresql:
  config:
    log_statement: "all"
    log_connections: "on"
    log_disconnections: "on"
```

**Audit Trail Table:**

```sql
CREATE TABLE audit_log (
  id SERIAL PRIMARY KEY,
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  user_id TEXT,
  action TEXT,
  table_name TEXT,
  record_id INTEGER,
  old_values JSONB,
  new_values JSONB,
  signature TEXT
);

-- Trigger function for audit logging
CREATE OR REPLACE FUNCTION audit_trigger_func()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO audit_log (user_id, action, table_name, record_id, old_values, new_values)
  VALUES (current_user, TG_OP, TG_TABLE_NAME, NEW.id, row_to_json(OLD), row_to_json(NEW));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

### ISO 9001

**Requirements:**
- Document control
- Record retention
- Traceability

**Configuration:**

```yaml
compliance:
  iso9001:
    enabled: true
    documentControl: true
    recordRetention: true

backup:
  enabled: true
  retention: 2555  # 7 years
```

### GDPR

**Requirements:**
- Data encryption
- Right to be forgotten
- Audit trail
- Data minimization

**Configuration:**

```yaml
compliance:
  gdpr:
    enabled: true
    dataEncryption: true
    rightToBeForgotten: true
    auditTrail: true

security:
  tls:
    enabled: true
```

**Right to be Forgotten:**

```sql
-- Anonymize user data
UPDATE users
SET
  email = 'deleted_' || id || '@example.com',
  name = 'Deleted User',
  phone = NULL,
  address = NULL
WHERE user_id = 12345;

-- Cascade delete
DELETE FROM users WHERE user_id = 12345;
```

---

## Security Hardening

### Pod Security Standards

**Restricted Profile (Recommended)**

```yaml
security:
  podSecurityContext:
    runAsNonRoot: true
    runAsUser: 999
    fsGroup: 999
    seccompProfile:
      type: RuntimeDefault
  
  containerSecurityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: false  # PostgreSQL needs write access
    capabilities:
      drop:
        - ALL
```

### Secrets Management

**Use External Secrets Operator**

```yaml
# external-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: postgresql-credentials
spec:
  secretStoreRef:
    name: vault
    kind: SecretStore
  target:
    name: postgresql
  data:
    - secretKey: password
      remoteRef:
        key: postgresql/production/password
```

**Seal Secrets**

```bash
# Install Sealed Secrets
helm install sealed-secrets sealed-secrets/sealed-secrets -n kube-system

# Seal a secret
kubectl create secret generic postgresql \
  --from-literal=password=my-secret --dry-run=client -o yaml | \
  kubeseal -o yaml > sealed-secret.yaml
```

### Disable Unnecessary Features

```yaml
postgresql:
  extensions:
    pgCron:
      enabled: false  # Disable unless needed
```

---

## Audit Logging

### PostgreSQL Logging

**Comprehensive Logging:**

```yaml
postgresql:
  config:
    logging_collector: "on"
    log_destination: "stderr"
    log_statement: "all"  # Log all statements
    log_duration: "on"
    log_min_duration_statement: "0"  # Log all query durations
    log_connections: "on"
    log_disconnections: "on"
    log_hostname: "on"
    log_line_prefix: "%t [%p] [%u@%d] [%h] [%a] "
```

**Production Logging (Less Verbose):**

```yaml
postgresql:
  config:
    log_statement: "ddl"  # Only DDL
    log_min_duration_statement: "1000"  # Queries > 1 second
```

### Query Auditing

```sql
-- Enable pg_stat_statements
CREATE EXTENSION pg_stat_statements;

-- View slow queries
SELECT
  query,
  calls,
  total_exec_time,
  mean_exec_time,
  max_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 20;
```

### Kubernetes Audit Logging

Forward PostgreSQL logs to centralized logging:

```yaml
# FluentBit/Fluentd configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
data:
  parsers.conf: |
    [PARSER]
        Name        postgresql
        Format      regex
        Regex       ^(?<time>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}.\d{3} \w+) \[(?<pid>\d+)\] \[(?<user>\w+)@(?<database>\w+)\] \[(?<host>[\w.]+)\] (?<message>.*)$
```

---

## Incident Response

### Immediate Actions

**1. Isolate the Database**

```bash
# Scale down application pods
kubectl scale deployment myapp --replicas=0 -n production

# Apply restrictive NetworkPolicy
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: postgresql-lockdown
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: postgresql-pod
  policyTypes:
  - Ingress
  ingress: []  # Deny all
EOF
```

**2. Collect Evidence**

```bash
# Export logs
kubectl logs postgresql-0 -n databases > incident-logs-$(date +%Y%m%d-%H%M%S).txt

# Export audit trail
kubectl exec postgresql-0 -n databases -- \
  pg_dump -U fireball audit_trail > audit-$(date +%Y%m%d-%H%M%S).sql
```

**3. Change Credentials**

```bash
# Generate new password
NEW_PASSWORD=$(openssl rand -base64 32)

# Update secret
kubectl patch secret postgresql -n databases \
  -p "{\"data\":{\"password\":\"$(echo -n $NEW_PASSWORD | base64)\"}}"

# Update PostgreSQL
kubectl exec postgresql-0 -n databases -- \
  psql -U postgres -c "ALTER USER fireball WITH PASSWORD '$NEW_PASSWORD';"
```

**4. Restore from Backup**

```powershell
# Restore last known good backup
.\scripts\manage-postgresql.ps1 -Action restore -BackupFile last-good-backup.dump -Force
```

### Post-Incident

1. **Root Cause Analysis**: Review logs, identify attack vector
2. **Patch Vulnerabilities**: Update PostgreSQL, dependencies
3. **Improve Monitoring**: Add alerts for suspicious activity
4. **Update Runbooks**: Document lessons learned
5. **Security Training**: Educate team on the incident

---

## Security Checklist

### Pre-Production

- [ ] Change all default passwords
- [ ] Enable TLS/SSL
- [ ] Configure NetworkPolicy
- [ ] Enable audit logging
- [ ] Set up automated backups
- [ ] Configure RBAC with least privilege
- [ ] Use SCRAM-SHA-256 authentication
- [ ] Enable Pod Security Standards
- [ ] Review pg_hba.conf rules
- [ ] Test backup/restore procedures

### Production

- [ ] Monitor security events
- [ ] Rotate credentials quarterly
- [ ] Review access logs monthly
- [ ] Update PostgreSQL regularly
- [ ] Test disaster recovery quarterly
- [ ] Audit user permissions monthly
- [ ] Review NetworkPolicy rules
- [ ] Scan for vulnerabilities
- [ ] Monitor for unusual query patterns
- [ ] Maintain compliance documentation

---

## Additional Resources

- **PostgreSQL Security**: https://www.postgresql.org/docs/current/security.html
- **OWASP Database Security**: https://cheatsheetseries.owasp.org/cheatsheets/Database_Security_Cheat_Sheet.html
- **CIS PostgreSQL Benchmark**: https://www.cisecurity.org/benchmark/postgresql
- **Kubernetes Security**: https://kubernetes.io/docs/concepts/security/

---

<div align="center">

**Security is not a feature, it's a requirement.**

*Stay vigilant. Your data depends on it.*

**- Patrick Ryan, Fireball Industries**

</div>
