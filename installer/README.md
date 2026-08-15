# Building the Windows installer

1. Install Inno Setup 6.
2. From the repository root, run:

```powershell
.\Build-Installer.ps1
```

The installer is written to `dist/`.

Setup is per-user and does not require administrator access. It installs to `%LOCALAPPDATA%\Programs\CodexUsageRemaining`, adds Start-menu entries, enables login startup, starts the tray app, and removes startup integration during uninstall.
