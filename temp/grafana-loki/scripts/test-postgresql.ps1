# PostgreSQL Testing Script
# Fireball Industries - Industrial IoT Edition
# Author: Patrick Ryan
#
# Usage:
#   .\test-postgresql.ps1 -ReleaseName <name> -Namespace <namespace> [-TestType <type>]

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ReleaseName = "postgresql",
    
    [Parameter(Mandatory=$false)]
    [string]$Namespace = "databases",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('all', 'connection', 'crud', 'replication', 'backup-restore', 'performance')]
    [string]$TestType = "all",
    
    [Parameter(Mandatory=$false)]
    [int]$PerformanceIterations = 1000
)

# Color output functions
function Write-TestSuccess {
    param([string]$Message)
    Write-Host "  ✓ $Message" -ForegroundColor Green
}

function Write-TestFailure {
    param([string]$Message)
    Write-Host "  ✗ $Message" -ForegroundColor Red
}

function Write-TestInfo {
    param([string]$Message)
    Write-Host "  ℹ $Message" -ForegroundColor Cyan
}

function Write-TestHeader {
    param([string]$Message)
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host "  $Message" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host ""
}

# Get PostgreSQL connection details
function Get-PostgreSQLConnection {
    $service = "$ReleaseName.$Namespace.svc.cluster.local"
    $port = 5432
    $database = "production_data"
    $user = "fireball"
    
    # Get password from secret
    $passwordB64 = kubectl get secret $ReleaseName -n $Namespace -o jsonpath='{.data.password}'
    $password = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($passwordB64))
    
    return @{
        Host = $service
        Port = $port
        Database = $database
        User = $user
        Password = $password
    }
}

# Execute SQL query
function Invoke-PostgreSQLQuery {
    param(
        [string]$Query,
        [string]$Database = "production_data"
    )
    
    $conn = Get-PostgreSQLConnection
    $podName = kubectl get pods -l app.kubernetes.io/instance=$ReleaseName -n $Namespace -o jsonpath='{.items[0].metadata.name}'
    
    $cmd = @"
export PGPASSWORD='$($conn.Password)'
psql -h localhost -U $($conn.User) -d $Database -c "$Query"
"@
    
    $result = kubectl exec $podName -n $Namespace -- bash -c $cmd 2>&1
    return @{
        Success = ($LASTEXITCODE -eq 0)
        Output = $result
    }
}

# Test: Connection
function Test-Connection {
    Write-TestHeader "Test: Database Connection"
    
    $conn = Get-PostgreSQLConnection
    Write-TestInfo "Connecting to: $($conn.Host):$($conn.Port)"
    
    $podName = kubectl get pods -l app.kubernetes.io/instance=$ReleaseName -n $Namespace -o jsonpath='{.items[0].metadata.name}'
    
    if (-not $podName) {
        Write-TestFailure "No pods found for release: $ReleaseName"
        return $false
    }
    
    Write-TestSuccess "Pod found: $podName"
    
    # Test pg_isready
    $ready = kubectl exec $podName -n $Namespace -- pg_isready -h localhost -p 5432 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-TestSuccess "PostgreSQL is accepting connections"
    }
    else {
        Write-TestFailure "PostgreSQL is not ready: $ready"
        return $false
    }
    
    # Test actual connection
    $result = Invoke-PostgreSQLQuery -Query "SELECT version();"
    if ($result.Success) {
        Write-TestSuccess "Successfully connected and queried database"
        Write-TestInfo "$($result.Output)"
        return $true
    }
    else {
        Write-TestFailure "Failed to query database: $($result.Output)"
        return $false
    }
}

