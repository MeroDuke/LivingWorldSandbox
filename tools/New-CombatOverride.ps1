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

function Get-GplFunction {
    param([string]$Name, [string]$SignaturePattern)

    $functionStart = -1
    for ($index = 0; $index -lt $lines.Count; $index += 1) {
        if ($lines[$index] -match $SignaturePattern) {
            $functionStart = $index
            break
        }
    }
    if ($functionStart -lt 0) { throw "Could not locate Northern Expansion function: $Name" }

    $depth = 0
    $bodyStarted = $false
    $functionEnd = -1
    for ($index = $functionStart; $index -lt $lines.Count; $index += 1) {
        $trimmed = $lines[$index].Trim()
        if ($trimmed -match '^begin\s*$') { $bodyStarted = $true; $depth += 1 }
        elseif ($bodyStarted -and $trimmed -match '^end\s*$') {
            $depth -= 1
            if ($depth -eq 0) { $functionEnd = $index; break }
        }
    }
    if ($functionEnd -lt 0) { throw "Could not determine end of Northern Expansion function: $Name" }

    $result = [System.Collections.Generic.List[string]]::new()
    for ($index = $functionStart; $index -le $functionEnd; $index += 1) { $result.Add($lines[$index]) }
    return ,$result
}

function Add-CombatCreditHook {
    param([System.Collections.Generic.List[string]]$FunctionLines, [string]$Name)

    $adjustPattern = '^\s*\$adjustattribute\s*\(\s*defender\s*,\s*#ATTRIB_HP\s*,\s*-dmg\s*\)\s*;\s*$'
    $indexes = @()
    for ($index = 0; $index -lt $FunctionLines.Count; $index += 1) {
        if ($FunctionLines[$index] -match $adjustPattern) { $indexes += $index }
    }
    if ($indexes.Count -ne 1) { throw "Expected one final HP adjustment in $Name(); found $($indexes.Count)." }
    $insertionIndex = $indexes[0]
    $indent = ($FunctionLines[$insertionIndex] -replace '^(\s*).*$', '$1')
    $FunctionLines.Insert($insertionIndex, "$indent`$LWS_CombatCredit ( attacker, defender, dmg );")
}

$damageFunction = Get-GplFunction -Name 'damage' -SignaturePattern '^\s*function\s+damage\s*\(\s*agent\s+attacker\s*,\s*agent\s+defender\s*\)\s*$'
$spellDamageFunction = Get-GplFunction -Name 'spelldamage' -SignaturePattern '^\s*function\s+spelldamage\s*\(\s*agent\s+attacker\s*,\s*agent\s+defender\s*,\s*integer\s+damage\s*,\s*integer\s+damage_minimum\s*\)\s*$'
Add-CombatCreditHook -FunctionLines $damageFunction -Name 'damage'
Add-CombatCreditHook -FunctionLines $spellDamageFunction -Name 'spelldamage'

$header = @(
    '// GENERATED FILE - DO NOT EDIT OR COMMIT.',
    '// Derived at build time from the locally installed Northern Expansion SDK.',
    '// The only behavioral change is the LWS_CombatCredit hook before direct and spell HP adjustments.',
    ''
)

Set-Content -LiteralPath $OutputPath -Value ($header + $damageFunction + '' + $spellDamageFunction) -Encoding Ascii
Write-Host "Generated Northern Expansion combat override at $OutputPath"
