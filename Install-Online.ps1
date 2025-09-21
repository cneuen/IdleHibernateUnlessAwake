#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true)]
param()

# --- Configuration ---
$githubRepo = "cneuen/IdleHibernateUnlessAwake"
$defaultInstallDir = Join-Path $env:LOCALAPPDATA "Programs\IdleHibernateUnlessAwake"

# --- 1. Choisir le dossier d'installation ---
Write-Host "Répertoire d'installation pour IdleHibernateUnlessAwake." -ForegroundColor Green
$installDir = Read-Host -Prompt "Entrez le chemin (défaut: $defaultInstallDir)"
if ([string]::IsNullOrWhiteSpace($installDir)) {
    $installDir = $defaultInstallDir
}

if (Test-Path $installDir) {
    $overwrite = Read-Host "Le répertoire '$installDir' existe déjà. Voulez-vous le remplacer ? (o/n)"
    if ($overwrite -ne 'o') {
        Write-Host "Installation annulée."
        return
    }
    Write-Host "Nettoyage du répertoire existant..."
    if ($pscmdlet.ShouldProcess($installDir, "Remove-Item -Recurse -Force")) {
        Remove-Item -Path $installDir -Recurse -Force
    }
}

Write-Host "Création du répertoire '$installDir'..."
if ($pscmdlet.ShouldProcess($installDir, "New-Item -ItemType Directory")) {
    New-Item -Path $installDir -ItemType Directory -Force | Out-Null
}


# --- 2. Téléchargement depuis GitHub ---
$zipUrl = "https://github.com/$githubRepo/archive/refs/heads/main.zip"
$zipPath = Join-Path $env:TEMP "IdleHibernateUnlessAwake-main.zip"

Write-Host "Téléchargement de la dernière version depuis GitHub..." -ForegroundColor Green
if ($pscmdlet.ShouldProcess($zipUrl, "Invoke-WebRequest -OutFile $zipPath")) {
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
}


# --- 3. Décompression ---
Write-Host "Extraction des fichiers..."
# Les fichiers sont dans un sous-dossier (ex: IdleHibernateUnlessAwake-main)
if ($pscmdlet.ShouldProcess($zipPath, "Expand-Archive -DestinationPath $installDir -Force")) {
    Expand-Archive -Path $zipPath -DestinationPath $installDir -Force
}

# Déplacer les fichiers du sous-dossier vers la racine
$unzippedSubFolder = Get-ChildItem -Path $installDir | Where-Object { $_.PSIsContainer } | Select-Object -First 1
if ($null -ne $unzippedSubFolder) {
    $subFolderPath = $unzippedSubFolder.FullName
    Get-ChildItem -Path $subFolderPath | Move-Item -Destination $installDir -Force
    Remove-Item -Path $subFolderPath -Recurse -Force
}

# Nettoyage du fichier zip
Remove-Item -Path $zipPath -Force


# --- 4. Configuration Interactive ---
Write-Host "`n--- Configuration ---" -ForegroundColor Green
$defaultSleepMinutes = 15
$sleepMinutes = Read-Host -Prompt "Hiberner après combien de minutes d'inactivité ? (défaut: $defaultSleepMinutes)"
if ([string]::IsNullOrWhiteSpace($sleepMinutes) -or -not ($sleepMinutes -match '^\d+$')) {
    $sleepMinutes = $defaultSleepMinutes
}

$sleepSeconds = [int]$sleepMinutes * 60

$enableLoggingChoice = Read-Host -Prompt "Activer les logs de débogage ? (o/n) (défaut: n)"
$enableLogging = $false
if ($enableLoggingChoice -eq 'o') {
    $enableLogging = $true
}

$config = @{
    SleepSeconds = $sleepSeconds
    EnableLogging = $enableLogging
}

$configPath = Join-Path $installDir "src\config.json"
Write-Host "Création du fichier de configuration sur '$configPath'..."
if ($pscmdlet.ShouldProcess($configPath, "Set-Content")) {
    $config | ConvertTo-Json | Set-Content -Path $configPath -Encoding UTF8
}


# --- 5. Installation de la tâche planifiée ---
Write-Host "`n--- Installation de la tâche planifiée ---" -ForegroundColor Green
$installTaskScript = Join-Path $installDir "tools\Install-IdleHibernateTask.ps1"

if (-not (Test-Path $installTaskScript)) {
    Write-Error "Le script d'installation n'a pas été trouvé sur '$installTaskScript'. L'installation a échoué."
    return
}

# Exécution du script d'installation
if ($pscmdlet.ShouldProcess($installTaskScript, "Exécution du script")) {
    # On se déplace dans le répertoire pour que les chemins relatifs du script fonctionnent
    Push-Location $installDir
    & $installTaskScript
    Pop-Location
}

Write-Host "`nInstallation terminée avec succès !" -ForegroundColor Green
Write-Host "Le script est installé dans '$installDir'."
Write-Host "Vous pouvez le désinstaller à tout moment en lançant 'tools\Uninstall-IdleHibernateTask.ps1' depuis ce répertoire."