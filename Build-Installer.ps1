param(
  [string]$InnoSetupCompiler
)

$ErrorActionPreference = "Stop"
$projectDir = Split-Path -Parent $PSCommandPath
$definition = Join-Path $projectDir "installer\CodexPetUsageOverlay.iss"

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

& $InnoSetupCompiler $definition
if ($LASTEXITCODE -ne 0) { throw "Inno Setup compilation failed with exit code $LASTEXITCODE." }

Get-ChildItem (Join-Path $projectDir "dist") -Filter "CodexUsageRemaining-Setup-*.exe" |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1 -ExpandProperty FullName
