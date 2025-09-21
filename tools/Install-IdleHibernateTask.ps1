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

# Détecter le dossier d'installation
$installDir = Join-Path $env:LOCALAPPDATA "Programs\IdleHibernateUnlessAwake"
$installSrcDir = Join-Path $installDir "src"
$runnerPath = Join-Path $installSrcDir "runner.ps1"

# Si le script runner.ps1 n'existe pas dans le dossier d'installation, essayer de le copier depuis le repo
if (-not (Test-Path $runnerPath)) {
  $repoRoot = Split-Path -Parent $PSCommandPath
  $repoRoot = Split-Path -Parent $repoRoot   # Go up from tools\ to root folder
  $sourceRunnerPath = Join-Path $repoRoot "src\runner.ps1"
  $sourceConfigPath = Join-Path $repoRoot "src\config.json"

  if (-not (Test-Path $sourceRunnerPath)) {
    throw "runner.ps1 not found: $sourceRunnerPath"
  }

  # Créer le dossier d'installation si nécessaire
  if (-not (Test-Path $installSrcDir)) {
    New-Item -Path $installSrcDir -ItemType Directory -Force | Out-Null
  }

  # Copier les fichiers seulement s'ils n'existent pas déjà
  if (-not (Test-Path $runnerPath)) {
    Copy-Item -Path $sourceRunnerPath -Destination $runnerPath -Force
  }
  
  $configDestPath = Join-Path $installSrcDir "config.json"
  if (Test-Path $sourceConfigPath -and -not (Test-Path $configDestPath)) {
    Copy-Item -Path $sourceConfigPath -Destination $configDestPath -Force
  }
}

# Action: launch PowerShell on runner.ps1
$pwsh = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
Write-Host "PowerShell path: $pwsh"
Write-Host "Runner path: $runnerPath"

# Charger et personnaliser le template XML
$templatePath = Join-Path $PSScriptRoot "task-template.xml"
if (-not (Test-Path $templatePath)) {
    throw "Template XML introuvable : $templatePath"
}

$taskXml = Get-Content -Path $templatePath -Raw -Encoding Unicode
$taskXml = $taskXml.Replace("__POWERSHELL_PATH__", $pwsh)
$taskXml = $taskXml.Replace("__RUNNER_PATH__", $runnerPath)

# Sauvegarder la définition XML dans un fichier temporaire
$xmlPath = [System.IO.Path]::GetTempFileName()
$taskXml | Out-File -FilePath $xmlPath -Encoding Unicode

Write-Host "Creating scheduled task with XML definition..." -ForegroundColor Yellow

try {
    # Utiliser schtasks avec le fichier XML
    $output = & schtasks.exe /create /tn $TaskName /xml $xmlPath /f 2>&1
    $success = $LASTEXITCODE -eq 0

    # Afficher la sortie pour le débogage
    $output | ForEach-Object { Write-Host $_ }

    if (-not $success) {
        throw "Failed to create scheduled task. Exit code: $LASTEXITCODE"
    }
}
finally {
    # Nettoyer le fichier temporaire
    if (Test-Path $xmlPath) {
        Remove-Item -Path $xmlPath -Force
    }
}

Write-Host "Task '$TaskName' installed."
Write-Host "Action: $pwsh $arg"
Write-Host "To customize settings (SleepSeconds, EnableLogging), modify src/config.json."
