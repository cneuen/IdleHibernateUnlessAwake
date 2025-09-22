[CmdletBinding()]
param(
    [ValidateSet('Install','Uninstall')]
    [string]$Action = 'Install',
    [string]$TaskName = 'IdleHibernateUnlessAwake',
    [int]$SleepSeconds = 900,
    [switch]$EnableLogging,
    [switch]$RemoveFiles
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$projectRoot = Split-Path -Parent $scriptDir
$templatePath = Join-Path $projectRoot 'task-template.xml'
$runnerSourcePath = Join-Path $projectRoot 'src\runner.ps1'

$installRoot = Join-Path $env:LOCALAPPDATA 'Programs\IdleHibernateUnlessAwake'
$installSrcDir = Join-Path $installRoot 'src'
$runnerInstallPath = Join-Path $installSrcDir 'runner.ps1'

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
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    if ($stdout) { Write-Host $stdout.Trim() }
    if ($stderr) { Write-Warning $stderr.Trim() }

    if ($process.ExitCode -ne 0) {
        throw "schtasks exited with code $($process.ExitCode)"
    }
}

switch ($Action) {
    'Install' {
        if ($SleepSeconds -lt 1) {
            throw 'SleepSeconds must be a positive integer.'
        }

        if (-not (Test-Path $runnerSourcePath)) {
            throw "runner.ps1 not found at $runnerSourcePath"
        }

        if (-not (Test-Path $templatePath)) {
            throw "Task XML template not found at $templatePath"
        }

        if (-not (Test-Path $installSrcDir)) {
            New-Item -Path $installSrcDir -ItemType Directory -Force | Out-Null
        }

        Copy-Item -Path $runnerSourcePath -Destination $runnerInstallPath -Force

        $commandPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        if (-not (Test-Path $commandPath)) {
            throw "Unable to locate powershell.exe at $commandPath"
        }

        $runnerArguments = "-NoProfile -ExecutionPolicy Bypass -File `"$runnerInstallPath`""
        if ($EnableLogging) {
            $runnerArguments += ' -EnableLogging'
        }
        $runnerArguments += " -SleepSeconds $SleepSeconds"

        $xmlTemplate = Get-Content -Path $templatePath -Raw -Encoding Unicode
        $commandEscaped = [System.Security.SecurityElement]::Escape($commandPath)
        $argumentsEscaped = [System.Security.SecurityElement]::Escape($runnerArguments)
        $xmlContent = $xmlTemplate.Replace('__COMMAND__', $commandEscaped).Replace('__ARGUMENTS__', $argumentsEscaped)

        $tempXml = Join-Path ([System.IO.Path]::GetTempPath()) ("IdleHibernateTask_{0}.xml" -f [guid]::NewGuid())
        try {
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
