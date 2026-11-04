# Builds everything and runs gateway (:3000), user-service (:3001) and tracker-service (:3002).
# Configuration comes from backend/.env. Needs JDK 21 and Maven 3.9+ on PATH. Ctrl+C stops all three.
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

mvn -q -DskipTests package
if ($LASTEXITCODE -ne 0) { throw 'Maven build failed' }

$procs = @()
try {
  foreach ($service in 'user-service', 'tracker-service', 'gateway') {
    $procs += Start-Process -FilePath java -ArgumentList '-jar', "$service/target/$service.jar" `
      -NoNewWindow -PassThru
  }
  Write-Host 'JobTrail API on http://localhost:3000/api/v1 (GET /health to check). Ctrl+C to stop.'
  Wait-Process -Id ($procs | ForEach-Object Id)
}
finally {
  $procs | Where-Object { -not $_.HasExited } | Stop-Process -Force
}
