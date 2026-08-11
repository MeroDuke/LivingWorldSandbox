$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$catalog = Get-Content -Raw (Join-Path $repositoryRoot 'Docs\legendary-catalog.json') | ConvertFrom-Json
$legendarySource = Get-Content -Raw (Join-Path $repositoryRoot 'GPL\LWS_Legendary.gpl')
$monsterStateSource = Get-Content -Raw (Join-Path $repositoryRoot 'GPL\LWS_MonsterState.gpl')
$lootSource = Get-Content -Raw (Join-Path $repositoryRoot 'GPL\LWS_Loot.gpl')
$chestSource = Get-Content -Raw (Join-Path $repositoryRoot 'GPL\LWS_Chest.gpl')
$prototypeSource = Get-Content -Raw (Join-Path $repositoryRoot 'GPL\LWS_LootPrototypes.dat')
$descriptionSource = Get-Content -Raw (Join-Path $repositoryRoot 'Data\LWS_Descriptions.xml')
$productionProject = Get-Content -Raw (Join-Path $repositoryRoot 'GPL\LivingWorldSandbox.gplproj')
$diagnosticProject = Get-Content -Raw (Join-Path $repositoryRoot 'GPL\LWS_CombatDiagnostic.gplproj')

if ([int]$catalog.dropChancePercent -ne 1 -or [int]$catalog.requiresProgressClass -ne 5) {
    throw 'Legendary catalog must use the Class 5 1% policy.'
}
if ($catalog.universalHeroPickup -ne $true -or $catalog.duplicatePerHero -ne $false -or $catalog.usesOriginalQuestItemIds -ne $false) {
    throw 'Legendary pickup, duplicate, or quest-item isolation policy is invalid.'
}
if (@($catalog.items).Count -ne 6) { throw 'The initial Legendary catalog must contain six items.' }
if (@($catalog.whitelistedSources).Count -ne 7) { throw 'The Legendary source whitelist must contain seven Unique monsters.' }

foreach ($project in @($productionProject, $diagnosticProject)) {
    if ($project -notmatch 'source="LWS_Legendary\.gpl"') { throw 'Legendary source is missing from a GPL project.' }
}
foreach ($item in $catalog.items) {
    foreach ($value in @($item.id, $item.spell, $item.marker)) {
        if ($legendarySource -notmatch [regex]::Escape($value)) { throw "Legendary runtime mapping is missing: $value" }
    }
    if ($prototypeSource -notmatch [regex]::Escape("[$($item.id)]")) { throw "Legendary prototype is missing: $($item.id)" }
    if ($descriptionSource -notmatch ('ID="' + [regex]::Escape($item.id) + '"')) { throw "Legendary description is missing: $($item.id)" }
}
foreach ($source in $catalog.whitelistedSources) {
    if ($monsterStateSource -notmatch ('Title"\s*==\s*"' + [regex]::Escape($source) + '"')) {
        throw "Legendary source marker is missing: $source"
    }
}
foreach ($pattern in @(
    'Function\s+LWS_CanReceiveLegendary',
    'Function\s+LWS_LegendaryTransfer',
    'Function\s+LWS_GrantLegendaryTitle',
    'Function\s+LWS_RandomLegendaryTitle',
    '\$HasAttribute\s*\(\s*Marker\s*,\s*Hero\s*\)',
    '\$LearnSpell',
    '\$DeleteInventoryItem'
)) {
    if ($legendarySource -notmatch $pattern) { throw "Missing Legendary behavior pattern: $pattern" }
}
if ($lootSource -notmatch 'LWS_CreateLockedMonsterChest' -or $chestSource -notmatch 'LWS_AddLockedChestSimpleReward\s*\(\s*Chest\s*,\s*Slot\s*,\s*"Legendary"') {
    throw 'Legendary roll is not connected to the locked monster chest resolver.'
}

Write-Host 'Legendary Unique catalog validation passed.'
