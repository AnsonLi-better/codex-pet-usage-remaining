param(
  [ValidateSet("Start", "Stop", "Status", "SelfTest", "InstallTask", "UninstallTask", "Run", "FindPet")]
  [string]$Command = "Start",
  [int]$UsagePollSeconds = 60,
  [int]$PetPollMs = 80,
  [int]$HoverPaddingPx = 24,
  [string]$CodexHome = "$env:USERPROFILE\.codex",
  [ValidateSet("zh", "en")]
  [string]$Language = "zh",
  [string]$LanguageHotkey = "Ctrl+Alt+Shift+L"
)

$ErrorActionPreference = "Stop"
$UsagePollSeconds = [Math]::Max(60, $UsagePollSeconds)
$PetPollMs = [Math]::Max(50, $PetPollMs)
$HoverPaddingPx = [Math]::Max(0, [Math]::Min(200, $HoverPaddingPx))
$AppName = "CodexPetUsageOverlay"
$AppDir = Join-Path $env:LOCALAPPDATA $AppName
$PidPath = Join-Path $AppDir "overlay.pid"
$LogPath = Join-Path $AppDir "overlay.log"
$HoverShowSeconds = 10
$DisplayName = "Codex Usage Remaining"
$TaskName = $DisplayName
$LegacyTaskName = "Codex Pet Usage Overlay"
$script:CodexStateCachePath = $null
$script:CodexStateCacheWriteTime = [datetime]::MinValue
$script:CodexStateCacheValue = $null
$script:TrackedPetHwnd = [IntPtr]::Zero
$script:Language = "zh"
$script:LanguageWasSet = $PSBoundParameters.ContainsKey("Language")
$script:HotkeyVk = [uint32]0
$script:HotkeyMods = [uint32]0

function U {
  param([string]$Text)
  return [regex]::Replace($Text, "\\u([0-9a-fA-F]{4})", {
    param($Match)
    return [string][char]([Convert]::ToInt32($Match.Groups[1].Value, 16))
  })
}

function Ensure-AppDir {
  New-Item -ItemType Directory -Force -Path $AppDir | Out-Null
}

function Write-AppLog {
  param([string]$Message)
  try {
    Ensure-AppDir
    $line = "{0:s} {1}" -f (Get-Date), $Message
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
  } catch {
  }
}

function Rotate-AppLog {
  try {
    Ensure-AppDir
    if (-not (Test-Path -LiteralPath $LogPath)) { return }
    if ((Get-Item -LiteralPath $LogPath).Length -lt 524288) { return }
    $oldLogPath = "$LogPath.old"
    if (Test-Path -LiteralPath $oldLogPath) { Remove-Item -LiteralPath $oldLogPath -Force }
    Move-Item -LiteralPath $LogPath -Destination $oldLogPath -Force
  } catch {
  }
}

function Get-OverlayProcessFromPid {
  param([int]$ProcessId)
  if ($ProcessId -le 0) { return $null }
  try {
    $process = Get-CimInstance Win32_Process -Filter "ProcessId=$ProcessId"
    if ($null -eq $process) { return $null }
    $scriptPath = [System.IO.Path]::GetFullPath($PSCommandPath)
    $commandLine = [string]$process.CommandLine
    if (
      $commandLine.IndexOf($scriptPath, [StringComparison]::OrdinalIgnoreCase) -ge 0 -and
      $commandLine.IndexOf("-File", [StringComparison]::OrdinalIgnoreCase) -ge 0 -and
      $commandLine.IndexOf("-Command Run", [StringComparison]::OrdinalIgnoreCase) -ge 0
    ) {
      return $process
    }
  } catch {
  }
  return $null
}

function Get-AllOverlayProcesses {
  try {
    $scriptPath = [System.IO.Path]::GetFullPath($PSCommandPath)
    return @(Get-CimInstance Win32_Process | Where-Object {
      $commandLine = [string]$_.CommandLine
      $commandLine.IndexOf($scriptPath, [StringComparison]::OrdinalIgnoreCase) -ge 0 -and
      $commandLine.IndexOf("-File", [StringComparison]::OrdinalIgnoreCase) -ge 0 -and
      $commandLine.IndexOf("-Command Run", [StringComparison]::OrdinalIgnoreCase) -ge 0
    })
  } catch {
    return @()
  }
}

function Get-RunningOverlayProcess {
  if (-not (Test-Path -LiteralPath $PidPath)) {
    return @(Get-AllOverlayProcesses | Select-Object -First 1)[0]
  }
  try {
    $pidText = (Get-Content -LiteralPath $PidPath -Raw).Trim()
    if ([string]::IsNullOrWhiteSpace($pidText)) { return $null }
    $process = Get-OverlayProcessFromPid -ProcessId ([int]$pidText)
    if ($null -ne $process) { return $process }
  } catch {
  }
  return @(Get-AllOverlayProcesses | Select-Object -First 1)[0]
}

function Get-StartupPowerShellPath {
  return Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
}

function Get-AutostartShortcutPath {
  $startupDir = [Environment]::GetFolderPath([Environment+SpecialFolder]::Startup)
  return Join-Path $startupDir "$DisplayName.lnk"
}

function Test-AutostartEnabled {
  $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
  $legacyTask = Get-ScheduledTask -TaskName $LegacyTaskName -ErrorAction SilentlyContinue
  return ($null -ne $task -or $null -ne $legacyTask -or (Test-Path -LiteralPath (Get-AutostartShortcutPath)))
}

function Install-AutostartShortcut {
  $shortcutPath = Get-AutostartShortcutPath
  $shell = New-Object -ComObject WScript.Shell
  $shortcut = $shell.CreateShortcut($shortcutPath)
  $shortcut.TargetPath = Get-StartupPowerShellPath
  $shortcut.Arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -Command Start' -f ([System.IO.Path]::GetFullPath($PSCommandPath))
  $shortcut.WorkingDirectory = Split-Path -Parent ([System.IO.Path]::GetFullPath($PSCommandPath))
  $shortcut.WindowStyle = 7
  $shortcut.Description = "Start $DisplayName"
  $shortcut.Save()
  Write-Output ("Installed Startup-folder shortcut: {0}" -f $shortcutPath)
}

function Install-TaskScheduler {
  if ($null -ne (Get-ScheduledTask -TaskName $LegacyTaskName -ErrorAction SilentlyContinue)) {
    Unregister-ScheduledTask -TaskName $LegacyTaskName -Confirm:$false -ErrorAction SilentlyContinue
  }
  $legacyShortcut = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::Startup)) "Codex Pet Usage Overlay.lnk"
  if (Test-Path -LiteralPath $legacyShortcut) { Remove-Item -LiteralPath $legacyShortcut -Force -ErrorAction SilentlyContinue }
  $scriptPath = [System.IO.Path]::GetFullPath($PSCommandPath)
  $scriptDir = Split-Path -Parent $scriptPath
  $powerShellPath = Get-StartupPowerShellPath
  $taskAction = New-ScheduledTaskAction -Execute $powerShellPath -Argument ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -Command Start' -f $scriptPath)
  $taskTrigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
  $taskPrincipal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
  $taskSettings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
  try {
    Register-ScheduledTask -TaskName $TaskName -Action $taskAction -Trigger $taskTrigger -Principal $taskPrincipal -Settings $taskSettings -Force -ErrorAction Stop | Out-Null
  } catch {
    Write-Warning ("Task Scheduler was unavailable; using the Startup folder instead: {0}" -f $_.Exception.Message)
    Install-AutostartShortcut
    return
  }
  Write-Output ("Installed Task Scheduler task: {0}" -f $TaskName)
  Write-Output "The task starts the overlay when you sign in; it will follow the Codex pet when Codex is opened."
}

function Uninstall-TaskScheduler {
  $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
  if ($null -ne $task) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop
    Write-Output ("Removed Task Scheduler task: {0}" -f $TaskName)
  }
  $shortcutPath = Get-AutostartShortcutPath
  if (Test-Path -LiteralPath $shortcutPath) {
    Remove-Item -LiteralPath $shortcutPath -Force
    Write-Output ("Removed Startup-folder shortcut: {0}" -f $shortcutPath)
  }
  if ($null -ne (Get-ScheduledTask -TaskName $LegacyTaskName -ErrorAction SilentlyContinue)) {
    Unregister-ScheduledTask -TaskName $LegacyTaskName -Confirm:$false -ErrorAction SilentlyContinue
  }
  $legacyShortcut = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::Startup)) "Codex Pet Usage Overlay.lnk"
  if (Test-Path -LiteralPath $legacyShortcut) { Remove-Item -LiteralPath $legacyShortcut -Force -ErrorAction SilentlyContinue }
}

