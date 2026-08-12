@echo off
setlocal
cd /d "%~dp0"
echo Removing Codex Pet Usage Overlay auto-start...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0CodexPetUsageOverlay.ps1" UninstallTask
echo.
echo Auto-start removed. The project files were not deleted.
pause
