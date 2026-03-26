# Script to Deploy Collab Central Server to Remote Server (172.16.202.56)

$TargetIP = "172.16.202.56"

Write-Host "----------------------------------------" -ForegroundColor Cyan
Write-Host "    COLLAB CENTRAL REMOTE DEPLOYMENT    " -ForegroundColor Cyan
Write-Host "       Target: $TargetIP           " -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor Cyan

# 1. Get Credentials
$User = Read-Host "Enter SSH Username for $TargetIP"
if (-not $User) { Write-Error "Username is required!"; exit 1 }

$RemotePath = "~/collab-central-deployment"

Write-Host "`n1. Creating remote directory: $RemotePath..." -ForegroundColor Yellow
ssh $User@$TargetIP "mkdir -p $RemotePath"
if ($LASTEXITCODE -ne 0) { Write-Error "SSH Connection failed. Check credentials/connectivity."; exit 1 }

Write-Host "`n2. Copying configuration files..." -ForegroundColor Yellow
try {
    scp ".\docker-compose.collab-central.yml" "${User}@${TargetIP}:${RemotePath}/"
    scp ".\start-collab-central.sh" "${User}@${TargetIP}:${RemotePath}/"
    
    # Copy Keycloak realm data if it exists
    if (Test-Path ".\dev_keycloak_realm_data") {
        Write-Host "   Copying Keycloak data..."
        scp -r ".\dev_keycloak_realm_data" "${User}@${TargetIP}:${RemotePath}/"
    }

    Write-Host "   Copying Collab-Server Source (for building)..."
    scp -r "..\Collab-Server" "${User}@${TargetIP}:${RemotePath}/Collab-Server"
}
catch {
    Write-Error "File copy failed."
    exit 1
}

Write-Host "`n3. Executing Remote Startup Script..." -ForegroundColor Green
# Connect, Fix line endings (just in case), Make executable, and Run
ssh -t $User@$TargetIP "cd $RemotePath && sed -i 's/\r$//' start-collab-central.sh && chmod +x start-collab-central.sh && sudo ./start-collab-central.sh"

Write-Host "`n----------------------------------------"
Write-Host "Deployment Request Sent."
Write-Host "Please check the output above for success message."
Write-Host "Central Server access points:"
Write-Host " - Keycloak: http://$TargetIP:8080/admin"
Write-Host " - Collab API: http://$TargetIP:8082"
Write-Host "----------------------------------------"

Pause
