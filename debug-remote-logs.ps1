# Script to Fetch Backend Logs from Remote Server

$TargetIP = "172.16.202.56"
$User = "ctri"
$LogFile = "remote_backend_logs.txt"

Write-Host "Fetching logs from $TargetIP..."
ssh $User@$TargetIP "docker logs rasp-designer-be --tail 100" | Out-File -Encoding UTF8 $LogFile

Write-Host "----------------------------------------"
Write-Host "Logs saved to: $LogFile"
Write-Host "----------------------------------------"
Get-Content $LogFile -Tail 20
Write-Host "----------------------------------------"
