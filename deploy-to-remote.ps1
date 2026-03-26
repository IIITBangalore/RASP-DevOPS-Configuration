# Script to Deploy RASP to Remote Server (172.16.202.56)

$TargetIP = "172.16.202.56"

Write-Host "----------------------------------------" -ForegroundColor Cyan
Write-Host "       RASP REMOTE DEPLOYMENT           " -ForegroundColor Cyan
Write-Host "       Target: $TargetIP           " -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor Cyan

# 1. Get Credentials
$User = Read-Host "Enter SSH Username for $TargetIP"
if (-not $User) { Write-Error "Username is required!"; exit 1 }

$RemotePath = "~/rasp-deployment"

Write-Host "`n1. Creating remote directory: $RemotePath..." -ForegroundColor Yellow
ssh $User@$TargetIP "mkdir -p $RemotePath"
if ($LASTEXITCODE -ne 0) { Write-Error "SSH Connection failed. Check credentials/connectivity."; exit 1 }

Write-Host "`n2. Copying configuration files..." -ForegroundColor Yellow
try {
    scp ".\dev.docker-compose.yml" "${User}@${TargetIP}:${RemotePath}/"
    scp ".\start-rasp.sh" "${User}@${TargetIP}:${RemotePath}/"
    
    # Copy directory recursively
    Write-Host "   Copying Keycloak data..."
    scp -r ".\dev_keycloak_realm_data" "${User}@${TargetIP}:${RemotePath}/"

    Write-Host "   Copying Backend Generator Source (for volume mount)..."
    scp -r "..\RASP-Backend-Generator" "${User}@${TargetIP}:${RemotePath}/rasp_backend_source"
}
catch {
    Write-Error "File copy failed."
    exit 1
}

Write-Host "`n3. Executing Remote Startup Script..." -ForegroundColor Green
# Connect, Fix line endings (just in case), Make executable, and Run
ssh -t $User@$TargetIP "cd $RemotePath && sed -i 's/\r$//' start-rasp.sh && chmod +x start-rasp.sh && sudo ./start-rasp.sh"

Write-Host "`n----------------------------------------"
Write-Host "Deployment Request Sent."
Write-Host "Please check the output above for success message."
Write-Host "If successful, access at: http://$TargetIP"
Write-Host "----------------------------------------"

Pause
