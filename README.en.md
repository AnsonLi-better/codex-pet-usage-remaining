<!-- markdownlint-disable MD033 -->
# Codex `/pet` Usage Companion Overlay

> A minimalist Windows overlay: hover your mouse over the Codex Desktop `/pet` mascot and a small card pops up showing your remaining usage in real time.

Written from scratch, **does not modify Codex**. It only reads Codex's local state file to locate the pet and uses your local Codex login to query usage. No data is sent to any third party.

<p align="center">
  <img src="assets/preview-green.png" width="122" alt="High usage (green)" title=">=60% green"/>
  <img src="assets/preview-amber.png" width="122" alt="Medium usage (amber)" title="30-59% amber"/>
  <img src="assets/preview-red.png" width="122" alt="Low usage (red)" title="<30% red"/>
  <img src="assets/preview-en.png" width="122" alt="English UI" title="English / Weekly"/>
</p>

<p align="center"><a href="README.md">简体中文</a> · <b>English</b></p>

## ✨ Features

- **Hover to show, follows the pet**: the overlay appears when the cursor enters the pet area and auto-hides 10 seconds after you leave. It tracks the pet window in real time (Win32 window tracking), so dragging the pet moves the overlay with it.
- **Minimal card**: ring + percentage inside the ring + countdown to the next refresh. Nothing else.
- **Color tiers**: the ring changes color by remaining usage — ≥60% green, 30–59% amber, <30% red.
- **7-day window**: shows the `secondary_window` remaining usage.
- **Bilingual UI**: press `Ctrl+Alt+Shift+L` to switch between Chinese and English (`7天窗口` ⇄ `Weekly`); your choice is remembered.
- **Resilient data sources**: live API → local logs → "unavailable". Temporary API issues never break the overlay.
- **Optional autostart** at login (current user).

## 📦 Prerequisites

- Windows 10 / 11 with PowerShell 5.1+ (built in)
- [Codex Desktop](https://openai.com/codex/) (signed in) with `/pet` open
- **Python** (optional): only needed for the local-log fallback when the live API is down

## 🚀 Quick start

```text
1. Download / clone this repository
2. Double-click Start.bat
3. Hover your mouse over the Codex pet — the overlay appears
```

To stop: double-click `Stop.bat`. To autostart at login: double-click `InstallStartup.bat`.

## 🧭 Commands

| Command | Description |
| --- | --- |
| `Start` | Start the overlay (background; reuses an already-running instance) |
| `Stop` | Stop the overlay |
| `Status` | Show running / autostart status and the latest log line |
| `SelfTest` | Self-check: script parsing, logic functions, Win32 C# class compilation |
| `InstallStartup` | Install autostart for the current user |
| `UninstallStartup` | Remove autostart |
| `FindPet` | Diagnose pet-window detection (lists Codex processes, candidates, picked window) |

Double-click the `.bat` files or run manually:

```powershell
powershell -ExecutionPolicy Bypass -File .\CodexPetUsageOverlay.ps1 Start
powershell -ExecutionPolicy Bypass -File .\CodexPetUsageOverlay.ps1 Status
```

## ⚙️ Options

```powershell
powershell -ExecutionPolicy Bypass -File .\CodexPetUsageOverlay.ps1 Start -UsagePollSeconds 60 -PetPollMs 80 -HoverPaddingPx 24
```

| Option | Default | Description |
| --- | --- | --- |
| `UsagePollSeconds` | `60` | Usage refresh interval (seconds), min 60 |
| `PetPollMs` | `80` | Cursor / pet position polling interval (ms), min 50 |
| `HoverPaddingPx` | `24` | Extra pixels around the pet treated as hover, so near-misses still trigger |
| `Language` | `zh` | UI language: `zh` Chinese / `en` English (omit to keep the saved choice) |
| `LanguageHotkey` | `Ctrl+Alt+Shift+L` | Global hotkey to switch the UI language at runtime |
| `CodexHome` | `%USERPROFILE%\.codex` | Codex data directory |

## 🧠 How it works

- **Hover detection**: polls the cursor every `PetPollMs`; entering the pet area (with padding) shows the overlay for 10 seconds.
- **Window tracking**: enumerates Codex process windows via Win32, scores candidates by size and position to find the pet window, caches its handle, then reads live coordinates every `PetPollMs` — so the overlay follows when you drag the pet. Falls back to the coordinates in `.codex-global-state.json` when no window matches.
- **Usage fetching**: every `UsagePollSeconds`, uses the access token from your local `auth.json` to call `chatgpt.com/backend-api/wham/usage` and takes the 7-day window (`secondary_window`) remaining percent. On failure it reads the `codex.rate_limits` events from local `logs_2.sqlite` / `logs_1.sqlite` as a fallback.
- **Rendering**: PowerShell 5.1 + WPF, built in pure code (no XAML). A transparent, always-on-top, click-through window that never interferes with interacting with the pet.

## 📁 Repository layout

```text
CodexPetUsageOverlay.ps1    main script (all logic)
Start.bat / Stop.bat / Status.bat
InstallStartup.bat / UninstallStartup.bat
assets/                     preview images
README.md / README.en.md    docs
LICENSE
```

## 🔒 Data & privacy

Reads local files only:

- `%USERPROFILE%\.codex\.codex-global-state.json` (pet position)
- `%USERPROFILE%\.codex\auth.json` (login; only the token is used)
- `%USERPROFILE%\.codex\logs_2.sqlite` / `logs_1.sqlite` (usage fallback)

The token is used only to call:

```text
https://chatgpt.com/backend-api/wham/usage
```

No pet images, screenshots, prompts, repo contents, or log bodies are sent anywhere else.

Runtime files (created automatically):

```text
%LOCALAPPDATA%\CodexPetUsageOverlay\overlay.pid
%LOCALAPPDATA%\CodexPetUsageOverlay\overlay.log
%LOCALAPPDATA%\CodexPetUsageOverlay\lang.txt
```

`lang.txt` records the UI language (`zh` / `en`); it survives restarts.

## 🔧 Troubleshooting

- **No overlay**: make sure `/pet` is open in Codex Desktop, then hover the pet.
- **Nothing after reboot**: run `Status.bat` and confirm `StartupEnabled: True` and `Running: True`.
- **Usage shows unavailable**: run `Status.bat` for the latest log, or read `%LOCALAPPDATA%\CodexPetUsageOverlay\overlay.log`. Usually a temporary API issue — it degrades gracefully.
- **Overlay doesn't follow the pet**: with the pet on screen, run `FindPet` and share its output for diagnosis.

## ⚠️ Known limitations

- `wham/usage` is not a stable public API; fields and availability may change.
- The local-log fallback depends on `codex.rate_limits` events appearing in Codex logs; without them it shows "unavailable".
- Autostart uses the current user's `HKCU\...\Run` plus a Startup-folder shortcut; use Task Scheduler if you need delayed or elevated startup.
- Pet-window detection is heuristic (size + position scoring) and could pick the wrong window in edge cases; `FindPet` can diagnose.

## 📄 License

[MIT](LICENSE)

## ⚖️ Disclaimer

Not affiliated with OpenAI / Anthropic. For personal learning use only. Please follow the Codex terms of service; official usage data takes precedence.
