param(
  [Parameter(Mandatory = $true)]
  [string]$InstallDir,
  [switch]$Force,
  [string]$SourceArchivePath
)

$ErrorActionPreference = "Stop"
$ComponentVersion = "0.147.0"
$ComponentUrl = "https://github.com/openai/codex/releases/download/rust-v0.147.0/codex-app-server-x86_64-pc-windows-msvc.exe.zip"
$ComponentSha256 = "72fdd5f4a5c47c56a822746cffdadbc4337082c543b55697f8328dd5db421707"
$ComponentArchiveExe = "codex-app-server-x86_64-pc-windows-msvc.exe"
$ToolsDir = Join-Path $InstallDir "tools"
$TargetPath = Join-Path $ToolsDir "codex-app-server.exe"
$ManifestPath = Join-Path $ToolsDir "official-stats-component.json"
$StateDir = Join-Path $env:LOCALAPPDATA "CodexPetUsageOverlay"
$LogPath = Join-Path $StateDir "component-install.log"

function Write-ComponentLog {
  param([string]$Message)
  if (-not (Test-Path -LiteralPath $StateDir)) { New-Item -ItemType Directory -Path $StateDir -Force | Out-Null }
  $line = "{0} {1}" -f ([datetime]::Now.ToString("s")), $Message
  Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
  Write-Output $Message
}

function Test-AccessibleSystemCodex {
  try {
    $command = Get-Command codex.exe -ErrorAction Stop
    $item = Get-Item -LiteralPath $command.Source -ErrorAction Stop
    return -not ($item.Attributes -band [System.IO.FileAttributes]::Encrypted)
  } catch {
  }
  return $false
}

function Test-CurrentBundledComponent {
  if (-not (Test-Path -LiteralPath $TargetPath) -or -not (Test-Path -LiteralPath $ManifestPath)) { return $false }
  try {
    $manifest = Get-Content -LiteralPath $ManifestPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    return ([string]$manifest.version -eq $ComponentVersion -and [string]$manifest.archiveSha256 -eq $ComponentSha256)
  } catch {
    return $false
  }
}

$tempRoot = $null
try {
  $InstallDir = [System.IO.Path]::GetFullPath($InstallDir)
  if (-not (Test-Path -LiteralPath $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null }

  if (-not $Force -and (Test-CurrentBundledComponent)) {
    Write-ComponentLog "Official statistics component is already installed."
    exit 0
  }
  if (-not $Force -and (Test-AccessibleSystemCodex)) {
    Write-ComponentLog "An accessible system Codex CLI is already installed; bundled component download skipped."
    exit 0
  }

  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-usage-stats-{0}" -f ([guid]::NewGuid().ToString("N")))
  $archivePath = Join-Path $tempRoot "component.zip"
  $extractDir = Join-Path $tempRoot "extract"
  New-Item -ItemType Directory -Path $extractDir -Force | Out-Null

  if ([string]::IsNullOrWhiteSpace($SourceArchivePath)) {
    Write-ComponentLog "Downloading official Codex statistics component v$ComponentVersion..."
    $client = New-Object System.Net.WebClient
    try { $client.DownloadFile($ComponentUrl, $archivePath) } finally { $client.Dispose() }
  } else {
    Write-ComponentLog "Installing official Codex statistics component v$ComponentVersion from a local verified archive..."
    Copy-Item -LiteralPath $SourceArchivePath -Destination $archivePath -Force
  }

  $actualHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actualHash -ne $ComponentSha256) { throw "Downloaded component failed SHA-256 verification." }
  Expand-Archive -LiteralPath $archivePath -DestinationPath $extractDir -Force
  $extracted = Get-ChildItem -LiteralPath $extractDir -Recurse -File -Filter $ComponentArchiveExe | Select-Object -First 1
  if ($null -eq $extracted) { throw "Downloaded archive did not contain $ComponentArchiveExe." }

  New-Item -ItemType Directory -Path $ToolsDir -Force | Out-Null
  $stagedPath = Join-Path $ToolsDir "codex-app-server.new.exe"
  Copy-Item -LiteralPath $extracted.FullName -Destination $stagedPath -Force
  Move-Item -LiteralPath $stagedPath -Destination $TargetPath -Force
  [PSCustomObject]@{
    name = "OpenAI Codex app-server"
    version = $ComponentVersion
    source = $ComponentUrl
    archiveSha256 = $ComponentSha256
    installedAt = [datetime]::UtcNow.ToString("o")
  } | ConvertTo-Json | Set-Content -LiteralPath $ManifestPath -Encoding UTF8
  Write-ComponentLog "Official statistics component installed successfully."
  exit 0
} catch {
  Write-ComponentLog "Official statistics component was not installed: $($_.Exception.Message)"
  exit 1
} finally {
  if ($null -ne $tempRoot -and (Test-Path -LiteralPath $tempRoot)) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}
