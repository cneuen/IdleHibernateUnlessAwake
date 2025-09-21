param(
  [string]$TaskName = "IdleHibernateUnlessAwake",
  [int]$DelaySeconds = 900  # 15 minutes d'attente dans runner.ps1
)

$repoRoot   = Split-Path -Parent $PSCommandPath
$repoRoot   = Split-Path -Parent $repoRoot   # remonte de tools\ au dossier racine
$runnerPath = Join-Path $repoRoot "src\runner.ps1"

if (-not (Test-Path $runnerPath)) {
  throw "runner.ps1 introuvable: $runnerPath"
}

# Action: lance PowerShell sur runner.ps1
$pwsh = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
$arg  = "-NoProfile -ExecutionPolicy Bypass -File `"$runnerPath`""

$action = New-ScheduledTaskAction -Execute $pwsh -Argument $arg

# Déclencheur: à l'état inactif
$trigger = New-ScheduledTaskTrigger -OnIdle

# Paramètres de la tâche
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero)

# Idle settings: on laisse Windows détecter l'inactivité, on n'arrête pas si ça redevient actif
$idle = New-ScheduledTaskIdleSettings -StopOnIdleEnd:$false -RestartOnIdle:$false -Duration ([TimeSpan]::FromMinutes(0)) -WaitTimeout ([TimeSpan]::FromHours(1))

# Principal: ton compte utilisateur
$me  = "{0}\{1}" -f $env:USERDOMAIN, $env:USERNAME
$pri = New-ScheduledTaskPrincipal -UserId $me -RunLevel Highest   # si tu veux éviter l'UAC, retire -RunLevel Highest

# Enregistre/écrase
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -IdleSettings $idle -Principal $pri -Force | Out-Null

Write-Host "Tâche '$TaskName' installée."
Write-Host "Action: $pwsh $arg"
