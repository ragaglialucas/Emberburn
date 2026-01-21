# PostgreSQL Management Script
# Fireball Industries - Industrial IoT Edition
# Author: Patrick Ryan (who's deployed this at 3 AM more times than he'd like to admit)
#
# Usage:
#   .\manage-postgresql.ps1 -Action <action> [parameters]
#
# Actions:
#   deploy, upgrade, delete, backup, restore, health-check, replication-status, vacuum, analyze

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('deploy', 'upgrade', 'delete', 'backup', 'restore', 'health-check', 'replication-status', 'vacuum', 'analyze', 'logs')]
    [string]$Action,
    
    [Parameter(Mandatory=$false)]
    [string]$ReleaseName = "postgresql",
    
    [Parameter(Mandatory=$false)]
    [string]$Namespace = "databases",
    
    [Parameter(Mandatory=$false)]
    [string]$ValuesFile = "",
    
    [Parameter(Mandatory=$false)]
    [string]$ChartPath = ".",
    
    [Parameter(Mandatory=$false)]
    [string]$BackupFile = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Database = "production_data",
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# Color output functions (because life's too short for boring terminals)
function Write-FireballSuccess {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-FireballError {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-FireballWarning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-FireballInfo {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor Cyan
}

function Write-FireballHeader {
    param([string]$Message)
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host "  $Message" -ForegroundColor Magenta
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host ""
}

# Check prerequisites
function Test-Prerequisites {
    Write-FireballInfo "Checking prerequisites..."
    
    # Check kubectl
    try {
        $null = kubectl version --client 2>&1
        Write-FireballSuccess "kubectl found"
    }
    catch {
        Write-FireballError "kubectl not found. Please install kubectl."
        exit 1
    }
    
    # Check helm
    try {
        $null = helm version --short 2>&1
        Write-FireballSuccess "Helm found"
    }
    catch {
        Write-FireballError "Helm not found. Please install Helm 3.x."
        exit 1
    }
    
    # Check cluster connection
    try {
        $null = kubectl cluster-info 2>&1
        Write-FireballSuccess "Connected to Kubernetes cluster"
    }
    catch {
        Write-FireballError "Cannot connect to Kubernetes cluster."
        exit 1
    }
}

# Deploy PostgreSQL
function Deploy-PostgreSQL {
    Write-FireballHeader "Deploying PostgreSQL - $ReleaseName"
    
    # Create namespace if it doesn't exist
    $namespaceExists = kubectl get namespace $Namespace 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-FireballInfo "Creating namespace: $Namespace"
        kubectl create namespace $Namespace
    }
    
    # Build Helm command
    $helmArgs = @(
        "install",
        $ReleaseName,
        $ChartPath,
        "--namespace", $Namespace,
        "--create-namespace"
    )
    
    if ($ValuesFile) {
        $helmArgs += "--values", $ValuesFile
    }
    
    if ($DryRun) {
        $helmArgs += "--dry-run", "--debug"
    }
    
    Write-FireballInfo "Executing: helm $($helmArgs -join ' ')"
    
    & helm $helmArgs
    
    if ($LASTEXITCODE -eq 0) {
        Write-FireballSuccess "PostgreSQL deployed successfully!"
        
        if (-not $DryRun) {
            Write-FireballInfo "Waiting for pods to be ready..."
            kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=$ReleaseName -n $Namespace --timeout=300s
            
            Write-FireballInfo "Getting connection information..."
            Write-Host ""
            & helm get notes $ReleaseName -n $Namespace
        }
    }
    else {
        Write-FireballError "Deployment failed!"
        exit 1
    }
}

# Upgrade PostgreSQL
function Upgrade-PostgreSQL {
    Write-FireballHeader "Upgrading PostgreSQL - $ReleaseName"
    
    $helmArgs = @(
        "upgrade",
        $ReleaseName,
        $ChartPath,
        "--namespace", $Namespace
    )
    
    if ($ValuesFile) {
        $helmArgs += "--values", $ValuesFile
    }
    
    if ($DryRun) {
        $helmArgs += "--dry-run", "--debug"
    }
    
    Write-FireballInfo "Executing: helm $($helmArgs -join ' ')"
    
    & helm $helmArgs
    
    if ($LASTEXITCODE -eq 0) {
        Write-FireballSuccess "PostgreSQL upgraded successfully!"
    }
    else {
        Write-FireballError "Upgrade failed!"
        exit 1
    }
}

# Delete PostgreSQL
function Remove-PostgreSQL {
    Write-FireballHeader "Deleting PostgreSQL - $ReleaseName"
    
    if (-not $Force) {
        Write-FireballWarning "This will delete the PostgreSQL deployment and potentially your data!"
        $confirmation = Read-Host "Are you ABSOLUTELY sure? Type 'delete' to confirm"
        if ($confirmation -ne "delete") {
            Write-FireballInfo "Aborted. Your data lives to see another day."
            return
        }
    }
    
    Write-FireballInfo "Uninstalling Helm release..."
    helm uninstall $ReleaseName --namespace $Namespace
    
    if ($LASTEXITCODE -eq 0) {
        Write-FireballSuccess "PostgreSQL uninstalled!"
        
        Write-FireballWarning "PVCs may still exist. To delete them:"
        Write-Host "  kubectl delete pvc -l app.kubernetes.io/instance=$ReleaseName -n $Namespace"
    }
}

# Backup PostgreSQL
function Backup-PostgreSQL {
    Write-FireballHeader "Backing up PostgreSQL - $ReleaseName"
    
    # Get the backup CronJob name
    $cronJobName = "$ReleaseName-backup"
    
    # Create a manual job from the CronJob
    $jobName = "$cronJobName-manual-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    Write-FireballInfo "Creating backup job: $jobName"
    kubectl create job --from=cronjob/$cronJobName $jobName -n $Namespace
    
    if ($LASTEXITCODE -eq 0) {
        Write-FireballSuccess "Backup job created!"
        Write-FireballInfo "Monitoring job progress..."
        
        kubectl wait --for=condition=complete job/$jobName -n $Namespace --timeout=600s
        
        if ($LASTEXITCODE -eq 0) {
            Write-FireballSuccess "Backup completed successfully!"
            
            # Show backup logs
            $podName = kubectl get pods -l job-name=$jobName -n $Namespace -o jsonpath='{.items[0].metadata.name}'
            Write-FireballInfo "Backup logs:"
            kubectl logs $podName -n $Namespace
        }
        else {
            Write-FireballError "Backup job failed or timed out!"
            
            # Show job status
            kubectl describe job/$jobName -n $Namespace
        }
    }
    else {
        Write-FireballError "Failed to create backup job!"
    }
}

# Restore PostgreSQL
function Restore-PostgreSQL {
    Write-FireballHeader "Restoring PostgreSQL - $ReleaseName"
    
    if (-not $BackupFile) {
        Write-FireballError "Please specify -BackupFile parameter"
        exit 1
    }
    
    Write-FireballWarning "This will restore the database. Existing data may be overwritten!"
    if (-not $Force) {
        $confirmation = Read-Host "Continue? (yes/no)"
        if ($confirmation -ne "yes") {
            Write-FireballInfo "Restore cancelled."
            return
        }
    }
    
    # Get primary pod (pod-0 for StatefulSet or single pod for Deployment)
    $podName = kubectl get pods -l app.kubernetes.io/instance=$ReleaseName -n $Namespace -o jsonpath='{.items[0].metadata.name}'
    
    Write-FireballInfo "Copying backup file to pod..."
    kubectl cp $BackupFile "$Namespace/${podName}:/tmp/restore.dump"
    
    Write-FireballInfo "Restoring database: $Database"
    
    $restoreCmd = @"
export PGPASSWORD=`$(cat /run/secrets/postgresql/password)
pg_restore -h localhost -U fireball -d $Database -c -v /tmp/restore.dump
rm /tmp/restore.dump
"@
    
    kubectl exec -it $podName -n $Namespace -- bash -c $restoreCmd
    
    if ($LASTEXITCODE -eq 0) {
        Write-FireballSuccess "Database restored successfully!"
    }
    else {
        Write-FireballError "Restore failed!"
    }
}

# Health check
function Test-PostgreSQLHealth {
    Write-FireballHeader "PostgreSQL Health Check - $ReleaseName"
    
    # Get pods
    Write-FireballInfo "Checking pods..."
    kubectl get pods -l app.kubernetes.io/instance=$ReleaseName -n $Namespace
    
    # Check pod health
    $pods = kubectl get pods -l app.kubernetes.io/instance=$ReleaseName -n $Namespace -o json | ConvertFrom-Json
    
    foreach ($pod in $pods.items) {
        $podName = $pod.metadata.name
        $status = $pod.status.phase
        
        if ($status -eq "Running") {
            Write-FireballSuccess "Pod $podName is running"
            
            # Check PostgreSQL connectivity
            $checkCmd = "pg_isready -h localhost -p 5432"
            $result = kubectl exec $podName -n $Namespace -- bash -c $checkCmd 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-FireballSuccess "  PostgreSQL is accepting connections"
            }
            else {
                Write-FireballError "  PostgreSQL is not ready: $result"
            }
        }
        else {
            Write-FireballError "Pod $podName is in state: $status"
        }
    }
    
    # Check services
    Write-FireballInfo "Checking services..."
    kubectl get svc -l app.kubernetes.io/instance=$ReleaseName -n $Namespace
    
    # Check PVCs
    Write-FireballInfo "Checking persistent volumes..."
    kubectl get pvc -l app.kubernetes.io/instance=$ReleaseName -n $Namespace
}

# Replication status
function Get-ReplicationStatus {
    Write-FireballHeader "Replication Status - $ReleaseName"
    
    # Get primary pod
    $primaryPod = "$ReleaseName-0"
    
    Write-FireballInfo "Querying replication status from primary: $primaryPod"
    
    $replQuery = "SELECT * FROM pg_stat_replication;"
    
    kubectl exec $primaryPod -n $Namespace -- bash -c "export PGPASSWORD=\`$(cat /run/secrets/postgresql/password); psql -U fireball -d postgres -c '$replQuery'"
    
    if ($LASTEXITCODE -eq 0) {
        Write-FireballSuccess "Replication status retrieved"
    }
    else {
        Write-FireballWarning "Could not retrieve replication status (may not be in HA mode)"
    }
}

# Vacuum database
function Invoke-Vacuum {
    Write-FireballHeader "Vacuuming Database - $Database"
    
    $podName = kubectl get pods -l app.kubernetes.io/instance=$ReleaseName -n $Namespace -o jsonpath='{.items[0].metadata.name}'
    
    Write-FireballInfo "Running VACUUM ANALYZE on $Database..."
    
    kubectl exec $podName -n $Namespace -- bash -c "export PGPASSWORD=\`$(cat /run/secrets/postgresql/password); vacuumdb -U fireball -d $Database --analyze --verbose"
    
    if ($LASTEXITCODE -eq 0) {
        Write-FireballSuccess "VACUUM completed!"
    }
    else {
        Write-FireballError "VACUUM failed!"
    }
}

# Analyze database
function Invoke-Analyze {
    Write-FireballHeader "Analyzing Database - $Database"
    
    $podName = kubectl get pods -l app.kubernetes.io/instance=$ReleaseName -n $Namespace -o jsonpath='{.items[0].metadata.name}'
    
    Write-FireballInfo "Running ANALYZE on $Database..."
    
    kubectl exec $podName -n $Namespace -- bash -c "export PGPASSWORD=\`$(cat /run/secrets/postgresql/password); vacuumdb -U fireball -d $Database --analyze-only --verbose"
    
    if ($LASTEXITCODE -eq 0) {
        Write-FireballSuccess "ANALYZE completed!"
    }
    else {
        Write-FireballError "ANALYZE failed!"
    }
}

# Get logs
function Get-PostgreSQLLogs {
    Write-FireballHeader "PostgreSQL Logs - $ReleaseName"
    
    $pods = kubectl get pods -l app.kubernetes.io/instance=$ReleaseName -n $Namespace -o jsonpath='{.items[*].metadata.name}'
    
    foreach ($pod in $pods -split ' ') {
        Write-FireballInfo "Logs from: $pod"
        Write-Host ""
        kubectl logs $pod -n $Namespace --tail=100
        Write-Host ""
        Write-Host "---"
        Write-Host ""
    }
}

# Main execution
Write-FireballHeader "PostgreSQL Management - Fireball Industries"
Write-Host "Patrick Ryan's Industrial Database Toolkit" -ForegroundColor Gray
Write-Host "(Because managing databases should be easier than explaining why production is down)" -ForegroundColor Gray
Write-Host ""

Test-Prerequisites

switch ($Action) {
    'deploy' { Deploy-PostgreSQL }
    'upgrade' { Upgrade-PostgreSQL }
    'delete' { Remove-PostgreSQL }
    'backup' { Backup-PostgreSQL }
    'restore' { Restore-PostgreSQL }
    'health-check' { Test-PostgreSQLHealth }
    'replication-status' { Get-ReplicationStatus }
    'vacuum' { Invoke-Vacuum }
    'analyze' { Invoke-Analyze }
    'logs' { Get-PostgreSQLLogs }
}

Write-Host ""
Write-FireballInfo "Done! May your queries be fast and your indexes be used. ☕"
Write-Host ""
