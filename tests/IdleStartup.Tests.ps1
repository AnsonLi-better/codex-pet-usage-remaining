$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'CodexPetUsageOverlay.ps1') -Command SelfTest
$testDir = Join-Path ([IO.Path]::GetTempPath()) ('codex-idle-test-' + [guid]::NewGuid().ToString('N'))
$AppDir = $testDir
$PidPath = Join-Path $testDir 'overlay.pid'
$LogPath = Join-Path $testDir 'overlay.log'
$OverlayWindowPath = Join-Path $testDir 'overlay-window.txt'
$LanguageHotkey = ''
$script:LanguageWasSet = $false
function Get-CodexProcessIds { return @() }
function Get-SavedLanguage { return 'en' }
function Test-AutostartEnabled { return $false }
function Get-Usage { throw 'Idle startup must not request quota.' }
function Get-TokenUsage { throw 'Idle startup must not read token usage.' }
Add-Type -AssemblyName PresentationFramework
$script:IdleFailure = $null
$inspectionTimer = New-Object System.Windows.Threading.DispatcherTimer
$inspectionTimer.Interval = [TimeSpan]::FromSeconds(3)
$inspectionTimer.Add_Tick({
  try {
    foreach ($candidate in [System.Windows.Application]::Current.Windows) {
      if ($candidate.IsVisible) { throw 'Idle startup displayed a WPF window.' }
    }
    if ($script:DesktopActive -ne $false) { throw 'Idle startup did not enter waiting mode.' }
    if ($null -ne $script:UsageAppServerProcess) { throw 'Idle startup launched the statistics server.' }
  } catch { $script:IdleFailure = $_.Exception.Message }
  finally {
    $inspectionTimer.Stop()
    [System.Windows.Application]::Current.Shutdown()
  }
})
try {
  $inspectionTimer.Start()
  Run-Overlay
  if ($script:IdleFailure) { throw $script:IdleFailure }
  'IdleStartup tests OK'
} finally {
  $inspectionTimer.Stop()
  $resolvedTestDir = [IO.Path]::GetFullPath($testDir)
  if ($resolvedTestDir.StartsWith([IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedTestDir)) {
    Remove-Item -LiteralPath $resolvedTestDir -Recurse -Force
  }
}
