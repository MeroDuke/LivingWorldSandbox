[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$definitionPath = Join-Path $repositoryRoot 'LWSCombatDiagnostic.mqxml'
$hookPath = Join-Path $repositoryRoot 'GPL\LWS_CombatDiagnostics.gpl'
$generatorPath = Join-Path $repositoryRoot 'tools\New-CombatOverride.ps1'
$bytecodePath = Join-Path $repositoryRoot 'Data\LWSCombatDiagnostic.bcd'

[xml]$definition = Get-Content -LiteralPath $definitionPath -Raw
$quest = $definition.Majesty.Quest

if ($quest.Name -ne 'LWSCombatDiagnostic') {
    throw 'Diagnostic quest Name must match its GPL entry function.'
}
if ($quest.DataConfiguration.Dataset.base -ne 'MajestyExpansion') {
    throw 'Combat diagnostic must use the Northern Expansion dataset.'
}
if ($quest.DataConfiguration.Dataset.Load.GPL.Target -ne 'Data/LWSCombatDiagnostic.bcd') {
    throw 'Diagnostic quest does not load the expected bytecode target.'
}

$hookSource = Get-Content -LiteralPath $hookPath -Raw
$requiredHookPatterns = @(
    'Function\s+LWS_CombatCredit',
    'FinalDamage\s*<=\s*0',
    'original_type',
    'GetUnitPlayerNumber',
    'DefenderHP\s*>\s*FinalDamage',
    'Defender''s\s+"type"\s*==\s*"lair"',
    'Defender''s\s+"type"\s*==\s*"building"',
    'LWS_DiagnosticKills',
    'LWS_DiagnosticBuildings'
)
foreach ($pattern in $requiredHookPatterns) {
    if ($hookSource -notmatch $pattern) {
        throw "Missing diagnostic hook pattern: $pattern"
    }
}

$generatorSource = Get-Content -LiteralPath $generatorPath -Raw
if ($generatorSource -notmatch 'OriginalQuests\\GPLMx\\TaskModules\\Subtasks\\mx_make_attack\.gpl') {
    throw 'Combat override generator is not pinned to the Northern Expansion combat source.'
}
if ($generatorSource -notmatch 'LWS_CombatCredit') {
    throw 'Combat override generator does not inject the attribution hook.'
}

if (-not (Test-Path -LiteralPath $bytecodePath -PathType Leaf)) {
    throw 'Diagnostic bytecode is missing.'
}
if ((Get-Item -LiteralPath $bytecodePath).Length -eq 0) {
    throw 'Diagnostic bytecode is empty.'
}

Write-Host 'Combat diagnostic validation passed.'
