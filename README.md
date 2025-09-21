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

- ✅ Windows 11 (tested)
- ⚠️ Windows 10 (may work but not tested)
- ❌ Linux / macOS (not supported)

## Requirements

- Windows 10/11
- PowerShell 5.1+ (or 7)
- PowerToys (optional, but the main feature is to check if it is running)
- Hibernation must be enabled. You can enable it by running the following command in an elevated command prompt:
  ```cmd
  powercfg /hibernate on
  ```

## Easy Installation (Online)

A single command to download, configure, and install everything.

Open a PowerShell terminal and run the following command. It will guide you through the installation.

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/cneuen/IdleHibernateUnlessAwake/main/Install-Online.ps1'))
```

This command will:
1.  Temporarily allow script execution for the current process.
2.  Download and run the `Install-Online.ps1` script from GitHub.
3.  The script will then prompt you for the installation directory and configuration settings.

## Manual Installation

If you have already downloaded the files, you can install the scheduled task by running the following command in PowerShell:

```powershell
.\tools\Install-IdleHibernateTask.ps1
```

## Manual Uninstallation

To uninstall the scheduled task, run:

```powershell
.\tools\Uninstall-IdleHibernateTask.ps1
```

## Configuration

You can configure the behavior of `IdleHibernateUnlessAwake` by editing the `src/config.json` file.

```json
{
  "SleepSeconds": 900,
  "EnableLogging": false
}
```

- `SleepSeconds`: The number of seconds to wait in an idle state before hibernating. Default is 900 (15 minutes).
- `EnableLogging`: Set to `true` to enable logging to `%LOCALAPPDATA%\IdleHibernateUnlessAwake\IdleAwakeProbe.txt`.

### Command-line parameters

You can also override the configuration settings by passing command-line parameters to `runner.ps1`.

- `-SleepSeconds <seconds>`: Overrides the `SleepSeconds` setting.
- `-EnableLogging`: Overrides the `EnableLogging` setting to `true`.

These parameters can be useful for testing or for creating custom scheduled tasks.

## Changelog

### 0.2.0
- Added `-SleepSeconds` parameter to control the idle duration before hibernation.
- Introduced `config.json` for easier configuration.

### 0.1.0
- Initial release.
- Added `-EnableLogging` parameter for debugging.
