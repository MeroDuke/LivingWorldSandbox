[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$definitionPath = Join-Path $repositoryRoot 'LWSCombatDiagnostic.mqxml'
$hookPath = Join-Path $repositoryRoot 'GPL\LWS_CombatDiagnostics.gpl'
$combatPath = Join-Path $repositoryRoot 'GPL\LWS_CombatProgression.gpl'
$buildingRewardsPath = Join-Path $repositoryRoot 'GPL\LWS_BuildingRewards.gpl'
$statePath = Join-Path $repositoryRoot 'GPL\LWS_MonsterState.gpl'
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
$combatSource = Get-Content -LiteralPath $combatPath -Raw
$buildingRewardsSource = Get-Content -LiteralPath $buildingRewardsPath -Raw
$stateSource = Get-Content -LiteralPath $statePath -Raw
$requiredStatePatterns = @(
    'Function\s+LWS_EnsureMonsterState',
    'original_type',
    'LWS_StateVersion',
    'LWS_BaseMaxHP',
    'LWS_Level',
    'LWS_KillsThisLevel',
    'LWS_TotalKills',
    'LWS_BuildingsDestroyed',
    'LWS_ProgressClass',
    'LWS_Perks',
    'Function\s+LWS_ClassFromLevelXP',
    '#ATTRIB_LevelXP',
    'Function\s+LWS_KillsRequired',
    'Function\s+LWS_RecordUnitKill',
    'Function\s+LWS_ApplyLevelGrowth',
    'LWS_BaseMaxHP"\s*\*\s*5',
    '#ATTRIB_MaxHP\s*,\s*HPBonus',
    '#ATTRIB_HP\s*,\s*HPBonus',
    'NewLevel\s*%\s*3',
    'NewLevel\s*%\s*5',
    '#ATTRIB_ExperienceLevel'
)
foreach ($pattern in $requiredStatePatterns) {
    if ($stateSource -notmatch $pattern) {
        throw "Missing monster state pattern: $pattern"
    }
}
$requiredBuildingRewardPatterns = @(
    'Function\s+LWS_ProcessBuildingDestroyed',
    'ChanceRoll\s*<\s*35',
    'Function\s+LWS_ApplyBuildingPerk',
    'LWS_Perks"\s*>=\s*3',
    '#ATTRIB_armor_basic_damage',
    '#ATTRIB_MagicResistance'
)
foreach ($pattern in $requiredBuildingRewardPatterns) {
    if ($buildingRewardsSource -notmatch $pattern) {
        throw "Missing building reward pattern: $pattern"
    }
}
$requiredCombatPatterns = @(
    'Function\s+LWS_CombatCredit',
    'FinalDamage\s*<=\s*0',
    'original_type',
    'GetUnitPlayerNumber',
    'DefenderHP\s*>\s*FinalDamage',
    'Defender''s\s+"type"\s*==\s*"lair"',
    'Defender''s\s+"type"\s*==\s*"building"',
    'LWS_DiagnosticKills',
    'LWS_DiagnosticBuildings',
    'LWS_RecordUnitKill',
    'LWS_ProcessBuildingDestroyed'
)
foreach ($pattern in $requiredCombatPatterns) {
    if ($combatSource -notmatch $pattern) {
        throw "Missing combat progression pattern: $pattern"
    }
}

$requiredHookPatterns = @(
    '\$LWS_EnsureMonsterState\s*\(\s*Attacker\s*\)',
    '\$LWS_ClassFromLevelXP\s*\(\s*2001\s*\)\s*!=\s*5',
    '\$LWS_KillsRequired\s*\(\s*5\s*,\s*1\s*\)\s*!=\s*20',
    'Function\s+LWS_PrepareClassShowcase',
    '\$SpawnUnit\s*\(\s*Palace\s*,\s*"GoblinOverlord"',
    'LWS_ProcessBuildingDestroyed\s*\(\s*PerkTester\s*,\s*99\s*,\s*0\s*\)',
    'LWS_ProcessBuildingDestroyed\s*\(\s*PerkTester\s*,\s*0\s*,\s*2\s*\)',
    'OldHP\s*=\s*OldMaxHP\s*/\s*2',
    '#ATTRIB_HP\s*\)\s*==\s*\$GetAttribute\s*\(\s*Monster\s*,\s*#ATTRIB_MaxHP',
    'LWS_PrepareClassShowcase\s*\(\s*ShowcaseMonster\s*,\s*1\s*,\s*1\s*\)',
    'LWS_PrepareClassShowcase\s*\(\s*ShowcaseMonster\s*,\s*2\s*,\s*2\s*\)',
    'LWS_PrepareClassShowcase\s*\(\s*ShowcaseMonster\s*,\s*3\s*,\s*4\s*\)',
    'LWS_PrepareClassShowcase\s*\(\s*ShowcaseMonster\s*,\s*4\s*,\s*12\s*\)',
    'LWS_PrepareClassShowcase\s*\(\s*ShowcaseMonster\s*,\s*5\s*,\s*20\s*\)',
    'LWS_DiagnosticKills',
    'LWS_DiagnosticBuildings',
    'PeasantCount\s*<\s*9',
    '\$LWS_RunCombatDiagnostic\s*\(\s*AIRootAgent\s*,\s*Palace\s*\)'
)
foreach ($pattern in $requiredHookPatterns) {
    if ($hookSource -notmatch $pattern) {
        throw "Missing diagnostic hook pattern: $pattern"
    }
}
if ($hookSource -match '\$NewThread\s*\(\s*\$LWS_RunCombatDiagnostic') {
    throw 'Diagnostic callback must not be passed directly to NewThread.'
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
