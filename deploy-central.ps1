# ============================================================
#  Deploy RASP Central Server to Remote Linux Host
#  Pushes compose files, Keycloak data, and runs start-central.sh
# ============================================================

param(
    [string]$TargetIP = "172.16.202.56"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "    RASP CENTRAL SERVER DEPLOYMENT      " -ForegroundColor Cyan
Write-Host "    Target: $TargetIP                   " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 1. Get SSH credentials
$User = Read-Host "Enter SSH Username for $TargetIP"
if (-not $User) { Write-Error "Username is required!"; exit 1 }

$RemotePath = "~/rasp-central"

Write-Host "`n1. Creating remote directory: $RemotePath ..." -ForegroundColor Yellow
ssh $User@$TargetIP "mkdir -p $RemotePath"
if ($LASTEXITCODE -ne 0) { Write-Error "SSH Connection failed."; exit 1 }

Write-Host "`n2. Copying configuration files ..." -ForegroundColor Yellow
try {
    scp ".\docker-compose.central.yml"   "${User}@${TargetIP}:${RemotePath}/"
    scp ".\start-central.sh"             "${User}@${TargetIP}:${RemotePath}/"

    if (Test-Path ".\dev_keycloak_realm_data") {
        Write-Host "   Copying Keycloak realm data ..."
        scp -r ".\dev_keycloak_realm_data" "${User}@${TargetIP}:${RemotePath}/"
    }

    if (Test-Path "..\RASP-Backend-Generator") {
        Write-Host "   Copying Backend Generator source (for RBAC volume) ..."
        scp -r "..\RASP-Backend-Generator" "${User}@${TargetIP}:${RemotePath}/rasp_backend_source"
    }
}
catch {
    Write-Error "File copy failed: $_"
    exit 1
}

Write-Host "`n3. Executing remote startup script ..." -ForegroundColor Green
ssh -t $User@$TargetIP "cd $RemotePath && sed -i 's/\r$//' start-central.sh && chmod +x start-central.sh && sudo ./start-central.sh"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Deployment complete. Verify services:"  -ForegroundColor Green
Write-Host "  Keycloak:      http://${TargetIP}:9080/admin/"
Write-Host "  MongoDB:       ${TargetIP}:27017"
Write-Host "  Collab Server: http://${TargetIP}:8088"
Write-Host "  RBAC Service:  http://${TargetIP}:9082"
Write-Host "========================================" -ForegroundColor Cyan

Pause
