# Codex /pet Usage Companion Overlay — Agent Setup Guide

> **For AI agents.** This document is a setup guide meant to be read and executed by an AI coding agent (Codex CLI, Claude Code, etc.) on the user's Windows machine. If you are such an agent, follow the steps below **in order**, run the commands, and keep the user informed of what you are doing at each step. If you are a human reading this, just hand the URL of this document to your agent.

## Goal

Download, verify, install, and launch the **Codex /pet usage companion overlay** on this Windows machine, then guide the user through first use.

## What this tool is

- When the user hovers the mouse over the Codex Desktop `/pet` mascot, a small 112×136 card appears showing real-time remaining usage: a color-coded progress ring + the percentage inside the ring + a countdown to the next refresh.
- Pure PowerShell 5.1 + WPF; portable, no installer, no third-party runtime.
- Ring color by remaining usage: **≥60% green, 30–59% amber, <30% red**. The UI is bilingual (Chinese ⇄ English, toggled with `Ctrl+Alt+Shift+L`).
- Safe: it only reads local files under `%USERPROFILE%\.codex\` (state, login, logs). It sends nothing to any third party.

## Prerequisites — check before continuing

1. Windows 10 or 11 with PowerShell 5.1+ (built in).
2. Codex Desktop installed and signed in, and `/pet` is usable.
3. Optional: Python (fallback for reading local logs when the live usage API is down).

## Step 1 — Download

```bash
git clone https://github.com/AnsonLi-better/codex-pet-usage-remaining
cd codex-pet-usage-remaining
```

If git is not installed, download the repository ZIP from the GitHub page and extract it, then `cd` into the extracted folder.

## Step 2 — Verify the script

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\CodexPetUsageOverlay.ps1 SelfTest
```

**The output must be `SelfTest OK`.** If it is not, stop and report the error to the user (usually an outdated PowerShell or a broken download). Do **not** continue past this step.

## Step 3 — Start the overlay

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\CodexPetUsageOverlay.ps1 Start
```

Tell the user: *"The usage overlay is now running in the background."*

## Step 4 — Autostart at login (ask the user first)

Ask the user: *"Want the overlay to start automatically when you log in?"* If yes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\CodexPetUsageOverlay.ps1 InstallStartup
```

Then confirm with `Status` that `StartupEnabled` is `True`.

## Step 5 — Guide the user through first use

1. Open Codex Desktop and type `/pet` so the pet appears on screen.
2. Hover the mouse over the pet — the overlay card should appear for about 10 seconds.
3. Drag the pet — the overlay should follow it.
4. Press `Ctrl+Alt+Shift+L` — the UI should switch between Chinese and English.

## Command reference (for the user)

| Command | What it does |
| --- | --- |
| `Start` | Start the overlay (background; reuses an already-running instance) |
| `Stop` | Stop the overlay |
| `Status` | Show running / autostart status and the latest log line |
| `SelfTest` | Self-check |
| `InstallStartup` | Install autostart for the current user |
| `UninstallStartup` | Remove autostart |
| `FindPet` | Diagnose pet-window detection |

Manual example: `powershell -NoProfile -ExecutionPolicy Bypass -File .\CodexPetUsageOverlay.ps1 Status`

## Troubleshooting the user may hit

- **No overlay card**: `/pet` must be open, and the cursor must be over the pet. The card only shows while hovering (about 10 seconds).
- **Shows `--%` / `--`**: the live usage API is temporarily unavailable; the overlay degrades gracefully and retries automatically. Not a bug.
- **Overlay doesn't follow the pet**: run `FindPet` and read its output to diagnose pet-window detection.

## Safety rules

- Do **not** modify Codex itself.
- Do **not** run with administrator privileges (not needed).
- Do **not** send the user's Codex token or usage data anywhere.
- If a step fails, show the user the full error and ask before working around it.
