[CmdletBinding()]
param(
    [string]$SdkPath,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot

$sdkCandidates = @()
if ($SdkPath) {
    $sdkCandidates += $SdkPath
}
if ($env:MAJESTYSDK) {
    $sdkCandidates += $env:MAJESTYSDK
}
$sdkCandidates += Join-Path $repositoryRoot 'SDK'

$resolvedSdk = $sdkCandidates |
    Where-Object { Test-Path -LiteralPath $_ -PathType Container } |
    Select-Object -First 1

if (-not $resolvedSdk) {
    throw 'Majesty SDK was not found. Pass -SdkPath or set MAJESTYSDK.'
}
$resolvedSdk = (Resolve-Path -LiteralPath $resolvedSdk).Path

$expansionCombatSource = Join-Path $resolvedSdk 'OriginalQuests\GPLMx\TaskModules\Subtasks\mx_make_attack.gpl'
if (-not (Test-Path -LiteralPath $expansionCombatSource -PathType Leaf)) {
    throw "Northern Expansion combat source was not found: $expansionCombatSource"
}

if (-not $OutputPath) {
    $OutputPath = Join-Path $repositoryRoot 'GPL\Generated\LWS_MX_Damage.gpl'
}
$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

$lines = Get-Content -LiteralPath $expansionCombatSource
$functionStart = -1
for ($index = 0; $index -lt $lines.Count; $index += 1) {
    if ($lines[$index] -match '^\s*function\s+damage\s*\(\s*agent\s+attacker\s*,\s*agent\s+defender\s*\)\s*$') {
        $functionStart = $index
        break
    }
}
if ($functionStart -lt 0) {
    throw 'Could not locate the Northern Expansion damage(attacker, defender) function.'
}

$depth = 0
$bodyStarted = $false
$functionEnd = -1
for ($index = $functionStart; $index -lt $lines.Count; $index += 1) {
    $trimmed = $lines[$index].Trim()
    if ($trimmed -match '^begin\s*$') {
        $bodyStarted = $true
        $depth += 1
    }
    elseif ($bodyStarted -and $trimmed -match '^end\s*$') {
        $depth -= 1
        if ($depth -eq 0) {
            $functionEnd = $index
            break
        }
    }
}
if ($functionEnd -lt 0) {
    throw 'Could not determine the end of the Northern Expansion damage function.'
}

$damageFunction = [System.Collections.Generic.List[string]]::new()
for ($index = $functionStart; $index -le $functionEnd; $index += 1) {
    $damageFunction.Add($lines[$index])
}

$adjustPattern = '^\s*\$adjustattribute\s*\(\s*defender\s*,\s*#ATTRIB_HP\s*,\s*-dmg\s*\)\s*;\s*$'
$insertionIndexes = @()
for ($index = 0; $index -lt $damageFunction.Count; $index += 1) {
    if ($damageFunction[$index] -match $adjustPattern) {
        $insertionIndexes += $index
    }
}
if ($insertionIndexes.Count -ne 1) {
    throw "Expected one final HP adjustment in damage(); found $($insertionIndexes.Count)."
}

$insertionIndex = $insertionIndexes[0]
$indent = ($damageFunction[$insertionIndex] -replace '^(\s*).*$', '$1')
$damageFunction.Insert($insertionIndex, "$indent`$LWS_CombatCredit ( attacker, defender, dmg );")

$header = @(
    '// GENERATED FILE - DO NOT EDIT OR COMMIT.',
    '// Derived at build time from the locally installed Northern Expansion SDK.',
    '// The only behavioral change is the LWS_CombatCredit hook before final HP adjustment.',
    ''
)

Set-Content -LiteralPath $OutputPath -Value ($header + $damageFunction) -Encoding Ascii
Write-Host "Generated Northern Expansion combat override at $OutputPath"
