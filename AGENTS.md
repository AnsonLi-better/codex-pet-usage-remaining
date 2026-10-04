# Contributor guidance

Windows PowerShell 5.1 + WPF/Windows Forms companion for Codex Desktop quota and token usage. See README.md / README.en.md for behavior and AGENT_SETUP.md for installation.

## Development and checks

- Use Windows PowerShell (`powershell.exe`), not PowerShell 7, for runtime verification.
- Run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\CodexPetUsageOverlay.ps1 -Command SelfTest`.
- Run `tests\DesktopPresence.Tests.ps1` and `tests\PetCompatibility.Tests.ps1` with the same PowerShell options.
- Run `powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File tests\IdleStartup.Tests.ps1` in a Windows desktop session.
- Build both installers with `Build-Installer.ps1` (Inno Setup 6 required).
- Regenerate bilingual SVG previews with `Generate-ReadmePreviews.ps1` after UI-label changes.

## Boundaries

- Never modify Codex itself or commit local auth, logs, usage state, or personal screenshots.
- Validate Desktop executable identity; CLI/private app-server processes must not activate the UI.
- Prefer native pet windows. Saved-coordinate compatibility requires real Desktop presence and the pet-open flag; document stale-state limitations.
- Keep Chinese/English README, generated previews, runtime version, and installer version consistent.
- Preserve Windows PowerShell-compatible encoding when editing scripts containing Chinese text.
- `dist/`, `vendor/`, and design experiments are ignored; installer binaries belong in reviewed releases, not source PRs.

## Current status

1.4.1 adds background waiting and newer-pet compatibility. Automated tests cover idle startup and detection; actual hover/drag appearance still needs manual desktop validation.