# Test: CRUD Operations
function Test-CRUDOperations {
    Write-TestHeader "Test: CRUD Operations"
    
    # Create table
    Write-TestInfo "Creating test table..."
    $result = Invoke-PostgreSQLQuery -Query @"
CREATE TABLE IF NOT EXISTS test_crud (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    value INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);
"@
    
    if ($result.Success) {
        Write-TestSuccess "Table created"
    }
    else {
        Write-TestFailure "Failed to create table: $($result.Output)"
        return $false
    }
    
    # Insert data
    Write-TestInfo "Inserting test data..."
    $result = Invoke-PostgreSQLQuery -Query @"
INSERT INTO test_crud (name, value) VALUES 
    ('test1', 100),
    ('test2', 200),
    ('test3', 300);
"@
    
    if ($result.Success) {
        Write-TestSuccess "Data inserted"
    }
    else {
        Write-TestFailure "Failed to insert data: $($result.Output)"
        return $false
    }
    
    # Read data
    Write-TestInfo "Reading data..."
    $result = Invoke-PostgreSQLQuery -Query "SELECT * FROM test_crud;"
    
    if ($result.Success) {
        Write-TestSuccess "Data retrieved"
        Write-TestInfo "$($result.Output)"
    }
    else {
        Write-TestFailure "Failed to read data: $($result.Output)"
        return $false
    }
    
    # Update data
    Write-TestInfo "Updating data..."
    $result = Invoke-PostgreSQLQuery -Query "UPDATE test_crud SET value = 999 WHERE name = 'test1';"
    
    if ($result.Success) {
        Write-TestSuccess "Data updated"
    }
    else {
        Write-TestFailure "Failed to update data: $($result.Output)"
        return $false
    }
    
    # Delete data
    Write-TestInfo "Deleting data..."
    $result = Invoke-PostgreSQLQuery -Query "DELETE FROM test_crud WHERE name = 'test3';"
    
    if ($result.Success) {
        Write-TestSuccess "Data deleted"
    }
    else {
        Write-TestFailure "Failed to delete data: $($result.Output)"
        return $false
    }
    
    # Cleanup
    Write-TestInfo "Cleaning up test table..."
    $result = Invoke-PostgreSQLQuery -Query "DROP TABLE test_crud;"
    
    if ($result.Success) {
        Write-TestSuccess "Test table dropped"
        return $true
    }
    else {
        Write-TestFailure "Failed to drop table: $($result.Output)"
        return $false
    }
}

# Test: Replication Lag
function Test-Replication {
    Write-TestHeader "Test: Replication Status"
    
    # Check if HA is enabled
    $pods = kubectl get pods -l app.kubernetes.io/instance=$ReleaseName -n $Namespace -o json | ConvertFrom-Json
    
    if ($pods.items.Count -le 1) {
        Write-TestInfo "Single instance detected - skipping replication tests"
        return $true
    }
    
    Write-TestInfo "HA deployment detected with $($pods.items.Count) replicas"
    
    # Check replication status
    $result = Invoke-PostgreSQLQuery -Query "SELECT * FROM pg_stat_replication;" -Database "postgres"
    
    if ($result.Success) {
        Write-TestSuccess "Replication status retrieved"
        Write-TestInfo "$($result.Output)"
        
        # Check for replication lag
        $lagResult = Invoke-PostgreSQLQuery -Query @"
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
"@ -Database "postgres"
        
        if ($lagResult.Success) {
            Write-TestSuccess "Replication lag checked"
            Write-TestInfo "$($lagResult.Output)"
            return $true
        }
    }
    
    Write-TestFailure "Failed to check replication: $($result.Output)"
    return $false
}

# Test: Backup and Restore
function Test-BackupRestore {
    Write-TestHeader "Test: Backup and Restore"
    
    # Create test data
    Write-TestInfo "Creating test data for backup..."
    $result = Invoke-PostgreSQLQuery -Query @"
CREATE TABLE IF NOT EXISTS test_backup (
    id SERIAL PRIMARY KEY,
    data VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW()
);
INSERT INTO test_backup (data) VALUES ('backup-test-data');
"@
    
    if (-not $result.Success) {
        Write-TestFailure "Failed to create test data: $($result.Output)"
        return $false
    }
    
    Write-TestSuccess "Test data created"
    
    # Trigger backup
    Write-TestInfo "Triggering backup job..."
    $cronJobName = "$ReleaseName-backup"
    $jobName = "$cronJobName-test-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    kubectl create job --from=cronjob/$cronJobName $jobName -n $Namespace 2>&1 | Out-Null
    
    if ($LASTEXITCODE -ne 0) {
        Write-TestFailure "Backup job creation failed (backup may not be enabled)"
        # Cleanup test data
        Invoke-PostgreSQLQuery -Query "DROP TABLE test_backup;" | Out-Null
        return $false
    }
    
    Write-TestInfo "Waiting for backup to complete..."
    kubectl wait --for=condition=complete job/$jobName -n $Namespace --timeout=300s 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-TestSuccess "Backup completed successfully"
        
        # Cleanup
        Invoke-PostgreSQLQuery -Query "DROP TABLE test_backup;" | Out-Null
        kubectl delete job $jobName -n $Namespace 2>&1 | Out-Null
        
        return $true
    }
    else {
        Write-TestFailure "Backup job failed or timed out"
        
        # Cleanup
        Invoke-PostgreSQLQuery -Query "DROP TABLE test_backup;" | Out-Null
        kubectl delete job $jobName -n $Namespace 2>&1 | Out-Null
        
        return $false
    }
}

