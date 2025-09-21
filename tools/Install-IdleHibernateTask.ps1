param(
  [string]$TaskName = "IdleHibernateUnlessAwake"
)

# Vérifier les privilèges d'administrateur
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Élévation des privilèges requise. Redémarrage en tant qu'administrateur..." -ForegroundColor Yellow
    $arguments = "& '" + $MyInvocation.MyCommand.Definition + "'"
    Start-Process powershell -Verb RunAs -ArgumentList $arguments
    exit
}

# Detect installation directory
$installDir = Join-Path $env:LOCALAPPDATA "Programs\IdleHibernateUnlessAwake"
$installSrcDir = Join-Path $installDir "src"
$runnerPath = Join-Path $installSrcDir "runner.ps1"

# If runner.ps1 doesn't exist in the installation directory, try to copy it from the repo
if (-not (Test-Path $runnerPath)) {
  $repoRoot = Split-Path -Parent $PSCommandPath
  $repoRoot = Split-Path -Parent $repoRoot   # Go up from tools\ to root folder
  $sourceRunnerPath = Join-Path $repoRoot "src\runner.ps1"

  if (-not (Test-Path $sourceRunnerPath)) {
    throw "runner.ps1 not found: $sourceRunnerPath"
  }

  # Create installation directory if needed
  if (-not (Test-Path $installSrcDir)) {
    New-Item -Path $installSrcDir -ItemType Directory -Force | Out-Null
  }

  # Copy runner.ps1 if it doesn't already exist
  if (-not (Test-Path $runnerPath)) {
    Copy-Item -Path $sourceRunnerPath -Destination $runnerPath -Force
  }
}

# Action: launch PowerShell on runner.ps1
$pwsh = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
Write-Host "PowerShell path: $pwsh"
Write-Host "Runner path: $runnerPath"

# Load and customize the XML template
$templatePath = Join-Path (Split-Path -Parent $PSScriptRoot) "task-template.xml"
if (-not (Test-Path $templatePath)) {
    throw "XML template not found: $templatePath"
}

$taskXml = Get-Content -Path $templatePath -Raw -Encoding Unicode
$taskXml = $taskXml.Replace("__POWERSHELL_PATH__", $pwsh)
$taskXml = $taskXml.Replace("__RUNNER_PATH__", $runnerPath)

# Save the XML definition to a temporary file
$xmlPath = [System.IO.Path]::GetTempFileName()
$taskXml | Out-File -FilePath $xmlPath -Encoding Unicode

Write-Host "Creating scheduled task with XML definition..." -ForegroundColor Yellow

try {
    # Use schtasks with the XML file
    $output = & schtasks.exe /create /tn $TaskName /xml $xmlPath /f 2>&1
    $success = $LASTEXITCODE -eq 0

    # Display output for debugging
    $output | ForEach-Object { Write-Host $_ }

    if (-not $success) {
        throw "Failed to create scheduled task. Exit code: $LASTEXITCODE"
    }
}
finally {
    # Clean up temporary file
    if (Test-Path $xmlPath) {
        Remove-Item -Path $xmlPath -Force
    }
}

Write-Host "Task '$TaskName' installed."
Write-Host "Action: $pwsh $arg"
Write-Host "To customize settings (SleepSeconds, EnableLogging), modify src/config.json."
