# # ============================================================
# #  Create a new RASP user instance (Windows)
# #  Usage: .\create-instance.ps1 -Name user1 -BasePort 8000 [-CentralIP 172.16.202.56]
# # ============================================================
 

# param(
#     [Parameter(Mandatory=$true)]
#     [string]$Name,

#     [Parameter(Mandatory=$true)]
#     [int]$BasePort,

#     [string]$CentralIP = "172.16.202.56"
# )

# # ── Calculate ports ─────────────────────────────────────────
# $PortFE  = $BasePort
# $PortBE  = $BasePort + 1
# $PortDB  = $BasePort + 2
# $PortDMS = $BasePort + 3

# # ── IMPORTANT: Run on server IP ─────────────────────────────
# # $HostIP = $CentralIP   # 🔥 FIXED (was local IP before)
# $HostIP = "127.0.0.1"   # Local development: browser accesses via localhost

# # ── Create instance directory ───────────────────────────────
# $ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
# $InstanceDir = Join-Path $ScriptDir "instances\$Name"
# New-Item -ItemType Directory -Force -Path $InstanceDir | Out-Null

# Write-Host "========================================" -ForegroundColor Cyan
# Write-Host "  Creating RASP Instance: $Name"         -ForegroundColor Cyan
# Write-Host "========================================" -ForegroundColor Cyan
# Write-Host "  Central Server:  $CentralIP"
# Write-Host "  Host IP:         $HostIP"
# Write-Host "  Frontend Port:   $PortFE"
# Write-Host "  Backend Port:    $PortBE"
# Write-Host "  MySQL Port:      $PortDB"
# Write-Host "  DMS Port:        $PortDMS"
# Write-Host "========================================"

# # ── Generate .env file ──────────────────────────────────────
# $EnvFile = Join-Path $InstanceDir ".env"

# $EnvContent = @"
# # Auto-generated for instance: $Name
# # Created: $(Get-Date -Format o)

# PROJECT_NAME=$Name

# # -- Host IPs --
# HOST_IP=$HostIP
# CENTRAL_IP=$CentralIP

# # -- Port assignments (base=$BasePort) --
# PORT_FE=$PortFE
# PORT_BE=$PortBE
# PORT_DB=$PortDB
# PORT_DMS=$PortDMS
# PORT_VAULT=$($BasePort + 4)
# PORT_WORKFLOW=$($BasePort + 5)

# # -- Auth Configuration (CRITICAL) --
# KEYCLOAK_URL=http://$($CentralIP):9080
# REALM=myRealm
# CLIENT_ID=backend-api

# # -- Service URLs --
# RBAC_URL=http://$($CentralIP):9082/api
# COLLAB_URL=http://$($CentralIP):8088/api

# # -- Volume paths (Windows defaults) --
# GENERATED_PATH=D:/RASP/generated
# SOURCE_PROJECT_PATH=D:/RASP/RASP-Backend-Generator
# "@

# Set-Content -Path $EnvFile -Value $EnvContent -Encoding UTF8
# Write-Host "`n✅ Generated: $EnvFile" -ForegroundColor Green

# # ── Start the instance ───────────────────────────────────────
# $ComposePath = Join-Path $ScriptDir "docker-compose.local.yml"

# Write-Host "`nStarting instance '$Name' ..." -ForegroundColor Yellow

# docker compose -p $Name --env-file $EnvFile -f $ComposePath up -d

# if ($LASTEXITCODE -eq 0) {
#     Write-Host ""
#     Write-Host "========================================" -ForegroundColor Green
#     Write-Host "  ✅ Instance '$Name' is running!"       -ForegroundColor Green
#     Write-Host "========================================" -ForegroundColor Green
#     Write-Host "  Frontend:    http://${HostIP}:$PortFE"
#     Write-Host "  Backend:     http://${HostIP}:$PortBE"
#     Write-Host "  MySQL:       ${HostIP}:$PortDB"
#     Write-Host "  DMS:         http://${HostIP}:$PortDMS"
#     Write-Host "  RBAC (central):   http://${CentralIP}:9082"
#     Write-Host "  Collab (central): http://${CentralIP}:8088"
#     Write-Host "========================================"
# } else {
#     Write-Host "  ❌ Failed to start instance '$Name'." -ForegroundColor Red
# }


# ============================================================
# Create a new RASP user instance (Windows)
# Usage:
# .\create-instance.ps1 -Name user1 -BasePort 8000 [-CentralIP 172.16.202.56]
# ============================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [int]$BasePort,

    [string]$CentralIP = "172.16.193.5"
)

# ────────────────────────────────────────────────────────────
# Calculate Ports
# ────────────────────────────────────────────────────────────

