param(
  [string]$TaskName = "IdleHibernateUnlessAwake"
)

$repoRoot   = Split-Path -Parent $PSCommandPath
$repoRoot   = Split-Path -Parent $repoRoot   # Go up from tools\ to root folder
$runnerPath = Join-Path $repoRoot "src\runner.ps1"

if (-not (Test-Path $runnerPath)) {
  throw "runner.ps1 not found: $runnerPath"
}

# Action: launch PowerShell on runner.ps1
$pwsh = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
$arg  = "-NoProfile -ExecutionPolicy Bypass -File `"$runnerPath`""

$schtasksCommand = "schtasks /create /tn `"$TaskName`" /tr `"$pwsh $arg`" /sc ONIDLE /i 15 /ru `"$me`" /rl HIGHEST /f"
Invoke-Expression $schtasksCommand

Write-Host "Task '$TaskName' installed."
Write-Host "Action: $pwsh $arg"
Write-Host "To customize settings (SleepSeconds, EnableLogging), modify src/config.json."
