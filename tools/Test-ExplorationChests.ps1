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
if ($bootstrapSource -notmatch 'Function\s+LWS_SeedExplorationChests' -or $bootstrapSource -notmatch 'ChestCount\s*<\s*3') {
    throw 'Production bootstrap must seed exactly three random exploration chests.'
}

foreach ($chestClass in 1..5) {
    if ($diagnosticSource -notmatch ('LWS_SpawnExplorationChest\s*\([^\r\n]+,\s*' + $chestClass + '\s*,')) {
        throw "Diagnostic arena is missing exploration chest class $chestClass."
    }
}
if (($diagnosticSource | Select-String -Pattern '\$RandomCoord\s*\(\s*Palace\s*,\s*180\s*,\s*320\s*\)' -AllMatches).Matches.Count -ne 5) {
    throw 'All five diagnostic chests must spawn visibly around the Palace.'
}

Write-Host 'Exploration chest validation passed.'
