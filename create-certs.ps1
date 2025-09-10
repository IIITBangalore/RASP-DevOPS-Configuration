Write-Output "Creating self-signed certificates"

# Create certs directory if it doesn't exist
$certsPath = "certs"
if (-Not (Test-Path -Path $certsPath)) {
    New-Item -ItemType Directory -Path $certsPath | Out-Null
}

# Change directory to certs
Set-Location $certsPath

# Generate certificates
mkcert rasp-designer-be.localhost
mkcert rasp-designer-fe.localhost
mkcert rasp-keycloak.localhost

Write-Output "Installing certificates"
