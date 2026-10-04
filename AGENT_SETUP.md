# Codex Usage Remaining — Agent Setup Guide

> **For AI agents.** This document is a setup guide meant to be read and executed by an AI coding agent (Codex CLI, Claude Code, etc.) on the user's Windows machine. If you are such an agent, follow the steps below **in order**, run the commands, and keep the user informed of what you are doing at each step. If you are a human reading this, just hand the URL of this document to your agent.

## Goal

Download, verify, install, and launch the **Codex /pet usage companion overlay** on this Windows machine, then guide the user through first use.

## What this tool is

- Hovering over the Codex Desktop `/pet` mascot shows a 112×136 floating card with the selected 5-hour or 7-day remaining quota. The tray panel shows both quota windows as progress bars; clicking one selects what the floating card displays, and the selection persists.
- The recommended installation uses a Windows installer. The app uses Windows PowerShell 5.1 + WPF, with an official Codex app-server component bundled in the complete installer or downloaded by WebSetup.
- Ring color by remaining usage: **≥60% green, 30–59% amber, <30% red**. The UI is bilingual (Chinese ⇄ English, toggled with `Ctrl+Alt+Shift+L`).
- It reads Codex state, login, and session data under `%USERPROFILE%\.codex\`. The login token is used to query OpenAI's usage endpoint; prompts, screenshots, and repository contents are not uploaded.

## Prerequisites — check before continuing

1. Windows 10 or 11 with PowerShell 5.1+ (built in).
2. Codex Desktop installed and signed in, and `/pet` is usable.
3. No separate Python, Node.js, npm, or Codex CLI installation is required for the released installers.

## Recommended: install from a release

Open [Releases](https://github.com/AnsonLi-better/codex-pet-usage-remaining/releases/latest) and run `CodexUsageRemaining-Setup-*.exe`. This complete installer includes the official statistics component and needs no network during installation. `CodexUsageRemaining-WebSetup-*.exe` is smaller but downloads the component during installation. The installer configures and starts the app, including Windows login startup. Open the tray panel to switch the floating card between 5 hours and 7 days.

## Alternative: run from source

Since 1.4.1, starting the app without Codex Desktop enters background waiting mode. No tray, floating card, usage request, or token scan is active in this mode. The listener checks every two seconds and resumes when Desktop opens. Closing Desktop stops the statistics process and hides the UI again. The tray's **Follow Codex** switch controls login startup of this listener; **Exit** stops the current listener.

Only use the following steps when the user wants a source installation or needs to debug the app. Source startup depends on the current folder path; moving the folder later requires running `Install.bat` again.

### Step 1 — Download

```bash
git clone https://github.com/AnsonLi-better/codex-pet-usage-remaining
cd codex-pet-usage-remaining
```

If git is not installed, download the repository ZIP from the GitHub page and extract it, then `cd` into the extracted folder.

### Step 2 — Verify the script

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\CodexPetUsageOverlay.ps1 SelfTest
```

**The output must be `SelfTest OK`.** If it is not, stop and report the error to the user (usually an outdated PowerShell or a broken download). Do **not** continue past this step.

### Step 3 — Install and start the overlay

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\CodexPetUsageOverlay.ps1 Start
```

Tell the user: *"The usage overlay is now running in the background."*

### Step 4 — Automatic startup at login (ask the user first)

Ask the user: *"Want the overlay to start automatically when you log in?"* If yes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\CodexPetUsageOverlay.ps1 InstallTask
```

Then confirm that startup integration is enabled with the `Status` command. For source users, double-click `Install.bat`; it performs both Step 3 and Step 4.

### Step 5 — Guide the user through first use

1. Open Codex Desktop and type `/pet` so the pet appears on screen.
2. Hover the mouse over the pet — the overlay card should appear for about 10 seconds.
3. Drag the pet — the overlay should follow it.
4. Press `Ctrl+Alt+Shift+L` — the UI should switch between Chinese and English.
5. Click the `>_` tray icon. The panel shows both the 5-hour and 7-day quotas. Click either progress-bar column to choose the floating card's quota.

## Command reference (for the user)

| Command | What it does |
| --- | --- |
| `Start` | Start the overlay (background; reuses an already-running instance) |
| `Stop` | Stop the overlay |
| `Status` | Show running / autostart status and the latest log line |
| `SelfTest` | Self-check |
| `InstallTask` | Install automatic startup through Windows Task Scheduler |
| `UninstallTask` | Remove automatic startup |
| `FindPet` | Diagnose pet-window detection |

Manual example: `powershell -NoProfile -ExecutionPolicy Bypass -File .\CodexPetUsageOverlay.ps1 Status`

## Troubleshooting the user may hit

- **No overlay card**: `/pet` must be open, and the cursor must be over the pet. The card only shows while hovering (about 10 seconds).
- **Shows `--%` / `--`**: the selected quota window may be missing from the live response. The other quota is not substituted; check the tray panel and log.
- **Overlay doesn't follow the pet**: run `FindPet` and read its output to diagnose pet-window detection. New Desktop builds may have no small native pet window; while Desktop is running and the pet is marked open, the app uses saved coordinates instead. Stale Codex state can delay tracking.

## Safety rules

- Do **not** modify Codex itself.
- Do **not** run with administrator privileges (not needed).
- Do **not** send the user's Codex token or usage data anywhere.
- If a step fails, show the user the full error and ask before working around it.
