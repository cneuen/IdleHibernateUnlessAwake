# IdleHibernateUnlessAwake

Forces Windows to hibernate (`shutdown /h /f`) after a configurable period of idle time, **unless PowerToys Awake is ON**.

## How it works

- A scheduled task triggers when the system is idle.
- `src/runner.ps1` waits for a configurable amount of time (default is 15 minutes).
- It then checks if PowerToys Awake is active by looking at the registry and JSON settings file.
- If Awake is OFF, it initiates hibernation.
- If Awake is ON, it does nothing.

## Requirements

- Windows 10/11
- PowerShell 5.1+ (or 7)
- PowerToys (optional, but the main feature is to check if it is running)

## Installation

To install the scheduled task, run the following command in PowerShell:

```powershell
.\tools\Install-IdleHibernateTask.ps1
```

## Uninstallation

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
- `EnableLogging`: Set to `true` to enable logging to `%TEMP%\IdleAwake.txt`.

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