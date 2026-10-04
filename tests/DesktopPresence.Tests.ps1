$ErrorActionPreference = 'Stop'
$sourcePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'CodexPetUsageOverlay.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($sourcePath, [ref]$null, [ref]$null)
foreach ($name in @('Test-CodexDesktopProcess', 'Get-CodexProcessIds', 'Build-PetRectFromHwnd', 'Update-Overlay', 'Sync-DesktopPresence', 'Refresh-Usage')) {
  $definition = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) | Where-Object Name -eq $name | Select-Object -First 1
  if ($definition) { Invoke-Expression $definition.Extent.Text }
}
# Isolate a desktop-closed machine, regardless of the test runner's real windows.
Add-Type @'
using System;
public static class CodexPetUsageOverlayNative {
  public delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr lparam);
  public static bool EnumWindows(EnumWindowsProc callback, IntPtr lparam) { return true; }
  public static bool IsWindowVisible(IntPtr hwnd) { return false; }
}
'@
function Get-Process { param($Name, $ErrorAction) return $script:FixtureProcesses }
if ($null -ne (Build-PetRectFromHwnd -Hwnd ([IntPtr]123))) { throw 'Hidden pet windows must not produce a visible overlay rectangle.' }
function New-FixtureProcess {
  param($Name, $Id, $Product = '', $Original = '')
  [PSCustomObject]@{ ProcessName = $Name; Id = $Id; MainModule = [PSCustomObject]@{ FileVersionInfo = [PSCustomObject]@{ ProductName = $Product; OriginalFilename = $Original } } }
}
$script:FixtureProcesses = @((New-FixtureProcess 'codex-app-server' 101), (New-FixtureProcess 'codex' 102))
$ids = @(Get-CodexProcessIds)
if ($ids.Count -ne 0) { throw 'Regression: CLI/private app-server counted as Codex Desktop while Desktop is closed; stale pet coordinates can display the overlay.' }
$script:FixtureProcesses = @((New-FixtureProcess 'ChatGPT' 201 'Codex' 'chrome.exe'), (New-FixtureProcess 'Codex' 202 'Codex' 'chrome.exe'), (New-FixtureProcess 'notepad' 203))
$ids = @(Get-CodexProcessIds)
if ($ids.Count -ne 2 -or $ids -notcontains 201 -or $ids -notcontains 202) { throw 'Desktop detection must support both Codex.exe and ChatGPT.exe.' }
# A saved pet position must not keep the actual overlay path alive without a live pet.
function Get-LivePetRect { return $null }
function Get-PetRect { throw 'Stale persisted pet coordinates must not be used for visibility.' }
$script:OverlayPaused = $false
$script:ShowOverlayUntil = (Get-Date).AddMinutes(1)
$script:CursorWasInPet = $true
$window = [PSCustomObject]@{ Hidden = $false }
$window | Add-Member -MemberType ScriptMethod -Name Hide -Value { $this.Hidden = $true }
Update-Overlay
if (-not $window.Hidden -or $script:CursorWasInPet -or $script:ShowOverlayUntil -ne [datetime]::MinValue) { throw 'A missing live pet must immediately hide and clear the overlay.' }

$script:FixtureProcesses = @((New-FixtureProcess 'codex-app-server' 101))
function Get-Usage { throw 'No quota request is allowed while Desktop is closed.' }
function Get-TokenUsage { throw 'No token scan is allowed while Desktop is closed.' }
Refresh-Usage

$script:DesktopActive = $null
$script:RefreshCount = 0
$script:ServerStops = 0
$PetPollMs = 80
$trayIcon = [PSCustomObject]@{ Visible = $true }
$controlWindow = $window
$petTimer = [PSCustomObject]@{ Interval = [TimeSpan]::Zero }
$usageTimer = [PSCustomObject]@{ Running = $false }
$usageTimer | Add-Member ScriptMethod Start { $this.Running = $true }
$usageTimer | Add-Member ScriptMethod Stop { $this.Running = $false }
function Refresh-Usage { $script:RefreshCount++ }
function Stop-UsageAppServer { $script:ServerStops++ }
Sync-DesktopPresence -DesktopRunning $false
if ($trayIcon.Visible -or $usageTimer.Running -or $script:RefreshCount -ne 0 -or $petTimer.Interval.TotalSeconds -ne 2) { throw 'Idle listener must not show tray or poll usage.' }
Sync-DesktopPresence -DesktopRunning $true
Sync-DesktopPresence -DesktopRunning $true
if (-not $trayIcon.Visible -or -not $usageTimer.Running -or $script:RefreshCount -ne 1) { throw 'Opening Desktop should activate and refresh once.' }
Sync-DesktopPresence -DesktopRunning $false
if ($trayIcon.Visible -or $usageTimer.Running -or $script:ServerStops -ne 2) { throw 'Closing Desktop must hide the tray and stop the private server.' }
Sync-DesktopPresence -DesktopRunning $true
if ($script:RefreshCount -ne 2) { throw 'Reopening Desktop should resume automatically.' }
'DesktopPresence tests OK'
