[CmdletBinding()]
param([string]$SdkPath, [string]$OutputPath)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$sdkCandidates = @($SdkPath, $env:MAJESTYSDK, (Join-Path $repositoryRoot 'SDK')) | Where-Object { $_ }
$resolvedSdk = $sdkCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Container } | Select-Object -First 1
if (-not $resolvedSdk) { throw 'Majesty SDK was not found. Pass -SdkPath or set MAJESTYSDK.' }
$sourcePath = Join-Path $resolvedSdk 'OriginalQuests\GPLMx\TaskModules\Buildings\mx_Treasure.gpl'
if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "Northern Expansion treasure source was not found: $sourcePath" }
if (-not $OutputPath) { $OutputPath = Join-Path $repositoryRoot 'GPL\Generated\LWS_MX_Treasure.gpl' }

$source = Get-Content -LiteralPath $sourcePath -Raw
$needle = 'Begin' + "`r`n" + "`tChest_Gold = `$GetAttribute (Chest, #ATTRIB_Gold);"
$replacement = 'Begin' + "`r`n" + "`t`$LWS_OpenExplorationChest (ThisAgent, Chest);" + "`r`n`r`n" + "`tChest_Gold = `$GetAttribute (Chest, #ATTRIB_Gold);"
if ([regex]::Matches($source, [regex]::Escape($needle)).Count -ne 1) { throw 'Could not locate unique Open_Chest reward point.' }
$source = $source.Replace($needle, $replacement)

$header = @('// GENERATED FILE - DO NOT EDIT OR COMMIT.', '// Derived from the read-only Northern Expansion SDK.', '// LWS change: resolve locked exploration-chest rewards before native gold/XP cleanup.', '')
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null
Set-Content -LiteralPath $OutputPath -Value (($header -join "`r`n") + "`r`n" + $source) -Encoding Ascii
Write-Host "Generated Northern Expansion treasure override at $OutputPath"
