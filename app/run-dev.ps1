# Runs the app against the local backend. Usage: ./run-dev.ps1 [extra flutter run args]
# 1. finds adb (PATH, ANDROID_HOME, or the SDK Flutter is configured with)
# 2. forwards the phone's/emulator's localhost:3000 to this PC (`adb reverse`), which is lost whenever the
#    phone is unplugged, rebooted or adb restarts -- so it is redone on every run
# 3. checks that the backend answers, then starts `flutter run`
param([Parameter(ValueFromRemainingArguments = $true)] $FlutterArgs)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Find-Adb {
  $cmd = Get-Command adb -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  foreach ($root in @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT)) {
    if ($root -and (Test-Path "$root\platform-tools\adb.exe")) { return "$root\platform-tools\adb.exe" }
  }
  $sdk = (flutter config --machine 2>$null | ConvertFrom-Json).'android-sdk'
  if ($sdk -and (Test-Path "$sdk\platform-tools\adb.exe")) { return "$sdk\platform-tools\adb.exe" }
  return $null
}

$adb = Find-Adb
if ($adb) {
  & $adb reverse tcp:3000 tcp:3000 | Out-Null
  Write-Host "adb reverse OK: $(& $adb reverse --list)"
} else {
  Write-Warning 'adb not found: add <Android SDK>\platform-tools to PATH, or pass --dart-define=API_BASE_URL=http://<PC-IP>:3000/api/v1'
}

try {
  $health = Invoke-RestMethod http://localhost:3000/api/v1/health -TimeoutSec 5
  Write-Host "Backend: $($health.status)"
} catch {
  $health = $null
  Write-Warning 'Backend not answering on http://localhost:3000 -- start gateway, user-service and tracker-service (backend/dev.ps1).'
}

flutter run @FlutterArgs
