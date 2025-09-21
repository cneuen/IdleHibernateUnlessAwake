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

# Construction de la commande avec échappement correct
$execCommand = "`"$pwsh`" -NoProfile -ExecutionPolicy Bypass -File `"$runnerPath`""

Write-Host "Command that will be executed: $execCommand" -ForegroundColor Cyan

# Créer un objet XML pour la tâche planifiée
$taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Hibernate le PC après une période d'inactivité, sauf si PowerToys Awake est actif</Description>
  </RegistrationInfo>
  <Triggers>
    <IdleTrigger>
      <Enabled>true</Enabled>
    </IdleTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfIdle>true</RunOnlyIfIdle>
    <IdleSettings>
      <Duration>PT15M</Duration>
      <WaitTimeout>PT1H</WaitTimeout>
      <StopOnIdleEnd>true</StopOnIdleEnd>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>$pwsh</Command>
      <Arguments>-NoProfile -ExecutionPolicy Bypass -File "$runnerPath"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

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
