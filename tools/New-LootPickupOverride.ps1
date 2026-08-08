[CmdletBinding()]
param(
    [string]$SdkPath,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$sdkCandidates = @()
if ($SdkPath) { $sdkCandidates += $SdkPath }
if ($env:MAJESTYSDK) { $sdkCandidates += $env:MAJESTYSDK }
$sdkCandidates += Join-Path $repositoryRoot 'SDK'
$resolvedSdk = $sdkCandidates |
    Where-Object { Test-Path -LiteralPath $_ -PathType Container } |
    Select-Object -First 1
if (-not $resolvedSdk) {
    throw 'Majesty SDK was not found. Pass -SdkPath or set MAJESTYSDK.'
}
$resolvedSdk = (Resolve-Path -LiteralPath $resolvedSdk).Path

$pickupSource = Join-Path $resolvedSdk 'OriginalQuests\GPLMx\TaskModules\Characters\mx_collect_object.gpl'
if (-not (Test-Path -LiteralPath $pickupSource -PathType Leaf)) {
    throw "Northern Expansion pickup source was not found: $pickupSource"
}
if (-not $OutputPath) {
    $OutputPath = Join-Path $repositoryRoot 'GPL\Generated\LWS_MX_CollectObject.gpl'
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null

$lines = Get-Content -LiteralPath $pickupSource
$functionStart = -1
for ($index = 0; $index -lt $lines.Count; $index += 1) {
    if ($lines[$index] -match '^\s*function\s+collect_object_callback\s*\(\s*agent\s+thisagent\s*,\s*agent\s+target\s*\)\s*$') {
        $functionStart = $index
        break
    }
}
if ($functionStart -lt 0) {
    throw 'Could not locate collect_object_callback(thisagent, target).'
}

$depth = 0
$bodyStarted = $false
$functionEnd = -1
$firstBegin = -1
for ($index = $functionStart; $index -lt $lines.Count; $index += 1) {
    $trimmed = $lines[$index].Trim()
    if ($trimmed -match '^begin\s*$') {
        if (-not $bodyStarted) { $firstBegin = $index }
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
if ($functionEnd -lt 0 -or $firstBegin -lt 0) {
    throw 'Could not determine the pickup callback body.'
}

$callback = [System.Collections.Generic.List[string]]::new()
for ($index = $functionStart; $index -le $functionEnd; $index += 1) {
    $callback.Add($lines[$index])
}
$relativeBegin = $firstBegin - $functionStart
$injected = @(
    '',
    '    if ( $HasAttribute ( "LWS_HealingPotionDrop", target ))',
    '        begin',
    '            if ( $GetAttribute ( thisagent, #ATTRIB_NumHealingPotions ) < #Max_Heal_Potions )',
    '                $AdjustAttribute ( thisagent, #ATTRIB_NumHealingPotions, 1 );',
    '            $Give_Exp ( thisagent, #resource_exp );',
    '            $DeleteGamePiece ( target );',
    '            return;',
    '        end'
)
for ($offset = $injected.Count - 1; $offset -ge 0; $offset -= 1) {
    $callback.Insert($relativeBegin + 1, $injected[$offset])
}

$header = @(
    '// GENERATED FILE - DO NOT EDIT OR COMMIT.',
    '// Derived at build time from the locally installed Northern Expansion SDK.',
    '// Marker-tagged LWS drops grant one native healing potion; vanilla herbs remain unchanged.',
    ''
)
Set-Content -LiteralPath $OutputPath -Value ($header + $callback) -Encoding Ascii
Write-Host "Generated Northern Expansion loot pickup override at $OutputPath"
