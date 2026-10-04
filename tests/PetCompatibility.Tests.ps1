$ErrorActionPreference = 'Stop'
$sourcePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'CodexPetUsageOverlay.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($sourcePath, [ref]$null, [ref]$null)
$definition = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) | Where-Object Name -eq 'Get-LivePetRect' | Select-Object -First 1
Invoke-Expression $definition.Extent.Text
$script:TrackedPetHwnd = [IntPtr]::Zero
$script:DesktopPresent = $true
$script:PetOpen = $true
function Get-CodexProcessIds { if ($script:DesktopPresent) { 201 } }
function Find-PetWindow { return $null }
function Get-PetRect { if ($script:PetOpen) { [PSCustomObject]@{ Left = 1346; Top = 535; Width = 118; Height = 118 } } }
if ($null -eq (Get-LivePetRect)) { throw 'Regression: open pet on newer Desktop without a small native window cannot trigger the overlay.' }
$script:PetOpen = $false
if ($null -ne (Get-LivePetRect)) { throw 'Closed pet must not trigger the overlay.' }
$script:PetOpen = $true
$script:DesktopPresent = $false
if ($null -ne (Get-LivePetRect)) { throw 'Saved open state must not trigger the overlay when Desktop is absent.' }
'PetCompatibility tests OK'
