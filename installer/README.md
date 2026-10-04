# Building the Windows installer

1. Install Inno Setup 6.
2. From the repository root, run:

```powershell
.\Build-Installer.ps1
```

The build writes two installers to `dist/`:

- `CodexUsageRemaining-Setup-<version>.exe`: complete installer with the pinned official statistics component bundled; installation does not need internet access.
- `CodexUsageRemaining-WebSetup-<version>.exe`: smaller installer that downloads and verifies that component during installation.

The build script verifies the component archive's SHA-256 digest before compiling. `dist/` and the downloaded `vendor/` archive are ignored by Git. Attach the two installers separately to a GitHub release after review; they are not part of the source pull request.

Setup is per-user and does not require administrator access. It installs to `%LOCALAPPDATA%\Programs\CodexUsageRemaining`, adds Start-menu entries, and enables the login listener. The tray and statistics activate only while Codex Desktop is running; the listener stays idle otherwise. Uninstall removes startup integration.
