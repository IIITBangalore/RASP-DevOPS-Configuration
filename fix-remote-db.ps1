# Script to Push Schema to Remote Database

$TargetIP = "172.16.202.56"
$User = "ctri"

Write-Host "Pushing Database Schema to $TargetIP..."
# Run npx prisma db push inside the container
ssh $User@$TargetIP "docker exec -i rasp-designer-be npx prisma db push --accept-data-loss"

if ($LASTEXITCODE -eq 0) {
    Write-Host "----------------------------------------"
    Write-Host "✅ Database Schema Pushed Successfully!"
    Write-Host "----------------------------------------"
} else {
    Write-Host "❌ Failed to push schema."
}
