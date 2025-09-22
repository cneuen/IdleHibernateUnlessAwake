[CmdletBinding()]
param(
    [ValidateSet('Install','Uninstall')]
    [string]$Action = 'Install',
    [string]$TaskName = 'IdleHibernateUnlessAwake',
    [int]$SleepSeconds = 900,
    [switch]$EnableLogging,
    [switch]$RemoveFiles,
    [switch]$RunElevated
)

$ErrorActionPreference = 'Stop'

$scriptDir = if ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { $null }
$projectRoot = if ($scriptDir) { Split-Path -Parent $scriptDir } else { $null }
$rawBaseUri = 'https://raw.githubusercontent.com/cneuen/IdleHibernateUnlessAwake/main/'
$onlineCacheRoot = $null

function Get-OnlineCacheRoot {
    if (-not $script:onlineCacheRoot) {
        $script:onlineCacheRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("IdleHibernateUnlessAwake_{0}" -f [guid]::NewGuid())
        New-Item -Path $script:onlineCacheRoot -ItemType Directory -Force | Out-Null
    }
    return $script:onlineCacheRoot
}

function Resolve-ProjectFile {
    param([Parameter(Mandatory)] [string]$RelativePath)

    if ($projectRoot) {
        $localPath = Join-Path $projectRoot $RelativePath
        if (Test-Path $localPath) {
            return $localPath
        }
    }

    $cacheRoot = Get-OnlineCacheRoot
    $targetPath = Join-Path $cacheRoot $RelativePath
    $targetDir = Split-Path -Parent $targetPath
    if (-not (Test-Path $targetDir)) {
        New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
    }

    $uri = $rawBaseUri + ($RelativePath -replace '\\','/')
    Write-Host "Downloading $RelativePath from $uri" -ForegroundColor Yellow
    Invoke-WebRequest -Uri $uri -OutFile $targetPath | Out-Null
    return $targetPath
}

function Invoke-Schtasks {
    param([string]$Arguments)

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'schtasks.exe'
    $psi.Arguments = $Arguments
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi

    $process.Start() | Out-Null
    $stderr = $process.StandardError.ReadToEnd()
    $output = $process.StandardOutput.ReadToEnd()
    $process.WaitForExit()

    if ($stderr) { Write-Host "Warning: $($stderr.Trim())" -ForegroundColor Yellow }
    if ($output) { Write-Host $output }

    if ($process.ExitCode -ne 0) {
        throw "schtasks exited with code $($process.ExitCode)`nOutput: $output`nError: $stderr"
    }
}

$installRoot = Join-Path $env:LOCALAPPDATA 'Programs\IdleHibernateUnlessAwake'
$installSrcDir = Join-Path $installRoot 'src'
$runnerInstallPath = Join-Path $installSrcDir 'runner.ps1'

try {
    switch ($Action) {
        'Install' {
            if ($SleepSeconds -lt 1) {
                throw 'SleepSeconds must be a positive integer.'
            }

            $runnerSourcePath = Resolve-ProjectFile 'src\runner.ps1'
            $templatePath = Resolve-ProjectFile 'task-template.xml'

            if (-not (Test-Path $installSrcDir)) {
                New-Item -Path $installSrcDir -ItemType Directory -Force | Out-Null
            }

            Copy-Item -Path $runnerSourcePath -Destination $runnerInstallPath -Force

            $commandPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
            if (-not (Test-Path $commandPath)) {
                throw "Unable to locate powershell.exe at $commandPath"
            }

            # Build runner arguments with logging and sleep settings
            $runnerArguments = "-NoProfile -ExecutionPolicy Bypass -File `"$runnerInstallPath`""
            if ($EnableLogging) {
                $runnerArguments += ' -EnableLogging'
            }
            $runnerArguments += " -SleepSeconds $SleepSeconds"

            $runLevel = if ($RunElevated) { 'HighestAvailable' } else { 'LeastPrivilege' }

            $xmlTemplate = Get-Content -Path $templatePath -Raw -Encoding Unicode
            $commandEscaped = [System.Security.SecurityElement]::Escape($commandPath)
            $argumentsEscaped = [System.Security.SecurityElement]::Escape($runnerArguments)
            $xmlContent = $xmlTemplate.Replace('__COMMAND__', $commandEscaped)
            $xmlContent = $xmlContent.Replace('__ARGUMENTS__', $argumentsEscaped)
            $xmlContent = $xmlContent.Replace('__RUNLEVEL__', $runLevel)

            $tempXml = Join-Path ([System.IO.Path]::GetTempPath()) ("IdleHibernateTask_{0}.xml" -f [guid]::NewGuid())
            try {
                # Validate XML before using it
                [xml]$null = $xmlContent
                
                # Save and use the validated XML
                $xmlContent | Out-File -FilePath $tempXml -Encoding Unicode
                Write-Host "Installing scheduled task '$TaskName'" -ForegroundColor Yellow
                Invoke-Schtasks "/create /tn `"$TaskName`" /xml `"$tempXml`" /f"
                Write-Host "Task '$TaskName' installed." -ForegroundColor Green
            }
            finally {
                if (Test-Path $tempXml) {
                    Remove-Item -Path $tempXml -Force
                }
            }
        }

        'Uninstall' {
            $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
            if ($null -ne $task) {
                Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
                Write-Host "Task '$TaskName' removed." -ForegroundColor Green
            }
            else {
                Write-Host "Task '$TaskName' not found." -ForegroundColor Yellow
            }

            if ($RemoveFiles -and (Test-Path $installRoot)) {
                Remove-Item -Path $installRoot -Recurse -Force
                Write-Host "Removed install directory $installRoot." -ForegroundColor Yellow
            }
        }
    }
}
finally {
    if ($onlineCacheRoot -and (Test-Path $onlineCacheRoot)) {
        Remove-Item -Path $onlineCacheRoot -Recurse -Force
    }
}
