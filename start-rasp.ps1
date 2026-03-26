# Script to start RASP with dynamic IP detection

# 1. Get the current IPv4 address
# Filter out Loopback, vEthernet (Docker/Hyper-V), and APIPA (169.254.x.x) addresses
$ipInfo = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
    $_.InterfaceAlias -notlike "vEthernet*" -and 
    $_.InterfaceAlias -notlike "Loopback*" -and 
    $_.IPAddress -notlike "169.254.*" 
} | Select-Object -First 1

$currentIP = $ipInfo.IPAddress

if (-not $currentIP) {
    Write-Host "Error: Could not detect IP address." -ForegroundColor Red
    exit 1
}

Write-Host "----------------------------------------" -ForegroundColor Cyan
Write-Host "       RASP SERVER STARTUP              " -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor Cyan
Write-Host "Detected IP Address: $currentIP" -ForegroundColor Yellow

# 2. Set the HOST_IP environment variable for Docker Compose
$env:HOST_IP = $currentIP
Write-Host "Set HOST_IP = $currentIP" -ForegroundColor Gray

# 3. Start Docker Configuration
Write-Host "Starting Docker Containers..." -ForegroundColor Green
docker compose -f dev.docker-compose.yml up -d

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ RASP Deployed Successfully!" -ForegroundColor Green
    Write-Host "----------------------------------------"
    Write-Host "Frontend:      http://$currentIP"
    Write-Host "Backend:       http://$currentIP:9000"
    Write-Host "Keycloak:      http://$currentIP:9080/admin/"
    Write-Host "----------------------------------------"
    Write-Host "NOTE: If this is a new IP, update Keycloak Redirect URIs to '*'" -ForegroundColor Magenta
} else {
    Write-Host "`n❌ Docker failed to start." -ForegroundColor Red
}

Pause
