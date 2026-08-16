param(
  [string]$InnoSetupCompiler
)

$ErrorActionPreference = "Stop"
$projectDir = Split-Path -Parent $PSCommandPath
$definition = Join-Path $projectDir "installer\CodexPetUsageOverlay.iss"
$componentInstaller = Join-Path $projectDir "Install-OfficialStats.ps1"
$definitionText = Get-Content -LiteralPath $definition -Raw
if ($definitionText -notmatch '#define\s+MyAppVersion\s+"([^"]+)"') { throw "Installer version was not found." }
$appVersion = [regex]::Match($definitionText, '#define\s+MyAppVersion\s+"([^"]+)"').Groups[1].Value

$componentText = Get-Content -LiteralPath $componentInstaller -Raw
if ($componentText -notmatch '\$ComponentUrl\s*=\s*"([^"]+)"' -or $componentText -notmatch '\$ComponentSha256\s*=\s*"([0-9a-f]{64})"') {
  throw "Official statistics component metadata is missing a pinned OpenAI release URL or SHA-256 digest."
}
$componentUrl = [regex]::Match($componentText, '\$ComponentUrl\s*=\s*"([^"]+)"').Groups[1].Value
$componentSha256 = [regex]::Match($componentText, '\$ComponentSha256\s*=\s*"([0-9a-f]{64})"').Groups[1].Value
$vendorDir = Join-Path $projectDir "vendor"
$componentArchive = Join-Path $vendorDir "codex-app-server-x86_64-pc-windows-msvc.exe.zip"

if ([string]::IsNullOrWhiteSpace($InnoSetupCompiler)) {
  $candidates = @(
    (Join-Path $env:LOCALAPPDATA "Programs\Inno Setup 6\ISCC.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"),
    (Join-Path $env:ProgramFiles "Inno Setup 6\ISCC.exe")
  )
  $InnoSetupCompiler = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

if ([string]::IsNullOrWhiteSpace($InnoSetupCompiler) -or -not (Test-Path -LiteralPath $InnoSetupCompiler)) {
  throw "Inno Setup 6 was not found. Install it, then run this script again."
}

if (-not (Test-Path -LiteralPath $vendorDir)) { New-Item -ItemType Directory -Path $vendorDir -Force | Out-Null }
$archiveValid = $false
if (Test-Path -LiteralPath $componentArchive) {
  $archiveValid = (Get-FileHash -LiteralPath $componentArchive -Algorithm SHA256).Hash.ToLowerInvariant() -eq $componentSha256
}
if (-not $archiveValid) {
  Write-Output "Downloading pinned official statistics component for the Full installer..."
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $client = New-Object System.Net.WebClient
  try { $client.DownloadFile($componentUrl, $componentArchive) } finally { $client.Dispose() }
  if ((Get-FileHash -LiteralPath $componentArchive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $componentSha256) {
    throw "Downloaded Full-installer component failed SHA-256 verification."
  }
}

& $InnoSetupCompiler $definition
if ($LASTEXITCODE -ne 0) { throw "Lite installer compilation failed with exit code $LASTEXITCODE." }

& $InnoSetupCompiler "/DFullBuild=1" $definition
if ($LASTEXITCODE -ne 0) { throw "Full installer compilation failed with exit code $LASTEXITCODE." }

@(
  (Join-Path $projectDir "dist\CodexUsageRemaining-Setup-$appVersion.exe"),
  (Join-Path $projectDir "dist\CodexUsageRemaining-WebSetup-$appVersion.exe")
) | Where-Object { Test-Path -LiteralPath $_ }
