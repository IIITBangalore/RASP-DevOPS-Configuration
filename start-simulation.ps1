param(
    [int]$numUsers = 2
)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Starting Distributed Simulation Setup" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Get the current IPv4 address
$ipInfo = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
    $_.InterfaceAlias -notlike "vEthernet*" -and 
    $_.InterfaceAlias -notlike "Loopback*" -and 
    $_.IPAddress -notlike "169.254.*" 
} | Select-Object -First 1

$currentIP = $ipInfo.IPAddress

if (-not $currentIP) {
    Write-Host "Warning: Could not detect IP address. Defaulting to 127.0.0.1" -ForegroundColor Yellow
    $currentIP = "127.0.0.1"
} else {
    Write-Host "Detected Host IP: $currentIP" -ForegroundColor Yellow
}

$env:HOST_IP = $currentIP

Write-Host "Step 1: Starting Central Server components..." -ForegroundColor Yellow
docker-compose -f docker-compose.central.yml up -d

Write-Host "Waiting a moment for central server DBs to initialize..."
Start-Sleep -Seconds 10

# Base ports for local instances
$basePortFE = 8080
$basePortBE = 9000
$basePortDB = 3306
$basePortRBAC = 9082
$basePortDMS = 8085

Write-Host ""
Write-Host "Step 2: Starting $numUsers Local Instances dynamically..." -ForegroundColor Yellow

for ($i = 1; $i -le $numUsers; $i++) {
    $projectName = "user$i"
    $portFE = $basePortFE + $i
    $portBE = $basePortBE + $i
    $portDB = $basePortDB + $i
    $portRBAC = $basePortRBAC + $i
    $portDMS = $basePortDMS + $i

    Write-Host " -> Starting Local Instance for User $i ($projectName)" -ForegroundColor Green
    Write-Host "    Frontend Port: $portFE"
    Write-Host "    Backend Port:  $portBE"
    Write-Host "    MySQL Port:    $portDB"
    Write-Host "    RBAC Port:     $portRBAC"
    Write-Host "    DMS Port:      $portDMS"
    Write-Host "    HOST_IP:       $currentIP"

    $env:PROJECT_NAME = $projectName
    $env:PORT_FE = $portFE
    $env:PORT_BE = $portBE
    $env:PORT_DB = $portDB
    $env:PORT_RBAC = $portRBAC
    $env:PORT_DMS = $portDMS

    # Run docker-compose for the specific user instance (forcing build for dynamic Dockerfiles)
    docker-compose -p $projectName -f docker-compose.local.yml up -d --build
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Simulation started successfully!" -ForegroundColor Green
Write-Host " Central server (Collab) running on port 8088." -ForegroundColor Green
Write-Host " $numUsers dynamic local user instances are running." -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
