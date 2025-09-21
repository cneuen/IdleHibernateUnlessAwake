param (
    [int]$SleepSeconds,
    [switch]$EnableLogging
)

# --- Configuration ---
$configPath = Join-Path $PSScriptRoot 'config.json'
$defaults = @{
    SleepSeconds = 900
    EnableLogging = $false
}
$fileConfig = @{}

if (Test-Path $configPath) {
    $fileConfig = Get-Content -Path $configPath -Raw | ConvertFrom-Json
}

$finalConfig = $defaults.Clone()
$fileConfig.GetEnumerator() | ForEach-Object { $finalConfig[$_.Name] = $_.Value }

if ($PSBoundParameters.ContainsKey('SleepSeconds')) {
    $finalConfig.SleepSeconds = $SleepSeconds
}
if ($PSBoundParameters.ContainsKey('EnableLogging')) {
    $finalConfig.EnableLogging = $EnableLogging.IsPresent
}

$SleepSeconds = $finalConfig.SleepSeconds
$EnableLogging = $finalConfig.EnableLogging

# Hibernate si Awake est OFF après 15 minutes d'inactivité
$logDir = Join-Path $env:LOCALAPPDATA 'IdleHibernateUnlessAwake'
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory | Out-Null
}
$log = Join-Path $logDir 'IdleAwakeProbe.txt'
function Write-Log($m) {
    if ($EnableLogging) {
        $ts = Get-Date -Format o
        "$ts | $m" | Out-File -FilePath $log -Append -Encoding UTF8
    }
}

Write-Log "Task started; user=$(whoami)"

try {
    # Attendre
    Start-Sleep -Seconds $SleepSeconds
    Write-Log "After $SleepSeconds sec wait"

    $awake = $false
    $mode  = $null
    $keep  = $null
    $src   = @()

    # --- Registre (anciennes versions) ---
    $reg = 'HKCU:\Software\Microsoft\PowerToys\Awake'
    if (Test-Path $reg) {
        $p = Get-ItemProperty -Path $reg -ErrorAction SilentlyContinue
        if ($p) {
            if ($p.PSObject.Properties.Name -contains 'Mode')    { $mode = $p.Mode }
            if ($p.PSObject.Properties.Name -contains 'Enabled') { $keep = [bool]$p.Enabled }
            $src += 'reg'
        }
    }

    # --- JSON (versions récentes) ---
    $json = Join-Path $env:LOCALAPPDATA 'Microsoft\PowerToys\Awake\settings.json'
    if (Test-Path $json) {
        try {
            $cfg = Get-Content -Path $json -Raw | ConvertFrom-Json
            if ($null -eq $mode) { $mode = $cfg.properties.mode }
            if ($null -eq $keep) { $keep = $cfg.properties.keepAwake }
            $src += 'json'
        } catch {}
    }

    # Décision
    if (($mode -is [int] -and $mode -ne 0) -or
        ($mode -in @('indefinite','timed')) -or
        ($keep -eq $true)) {
        $awake = $true
    }

    Write-Log ("sources=" + ($src -join '+') + " | mode=" + $mode + " | keep=" + $keep + " | Awake=" + $awake)

    if ($awake) {
        Write-Log "Awake ON -> skipping hibernate"
        exit 1
    }

    Write-Log "Awake OFF -> shutdown /h /f"
    Start-Process -FilePath 'shutdown.exe' -ArgumentList '/h','/f'
    exit 0
}
catch {
    Write-Log ("ERROR: " + $_.Exception.Message)
    exit 2
}