function Start-Overlay {
  Ensure-AppDir
  $running = Get-RunningOverlayProcess
  if ($null -ne $running) {
    Write-Output ("Already running. PID: {0}" -f $running.ProcessId)
    return
  }

  $scriptPath = [System.IO.Path]::GetFullPath($PSCommandPath)
  $scriptDir = Split-Path -Parent $scriptPath
  $quotedScript = '"' + ($scriptPath -replace '"', '\"') + '"'
  $quotedCodexHome = '"' + ([System.IO.Path]::GetFullPath($CodexHome) -replace '"', '\"') + '"'
  $langArg = if ($script:LanguageWasSet) { " -Language $Language" } else { "" }
  $args = "-NoProfile -ExecutionPolicy Bypass -File $quotedScript -Command Run -UsagePollSeconds $UsagePollSeconds -PetPollMs $PetPollMs -HoverPaddingPx $HoverPaddingPx$langArg -LanguageHotkey `"$LanguageHotkey`" -CodexHome $quotedCodexHome"
  $process = Start-Process -FilePath (Get-StartupPowerShellPath) -ArgumentList ("-STA " + $args) -WorkingDirectory $scriptDir -WindowStyle Hidden -PassThru
  Set-Content -LiteralPath $PidPath -Value $process.Id -Encoding ASCII
  Write-Output ("Started Codex pet usage overlay. PID: {0}" -f $process.Id)
}

function Stop-Overlay {
  $running = @(Get-AllOverlayProcesses)
  if ($running.Count -eq 0) {
    if (Test-Path -LiteralPath $PidPath) { Remove-Item -LiteralPath $PidPath -Force }
    Write-Output "Codex pet usage overlay is not running."
    return
  }
  foreach ($process in $running) {
    Stop-Process -Id ([int]$process.ProcessId) -Force
    Write-Output ("Stopped Codex pet usage overlay. PID: {0}" -f $process.ProcessId)
  }
  if (Test-Path -LiteralPath $PidPath) { Remove-Item -LiteralPath $PidPath -Force }
}

function Read-CodexState {
  $statePath = Join-Path $CodexHome ".codex-global-state.json"
  if (-not (Test-Path -LiteralPath $statePath)) { return $null }
  try {
    $writeTime = (Get-Item -LiteralPath $statePath).LastWriteTimeUtc
    if (
      $script:CodexStateCachePath -eq $statePath -and
      $script:CodexStateCacheWriteTime -eq $writeTime -and
      $null -ne $script:CodexStateCacheValue
    ) {
      return $script:CodexStateCacheValue
    }
    $state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $script:CodexStateCachePath = $statePath
    $script:CodexStateCacheWriteTime = $writeTime
    $script:CodexStateCacheValue = $state
    return $state
  } catch {
    Write-AppLog "State read failed: $($_.Exception.Message)"
    return $null
  }
}

function Get-PetRect {
  $state = Read-CodexState
  if ($null -eq $state) { return $null }
  $open = $state.'electron-avatar-overlay-open'
  $bounds = $state.'electron-avatar-overlay-bounds'
  if (-not $open -or $null -eq $bounds) { return $null }
  $mascot = if ($bounds.mascot) {
    $bounds.mascot
  } else {
    # Newer Codex builds persist only the overall avatar overlay origin.
    [PSCustomObject]@{ left = 0; top = 0; width = 118; height = 118 }
  }
  return [PSCustomObject]@{
    Left = [double]$bounds.x + [double]$mascot.left
    Top = [double]$bounds.y + [double]$mascot.top
    Width = [double]$mascot.width
    Height = [double]$mascot.height
    DisplayLeft = if ($bounds.displayBounds) { [double]$bounds.displayBounds.x } else { 0.0 }
    DisplayTop = if ($bounds.displayBounds) { [double]$bounds.displayBounds.y } else { 0.0 }
    DisplayWidth = if ($bounds.displayBounds) { [double]$bounds.displayBounds.width } else { 1920.0 }
    DisplayHeight = if ($bounds.displayBounds) { [double]$bounds.displayBounds.height } else { 1080.0 }
  }
}

function Get-NativeWindowList {
  param([int[]]$ProcessIds)
  $found = New-Object System.Collections.ArrayList
  $cb = [CodexPetUsageOverlayNative+EnumWindowsProc]{
    param($hwnd, $lparam)
    if ([CodexPetUsageOverlayNative]::IsWindowVisible($hwnd)) {
      $procId = 0
      [void][CodexPetUsageOverlayNative]::GetWindowThreadProcessId($hwnd, [ref]$procId)
      if ($ProcessIds -contains [int]$procId) {
        $rect = [CodexPetUsageOverlayNative+RECT]::new()
        [void][CodexPetUsageOverlayNative]::GetWindowRect($hwnd, [ref]$rect)
        $title = New-Object System.Text.StringBuilder 256
        [void][CodexPetUsageOverlayNative]::GetWindowText($hwnd, $title, 256)
        $class = New-Object System.Text.StringBuilder 256
        [void][CodexPetUsageOverlayNative]::GetClassName($hwnd, $class, 256)
        [void]$found.Add([PSCustomObject]@{
          HWND = $hwnd
          X = [double]$rect.Left
          Y = [double]$rect.Top
          Width = [double]($rect.Right - $rect.Left)
          Height = [double]($rect.Bottom - $rect.Top)
          Title = $title.ToString()
          Class = $class.ToString()
          Pid = [int]$procId
        })
      }
    }
    return $true
  }
  [void][CodexPetUsageOverlayNative]::EnumWindows($cb, [IntPtr]::Zero)
  foreach ($top in @($found)) {
    [void][CodexPetUsageOverlayNative]::EnumChildWindows($top.HWND, $cb, [IntPtr]::Zero)
  }
  return @($found)
}

function Get-CodexProcessIds {
  $result = New-Object 'System.Collections.Generic.HashSet[int]'
  foreach ($process in (Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match 'codex' })) {
    [void]$result.Add([int]$process.Id)
  }
  $cb = [CodexPetUsageOverlayNative+EnumWindowsProc]{
    param($hwnd, $lparam)
    if ([CodexPetUsageOverlayNative]::IsWindowVisible($hwnd)) {
      $title = New-Object System.Text.StringBuilder 256
      [void][CodexPetUsageOverlayNative]::GetWindowText($hwnd, $title, 256)
      if ($title.ToString() -match '^codex($|\s)') {
        $procId = 0
        [void][CodexPetUsageOverlayNative]::GetWindowThreadProcessId($hwnd, [ref]$procId)
        [void]$result.Add([int]$procId)
      }
    }
    return $true
  }
  [void][CodexPetUsageOverlayNative]::EnumWindows($cb, [IntPtr]::Zero)
  return @($result)
}

function Find-PetWindow {
  $pids = Get-CodexProcessIds
  if ($pids.Count -eq 0) { return $null }
  $anchor = Get-PetRect
  $anchorCx = $null
  $anchorCy = $null
  if ($null -ne $anchor) {
    $anchorCx = $anchor.Left + $anchor.Width / 2.0
    $anchorCy = $anchor.Top + $anchor.Height / 2.0
  }
  $best = $null
  $bestScore = [double]::MaxValue
  foreach ($window in (Get-NativeWindowList -ProcessIds $pids)) {
    if ($window.Width -lt 40 -or $window.Width -gt 220 -or $window.Height -lt 40 -or $window.Height -gt 220) { continue }
    if ($window.X -lt -1000 -or $window.Y -lt -1000) { continue }
    $score = [Math]::Abs($window.Width - 118.0) + [Math]::Abs($window.Height - 118.0)
    if ($null -ne $anchorCx) {
      $score += [Math]::Abs(($window.X + $window.Width / 2.0) - $anchorCx) + [Math]::Abs(($window.Y + $window.Height / 2.0) - $anchorCy)
    }
    if ($score -lt $bestScore) {
      $bestScore = $score
      $best = $window
    }
  }
  return $best
}

function Get-WindowMonitorRect {
  param($Hwnd)
  try {
    $monitor = [CodexPetUsageOverlayNative]::MonitorFromWindow([IntPtr]$Hwnd, 2)
    if ($monitor -eq [IntPtr]::Zero) { return $null }
    $info = [CodexPetUsageOverlayNative+MONITORINFO]::new()
    $info.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf([CodexPetUsageOverlayNative+MONITORINFO])
    if ([CodexPetUsageOverlayNative]::GetMonitorInfo($monitor, [ref]$info)) {
      return [PSCustomObject]@{
        x = [double]$info.rcMonitor.Left
        y = [double]$info.rcMonitor.Top
        width = [double]($info.rcMonitor.Right - $info.rcMonitor.Left)
        height = [double]($info.rcMonitor.Bottom - $info.rcMonitor.Top)
      }
    }
  } catch {
  }
  return $null
}

function Build-PetRectFromHwnd {
  param($Hwnd)
  if ($null -eq $Hwnd -or [IntPtr]$Hwnd -eq [IntPtr]::Zero) { return $null }
  $rect = [CodexPetUsageOverlayNative+RECT]::new()
  if (-not [CodexPetUsageOverlayNative]::GetWindowRect([IntPtr]$Hwnd, [ref]$rect)) { return $null }
  $width = [double]($rect.Right - $rect.Left)
  $height = [double]($rect.Bottom - $rect.Top)
  if ($width -lt 20 -or $height -lt 20) { return $null }
  $display = Get-WindowMonitorRect -Hwnd ([IntPtr]$Hwnd)
  if ($null -eq $display) {
    $state = Read-CodexState
    if ($null -ne $state -and $null -ne $state.'electron-avatar-overlay-bounds' -and $null -ne $state.'electron-avatar-overlay-bounds'.displayBounds) {
      $display = $state.'electron-avatar-overlay-bounds'.displayBounds
    } else {
      $display = [PSCustomObject]@{ x = 0.0; y = 0.0; width = 1920.0; height = 1080.0 }
    }
  }
  return [PSCustomObject]@{
    Left = [double]$rect.Left
    Top = [double]$rect.Top
    Width = $width
    Height = $height
    DisplayLeft = [double]$display.x
    DisplayTop = [double]$display.y
    DisplayWidth = [double]$display.width
    DisplayHeight = [double]$display.height
  }
}

function Get-LivePetRect {
  $codexPids = @(Get-CodexProcessIds)
  if ($codexPids.Count -eq 0) {
    $script:TrackedPetHwnd = [IntPtr]::Zero
    return $null
  }
  if ($script:TrackedPetHwnd -ne [IntPtr]::Zero) {
    $trackedPid = 0
    [void][CodexPetUsageOverlayNative]::GetWindowThreadProcessId($script:TrackedPetHwnd, [ref]$trackedPid)
    if ($codexPids -contains [int]$trackedPid) {
      $rect = Build-PetRectFromHwnd -Hwnd $script:TrackedPetHwnd
      if ($null -ne $rect) { return $rect }
    }
    $script:TrackedPetHwnd = [IntPtr]::Zero
  }
  $window = Find-PetWindow
  if ($null -eq $window) { return $null }
  $script:TrackedPetHwnd = $window.HWND
  return Build-PetRectFromHwnd -Hwnd $window.HWND
}

function Test-CanUsePersistedPetRect {
  param([bool]$CodexRunning, $PersistedPetRect)
  return ($CodexRunning -and $null -ne $PersistedPetRect)
}

function Invoke-FindPetDiagnostic {
  $pids = Get-CodexProcessIds
  Write-Output ("Codex PIDs: {0}" -f (($pids | ForEach-Object { [int]$_ }) -join ", "))
  if ($pids.Count -eq 0) {
    Write-Output "No Codex process found. Is Codex Desktop running with the pet open?"
    return
  }
  $anchor = Get-PetRect
  if ($null -ne $anchor) {
    Write-Output ("JSON anchor: pos=({0},{1}) size={2}x{3}" -f [int]$anchor.Left, [int]$anchor.Top, [int]$anchor.Width, [int]$anchor.Height)
  } else {
    Write-Output "JSON anchor: none (pet not marked open in .codex-global-state.json)"
  }
  Write-Output "Candidate pet-like windows (Codex pid, visible, 40-220px):"
  $candidates = @(Get-NativeWindowList -ProcessIds $pids | Where-Object { $_.Width -ge 40 -and $_.Width -le 220 -and $_.Height -ge 40 -and $_.Height -le 220 -and $_.X -gt -1000 })
  if ($candidates.Count -eq 0) { Write-Output "  (none found)" }
  foreach ($w in $candidates) {
    Write-Output ("  HWND={0} pos=({1},{2}) size={3}x{4} class={5} title='{6}'" -f $w.HWND, [int]$w.X, [int]$w.Y, [int]$w.Width, [int]$w.Height, $w.Class, $w.Title)
  }
  $picked = Find-PetWindow
  if ($null -ne $picked) {
    Write-Output ("Picked: HWND={0} pos=({1},{2}) size={3}x{4}" -f $picked.HWND, [int]$picked.X, [int]$picked.Y, [int]$picked.Width, [int]$picked.Height)
  } else {
    Write-Output "Picked: none"
  }
}

function Test-PointInRect {
  param($Point, $Rect, [int]$Padding = 0)
  if ($null -eq $Point -or $null -eq $Rect) { return $false }
  return (
    [double]$Point.X -ge ([double]$Rect.Left - $Padding) -and
    [double]$Point.X -le ([double]$Rect.Left + [double]$Rect.Width + $Padding) -and
    [double]$Point.Y -ge ([double]$Rect.Top - $Padding) -and
    [double]$Point.Y -le ([double]$Rect.Top + [double]$Rect.Height + $Padding)
  )
}

function Get-OverlayShowUntil {
  param([bool]$CursorInPet, [bool]$CursorWasInPet, [datetime]$CurrentShowUntil, [datetime]$Now, [int]$Seconds)
  if ($CursorInPet -and -not $CursorWasInPet -and $Now -gt $CurrentShowUntil) { return $Now.AddSeconds($Seconds) }
  return $CurrentShowUntil
}

function Test-ShouldShowOverlay {
  param([datetime]$ShowUntilAt, [datetime]$Now)
  return ($ShowUntilAt -ne [datetime]::MinValue -and $Now -le $ShowUntilAt)
}

function Convert-DevicePointToDip {
  param($Window, $Point)
  if ($null -eq $Point) { return $null }
  try {
    $devicePoint = New-Object System.Windows.Point -ArgumentList ([double]$Point.X), ([double]$Point.Y)
    $source = [System.Windows.PresentationSource]::FromVisual($Window)
    if ($source -and $source.CompositionTarget) {
      $dipPoint = $source.CompositionTarget.TransformFromDevice.Transform($devicePoint)
      return [PSCustomObject]@{ X = [double]$dipPoint.X; Y = [double]$dipPoint.Y; DeviceX = [double]$Point.X; DeviceY = [double]$Point.Y }
    }
    $dpi = [System.Windows.Media.VisualTreeHelper]::GetDpi($Window)
    if ($dpi.DpiScaleX -gt 0 -and $dpi.DpiScaleY -gt 0) {
      return [PSCustomObject]@{ X = [double]$Point.X / [double]$dpi.DpiScaleX; Y = [double]$Point.Y / [double]$dpi.DpiScaleY; DeviceX = [double]$Point.X; DeviceY = [double]$Point.Y }
    }
  } catch {
  }
  return [PSCustomObject]@{ X = [double]$Point.X; Y = [double]$Point.Y; DeviceX = [double]$Point.X; DeviceY = [double]$Point.Y }
}

function Clamp-Percent {
  param($Value)
  if ($null -eq $Value) { return $null }
  return [Math]::Max(0.0, [Math]::Min(100.0, [double]$Value))
}

function Get-BucketRemaining {
  param($Bucket)
  if ($null -eq $Bucket) { return $null }
  if ($null -ne $Bucket.remaining_percent) { return Clamp-Percent $Bucket.remaining_percent }
  if ($null -ne $Bucket.used_percent) { return Clamp-Percent (100.0 - [double]$Bucket.used_percent) }
  return $null
}

function Get-BucketWindowSeconds {
  param($Bucket)
  if ($null -eq $Bucket) { return $null }
  if ($null -ne $Bucket.limit_window_seconds) { return [double]$Bucket.limit_window_seconds }
  if ($null -ne $Bucket.window_seconds) { return [double]$Bucket.window_seconds }
  return $null
}

function Convert-ResetAt {
  param($Bucket)
  if ($null -eq $Bucket) { return $null }
  if ($null -ne $Bucket.reset_after_seconds) {
    return (Get-Date).AddSeconds([double]$Bucket.reset_after_seconds)
  }
  if ($null -ne $Bucket.seconds_until_reset) {
    return (Get-Date).AddSeconds([double]$Bucket.seconds_until_reset)
  }
  foreach ($name in @("reset_at", "resets_at", "reset_time", "expires_at", "window_reset_at")) {
    $value = $Bucket.$name
    if ($null -eq $value) { continue }
    try {
      if ($value -is [int] -or $value -is [long] -or $value -is [double] -or "$value" -match "^\d+(\.\d+)?$") {
        return [DateTimeOffset]::FromUnixTimeSeconds([int64][double]$value).LocalDateTime
      }
      return ([datetime]::Parse([string]$value)).ToLocalTime()
    } catch {
    }
  }
  return $null
}

function Convert-UsagePayload {
  param($Payload, [string]$Source)
  if ($null -eq $Payload) { return $null }
  $rate = if ($Payload.rate_limit) { $Payload.rate_limit } elseif ($Payload.rate_limits) { $Payload.rate_limits } else { $null }
  if ($null -eq $rate) { return $null }
  $primary = if ($rate.primary_window) { $rate.primary_window } elseif ($rate.primary) { $rate.primary } else { $null }
  $secondary = if ($rate.secondary_window) { $rate.secondary_window } elseif ($rate.secondary) { $rate.secondary } else { $null }
  $primaryRemaining = Get-BucketRemaining $primary
  $secondaryRemaining = Get-BucketRemaining $secondary
  if ($null -eq $primaryRemaining -and $null -eq $secondaryRemaining) { return $null }
  return [PSCustomObject]@{
    Available = $true
    Source = $Source
    PrimaryRemaining = $primaryRemaining
    SecondaryRemaining = $secondaryRemaining
    PrimaryResetAt = Convert-ResetAt $primary
    SecondaryResetAt = Convert-ResetAt $secondary
    PrimaryWindowSeconds = Get-BucketWindowSeconds $primary
    SecondaryWindowSeconds = Get-BucketWindowSeconds $secondary
    ObservedAt = Get-Date
  }
}

function Get-LiveUsage {
  $authPath = Join-Path $CodexHome "auth.json"
  if (-not (Test-Path -LiteralPath $authPath)) { return $null }
  $auth = Get-Content -LiteralPath $authPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $token = $auth.tokens.access_token
  if ([string]::IsNullOrWhiteSpace($token)) { return $null }
  $payload = Invoke-RestMethod -Uri "https://chatgpt.com/backend-api/wham/usage" -Headers @{
    Authorization = "Bearer $token"
    Accept = "application/json"
  } -TimeoutSec 20
  return Convert-UsagePayload -Payload $payload -Source "live"
}

function Get-BalancedJsonObject {
  param([string]$Text, [int]$Start)
  $depth = 0
  $inString = $false
  $escaping = $false
  for ($i = $Start; $i -lt $Text.Length; $i++) {
    $ch = $Text[$i]
    if ($inString) {
      if ($escaping) {
        $escaping = $false
      } elseif ($ch -eq "\") {
        $escaping = $true
      } elseif ($ch -eq '"') {
        $inString = $false
      }
      continue
    }
    if ($ch -eq '"') {
      $inString = $true
    } elseif ($ch -eq "{") {
      $depth++
    } elseif ($ch -eq "}") {
      $depth--
      if ($depth -eq 0) { return $Text.Substring($Start, $i - $Start + 1) }
    }
  }
  return $null
}

function Convert-LogBodyToUsage {
  param([string]$Body)
  if ([string]::IsNullOrWhiteSpace($Body)) { return $null }
  $marker = "codex.rate_limits"
  $markerIndex = $Body.IndexOf($marker, [StringComparison]::OrdinalIgnoreCase)
  while ($markerIndex -ge 0) {
    $start = $Body.LastIndexOf("{", $markerIndex)
    while ($start -ge 0) {
      $json = Get-BalancedJsonObject -Text $Body -Start $start
      if ($json -and $json.IndexOf($marker, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
        try {
          $payload = $json | ConvertFrom-Json
          if ($payload.type -eq $marker -or $payload.rate_limit -or $payload.rate_limits) {
            $usage = Convert-UsagePayload -Payload $payload -Source "log"
            if ($null -ne $usage) { return $usage }
          }
        } catch {
        }
      }
      if ($start -eq 0) { break }
      $start = $Body.LastIndexOf("{", $start - 1)
    }
    $nextFrom = $markerIndex + $marker.Length
    if ($nextFrom -ge $Body.Length) { break }
    $markerIndex = $Body.IndexOf($marker, $nextFrom, [StringComparison]::OrdinalIgnoreCase)
  }
  return $null
}

function Get-LogUsage {
  param([string[]]$LogPaths)
  if ($null -eq $LogPaths -or $LogPaths.Count -eq 0) {
    $LogPaths = @(
      (Join-Path $CodexHome "logs_2.sqlite"),
      (Join-Path $CodexHome "logs_1.sqlite")
    )
  }
  $existing = @($LogPaths | Where-Object { Test-Path -LiteralPath $_ })
  if ($existing.Count -eq 0) { return $null }
  $python = Get-Command python -ErrorAction SilentlyContinue
  if ($null -eq $python) { return $null }

  $code = @'
import base64
import sqlite3
import sys

for path in sys.argv[1:]:
    try:
        con = sqlite3.connect("file:" + path + "?mode=ro", uri=True)
        try:
            row = con.execute(
                """
                SELECT feedback_log_body
                FROM logs
                WHERE feedback_log_body LIKE '%codex.rate_limits%'
                ORDER BY ts DESC, ts_nanos DESC, id DESC
                LIMIT 1
                """
            ).fetchone()
        finally:
            con.close()
        if row and row[0]:
            print(base64.b64encode(row[0].encode("utf-8")).decode("ascii"))
            raise SystemExit(0)
    except Exception:
        pass
print("")
'@
  try {
    $encoded = $code | & $python.Source - @existing 2>$null
    $encoded = ([string]$encoded).Trim()
    if ([string]::IsNullOrWhiteSpace($encoded)) { return $null }
    $body = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded))
    return Convert-LogBodyToUsage -Body $body
  } catch {
    Write-AppLog "Log usage lookup failed: $($_.Exception.Message)"
    return $null
  }
}

function Get-Usage {
  try {
    $usage = Get-LiveUsage
    if ($null -ne $usage) { return $usage }
  } catch {
    Write-AppLog "Live usage lookup failed: $($_.Exception.Message)"
  }
  $logUsage = Get-LogUsage
  if ($null -ne $logUsage) { return $logUsage }
  return [PSCustomObject]@{
    Available = $false
    Source = "none"
    ObservedAt = Get-Date
  }
}

function Format-Duration {
  param($ResetAt, [string]$Language = "zh")
  if ($null -eq $ResetAt) { return "--" }
  $seconds = [int][Math]::Max(0, [Math]::Ceiling((([datetime]$ResetAt) - (Get-Date)).TotalSeconds))
  $isEn = ($Language -eq "en")
  if ($seconds -ge 86400) {
    $days = [int][Math]::Floor($seconds / 86400)
    $hours = [int][Math]::Floor(($seconds % 86400) / 3600)
    if ($isEn) { return ("{0}d {1}h" -f $days, $hours) }
    return ("{0}" -f $days) + (U "\u5929 ") + ("{0}" -f $hours) + (U "\u5c0f\u65f6")
  }
  if ($seconds -ge 3600) {
    $hours = [int][Math]::Floor($seconds / 3600)
    $minutes = [int][Math]::Floor(($seconds % 3600) / 60)
    if ($isEn) { return ("{0}h {1}m" -f $hours, $minutes) }
    return ("{0}" -f $hours) + (U "\u5c0f\u65f6 ") + ("{0}" -f $minutes) + (U "\u5206\u949f")
  }
  if ($seconds -ge 60) {
    $minutes = [int][Math]::Floor($seconds / 60)
    $secs = $seconds % 60
    if ($isEn) { return ("{0}m {1}s" -f $minutes, $secs) }
    return ("{0}" -f $minutes) + (U "\u5206\u949f ") + ("{0}" -f $secs) + (U "\u79d2")
  }
  if ($isEn) { return ("{0}s" -f $seconds) }
  return ("{0}" -f $seconds) + (U "\u79d2")
}

function Get-SavedLanguage {
  $langPath = Join-Path $AppDir "lang.txt"
  if (Test-Path -LiteralPath $langPath) {
    $text = (Get-Content -LiteralPath $langPath -Raw -Encoding ASCII).Trim()
    if ($text -eq "zh" -or $text -eq "en") { return $text }
  }
  return "zh"
}

function Set-SavedLanguage {
  param([string]$Language)
  try {
    Ensure-AppDir
    Set-Content -LiteralPath (Join-Path $AppDir "lang.txt") -Value $Language -Encoding ASCII
  } catch {
  }
}

function Convert-HotkeyToVk {
  param([string]$Hotkey)
  $mods = 0
  $vk = 0
  foreach ($part in @($Hotkey -split "\+")) {
    $trimmed = $part.Trim()
    if ($trimmed -match "^(?i)(ctrl|control)$") { $mods = $mods -bor 0x2 }
    elseif ($trimmed -match "^(?i)alt$") { $mods = $mods -bor 0x1 }
    elseif ($trimmed -match "^(?i)shift$") { $mods = $mods -bor 0x4 }
    elseif ($trimmed -match "^(?i)win$") { $mods = $mods -bor 0x8 }
    elseif ($trimmed -match "^(?i)f([1-9][0-9]?)$") {
      $n = [int]$Matches[1]
      if ($n -ge 1 -and $n -le 24) { $vk = 0x6F + $n }
    }
    elseif ($trimmed.Length -eq 1 -and $trimmed -match "^[0-9a-zA-Z]$") {
      if ($trimmed -match "^[0-9]$") {
        $vk = 0x30 + [int]$trimmed
      } else {
        $vk = [int][char]$trimmed.ToUpper()
      }
    }
  }
  return [PSCustomObject]@{ Vk = [uint32]$vk; Mods = [uint32]$mods }
}

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw "SelfTest failed: $Message" }
}

function Invoke-SelfTest {
  $payload = [PSCustomObject]@{
    rate_limit = [PSCustomObject]@{
      primary_window = [PSCustomObject]@{ used_percent = 37; limit_window_seconds = 18000; reset_after_seconds = 90 }
      secondary_window = [PSCustomObject]@{ used_percent = 52; limit_window_seconds = 604800; reset_after_seconds = 120 }
    }
  }
  $usage = Convert-UsagePayload -Payload $payload -Source "test"
  Assert-True ([Math]::Abs($usage.PrimaryRemaining - 63.0) -lt 0.01) "used_percent should become remaining percent"
  Assert-True ([Math]::Abs($usage.SecondaryRemaining - 48.0) -lt 0.01) "secondary used_percent should become remaining percent"

  $payload2 = [PSCustomObject]@{
    rate_limits = [PSCustomObject]@{
      primary = [PSCustomObject]@{ remaining_percent = 12; reset_at = [DateTimeOffset]::Now.AddMinutes(10).ToUnixTimeSeconds() }
    }
  }
  $usage2 = Convert-UsagePayload -Payload $payload2 -Source "test"
  Assert-True ([Math]::Abs($usage2.PrimaryRemaining - 12.0) -lt 0.01) "remaining_percent should be used directly"
  Assert-True ((Format-Duration $usage2.PrimaryResetAt) -ne "--") "reset_at should format"
  Assert-True ($null -eq (Convert-UsagePayload -Payload ([PSCustomObject]@{}) -Source "test")) "missing payload should return null"

  $body = 'prefix {"type":"codex.rate_limits","rate_limits":{"primary_window":{"used_percent":25,"limit_window_seconds":18000,"reset_after_seconds":60},"secondary_window":{"remaining_percent":88,"limit_window_seconds":604800,"reset_after_seconds":120}}} suffix'
  $logParsed = Convert-LogBodyToUsage -Body $body
  Assert-True ([Math]::Abs($logParsed.PrimaryRemaining - 75.0) -lt 0.01) "log body primary parse"
  Assert-True ([Math]::Abs($logParsed.SecondaryRemaining - 88.0) -lt 0.01) "log body secondary parse"

  $tempDb = Join-Path ([System.IO.Path]::GetTempPath()) ("codex_pet_usage_overlay_test_{0}.sqlite" -f ([guid]::NewGuid().ToString("N")))
  $py = @'
import sqlite3
import sys
import base64
path = sys.argv[1]
body = base64.b64decode(sys.argv[2]).decode("utf-8")
con = sqlite3.connect(path)
con.execute("create table logs (id integer primary key, ts integer, ts_nanos integer, feedback_log_body text)")
con.execute("insert into logs (ts, ts_nanos, feedback_log_body) values (1, 1, ?)", (body,))
con.commit()
con.close()
'@
  try {
    $python = Get-Command python -ErrorAction Stop
    $body64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($body))
    $py | & $python.Source - $tempDb $body64 | Out-Null
  $sqliteParsed = Get-LogUsage -LogPaths @($tempDb)
    Assert-True ([Math]::Abs($sqliteParsed.PrimaryRemaining - 75.0) -lt 0.01) "sqlite fallback parse"
  } finally {
    if (Test-Path -LiteralPath $tempDb) { Remove-Item -LiteralPath $tempDb -Force }
  }

  $rect = [PSCustomObject]@{ Left = 10; Top = 20; Width = 30; Height = 40 }
  Assert-True (Test-PointInRect -Point ([PSCustomObject]@{ X = 15; Y = 25 }) -Rect $rect) "cursor inside pet rect should show"
  Assert-True (-not (Test-PointInRect -Point ([PSCustomObject]@{ X = 50; Y = 25 }) -Rect $rect)) "cursor outside pet rect should not show"
  Assert-True (Test-PointInRect -Point ([PSCustomObject]@{ X = 50; Y = 25 }) -Rect $rect -Padding 10) "padding should catch near-pet cursor"
  Assert-True (-not (Test-CanUsePersistedPetRect -CodexRunning $false -PersistedPetRect $rect)) "persisted pet position must not show while Codex is closed"
  Assert-True (Test-CanUsePersistedPetRect -CodexRunning $true -PersistedPetRect $rect) "persisted pet position may be used while Codex is running"
  $now = Get-Date
  $firstUntil = Get-OverlayShowUntil -CursorInPet $true -CursorWasInPet $false -CurrentShowUntil ([datetime]::MinValue) -Now $now -Seconds 10
  Assert-True (Test-ShouldShowOverlay -ShowUntilAt $firstUntil -Now $now.AddSeconds(9)) "entering pet should show for 10 seconds"
  Assert-True (-not (Test-ShouldShowOverlay -ShowUntilAt $firstUntil -Now $now.AddSeconds(11))) "show should expire after 10 seconds"
  $stayUntil = Get-OverlayShowUntil -CursorInPet $true -CursorWasInPet $true -CurrentShowUntil $firstUntil -Now $now.AddSeconds(5) -Seconds 10
  Assert-True ($stayUntil -eq $firstUntil) "staying on pet should not extend display time"
  $activeReenterUntil = Get-OverlayShowUntil -CursorInPet $true -CursorWasInPet $false -CurrentShowUntil $firstUntil -Now $now.AddSeconds(5) -Seconds 10
  Assert-True ($activeReenterUntil -eq $firstUntil) "re-entering while already visible should not extend display time"
  $reenterUntil = Get-OverlayShowUntil -CursorInPet $true -CursorWasInPet $false -CurrentShowUntil $firstUntil -Now $now.AddSeconds(12) -Seconds 10
  Assert-True ($reenterUntil -gt $firstUntil) "leaving and re-entering should trigger a new 10-second display"
  $dipPoint = Convert-DevicePointToDip -Window $null -Point ([PSCustomObject]@{ X = 12; Y = 34 })
  Assert-True ($dipPoint.X -eq 12 -and $dipPoint.Y -eq 34) "DPI conversion should safely fall back without a WPF source"
  Assert-True ((Get-UsageColor 70.0) -eq "#43E6A8") "high remaining should be green"
  Assert-True ((Get-UsageColor 40.0) -eq "#F5B83D") "medium remaining should be amber"
  Assert-True ((Get-UsageColor 10.0) -eq "#F25C5C") "low remaining should be red"
  Assert-True ((Get-UsageColor $null) -eq "#43E6A8") "null remaining should default to green"
  Assert-True ((Format-Duration -ResetAt ([datetime]::Now.AddHours(26)) -Language "en") -eq "1d 2h") "en duration days should format as d/h"
  Assert-True ((Format-Duration -ResetAt ([datetime]::Now.AddMinutes(90)) -Language "en") -eq "1h 30m") "en duration hours should format as h/m"
  Assert-True ((Format-Duration -ResetAt ([datetime]::Now.AddSeconds(45)) -Language "en") -eq "45s") "en duration seconds should format as s"
  Assert-True ((Format-Duration -ResetAt ([datetime]::Now.AddMinutes(90)) -Language "zh") -ne "1h 30m") "zh duration should differ from en"
  Assert-True ((Get-SavedLanguage) -eq "zh" -or (Get-SavedLanguage) -eq "en") "saved language should be valid"
  $hk = Convert-HotkeyToVk -Hotkey "Ctrl+Alt+Shift+L"
  Assert-True ($hk.Vk -eq 0x4C -and $hk.Mods -eq 0x7) "Ctrl+Alt+Shift+L should map to vk 0x4C mods 0x7"

  Write-Output "SelfTest OK"
}

function Show-Status {
  $running = Get-RunningOverlayProcess
  $state = Read-CodexState
  $taskInstalled = Test-AutostartEnabled
  $latestLog = ""
  if (Test-Path -LiteralPath $LogPath) {
    try {
      $latestLog = Get-Content -LiteralPath $LogPath -Tail 1 -ErrorAction Stop
    } catch {
      $latestLog = "(log unavailable: $($_.Exception.Message))"
    }
  }
  [PSCustomObject]@{
    Running = $null -ne $running
    ProcessId = if ($running) { $running.ProcessId } else { $null }
    PidFile = $PidPath
    LogFile = $LogPath
    TaskInstalled = $taskInstalled
    CodexHome = [System.IO.Path]::GetFullPath($CodexHome)
    CodexStateFile = Test-Path -LiteralPath (Join-Path $CodexHome ".codex-global-state.json")
    PetOverlayOpen = if ($state) { [bool]$state.'electron-avatar-overlay-open' } else { $false }
    LatestLog = $latestLog
  } | Format-List
}

function Get-UsageColor {
  param($RemainingPercent)
  if ($null -eq $RemainingPercent) { return "#43E6A8" }
  $value = [double]$RemainingPercent
  if ($value -ge 60.0) { return "#43E6A8" }
  if ($value -ge 30.0) { return "#F5B83D" }
  return "#F25C5C"
}

function New-Brush {
  param([string]$Hex, [byte]$Alpha = 255)
  $clean = $Hex.TrimStart("#")
  $r = [Convert]::ToByte($clean.Substring(0, 2), 16)
  $g = [Convert]::ToByte($clean.Substring(2, 2), 16)
  $b = [Convert]::ToByte($clean.Substring(4, 2), 16)
  return New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb($Alpha, $r, $g, $b))
}

function Set-EllipseBounds {
  param($Ellipse, [double]$CenterX, [double]$CenterY, [double]$Radius)
  $Ellipse.Width = $Radius * 2.0
  $Ellipse.Height = $Radius * 2.0
  [System.Windows.Controls.Canvas]::SetLeft($Ellipse, $CenterX - $Radius)
  [System.Windows.Controls.Canvas]::SetTop($Ellipse, $CenterY - $Radius)
}

function Set-ArcPath {
  param($Path, [double]$CenterX, [double]$CenterY, [double]$Radius, $Percent)
  if ($null -eq $Percent -or [double]$Percent -le 0) {
    $Path.Data = $null
    return
  }
  $p = [Math]::Min(99.99, [Math]::Max(0.01, [double]$Percent)) / 100.0
  $startAngle = -90.0
  $endAngle = $startAngle + 360.0 * $p
  $toRad = [Math]::PI / 180.0
  $sx = $CenterX + $Radius * [Math]::Cos($startAngle * $toRad)
  $sy = $CenterY + $Radius * [Math]::Sin($startAngle * $toRad)
  $ex = $CenterX + $Radius * [Math]::Cos($endAngle * $toRad)
  $ey = $CenterY + $Radius * [Math]::Sin($endAngle * $toRad)
  $large = if ($p -gt 0.5) { 1 } else { 0 }
  $data = "M {0:N2},{1:N2} A {2:N2},{2:N2} 0 {3} 1 {4:N2},{5:N2}" -f $sx, $sy, $Radius, $large, $ex, $ey
  $Path.Data = [System.Windows.Media.Geometry]::Parse($data)
}

function Run-Overlay {
  Ensure-AppDir
  Rotate-AppLog
  Set-Content -LiteralPath $PidPath -Value $PID -Encoding ASCII

  # WPF's font cache constructs file URIs from windir. Some launchers omit this
  # otherwise standard variable even though SystemRoot is present.
  if ([string]::IsNullOrWhiteSpace($env:windir)) { $env:windir = $env:SystemRoot }

  Add-Type -AssemblyName PresentationFramework
  Add-Type -AssemblyName PresentationCore
  Add-Type -AssemblyName WindowsBase
  Add-Type -AssemblyName System.Windows.Forms
  $script:UsageState = [PSCustomObject]@{ Available = $false; Source = "none"; ObservedAt = Get-Date }
  $script:ShowOverlayUntil = [datetime]::MinValue
  $script:CursorWasInPet = $false
  $script:OverlayWasVisible = $false
  $script:OverlayPaused = $false
  $script:AutostartEnabled = Test-AutostartEnabled
  $script:LastTextUpdateAt = [datetime]::MinValue
  if ($script:LanguageWasSet) {
    $script:Language = $Language
    Set-SavedLanguage -Language $Language
  } else {
    $script:Language = Get-SavedLanguage
  }
  $resolvedHotkey = Convert-HotkeyToVk -Hotkey $LanguageHotkey
  $script:HotkeyVk = $resolvedHotkey.Vk
  $script:HotkeyMods = $resolvedHotkey.Mods
  Write-AppLog ("Overlay run started. Language: {0}, LanguageHotkey: {1}" -f $script:Language, $LanguageHotkey)

  try {
    $window = New-Object System.Windows.Window
  } catch {
    $detail = $_.Exception
    $messages = New-Object System.Collections.Generic.List[string]
    while ($null -ne $detail) {
      $messages.Add(("{0}: {1}" -f $detail.GetType().FullName, $detail.Message))
      $detail = $detail.InnerException
    }
    Write-AppLog ("WPF window initialization failed: {0}" -f ($messages -join " | "))
    throw
  }
  $window.WindowStyle = [System.Windows.WindowStyle]::None
  $window.ResizeMode = [System.Windows.ResizeMode]::NoResize
  $window.AllowsTransparency = $true
  $window.Background = [System.Windows.Media.Brushes]::Transparent
  $window.ShowInTaskbar = $false
  $window.ShowActivated = $false
  $window.Topmost = $true
  $window.Width = 112
  $window.Height = 136

  $canvas = New-Object System.Windows.Controls.Canvas
  $window.Content = $canvas

  $panel = New-Object System.Windows.Controls.Border
  $panel.Width = 112
  $panel.Height = 136
  $panel.CornerRadius = New-Object System.Windows.CornerRadius 14
  $panel.Background = New-Brush "#141C24" 238
  $panel.BorderBrush = New-Brush "#EAF3F7" 40
  $panel.BorderThickness = New-Object System.Windows.Thickness 1
  [void]$canvas.Children.Add($panel)

  $outerTrack = New-Object System.Windows.Shapes.Ellipse
  $outerTrack.Stroke = New-Brush "#EAF3F7" 26
  $outerTrack.StrokeThickness = 7
  $outerArc = New-Object System.Windows.Shapes.Path
  $outerArc.Stroke = New-Brush "#43E6A8" 240
  $outerArc.StrokeThickness = 7
  $outerArc.StrokeStartLineCap = [System.Windows.Media.PenLineCap]::Round
  $outerArc.StrokeEndLineCap = [System.Windows.Media.PenLineCap]::Round

  foreach ($shape in @($outerTrack, $outerArc)) {
    [void]$canvas.Children.Add($shape)
  }

  $modeTag = New-Object System.Windows.Controls.TextBlock
  $modeTag.Text = U "7\u5929\u7a97\u53e3"
  $modeTag.Foreground = New-Brush "#A6B4BD" 235
  $modeTag.FontSize = 10
  $modeTag.TextAlignment = [System.Windows.TextAlignment]::Center
  $modeTag.Width = 112
  $percentText = New-Object System.Windows.Controls.TextBlock
  $percentText.Text = "--%"
  $percentText.Foreground = New-Brush "#FFFFFF" 248
  $percentText.FontSize = 22
  $percentText.FontWeight = [System.Windows.FontWeights]::Bold
  $percentText.TextAlignment = [System.Windows.TextAlignment]::Center
  $percentText.Width = 70
  $timeText = New-Object System.Windows.Controls.TextBlock
  $timeText.Text = "--"
  $timeText.Foreground = New-Brush "#A6B4BD" 235
  $timeText.FontSize = 10.5
  $timeText.TextAlignment = [System.Windows.TextAlignment]::Center
  $timeText.Width = 112
  foreach ($text in @($modeTag, $percentText, $timeText)) { [void]$canvas.Children.Add($text) }

  function Update-Text {
    $modeTag.Text = if ($script:Language -eq "en") { "Weekly" } else { U "7\u5929\u7a97\u53e3" }
    if (-not $script:UsageState.Available) {
      $percentText.Text = "--%"
      $timeText.Text = "--"
      return
    }
    $remaining = if ($null -ne $script:UsageState.SecondaryRemaining) { $script:UsageState.SecondaryRemaining } elseif ($null -ne $script:UsageState.PrimaryRemaining) { $script:UsageState.PrimaryRemaining } else { 0 }
    $resetAt = if ($null -ne $script:UsageState.SecondaryResetAt) { $script:UsageState.SecondaryResetAt } else { $script:UsageState.PrimaryResetAt }
    $percentText.Text = ("{0:N0}%" -f $remaining)
    if ($null -ne $resetAt) {
      if ($script:Language -eq "en") {
        $timeText.Text = "in " + (Format-Duration -ResetAt $resetAt -Language "en")
      } else {
        $timeText.Text = (U "\u4e0b\u6b21 ") + (Format-Duration -ResetAt $resetAt -Language "zh") + (U "\u540e")
      }
    } else {
      $timeText.Text = "--"
    }
  }

  function Refresh-Usage {
    $script:UsageState = Get-Usage
    if (-not $script:UsageState.Available) {
      Write-AppLog "Usage unavailable."
    }
    Update-Text
  }

  function Toggle-Language {
    if ($script:Language -eq "zh") { $script:Language = "en" } else { $script:Language = "zh" }
    Set-SavedLanguage -Language $script:Language
    Update-Text
    Update-Overlay
    Write-AppLog ("Language toggled to {0}" -f $script:Language)
  }

  function Update-Overlay {
    if ($script:OverlayPaused) {
      $script:ShowOverlayUntil = [datetime]::MinValue
      $script:CursorWasInPet = $false
      $window.Hide()
      return
    }
    $pet = Get-LivePetRect
    if ($null -eq $pet) {
      $persistedPet = Get-PetRect
      $codexRunning = @(Get-CodexProcessIds).Count -gt 0
      if (Test-CanUsePersistedPetRect -CodexRunning $codexRunning -PersistedPetRect $persistedPet) {
        $pet = $persistedPet
      }
    }
    if ($null -eq $pet) {
      $script:ShowOverlayUntil = [datetime]::MinValue
      $script:CursorWasInPet = $false
      $window.Hide()
      return
    }

    $cursor = Convert-DevicePointToDip -Window $window -Point ([System.Windows.Forms.Cursor]::Position)
    $now = Get-Date
    # ponytail: cursor polling can miss very fast fly-bys; replace with a mouse hook only if 100ms polling still misses real use.
    $cursorInPet = Test-PointInRect -Point $cursor -Rect $pet -Padding $HoverPaddingPx
    $script:ShowOverlayUntil = Get-OverlayShowUntil -CursorInPet $cursorInPet -CursorWasInPet $script:CursorWasInPet -CurrentShowUntil $script:ShowOverlayUntil -Now $now -Seconds $HoverShowSeconds
    $script:CursorWasInPet = $cursorInPet
    if (-not (Test-ShouldShowOverlay -ShowUntilAt $script:ShowOverlayUntil -Now $now)) {
      $script:OverlayWasVisible = $false
      $window.Hide()
      return
    }

    $panelWidth = 112.0
    $gap = 10.0
    $height = 136.0
    $displayRight = $pet.DisplayLeft + $pet.DisplayWidth
    $displayBottom = $pet.DisplayTop + $pet.DisplayHeight
    $widgetLeftRight = $pet.Left + $pet.Width + $gap
    $widgetLeftLeft = $pet.Left - $panelWidth - $gap
    $placeTextLeft = ($widgetLeftRight + $panelWidth) -gt $displayRight

    if ($placeTextLeft) {
      $window.Left = [Math]::Max($pet.DisplayLeft, $widgetLeftLeft)
    } else {
      $window.Left = $widgetLeftRight
    }
    $window.Top = [Math]::Min([Math]::Max($pet.DisplayTop, $pet.Top + ($pet.Height / 2.0) - ($height / 2.0)), $displayBottom - $height)
    $window.Width = $panelWidth
    $window.Height = $height

    $panel.Width = $panelWidth
    $panel.Height = $height
    $cx = 56.0
    $cy = 64.0
    $outerRadius = 32.0
    $secondaryRemaining = if ($null -ne $script:UsageState.SecondaryRemaining) { $script:UsageState.SecondaryRemaining } else { $null }
    $primaryRemaining = if ($null -ne $script:UsageState.PrimaryRemaining) { $script:UsageState.PrimaryRemaining } else { $null }
    $remaining = if ($null -ne $secondaryRemaining) { $secondaryRemaining } elseif ($null -ne $primaryRemaining) { $primaryRemaining } else { 0 }
    $outerArc.Stroke = New-Brush (Get-UsageColor $remaining) 240
    Set-EllipseBounds -Ellipse $outerTrack -CenterX $cx -CenterY $cy -Radius $outerRadius
    Set-ArcPath -Path $outerArc -CenterX $cx -CenterY $cy -Radius $outerRadius -Percent $remaining
    [System.Windows.Controls.Canvas]::SetLeft($panel, 0.0)
    [System.Windows.Controls.Canvas]::SetTop($panel, 0.0)
    [System.Windows.Controls.Canvas]::SetLeft($percentText, 21.0)
    [System.Windows.Controls.Canvas]::SetTop($percentText, 49.0)
    [System.Windows.Controls.Canvas]::SetLeft($modeTag, 0.0)
    [System.Windows.Controls.Canvas]::SetTop($modeTag, 8.0)
    [System.Windows.Controls.Canvas]::SetLeft($timeText, 0.0)
    [System.Windows.Controls.Canvas]::SetTop($timeText, 112.0)
    if (-not $window.IsVisible) { $window.Show() }
    $script:OverlayWasVisible = $true
  }

  $window.Add_SourceInitialized({
    $helper = New-Object System.Windows.Interop.WindowInteropHelper -ArgumentList $window
    [CodexPetUsageOverlayNative]::MakeClickThrough($helper.Handle)
    if ($script:HotkeyVk -ne 0 -and $script:HotkeyMods -ne 0) {
      try {
        $registered = [CodexPetUsageOverlayNative]::RegisterHotKey($helper.Handle, 1, [uint32]($script:HotkeyMods -bor 0x4000), $script:HotkeyVk)
        if ($registered) {
          Write-AppLog ("Language hotkey registered: {0}" -f $LanguageHotkey)
        } else {
          Write-AppLog ("Language hotkey registration failed (conflict?): {0}" -f $LanguageHotkey)
        }
      } catch {
        Write-AppLog "Language hotkey registration error: $($_.Exception.Message)"
      }
    }
    $source = [System.Windows.Interop.HwndSource]::FromHwnd($helper.Handle)
    if ($null -ne $source) {
      [void]$source.AddHook({
        param($h, $msg, $w, $l, [ref]$handled)
        if ([int64]$msg -eq 0x0312 -and [int32]$w -eq 1) {
          $handled.Value = $true
          try { Toggle-Language } catch { Write-AppLog "Language hotkey toggle failed: $($_.Exception.Message)" }
        }
        return [IntPtr]::Zero
      })
    }
  })
  # Show then hide once at startup so the HwndSource is created and SourceInitialized
  # (click-through + hotkey registration) runs immediately, even while the overlay stays
  # hidden until first hover. The window is transparent and NOACTIVATE, so no visible flash.
  $window.Show()
  $window.Hide()

  # System tray management keeps everyday controls out of the project folder.
  $trayMenu = New-Object System.Windows.Forms.ContextMenuStrip
  $trayStatus = New-Object System.Windows.Forms.ToolStripMenuItem
  $trayStatus.Text = $DisplayName
  $trayStatus.Enabled = $false
  [void]$trayMenu.Items.Add($trayStatus)
  [void]$trayMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

  $pauseItem = New-Object System.Windows.Forms.ToolStripMenuItem
  $pauseItem.Text = if ($script:Language -eq "en") { "Pause overlay" } else { U "\u6682\u505c\u60ac\u6d6e\u7a97" }
  $pauseItem.CheckOnClick = $true
  $pauseItem.Add_Click({
    $script:OverlayPaused = $pauseItem.Checked
    if ($script:OverlayPaused) {
      $window.Hide()
      $script:ShowOverlayUntil = [datetime]::MinValue
      $pauseItem.Text = if ($script:Language -eq "en") { "Resume overlay" } else { U "\u6062\u590d\u60ac\u6d6e\u7a97" }
      Write-AppLog "Overlay paused from tray."
    } else {
      $pauseItem.Text = if ($script:Language -eq "en") { "Pause overlay" } else { U "\u6682\u505c\u60ac\u6d6e\u7a97" }
      Write-AppLog "Overlay resumed from tray."
      Update-Overlay
    }
  })
  [void]$trayMenu.Items.Add($pauseItem)

  $startupItem = New-Object System.Windows.Forms.ToolStripMenuItem
  $startupItem.Text = if ($script:Language -eq "en") { "Start with Windows" } else { U "\u5f00\u673a\u81ea\u52a8\u542f\u52a8" }
  $startupItem.Checked = Test-AutostartEnabled
  $startupItem.Add_Click({
    try {
      if ($startupItem.Checked) {
        Uninstall-TaskScheduler
        $startupItem.Checked = $false
      } else {
        Install-TaskScheduler
        $startupItem.Checked = $true
      }
    } catch {
      [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, $AppName, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    }
  })
  [void]$trayMenu.Items.Add($startupItem)

  $logItem = New-Object System.Windows.Forms.ToolStripMenuItem
  $logItem.Text = if ($script:Language -eq "en") { "View log" } else { U "\u67e5\u770b\u65e5\u5fd7" }
  $logItem.Add_Click({
    try { Start-Process -FilePath "notepad.exe" -ArgumentList ('"{0}"' -f $LogPath) } catch {
      [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, $AppName) | Out-Null
    }
  })
  [void]$trayMenu.Items.Add($logItem)
  [void]$trayMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

  $exitItem = New-Object System.Windows.Forms.ToolStripMenuItem
  $exitItem.Text = if ($script:Language -eq "en") { "Exit" } else { U "\u9000\u51fa" }
  [void]$trayMenu.Items.Add($exitItem)

  $trayIcon = New-Object System.Windows.Forms.NotifyIcon
  $trayIcon.Text = $DisplayName
  $iconPath = Join-Path (Split-Path -Parent ([System.IO.Path]::GetFullPath($PSCommandPath))) "assets\app-icon.ico"
  if (Test-Path -LiteralPath $iconPath) {
    $trayIcon.Icon = New-Object System.Drawing.Icon $iconPath
  } else {
    $trayIcon.Icon = [System.Drawing.SystemIcons]::Information
  }
  $trayIcon.ContextMenuStrip = $trayMenu
  $trayIcon.Visible = $true

  # Compact WPF control panel opened from the tray icon. If a host-specific WPF
  # incompatibility occurs, keep the tray app alive with the classic menu.
  try {
  Write-AppLog "Control panel initialization started."
  $controlWindow = New-Object System.Windows.Window
  $controlWindow.Width = 280
  $controlWindow.Height = 330
  $controlWindow.WindowStyle = [System.Windows.WindowStyle]::None
  $controlWindow.ResizeMode = [System.Windows.ResizeMode]::NoResize
  $controlWindow.AllowsTransparency = $true
  $controlWindow.Background = [System.Windows.Media.Brushes]::Transparent
  $controlWindow.ShowInTaskbar = $false
  $controlWindow.Topmost = $true
  $controlWindow.ShowActivated = $true

  $controlRoot = New-Object System.Windows.Controls.Border
  $controlRoot.CornerRadius = New-Object System.Windows.CornerRadius 16
  $controlRoot.Background = New-Brush "#080A0C" 252
  $controlRoot.BorderBrush = New-Brush "#FFFFFF" 38
  $controlRoot.BorderThickness = New-Object System.Windows.Thickness 1
  $controlRoot.Padding = New-Object System.Windows.Thickness 16
  $controlWindow.Content = $controlRoot

  $controlGrid = New-Object System.Windows.Controls.Grid
  $controlRoot.Child = $controlGrid
  foreach ($height in @(42, 76, 32, 32, 32, 1, 32, 32, 19)) {
    $row = New-Object System.Windows.Controls.RowDefinition
    $row.Height = New-Object System.Windows.GridLength $height
    $controlGrid.RowDefinitions.Add($row)
  }

  $header = New-Object System.Windows.Controls.Grid
  $header.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
  $header.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
  $header.ColumnDefinitions[0].Width = New-Object System.Windows.GridLength -ArgumentList 1,([System.Windows.GridUnitType]::Star)
  $header.ColumnDefinitions[1].Width = New-Object System.Windows.GridLength 72
  [System.Windows.Controls.Grid]::SetRow($header, 0)
  [void]$controlGrid.Children.Add($header)
  $headerText = New-Object System.Windows.Controls.StackPanel
  $title = New-Object System.Windows.Controls.TextBlock
  $title.Text = $DisplayName
  $title.Foreground = New-Brush "#F5F2E8"
  $title.FontSize = 16
  $title.FontWeight = [System.Windows.FontWeights]::SemiBold
  $status = New-Object System.Windows.Controls.TextBlock
  $status.Text = if ($script:Language -eq "en") { "● Running" } else { U "\u25cf \u8fd0\u884c\u4e2d" }
  $status.Foreground = New-Brush "#43E6A8"
  $status.FontSize = 11
  $status.Margin = New-Object System.Windows.Thickness 0,4,0,0
  [void]$headerText.Children.Add($title); [void]$headerText.Children.Add($status)
  [void]$header.Children.Add($headerText)
  $glyph = New-Object System.Windows.Controls.TextBlock
  $glyph.Text = ">_<"
  $glyph.Foreground = New-Brush "#F5F2E8"
  $glyph.FontFamily = New-Object System.Windows.Media.FontFamily "Consolas"
  $glyph.FontSize = 16
  $glyph.FontWeight = [System.Windows.FontWeights]::Bold
  $glyph.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
  $glyph.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
  [System.Windows.Controls.Grid]::SetColumn($glyph, 1)
  [void]$header.Children.Add($glyph)

  $usageCard = New-Object System.Windows.Controls.Border
  $usageCard.Background = New-Brush "#11161B" 255
  $usageCard.CornerRadius = New-Object System.Windows.CornerRadius 12
  $usageCard.Margin = New-Object System.Windows.Thickness 0,5,0,8
  [System.Windows.Controls.Grid]::SetRow($usageCard, 1)
  [void]$controlGrid.Children.Add($usageCard)
  $usageCanvas = New-Object System.Windows.Controls.Canvas
  $usageCard.Child = $usageCanvas
  $controlLabel = New-Object System.Windows.Controls.TextBlock
  $controlLabel.Text = if ($script:Language -eq "en") { "7-day remaining" } else { U "7 \u5929\u5269\u4f59" }
  $controlLabel.Foreground = New-Brush "#98A4AC"
  $controlLabel.FontSize = 11
  [System.Windows.Controls.Canvas]::SetLeft($controlLabel, 14); [System.Windows.Controls.Canvas]::SetTop($controlLabel, 10)
  [void]$usageCanvas.Children.Add($controlLabel)
  $controlPercent = New-Object System.Windows.Controls.TextBlock
  $controlPercent.Text = "--%"
  $controlPercent.Foreground = New-Brush "#F5F2E8"
  $controlPercent.FontSize = 28
  $controlPercent.FontWeight = [System.Windows.FontWeights]::SemiBold
  [System.Windows.Controls.Canvas]::SetLeft($controlPercent, 14); [System.Windows.Controls.Canvas]::SetTop($controlPercent, 28)
  [void]$usageCanvas.Children.Add($controlPercent)
  $controlTrack = New-Object System.Windows.Shapes.Ellipse
  $controlTrack.Stroke = New-Brush "#FFFFFF" 28
  $controlTrack.StrokeThickness = 6
  $controlArc = New-Object System.Windows.Shapes.Path
  $controlArc.Stroke = New-Brush "#43E6A8"
  $controlArc.StrokeThickness = 6
  $controlArc.StrokeStartLineCap = [System.Windows.Media.PenLineCap]::Round
  $controlArc.StrokeEndLineCap = [System.Windows.Media.PenLineCap]::Round
  foreach ($shape in @($controlTrack, $controlArc)) { [void]$usageCanvas.Children.Add($shape) }
  Set-EllipseBounds -Ellipse $controlTrack -CenterX 210 -CenterY 34 -Radius 24

  $controlButtonTemplate = [System.Windows.Markup.XamlReader]::Parse(@'
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                 TargetType="{x:Type Button}"
                 xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <Border x:Name="RowBackground"
          Background="{TemplateBinding Background}"
          CornerRadius="6"
          Padding="{TemplateBinding Padding}"
          SnapsToDevicePixels="True">
    <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                      VerticalAlignment="{TemplateBinding VerticalContentAlignment}"
                      SnapsToDevicePixels="True" />
  </Border>
  <ControlTemplate.Triggers>
    <Trigger Property="IsMouseOver" Value="True">
      <Setter TargetName="RowBackground" Property="Background" Value="#171C20" />
    </Trigger>
    <Trigger Property="IsPressed" Value="True">
      <Setter TargetName="RowBackground" Property="Background" Value="#20272C" />
    </Trigger>
  </ControlTemplate.Triggers>
</ControlTemplate>
'@)

  function New-ControlRow {
    param([int]$Row, [string]$Label, [string]$Value, [string]$Accent = "#F5F2E8")
    $button = New-Object System.Windows.Controls.Button
    $button.Background = [System.Windows.Media.Brushes]::Transparent
    $button.BorderThickness = New-Object System.Windows.Thickness 0
    $button.Template = $controlButtonTemplate
    $button.HorizontalContentAlignment = [System.Windows.HorizontalAlignment]::Stretch
    $button.Padding = New-Object System.Windows.Thickness 4,0,4,0
    $content = New-Object System.Windows.Controls.Grid
    $content.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
    $content.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
    $content.ColumnDefinitions[0].Width = New-Object System.Windows.GridLength -ArgumentList 1,([System.Windows.GridUnitType]::Star)
    $content.ColumnDefinitions[1].Width = New-Object System.Windows.GridLength 92
    $left = New-Object System.Windows.Controls.TextBlock
    $left.Text = $Label; $left.Foreground = New-Brush $Accent; $left.FontSize = 12
    $left.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $right = New-Object System.Windows.Controls.TextBlock
    $right.Text = $Value; $right.Foreground = New-Brush "#98A4AC"; $right.FontSize = 12
    $right.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
    $right.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    [System.Windows.Controls.Grid]::SetColumn($right, 1)
    [void]$content.Children.Add($left); [void]$content.Children.Add($right)
    $button.Content = $content
    [System.Windows.Controls.Grid]::SetRow($button, $Row)
    [void]$controlGrid.Children.Add($button)
    return [PSCustomObject]@{ Button = $button; Label = $left; Value = $right }
  }

  function New-ToggleVisual {
    $track = New-Object System.Windows.Controls.Border
    $track.Width = 36; $track.Height = 20
    $track.CornerRadius = New-Object System.Windows.CornerRadius 10
    $track.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
    $track.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $dot = New-Object System.Windows.Shapes.Ellipse
    $dot.Width = 14; $dot.Height = 14
    $dot.Fill = New-Brush "#F5F2E8"
    $dot.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
    $dot.Margin = New-Object System.Windows.Thickness 3,0,0,0
    $track.Child = $dot
    return [PSCustomObject]@{ Track = $track; Dot = $dot }
  }

  function Set-ToggleVisual {
    param($Toggle, [bool]$Enabled)
    if ($Enabled) {
      $trackColor = "#43E6A8"
      $dotAlignment = [System.Windows.HorizontalAlignment]::Right
      $dotMargin = New-Object System.Windows.Thickness 0,0,3,0
    } else {
      $trackColor = "#30383E"
      $dotAlignment = [System.Windows.HorizontalAlignment]::Left
      $dotMargin = New-Object System.Windows.Thickness 3,0,0,0
    }
    $Toggle.Track.Background = New-Brush $trackColor
    $Toggle.Dot.HorizontalAlignment = $dotAlignment
    $Toggle.Dot.Margin = $dotMargin
  }

  $overlayLabel = if ($script:Language -eq "en") { "Overlay" } else { U "\u60ac\u6d6e\u7a97" }
  $startupLabel = if ($script:Language -eq "en") { "Start with Windows" } else { U "\u5f00\u673a\u81ea\u52a8\u542f\u52a8" }
  $startupValue = if ($script:AutostartEnabled) { "ON" } else { "OFF" }
  $languageLabel = if ($script:Language -eq "en") { "Language" } else { U "\u754c\u9762\u8bed\u8a00" }
  $languageValue = if ($script:Language -eq "en") { "English  ›" } else { U "\u4e2d\u6587  \u203a" }
  $overlayRow = New-ControlRow 2 $overlayLabel "ON"
  $startupRow = New-ControlRow 3 $startupLabel $startupValue
  $languageRow = New-ControlRow 4 $languageLabel $languageValue
  $overlayToggle = New-ToggleVisual
  $startupToggle = New-ToggleVisual
  $overlayRow.Value.Visibility = [System.Windows.Visibility]::Collapsed
  $startupRow.Value.Visibility = [System.Windows.Visibility]::Collapsed
  [System.Windows.Controls.Grid]::SetColumn($overlayToggle.Track, 1)
  [System.Windows.Controls.Grid]::SetColumn($startupToggle.Track, 1)
  [void]$overlayRow.Button.Content.Children.Add($overlayToggle.Track)
  [void]$startupRow.Button.Content.Children.Add($startupToggle.Track)

  $languageChoices = New-Object System.Windows.Controls.StackPanel
  $languageChoices.Orientation = [System.Windows.Controls.Orientation]::Horizontal
  $languageChoices.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
  $languageChoices.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
  $languageChoices.Visibility = [System.Windows.Visibility]::Collapsed
  $zhChoice = New-Object System.Windows.Controls.TextBlock
  $zhChoice.Text = U "\u4e2d\u6587"; $zhChoice.FontSize = 11; $zhChoice.Margin = New-Object System.Windows.Thickness 0,0,10,0
  $enChoice = New-Object System.Windows.Controls.TextBlock
  $enChoice.Text = "EN"; $enChoice.FontSize = 11
  [void]$languageChoices.Children.Add($zhChoice); [void]$languageChoices.Children.Add($enChoice)
  [System.Windows.Controls.Grid]::SetColumn($languageChoices, 1)
  [void]$languageRow.Button.Content.Children.Add($languageChoices)
  $separator = New-Object System.Windows.Controls.Border
  $separator.Background = New-Brush "#FFFFFF" 24
  $separator.Height = 1
  [System.Windows.Controls.Grid]::SetRow($separator, 5); [void]$controlGrid.Children.Add($separator)
  $logLabel = if ($script:Language -eq "en") { "View log" } else { U "\u67e5\u770b\u65e5\u5fd7" }
  $exitLabel = if ($script:Language -eq "en") { "Exit" } else { U "\u9000\u51fa\u7a0b\u5e8f" }
  $controlLogRow = New-ControlRow 6 $logLabel "›"
  $controlExitRow = New-ControlRow 7 $exitLabel "" "#FF6B62"
  $versionText = New-Object System.Windows.Controls.TextBlock
  $versionText.Text = "v1.1.0"; $versionText.Foreground = New-Brush "#65717A"; $versionText.FontSize = 9
  $versionText.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
  $versionText.VerticalAlignment = [System.Windows.VerticalAlignment]::Bottom
  [System.Windows.Controls.Grid]::SetRow($versionText, 8); [void]$controlGrid.Children.Add($versionText)

  function Update-ControlPanel {
    $remaining = if ($script:UsageState.Available -and $null -ne $script:UsageState.SecondaryRemaining) { [double]$script:UsageState.SecondaryRemaining } elseif ($script:UsageState.Available -and $null -ne $script:UsageState.PrimaryRemaining) { [double]$script:UsageState.PrimaryRemaining } else { $null }
    $status.Text = if ($script:Language -eq "en") { "● Running" } else { U "\u25cf \u8fd0\u884c\u4e2d" }
    $controlLabel.Text = if ($script:Language -eq "en") { "7-day remaining" } else { U "7 \u5929\u5269\u4f59" }
    $overlayRow.Label.Text = if ($script:Language -eq "en") { "Overlay" } else { U "\u60ac\u6d6e\u7a97" }
    $startupRow.Label.Text = if ($script:Language -eq "en") { "Start with Windows" } else { U "\u5f00\u673a\u81ea\u52a8\u542f\u52a8" }
    $languageRow.Label.Text = if ($script:Language -eq "en") { "Language" } else { U "\u754c\u9762\u8bed\u8a00" }
    $languageRow.Value.Text = if ($script:Language -eq "en") { "English  ›" } else { U "\u4e2d\u6587  \u203a" }
    $controlLogRow.Label.Text = if ($script:Language -eq "en") { "View log" } else { U "\u67e5\u770b\u65e5\u5fd7" }
    $controlExitRow.Label.Text = if ($script:Language -eq "en") { "Exit" } else { U "\u9000\u51fa\u7a0b\u5e8f" }
    $pauseItem.Text = if ($script:OverlayPaused) {
      if ($script:Language -eq "en") { "Resume overlay" } else { U "\u6062\u590d\u60ac\u6d6e\u7a97" }
    } else {
      if ($script:Language -eq "en") { "Pause overlay" } else { U "\u6682\u505c\u60ac\u6d6e\u7a97" }
    }
    $startupItem.Text = if ($script:Language -eq "en") { "Start with Windows" } else { U "\u5f00\u673a\u81ea\u52a8\u542f\u52a8" }
    $logItem.Text = if ($script:Language -eq "en") { "View log" } else { U "\u67e5\u770b\u65e5\u5fd7" }
    $exitItem.Text = if ($script:Language -eq "en") { "Exit" } else { U "\u9000\u51fa" }
    $controlPercent.Text = if ($null -ne $remaining) { "{0:N0}%" -f $remaining } else { "--%" }
    $controlArc.Stroke = New-Brush (Get-UsageColor $remaining)
    Set-ArcPath -Path $controlArc -CenterX 210 -CenterY 34 -Radius 24 -Percent $remaining
    Set-ToggleVisual -Toggle $overlayToggle -Enabled (-not $script:OverlayPaused)
    Set-ToggleVisual -Toggle $startupToggle -Enabled $script:AutostartEnabled
    if ($script:Language -eq "zh") { $zhColor = "#43E6A8"; $enColor = "#98A4AC" }
    else { $zhColor = "#98A4AC"; $enColor = "#43E6A8" }
    $zhChoice.Foreground = New-Brush $zhColor
    $enChoice.Foreground = New-Brush $enColor
  }

  function Show-ControlPanel {
    Update-ControlPanel
    $cursorPos = [System.Windows.Forms.Cursor]::Position
    $screen = [System.Windows.Forms.Screen]::FromPoint($cursorPos)
    $controlWindow.Show()
    $source = [System.Windows.PresentationSource]::FromVisual($controlWindow)
    if ($null -ne $source -and $null -ne $source.CompositionTarget) {
      $fromDevice = $source.CompositionTarget.TransformFromDevice
      $cursorDevicePoint = New-Object System.Windows.Point -ArgumentList ([double]$cursorPos.X),([double]$cursorPos.Y)
      $workTopLeftDevice = New-Object System.Windows.Point -ArgumentList ([double]$screen.WorkingArea.Left),([double]$screen.WorkingArea.Top)
      $workBottomRightDevice = New-Object System.Windows.Point -ArgumentList ([double]$screen.WorkingArea.Right),([double]$screen.WorkingArea.Bottom)
      $cursorDip = $fromDevice.Transform($cursorDevicePoint)
      $workTopLeft = $fromDevice.Transform($workTopLeftDevice)
      $workBottomRight = $fromDevice.Transform($workBottomRightDevice)
      $controlWindow.Left = [Math]::Min([Math]::Max($workTopLeft.X, $cursorDip.X - $controlWindow.Width + 18), $workBottomRight.X - $controlWindow.Width)
      $controlWindow.Top = [Math]::Min([Math]::Max($workTopLeft.Y, $cursorDip.Y - $controlWindow.Height - 10), $workBottomRight.Y - $controlWindow.Height)
    }
    $controlWindow.Activate() | Out-Null
  }

  $overlayRow.Button.Add_Click({
    $script:OverlayPaused = -not $script:OverlayPaused
    $pauseItem.Checked = $script:OverlayPaused
    if ($script:OverlayPaused) { $window.Hide(); $script:ShowOverlayUntil = [datetime]::MinValue }
    Update-ControlPanel
  })
  $startupRow.Button.Add_Click({
    try {
      if ($script:AutostartEnabled) { Uninstall-TaskScheduler } else { Install-TaskScheduler }
      $script:AutostartEnabled = -not $script:AutostartEnabled
      Update-ControlPanel
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, $AppName) | Out-Null }
  })
  $languageRow.Button.Add_MouseEnter({
    $languageRow.Value.Visibility = [System.Windows.Visibility]::Collapsed
    $languageChoices.Visibility = [System.Windows.Visibility]::Visible
  })
  $languageRow.Button.Add_MouseLeave({
    $languageChoices.Visibility = [System.Windows.Visibility]::Collapsed
    $languageRow.Value.Text = if ($script:Language -eq "en") { "English  ›" } else { U "\u4e2d\u6587  \u203a" }
    $languageRow.Value.Visibility = [System.Windows.Visibility]::Visible
  })
  $languageRow.Button.Add_PreviewMouseLeftButtonDown({
    param($sender, $eventArgs)
    if ($languageChoices.Visibility -ne [System.Windows.Visibility]::Visible) { return }
    if ($eventArgs.OriginalSource -eq $zhChoice -and $script:Language -ne "zh") {
      Toggle-Language
      Update-ControlPanel
      $eventArgs.Handled = $true
    } elseif ($eventArgs.OriginalSource -eq $enChoice -and $script:Language -ne "en") {
      Toggle-Language
      Update-ControlPanel
      $eventArgs.Handled = $true
    }
  })
  $controlLogRow.Button.Add_Click({ try { Start-Process notepad.exe ('"{0}"' -f $LogPath) } catch {} })
  $controlExitRow.Button.Add_Click({ $exitItem.PerformClick() })
  $controlWindow.Add_Deactivated({ $controlWindow.Hide() })
  $trayIcon.ContextMenuStrip = $null
  $trayIcon.Add_MouseClick({
    param($sender, $eventArgs)
    $window.Dispatcher.BeginInvoke([Action]{ Show-ControlPanel }) | Out-Null
  })
  Write-AppLog "Control panel initialization completed."
  } catch {
    Write-AppLog ("Control panel initialization failed; classic tray menu retained: {0}" -f $_.Exception.Message)
    $trayIcon.ContextMenuStrip = $trayMenu
  }

  $usageTimer = New-Object System.Windows.Threading.DispatcherTimer
  $usageTimer.Interval = [TimeSpan]::FromSeconds($UsagePollSeconds)
  $usageTimer.Add_Tick({
    try { Refresh-Usage; Update-Overlay } catch { Write-AppLog "Usage timer failed: $($_.Exception.Message)" }
  })
  $petTimer = New-Object System.Windows.Threading.DispatcherTimer
  $petTimer.Interval = [TimeSpan]::FromMilliseconds($PetPollMs)
  $petTimer.Add_Tick({
    try {
      if ($window.IsVisible -and ((Get-Date) - $script:LastTextUpdateAt).TotalSeconds -ge 1) {
        Update-Text
        $script:LastTextUpdateAt = Get-Date
      }
      Update-Overlay
    } catch { Write-AppLog "Pet timer failed: $($_.Exception.Message)" }
  })

  $app = New-Object System.Windows.Application
  $app.ShutdownMode = [System.Windows.ShutdownMode]::OnExplicitShutdown
  $exitItem.Add_Click({
    Write-AppLog "Exit requested from tray."
    $trayIcon.Visible = $false
    $trayIcon.Dispose()
    if (Test-Path -LiteralPath $PidPath) { Remove-Item -LiteralPath $PidPath -Force -ErrorAction SilentlyContinue }
    $app.Shutdown()
  })
  $app.Add_Exit({
    if ($null -ne $trayIcon) {
      $trayIcon.Visible = $false
      $trayIcon.Dispose()
    }
  })
  $usageTimer.Start()
  $petTimer.Start()
  Refresh-Usage
  Update-Overlay
  [void]$app.Run($window)
}

if (-not ("CodexPetUsageOverlayNative" -as [type])) {
  Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class CodexPetUsageOverlayNative {
    private const int GWL_EXSTYLE = -20;
    private const long WS_EX_TRANSPARENT = 0x00000020L;
    private const long WS_EX_TOOLWINDOW = 0x00000080L;
    private const long WS_EX_NOACTIVATE = 0x08000000L;

    [DllImport("user32.dll", EntryPoint="GetWindowLongW", SetLastError=true)]
    private static extern int GetWindowLong32(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", EntryPoint="SetWindowLongW", SetLastError=true)]
    private static extern int SetWindowLong32(IntPtr hWnd, int nIndex, int dwNewLong);

    [DllImport("user32.dll", EntryPoint="GetWindowLongPtrW", SetLastError=true)]
    private static extern IntPtr GetWindowLongPtr64(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", EntryPoint="SetWindowLongPtrW", SetLastError=true)]
    private static extern IntPtr SetWindowLongPtr64(IntPtr hWnd, int nIndex, IntPtr dwNewLong);

    public static void MakeClickThrough(IntPtr hWnd) {
        if (hWnd == IntPtr.Zero) { return; }
        if (IntPtr.Size == 8) {
            long style = GetWindowLongPtr64(hWnd, GWL_EXSTYLE).ToInt64();
            style |= WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE;
            SetWindowLongPtr64(hWnd, GWL_EXSTYLE, new IntPtr(style));
        } else {
            int style = GetWindowLong32(hWnd, GWL_EXSTYLE);
            style |= unchecked((int)(WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE));
            SetWindowLong32(hWnd, GWL_EXSTYLE, style);
        }
    }

    // ---- pet window tracking ----
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumChildWindows(IntPtr hWndParent, EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll", CharSet=CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll", CharSet=CharSet.Unicode)]
    public static extern int GetClassName(IntPtr hWnd, System.Text.StringBuilder lpClassName, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint dwFlags);

    [DllImport("user32.dll", CharSet=CharSet.Unicode)]
    public static extern bool GetMonitorInfo(IntPtr hMonitor, ref MONITORINFO lpmi);

    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct MONITORINFO {
        public int cbSize;
        public RECT rcMonitor;
        public RECT rcWork;
        public uint dwFlags;
    }
}
"@
}

switch ($Command) {
  "Start" { Start-Overlay }
  "Stop" { Stop-Overlay }
  "Status" { Show-Status }
  "SelfTest" { Invoke-SelfTest }
  "InstallTask" { Install-TaskScheduler }
  "UninstallTask" { Uninstall-TaskScheduler }
  "Run" { Run-Overlay }
  "FindPet" { Invoke-FindPetDiagnostic }
}
