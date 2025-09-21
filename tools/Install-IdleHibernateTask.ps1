param(
  [string]$TaskName = "IdleHibernateUnlessAwake"
)

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
$command = "`"$pwsh`" -NoProfile -ExecutionPolicy Bypass -File `"$runnerPath`""

# Obtenir le nom d'utilisateur au format correct pour schtasks (SYSTEM\Username)
$userName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
if ($userName -notlike "*\*") {
    $computerName = $env:COMPUTERNAME
    $userName = "$computerName\$userName"
}

Write-Host "Creating task as user: $userName"

$schtasksArgs = @(
    "/create",
    "/tn", $TaskName,
    "/tr", $command,
    "/sc", "ONIDLE",
    "/i", "15",
    "/ru", $userName,
    "/rl", "HIGHEST",
    "/f"
)

# Exécuter schtasks et capturer la sortie complète
$output = & schtasks.exe $schtasksArgs 2>&1
$success = $LASTEXITCODE -eq 0

# Afficher la sortie pour le débogage
$output | ForEach-Object { Write-Host $_ }

if (-not $success) {
    throw "Failed to create scheduled task. Exit code: $LASTEXITCODE"
}

Write-Host "Task '$TaskName' installed."
Write-Host "Action: $pwsh $arg"
Write-Host "To customize settings (SleepSeconds, EnableLogging), modify src/config.json."
