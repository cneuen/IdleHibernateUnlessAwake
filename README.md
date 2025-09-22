![Platform](https://img.shields.io/badge/platform-Windows%2011-blue?logo=windows)

# IdleHibernateUnlessAwake

Forces Windows to hibernate (`shutdown /h /f`) after a configurable period of idle time, **unless PowerToys Awake is ON**.

## Context

This script is useful in cases where the PC only supports S0 sleep (Modern Standby) and not S3 (which is sometimes disabled in the BIOS).

## How it works

- A scheduled task triggers when the system is idle.
- `src/runner.ps1` waits for a configurable amount of time (default is 15 minutes).
- It then checks if PowerToys Awake is active by looking at the registry and JSON settings file.
- If Awake is OFF, it initiates hibernation.
- If Awake is ON, it does nothing.

## Compatibility

- Windows 11 (tested)
- Windows 10 (may work but not tested)
- Linux / macOS (not supported)

## Requirements

- Windows 10/11
- PowerShell 5.1+ (or 7)
- PowerToys (optional, but the main feature is to check if it is running)
- Hibernation must be enabled. You can enable it by running the following command in an elevated command prompt:
  ```cmd
  powercfg /hibernate on
  ```

## Online Installation

Run the installer directly from GitHub. It pulls the latest runner and XML template on demand, so no additional files are required locally.

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; iex "& { $(Invoke-WebRequest 'https://raw.githubusercontent.com/cneuen/IdleHibernateUnlessAwake/main/tools/Install-IdleHibernateTask.ps1').Content } -Action Install -SleepSeconds 900"
```

Add optional switches like `-EnableLogging` or `-RunElevated` to tweak the behavior before the task is created.

## Local Installation

If you already cloned the repository, invoke the same script from disk:

```powershell
.\tools\Install-IdleHibernateTask.ps1 -SleepSeconds 900 -EnableLogging
```

`-Action` defaults to `Install`, so you can omit it during local installs.

## Uninstallation

Reuse the script to remove the scheduled task. Include `-RemoveFiles` to delete the copied runner from `%LOCALAPPDATA%\Programs\IdleHibernateUnlessAwake`.

```powershell
.\tools\Install-IdleHibernateTask.ps1 -Action Uninstall -RemoveFiles
```

## Configuration

`tools/Install-IdleHibernateTask.ps1` accepts:

- `-SleepSeconds <int>` - idle wait time before hibernation (default: 900 seconds).
- `-EnableLogging` - forward task execution details to `%LOCALAPPDATA%\\IdleHibernateUnlessAwake\\IdleAwakeProbe.txt`.
- `-TaskName <string>` - customise the scheduled-task identifier.
- `-RemoveFiles` - optional cleanup toggle for the uninstall action.
- `-RunElevated` - request `HighestAvailable` run level (requires admin); leave it off for standard user installs.

`src/runner.ps1` also exposes `-SleepSeconds` and `-EnableLogging` for ad-hoc testing should you want to run it manually.

## Changelog

### 0.2.0
- Added `-SleepSeconds` parameter to control the idle duration before hibernation.
- Introduced `config.json` for easier configuration.

### 0.1.0
- Initial release.
- Added `-EnableLogging` parameter for debugging.