$PortFE       = $BasePort
$PortBE       = $BasePort + 1
$PortDB       = $BasePort + 2
$PortDMS      = $BasePort + 3
$PortVault    = $BasePort + 4
$PortWorkflow = $BasePort + 5

# Local development access via browser
$HostIP = "127.0.0.1"

# ────────────────────────────────────────────────────────────
# Create Instance Directory
# ────────────────────────────────────────────────────────────

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstanceDir = Join-Path $ScriptDir "instances\$Name"

New-Item -ItemType Directory -Force -Path $InstanceDir | Out-Null

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Creating RASP Instance: $Name"         -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Central Server:  $CentralIP"
Write-Host "  Host IP:         $HostIP"
Write-Host "  Frontend Port:   $PortFE"
Write-Host "  Backend Port:    $PortBE"
Write-Host "  MySQL Port:      $PortDB"
Write-Host "  DMS Port:        $PortDMS"
Write-Host "  Vault Port:      $PortVault"
Write-Host "  Workflow Port:   $PortWorkflow"
Write-Host "========================================"

# ────────────────────────────────────────────────────────────
# Generate .env File
# ────────────────────────────────────────────────────────────

$EnvFile = Join-Path $InstanceDir ".env"

$EnvContent = @"
# ============================================================
# Auto-generated for instance: $Name
# Created: $(Get-Date -Format o)
# ============================================================

PROJECT_NAME=$Name

# ------------------------------------------------------------
# Host Configuration
# ------------------------------------------------------------

HOST_IP=$HostIP
CENTRAL_IP=$CentralIP

# ------------------------------------------------------------
# Port Configuration
# ------------------------------------------------------------

PORT_FE=$PortFE
PORT_BE=$PortBE
PORT_DB=$PortDB
PORT_DMS=$PortDMS
PORT_VAULT=$PortVault
PORT_WORKFLOW=$PortWorkflow

# ------------------------------------------------------------
# Keycloak Configuration
# ------------------------------------------------------------

KEYCLOAK_URL=http://$($CentralIP):9080
REALM=myRealm
CLIENT_ID=backend-api

# ------------------------------------------------------------
# Central Platform Services
# ------------------------------------------------------------

GENERATOR_URL=http://$($CentralIP):9082/api
COLLABORATION_URL=http://$($CentralIP):8088/api
CODEGEN_AI_URL=http://$($CentralIP):9000/api/subgraph

# ------------------------------------------------------------
# Local Workflow Service
# ------------------------------------------------------------

WORKFLOW_HOST=${Name}-workflow
WORKFLOW_PORT=9000
GENERATED_WORKFLOW_URL=http://${Name}-workflow:9000/api

# ------------------------------------------------------------
# Internal Configuration
# ------------------------------------------------------------

INTERNAL_TOKEN=qwewqdwqdewq
RASP_VERSION=0.8

# ------------------------------------------------------------
# Optional Local Paths (Windows)
# ------------------------------------------------------------

GENERATED_PATH=D:/RASP/generated
SOURCE_PROJECT_PATH=D:/RASP/RASP-Backend-Generator
"@

Set-Content -Path $EnvFile -Value $EnvContent -Encoding UTF8

Write-Host ""
Write-Host "✅ Generated: $EnvFile" -ForegroundColor Green

# ────────────────────────────────────────────────────────────
# Start Docker Compose Instance
# ────────────────────────────────────────────────────────────

$ComposePath = Join-Path $ScriptDir "docker-compose.local.yml"

Write-Host ""
Write-Host "Starting instance '$Name' ..." -ForegroundColor Yellow

docker compose `
    -p $Name `
    --env-file $EnvFile `
    -f $ComposePath `
    up -d

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  ✅ Instance '$Name' is running!"       -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Frontend:         http://${HostIP}:$PortFE"
    Write-Host "  Backend:          http://${HostIP}:$PortBE"
    Write-Host "  MySQL:            ${HostIP}:$PortDB"
    Write-Host "  DMS:              http://${HostIP}:$PortDMS"
    Write-Host "  Vault:            http://${HostIP}:$PortVault"
    Write-Host "  Workflow:         http://${HostIP}:$PortWorkflow"
    Write-Host ""
    Write-Host "  Central Services:"
    Write-Host "  Keycloak:         http://${CentralIP}:9080"
    Write-Host "  RBAC Generator:   http://${CentralIP}:9082"
    Write-Host "  Collaboration:    http://${CentralIP}:8088"
    Write-Host "  AI Codegen:       http://${CentralIP}:9000"
    Write-Host "========================================"
}
else {
    Write-Host ""
    Write-Host "❌ Failed to start instance '$Name'." -ForegroundColor Red
}