# IdleHibernateUnlessAwake

Forces Windows to hibernate (`shutdown /h /f`) after 15 minutes of idle **unless PowerToys Awake is ON**.

## Install
.\tools\Install-IdleHibernateTask.ps1

## Uninstall
.\tools\Uninstall-IdleHibernateTask.ps1

How it works

- A scheduled task triggers on idle.
- src/runner.ps1 waits 15 minutes, checks PowerToys Awake (registry/JSON).
- If Awake = OFF → hibernate. If ON → do nothing.

Requirements
- Windows 11
- PowerShell 5.1+ (or 7)
- PowerToys (optional, only for the “Awake” check)