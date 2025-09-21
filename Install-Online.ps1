#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true)]
param()

# --- Configuration ---
$githubRepo = "cneuen/IdleHibernateUnlessAwake"
$defaultInstallDir = Join-Path $env:LOCALAPPDATA "Programs\IdleHibernateUnlessAwake"

# --- 1. Choose Installation Directory ---
Write-Host "Installation directory for IdleHibernateUnlessAwake." -ForegroundColor Green
$installDir = Read-Host -Prompt "Enter path (default: $defaultInstallDir)"
if ([string]::IsNullOrWhiteSpace($installDir)) {
    $installDir = $defaultInstallDir
}

if (Test-Path $installDir) {
    $overwrite = Read-Host "The directory '$installDir' already exists. Do you want to replace it? (y/n)"
    if ($overwrite -ne 'o') {
        Write-Host "Installation cancelled."
        return
    }
    Write-Host "Cleaning existing directory..."
    Remove-Item -Path $installDir -Recurse -Force
}

Write-Host "Creating directory '$installDir'..."
    New-Item -Path $installDir -ItemType Directory -Force | Out-Null


# --- 2. Download from GitHub ---
$zipUrl = "https://github.com/$githubRepo/archive/refs/heads/main.zip"
$zipPath = Join-Path $env:TEMP "IdleHibernateUnlessAwake-main.zip"

Write-Host "Downloading latest version from GitHub..." -ForegroundColor Green
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing


# --- 3. Decompression ---
Write-Host "Extracting files..."
# Files are in a subfolder (e.g., IdleHibernateUnlessAwake-main)
    Expand-Archive -Path $zipPath -DestinationPath $installDir -Force

# Move files from subfolder to root
$unzippedSubFolder = Get-ChildItem -Path $installDir | Where-Object { $_.PSIsContainer } | Select-Object -First 1
if ($null -ne $unzippedSubFolder) {
    $subFolderPath = $unzippedSubFolder.FullName
    Get-ChildItem -Path $subFolderPath | Move-Item -Destination $installDir -Force
    Remove-Item -Path $subFolderPath -Recurse -Force
}

# Cleaning up zip file
Remove-Item -Path $zipPath -Force


# --- 4. Interactive Configuration ---
Write-Host "`n--- Configuration ---" -ForegroundColor Green
$defaultSleepMinutes = 15
$sleepMinutes = Read-Host -Prompt "Hibernate after how many minutes of inactivity? (default: $defaultSleepMinutes)"
if ([string]::IsNullOrWhiteSpace($sleepMinutes) -or -not ($sleepMinutes -match '^\d+$')) {
    $sleepMinutes = $defaultSleepMinutes
}

$sleepSeconds = [int]$sleepMinutes * 60

$enableLoggingChoice = Read-Host -Prompt "Enable debug logs? (y/n) (default: n)"
$enableLogging = $false
if ($enableLoggingChoice -eq 'y') {
    $enableLogging = $true
}

$config = @{
    SleepSeconds = $sleepSeconds
    EnableLogging = $enableLogging
}

$configPath = Join-Path $installDir "src\config.json"
Write-Host "Creating configuration file at '$configPath'..."
    $config | ConvertTo-Json | Set-Content -Path $configPath -Encoding UTF8


# --- 5. Install Scheduled Task ---
Write-Host "`n--- Installing Scheduled Task ---" -ForegroundColor Green
$installTaskScript = Join-Path $installDir "tools\Install-IdleHibernateTask.ps1"

if (-not (Test-Path $installTaskScript)) {
    Write-Error "Installation script not found at '$installTaskScript'. Installation failed."
    return
}

# Executing installation script
    # Change to directory so relative paths in script work
    Push-Location $installDir
    & $installTaskScript
    Pop-Location

Write-Host "`nInstallation completed successfully!" -ForegroundColor Green
Write-Host "The script is installed in '$installDir'."
Write-Host "You can uninstall it at any time by running 'tools\Uninstall-IdleHibernateTask.ps1' from this directory."