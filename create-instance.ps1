# ============================================================
#  Create a new RASP user instance (Windows)
#  Usage: .\create-instance.ps1 -Name user1 -BasePort 8000 [-CentralIP 172.16.202.56]
# ============================================================
 

param(
    [Parameter(Mandatory=$true)]
    [string]$Name,

    [Parameter(Mandatory=$true)]
    [int]$BasePort,

    [string]$CentralIP = "172.16.202.56"
)

# ── Calculate ports ─────────────────────────────────────────
$PortFE  = $BasePort
$PortBE  = $BasePort + 1
$PortDB  = $BasePort + 2
$PortDMS = $BasePort + 3

# ── IMPORTANT: Run on server IP ─────────────────────────────
# $HostIP = $CentralIP   # 🔥 FIXED (was local IP before)
$HostIP = "127.0.0.1"   # Local development: browser accesses via localhost

# ── Create instance directory ───────────────────────────────
$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstanceDir = Join-Path $ScriptDir "instances\$Name"
New-Item -ItemType Directory -Force -Path $InstanceDir | Out-Null

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Creating RASP Instance: $Name"         -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Central Server:  $CentralIP"
Write-Host "  Host IP:         $HostIP"
Write-Host "  Frontend Port:   $PortFE"
Write-Host "  Backend Port:    $PortBE"
Write-Host "  MySQL Port:      $PortDB"
Write-Host "  DMS Port:        $PortDMS"
Write-Host "========================================"

# ── Generate .env file ──────────────────────────────────────
$EnvFile = Join-Path $InstanceDir ".env"

$EnvContent = @"
# Auto-generated for instance: $Name
# Created: $(Get-Date -Format o)

PROJECT_NAME=$Name

# -- Host IPs --
HOST_IP=$HostIP
CENTRAL_IP=$CentralIP

# -- Port assignments (base=$BasePort) --
PORT_FE=$PortFE
PORT_BE=$PortBE
PORT_DB=$PortDB
PORT_DMS=$PortDMS
PORT_VAULT=$($BasePort + 4)
PORT_WORKFLOW=$($BasePort + 5)

# -- Auth Configuration (CRITICAL) --
KEYCLOAK_URL=http://$($CentralIP):9080
REALM=myRealm
CLIENT_ID=backend-api

# -- Service URLs --
RBAC_URL=http://$($CentralIP):9082/api
COLLAB_URL=http://$($CentralIP):8088/api

# -- Volume paths (Windows defaults) --
GENERATED_PATH=D:/RASP/generated
SOURCE_PROJECT_PATH=D:/RASP/RASP-Backend-Generator
"@

Set-Content -Path $EnvFile -Value $EnvContent -Encoding UTF8
Write-Host "`n✅ Generated: $EnvFile" -ForegroundColor Green

# ── Start the instance ───────────────────────────────────────
$ComposePath = Join-Path $ScriptDir "docker-compose.local.yml"

Write-Host "`nStarting instance '$Name' ..." -ForegroundColor Yellow

docker compose -p $Name --env-file $EnvFile -f $ComposePath up -d

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  ✅ Instance '$Name' is running!"       -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Frontend:    http://${HostIP}:$PortFE"
    Write-Host "  Backend:     http://${HostIP}:$PortBE"
    Write-Host "  MySQL:       ${HostIP}:$PortDB"
    Write-Host "  DMS:         http://${HostIP}:$PortDMS"
    Write-Host "  RBAC (central):   http://${CentralIP}:9082"
    Write-Host "  Collab (central): http://${CentralIP}:8088"
    Write-Host "========================================"
} else {
    Write-Host "  ❌ Failed to start instance '$Name'." -ForegroundColor Red
}
