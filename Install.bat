@echo off
setlocal
cd /d "%~dp0"
echo Installing Codex Pet Usage Overlay...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0CodexPetUsageOverlay.ps1" InstallTask
if errorlevel 1 (
  echo.
  echo Installation failed. Please send the message above for diagnosis.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0CodexPetUsageOverlay.ps1" Start
if errorlevel 1 (
  echo.
  echo Auto-start was installed, but the overlay could not be started now.
  echo You can try Start.bat after closing this window.
  pause
  exit /b 1
)
echo.
echo Installation complete. The overlay is running now and will also start automatically when you sign in to Windows.
pause
