$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$policy = Get-Content -Raw (Join-Path $repositoryRoot 'Docs\monster-loot-policy.json') | ConvertFrom-Json
$lootSource = Get-Content -Raw (Join-Path $repositoryRoot 'GPL\LWS_Loot.gpl')
$combatSource = Get-Content -Raw (Join-Path $repositoryRoot 'GPL\LWS_CombatProgression.gpl')

if ([int]$policy.worldDropLimitPerMonster -ne 2) {
    throw 'Monster world-drop limit must be exactly two.'
}
if ($policy.monsterLevelCanChangeRarityCeiling -ne $false) {
    throw 'Monster level must not change its progression-class rarity ceiling.'
}
if ($policy.dropChancesDefined -ne $true) {
    throw 'Drop chances must be defined.'
}
foreach ($channel in @('HealingPotion', 'Weapon', 'Armor')) {
    if ([int]$policy.dropChances.$channel -ne 8) {
        throw "$channel drop chance must be 8%."
    }
}

$expected = @(
    @{ Class = 0; Min = 'None'; Max = 'None'; Epic = $false },
    @{ Class = 1; Min = 'Common'; Max = 'Common'; Epic = $false },
    @{ Class = 2; Min = 'Common'; Max = 'Uncommon'; Epic = $false },
    @{ Class = 3; Min = 'Uncommon'; Max = 'Rare'; Epic = $false },
    @{ Class = 4; Min = 'Rare'; Max = 'Epic'; Epic = $false },
    @{ Class = 5; Min = 'Epic'; Max = 'Legendary'; Epic = $true }
)
foreach ($row in $expected) {
    $actual = @($policy.progressClasses | Where-Object { [int]$_.class -eq $row.Class })
    if ($actual.Count -ne 1 -or $actual[0].minRarity -ne $row.Min -or $actual[0].maxRarity -ne $row.Max -or $actual[0].guaranteedEpic -ne $row.Epic) {
        throw "Unexpected loot policy for progression class $($row.Class)."
    }
}
if ($policy.legendary.requiresProgressClass -ne 5 -or $policy.legendary.requiresExplicitSourceWhitelist -ne $true) {
    throw 'Legendary loot must require Class 5 and explicit source whitelisting.'
}
if ($policy.class5GuaranteedEquipmentCandidate -ne $true -or $policy.legendaryReplacesGuaranteedEpic -ne $true) {
    throw 'Class 5 must guarantee one equipment candidate and replace it on Legendary success.'
}
$expectedDistribution = @{
    class1 = @{ Common = 100 }
    class2 = @{ Common = 75; Uncommon = 25 }
    class3 = @{ Uncommon = 75; Rare = 25 }
    class4 = @{ Rare = 75; Epic = 25 }
    class5 = @{ Epic = 99; Legendary = 1 }
}
foreach ($className in $expectedDistribution.Keys) {
    $actualDistribution = $policy.rarityDistributionOnSuccessfulEquipmentDrop.$className
    foreach ($rarity in $expectedDistribution[$className].Keys) {
        if ([int]$actualDistribution.$rarity -ne $expectedDistribution[$className][$rarity]) {
            throw "Unexpected $className $rarity distribution."
        }
    }
}
foreach ($requiredType in @('HealingPotion', 'Weapon', 'Armor', 'FutureConsumable', 'FutureSpecialItem', 'LegendaryUnique')) {
    if ($requiredType -notin @($policy.slotItemTypes)) {
        throw "Missing extensible loot slot type: $requiredType"
    }
}

$requiredPatterns = @(
    'Function\s+LWS_ResolveMonsterLoot',
    'Function\s+LWS_SpawnLootItem',
    'LWS_LootSlotsUsed"\s*>=\s*2',
    'Defender''s\s+"LWS_LootSlotsUsed"\s*\+=\s*1',
    'Function\s+LWS_LootMinimumRarity',
    'Function\s+LWS_LootMaximumRarity',
    'Function\s+LWS_LootGuaranteesEpic',
    'Function\s+LWS_OptionalLootDropSucceeds',
    'Function\s+LWS_EquipmentDropSucceeds',
    'Function\s+LWS_SelectLootRarity',
    'RarityRoll\s*<\s*75',
    'RarityRoll\s*<\s*1',
    'Function\s+LWS_IsLegendaryLootSource',
    'LWS_LegendaryLootSource'
)
foreach ($pattern in $requiredPatterns) {
    if ($lootSource -notmatch $pattern) {
        throw "Missing central loot policy pattern: $pattern"
    }
}
if (($combatSource | Select-String -Pattern 'LWS_ResolveMonsterLoot' -AllMatches).Matches.Count -ne 1) {
    throw 'Combat fatal-hit pipeline must call exactly one central loot resolver.'
}
if ($lootSource -match 'LWS_ArmorLootResolved|LWS_EquipmentLootResolved') {
    throw 'Independent item-type resolver flags would bypass the shared two-slot cap.'
}

Write-Host 'Central monster loot policy validation passed.'
