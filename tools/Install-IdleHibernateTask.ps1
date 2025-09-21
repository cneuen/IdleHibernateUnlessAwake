param(
  [string]$TaskName = "IdleHibernateUnlessAwake"
)

$repoRoot = Split-Path -Parent $PSCommandPath
$repoRoot = Split-Path -Parent $repoRoot   # Go up from tools\ to root folder
$sourceRunnerPath = Join-Path $repoRoot "src\runner.ps1"
$sourceConfigPath = Join-Path $repoRoot "src\config.json"

if (-not (Test-Path $sourceRunnerPath)) {
  throw "runner.ps1 not found: $sourceRunnerPath"
}

# Créer le dossier d'installation
$installDir = Join-Path $env:LOCALAPPDATA "Programs\IdleHibernateUnlessAwake"
$installSrcDir = Join-Path $installDir "src"
if (-not (Test-Path $installSrcDir)) {
  New-Item -Path $installSrcDir -ItemType Directory -Force | Out-Null
}

# Copier les fichiers
$runnerPath = Join-Path $installSrcDir "runner.ps1"
Copy-Item -Path $sourceRunnerPath -Destination $runnerPath -Force
if (Test-Path $sourceConfigPath) {
  Copy-Item -Path $sourceConfigPath -Destination (Join-Path $installSrcDir "config.json") -Force
}

# Action: launch PowerShell on runner.ps1
$pwsh = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
$arg  = "-NoProfile -ExecutionPolicy Bypass -File `"$runnerPath`""

$me = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$schtasksCommand = "schtasks /create /tn `"$TaskName`" /tr `"$pwsh $arg`" /sc ONIDLE /i 15 /ru `"$me`" /rl HIGHEST /f"
Invoke-Expression $schtasksCommand

Write-Host "Task '$TaskName' installed."
Write-Host "Action: $pwsh $arg"
Write-Host "To customize settings (SleepSeconds, EnableLogging), modify src/config.json."
