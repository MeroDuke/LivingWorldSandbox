[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$chestSource = Get-Content -Raw (Join-Path $repositoryRoot 'GPL\LWS_Chest.gpl')
$lootSource = Get-Content -Raw (Join-Path $repositoryRoot 'GPL\LWS_Loot.gpl')
$diagnosticSource = Get-Content -Raw (Join-Path $repositoryRoot 'GPL\LWS_CombatDiagnostics.gpl')
$buildSource = Get-Content -Raw (Join-Path $repositoryRoot 'tools\Build-Quest.ps1')
$bootstrapSource = Get-Content -Raw (Join-Path $repositoryRoot 'GPL\LivingWorldSandbox.gpl')
$generatorSource = Get-Content -Raw (Join-Path $repositoryRoot 'tools\New-TreasureOverride.ps1')

$requiredChestPatterns = @(
    'Function\s+LWS_ConfigureExplorationChest',
    'Function\s+LWS_CreateLockedMonsterChest',
    'Function\s+LWS_OpenExplorationChest',
    'Function\s+LWS_GrantChestSlot',
    'Function\s+LWS_TryGrantHealingPotion',
    'Function\s+LWS_GrantDefaultChestFallback',
    'LWS_ApplyLockedWeaponReward\s*\([^;]+\)\s*==\s*FALSE[^}]+LWS_GrantDefaultChestFallback',
    'LWS_ApplyLockedArmorReward\s*\([^;]+\)\s*==\s*FALSE[^}]+LWS_GrantDefaultChestFallback',
    'LWS_LegendaryMarker[^}]+LWS_GrantDefaultChestFallback',
    'LWS_ChestRewardCount',
    'if\s*\(\s*RewardCount\s*>\s*2\s*\)\s*RewardCount\s*=\s*2',
    'LWS_HeroWeaponFamily',
    'LWS_HeroArmorFamily'
)
foreach ($pattern in $requiredChestPatterns) {
    if ($chestSource -notmatch $pattern) { throw "Missing exploration chest pattern: $pattern" }
}

if ($lootSource -notmatch 'LWS_CreateLockedMonsterChest') {
    throw 'Monster rewards are not packaged into a locked chest.'
}
if ($lootSource -match '\$LWS_SpawnRandomEquipment\s*\(\s*Defender') {
    throw 'The fatal-hit resolver still spawns concrete equipment directly.'
}
if ($generatorSource -notmatch 'LWS_OpenExplorationChest') {
    throw 'Native Open_Chest override does not call the LWS chest resolver.'
}
if ($buildSource -notmatch 'New-TreasureOverride\.ps1') {
    throw 'Production build does not generate the read-only SDK treasure override.'
}
if ($bootstrapSource -notmatch 'LWS_SeedExplorationChests\s*\(\s*Palace\s*\)') {
    throw 'Production bootstrap does not seed exploration chests.'
}
if ($bootstrapSource -notmatch 'ChestCount\s*<\s*12' -or
    $bootstrapSource -notmatch 'ChestCount\s*<\s*8' -or
    $bootstrapSource -notmatch 'FarthestDistance\s*\*\s*3') {
    throw 'Production exploration chest count, 8/4 class split, or outer-quarter distance rule is missing.'
}
if ($chestSource -notmatch '#chest_starting_gold\s*\+\s*\$RandomNumber\s*\(\s*#chest_random_gold\s*\)') {
    throw 'Full-potion fallback does not use the native 50-149 chest gold formula.'
}
if ($diagnosticSource -notmatch 'Function\s+LWS_SetupChestRewardArena' -or
    $diagnosticSource -notmatch '"Potion"' -or
    $diagnosticSource -notmatch '"Legendary"' -or
    $diagnosticSource -notmatch '"Weapon"') {
    throw 'Temporary focused chest reward arena is missing.'
}

Write-Host 'Exploration chest validation passed.'
