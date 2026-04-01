param(
    [int]$numUsers = 2,
    [string]$CentralIP = "172.16.202.56"
)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Starting Distributed Simulation Setup"    -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# ── Detect host IP ──────────────────────────────────────────
$ipInfo = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
    $_.InterfaceAlias -notlike "vEthernet*" -and
    $_.InterfaceAlias -notlike "Loopback*" -and
    $_.IPAddress -notlike "169.254.*"
} | Select-Object -First 1

$currentIP = if ($ipInfo) { $ipInfo.IPAddress } else { "127.0.0.1" }
Write-Host "Detected Host IP: $currentIP" -ForegroundColor Yellow
Write-Host "Central Server:   $CentralIP" -ForegroundColor Yellow

$env:HOST_IP    = $currentIP
$env:CENTRAL_IP = $CentralIP

# ── Step 1: Start Central Server ────────────────────────────
Write-Host "`nStep 1: Starting Central Server components ..." -ForegroundColor Yellow
docker compose -f docker-compose.central.yml up -d

Write-Host "Waiting for central server to initialize ..."
Start-Sleep -Seconds 15

# ── Step 2: Start user instances ────────────────────────────
Write-Host "`nStep 2: Starting $numUsers Local Instances ..." -ForegroundColor Yellow

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ComposePath = Join-Path $ScriptDir "docker-compose.local.yml"

for ($i = 1; $i -le $numUsers; $i++) {
    $projectName = "user$i"
    $basePort    = 8000 + (($i - 1) * 100)
    $portFE      = $basePort
    $portBE      = $basePort + 1
    $portDB      = $basePort + 2
    $portDMS     = $basePort + 3

    Write-Host "`n -> Starting Instance: $projectName" -ForegroundColor Green
    Write-Host "    FE=$portFE  BE=$portBE  DB=$portDB  DMS=$portDMS"

    # Create instance .env
    $InstanceDir = Join-Path $ScriptDir "instances\$projectName"
    New-Item -ItemType Directory -Force -Path $InstanceDir | Out-Null

    $EnvFile = Join-Path $InstanceDir ".env"
    @"
PROJECT_NAME=$projectName
HOST_IP=$currentIP
CENTRAL_IP=$CentralIP
PORT_FE=$portFE
PORT_BE=$portBE
PORT_DB=$portDB
PORT_DMS=$portDMS
GENERATED_PATH=D:/RASP/generated
SOURCE_PROJECT_PATH=D:/RASP/RASP-Backend-Generator
"@ | Set-Content -Path $EnvFile -Encoding UTF8

    docker compose -p $projectName --env-file $EnvFile -f $ComposePath up -d
}

# ── Summary ─────────────────────────────────────────────────
Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Simulation started successfully!"         -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host " Central Services:"                        -ForegroundColor Yellow
Write-Host "   Keycloak:  http://${currentIP}:9080"
Write-Host "   Collab:    http://${currentIP}:8088"
Write-Host "   RBAC:      http://${currentIP}:9082"
Write-Host "   MongoDB:   ${currentIP}:27017"
Write-Host ""
Write-Host " User Instances:" -ForegroundColor Yellow

for ($i = 1; $i -le $numUsers; $i++) {
    $bp = 8000 + (($i - 1) * 100)
    Write-Host "   user$i  ->  FE=http://${currentIP}:$bp  BE=http://${currentIP}:$($bp+1)"
}
Write-Host "========================================="