# Test: Performance Benchmarks
function Test-Performance {
    Write-TestHeader "Test: Performance Benchmarks"
    
    Write-TestInfo "Running performance tests ($PerformanceIterations iterations)..."
    
    # Create test table
    $result = Invoke-PostgreSQLQuery -Query @"
CREATE TABLE IF NOT EXISTS test_perf (
    id SERIAL PRIMARY KEY,
    value INTEGER,
    data TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);
"@
    
    if (-not $result.Success) {
        Write-TestFailure "Failed to create test table"
        return $false
    }
    
    # Test INSERT performance
    Write-TestInfo "Testing INSERT performance..."
    $insertStart = Get-Date
    
    $result = Invoke-PostgreSQLQuery -Query @"
INSERT INTO test_perf (value, data)
SELECT 
    generate_series(1, $PerformanceIterations),
    md5(random()::text);
"@
    
    $insertEnd = Get-Date
    $insertDuration = ($insertEnd - $insertStart).TotalSeconds
    $insertRate = [math]::Round($PerformanceIterations / $insertDuration, 2)
    
    if ($result.Success) {
        Write-TestSuccess "INSERT: $PerformanceIterations rows in $([math]::Round($insertDuration, 2))s ($insertRate rows/sec)"
    }
    else {
        Write-TestFailure "INSERT test failed: $($result.Output)"
        return $false
    }
    
    # Test SELECT performance
    Write-TestInfo "Testing SELECT performance..."
    $selectStart = Get-Date
    
    $result = Invoke-PostgreSQLQuery -Query "SELECT COUNT(*) FROM test_perf;"
    
    $selectEnd = Get-Date
    $selectDuration = ($selectEnd - $selectStart).TotalSeconds
    
    if ($result.Success) {
        Write-TestSuccess "SELECT: Query completed in $([math]::Round($selectDuration, 3))s"
    }
    else {
        Write-TestFailure "SELECT test failed: $($result.Output)"
    }
    
    # Test UPDATE performance
    Write-TestInfo "Testing UPDATE performance..."
    $updateStart = Get-Date
    
    $result = Invoke-PostgreSQLQuery -Query "UPDATE test_perf SET value = value + 1 WHERE id <= 100;"
    
    $updateEnd = Get-Date
    $updateDuration = ($updateEnd - $updateStart).TotalSeconds
    
    if ($result.Success) {
        Write-TestSuccess "UPDATE: Completed in $([math]::Round($updateDuration, 3))s"
    }
    else {
        Write-TestFailure "UPDATE test failed: $($result.Output)"
    }
    
    # Cleanup
    Write-TestInfo "Cleaning up performance test data..."
    Invoke-PostgreSQLQuery -Query "DROP TABLE test_perf;" | Out-Null
    
    Write-TestSuccess "Performance tests completed"
    return $true
}

# Main execution
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "  PostgreSQL Testing Suite - Fireball Industries" -ForegroundColor Magenta
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "  Release: $ReleaseName" -ForegroundColor Gray
Write-Host "  Namespace: $Namespace" -ForegroundColor Gray
Write-Host "  Test Type: $TestType" -ForegroundColor Gray
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""

$results = @{}

if ($TestType -eq 'all' -or $TestType -eq 'connection') {
    $results['Connection'] = Test-Connection
}

if ($TestType -eq 'all' -or $TestType -eq 'crud') {
    $results['CRUD'] = Test-CRUDOperations
}

if ($TestType -eq 'all' -or $TestType -eq 'replication') {
    $results['Replication'] = Test-Replication
}

if ($TestType -eq 'all' -or $TestType -eq 'backup-restore') {
    $results['Backup-Restore'] = Test-BackupRestore
}

if ($TestType -eq 'all' -or $TestType -eq 'performance') {
    $results['Performance'] = Test-Performance
}

# Summary
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Test Summary" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$passed = 0
$failed = 0

foreach ($test in $results.GetEnumerator()) {
    if ($test.Value) {
        Write-Host "  ✓ $($test.Key)" -ForegroundColor Green
        $passed++
    }
    else {
        Write-Host "  ✗ $($test.Key)" -ForegroundColor Red
        $failed++
    }
}

Write-Host ""
Write-Host "  Total: $($results.Count) | Passed: $passed | Failed: $failed" -ForegroundColor $(if ($failed -eq 0) { 'Green' } else { 'Yellow' })
Write-Host ""

if ($failed -eq 0) {
    Write-Host "All tests passed! Your PostgreSQL is healthy. ☕" -ForegroundColor Green
}
else {
    Write-Host "Some tests failed. Check the output above for details." -ForegroundColor Yellow
}

Write-Host ""
