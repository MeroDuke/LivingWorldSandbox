[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$definitionPath = Join-Path $repositoryRoot 'LWSCombatDiagnostic.mqxml'
$hookPath = Join-Path $repositoryRoot 'GPL\LWS_CombatDiagnostics.gpl'
$combatPath = Join-Path $repositoryRoot 'GPL\LWS_CombatProgression.gpl'
$buildingRewardsPath = Join-Path $repositoryRoot 'GPL\LWS_BuildingRewards.gpl'
$lootPath = Join-Path $repositoryRoot 'GPL\LWS_Loot.gpl'
$equipmentPath = Join-Path $repositoryRoot 'GPL\LWS_Equipment.gpl'
$lootPrototypePath = Join-Path $repositoryRoot 'GPL\LWS_LootPrototypes.dat'
$descriptionPath = Join-Path $repositoryRoot 'Data\LWS_Descriptions.xml'
$statePath = Join-Path $repositoryRoot 'GPL\LWS_MonsterState.gpl'
$generatorPath = Join-Path $repositoryRoot 'tools\New-CombatOverride.ps1'
$itemGeneratorPath = Join-Path $repositoryRoot 'tools\New-ItemEvaluationOverride.ps1'
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
$lootSource = Get-Content -LiteralPath $lootPath -Raw
$equipmentSource = Get-Content -LiteralPath $equipmentPath -Raw
$lootPrototypeSource = Get-Content -LiteralPath $lootPrototypePath -Raw
$descriptionSource = Get-Content -LiteralPath $descriptionPath -Raw
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
$requiredLootPatterns = @(
    'Function\s+LWS_TryHealingPotionDrop',
    'Function\s+LWS_HealingPotion_Birth',
    'Function\s+LWS_HealingPotion_Transfer',
    'LWS_LootResolved',
    'ChanceRoll\s*>=\s*8',
    '\$AdjustAttribute\s*\(\s*NewOwnerAgent\s*,\s*#ATTRIB_NumHealingPotions\s*,\s*1',
    '\$DeleteInventoryItem\s*\(\s*AttributeID\s*,\s*NewOwnerAgent',
    '\$SpawnUnit\s*\(\s*Defender\s*,\s*"LWS_HealingPotion"[^;]+"Override"[^;]+\$MakeInventoryAttribute\s*\(\s*"LWS_HealingPotion"',
    'Function\s+LWS_TryDiagnosticWeaponDrop',
    'LWS_DiagnosticWeaponDropChance',
    'LWS_T2_Longsword_Plus5',
    'LWS_T2_Longsword_Plus7'
)
foreach ($pattern in $requiredLootPatterns) {
    if ($lootSource -notmatch $pattern) {
        throw "Missing healing potion loot pattern: $pattern"
    }
}
if ($lootSource -match 'Resource_Healplant|healing_herbs') {
    throw 'Healing potion loot must not use the healer herb resource.'
}
if ($lootPrototypeSource -notmatch '\[LWS_HealingPotion\]' -or $lootPrototypeSource -notmatch 'Special_Item') {
    throw 'Healing potion special-item prototype is missing.'
}
if ($descriptionSource -notmatch 'ID="LWS_HealingPotion"' -or $descriptionSource -notmatch 'IsInventoryItem') {
    throw 'Healing potion unit description is missing or is not an inventory item.'
}
$requiredEquipmentPatterns = @(
    'Function\s+LWS_WeaponTierBaseBonus',
    'Function\s+LWS_WeaponEffectiveBonus',
    'Function\s+LWS_ShouldRetrieveWeapon',
    'Function\s+LWS_SelectDesiredSpecialItem',
    'Function\s+LWS_EquipWeaponTransfer',
    'LWS_WeaponTier',
    'LWS_WeaponAffixBonus',
    'Function\s+BlackSmith_Check',
    'Function\s+Obtain_Upgrade',
    'Tier\s*==\s*2[^}]+Tier\s*=\s*3',
    'Tier\s*==\s*3[^}]+Tier\s*=\s*4',
    '#ATTRIB_Weapon_Struct_Bonus\s*,\s*\$LWS_WeaponEffectiveBonus\s*\(\s*Tier\s*,\s*AffixBonus'
)
foreach ($pattern in $requiredEquipmentPatterns) {
    if ($equipmentSource -notmatch $pattern) {
        throw "Missing tiered equipment pattern: $pattern"
    }
}
foreach ($itemName in @('LWS_T2_Longsword_Plus5', 'LWS_T2_Longsword_Plus6', 'LWS_T2_Longsword_Plus7')) {
    if ($lootPrototypeSource -notmatch [regex]::Escape("[$itemName]") -or $descriptionSource -notmatch ('ID="' + [regex]::Escape($itemName) + '"')) {
        throw "Tiered weapon item is incomplete: $itemName"
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
    'LWS_ProcessBuildingDestroyed',
    'LWS_TryHealingPotionDrop',
    'LWS_TryDiagnosticWeaponDrop'
)
foreach ($pattern in $requiredCombatPatterns) {
    if ($combatSource -notmatch $pattern) {
        throw "Missing combat progression pattern: $pattern"
    }
}

$requiredHookPatterns = @(
    'Function\s+LWS_EnsurePalacePeasantSpawner',
    'Palace''s\s+"num_peasants"\s*=\s*\$ListSize',
    '\$RunThread\s*\(\s*Palace''s\s+"peasant_spawn"',
    '\$LWS_EnsureMonsterState\s*\(\s*Attacker\s*\)',
    '\$LWS_ClassFromLevelXP\s*\(\s*2001\s*\)\s*!=\s*5',
    '\$LWS_KillsRequired\s*\(\s*5\s*,\s*1\s*\)\s*!=\s*20',
    'Function\s+LWS_PrepareClassShowcase',
    'Function\s+LWS_RunLootDiagnostic',
    'Function\s+LWS_RunSpellAttributionDiagnostic',
    '\$spelldamage\s*\(\s*SpellMonster\s*,\s*EnemyTarget\s*,\s*1\s*,\s*1\s*\)',
    '\$spelldamage\s*\(\s*SpellMonster\s*,\s*FriendlyTarget\s*,\s*1\s*,\s*1\s*\)',
    'RequiredKills\s*=\s*\$LWS_KillsRequired',
    'SpellMonster''s\s+"LWS_Level"\s*!=\s*2',
    'LWS_TryHealingPotionDrop\s*\(\s*NoDropVictim\s*,\s*1\s*,\s*99\s*\)',
    'LWS_TryHealingPotionDrop\s*\(\s*DropVictim\s*,\s*1\s*,\s*0\s*\)',
    'Function\s+LWS_SetupEquipmentArena',
    '\$SpawnUnit\s*\(\s*Palace\s*,\s*"Warriors_Guild"',
    '\$SpawnUnit\s*\(\s*WarriorsGuild\s*,\s*"Paladin"',
    '\$SpawnUnit\s*\(\s*Palace\s*,\s*"Blacksmith3"',
    '#ATTRIB_ResearchArmorLevel_2\s*,\s*0',
    '#ATTRIB_ResearchArmorLevel_3\s*,\s*0',
    '#ATTRIB_ResearchArmorLevel_4\s*,\s*0',
    '#ATTRIB_ResearchWeaponLevel_2\s*,\s*0',
    '#ATTRIB_ResearchWeaponLevel_3\s*,\s*0',
    '#ATTRIB_ResearchWeaponLevel_4\s*,\s*0',
    '\$Adopt\s*\(\s*WarriorsGuild\s*,\s*Paladin\s*\)',
    '\$Advance_To_Level\s*\(\s*Paladin\s*,\s*8\s*\)',
    '#ATTRIB_Gold\s*,\s*1000',
    '#ATTRIB_StoredGold\s*,\s*1000',
    'Upgrade_Weapon_Chance"\s*=\s*100',
    '\$SpawnUnit\s*\(\s*Paladin\s*,\s*"LWS_T2_Longsword_Plus6"[^;]+"Override"[^;]+\$MakeInventoryAttribute\s*\(\s*"LWS_T2_Longsword_Plus6"',
    'LWS_DiagnosticWeaponDropChance"\s*,\s*"integer"\s*,\s*50',
    '\$IsValidGamePiece\s*\(\s*ShowcaseMonster\s*\)',
    '#ATTRIB_NumHealingPotions\s*\)\s*!=\s*\(\s*PotionsBefore\s*\+\s*1',
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
    'LairTarget''s\s+"Has_Special_Spawn"\s*=\s*TRUE',
    'LairTarget''s\s+"Special_Spawn_Type"\s*=\s*"xx"',
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
if ($hookSource -match 'EnemyCount\s*<|PotionCount\s*<|PeasantCount\s*<') {
    throw 'Legacy crowd and potion arena setup must remain removed.'
}
if ($hookSource -match '\$SpawnUnit\s*\([^;]+"Peasant"') {
    throw 'Diagnostic checks must not spawn real Palace peasants.'
}
if ($hookSource -match '\$ListObjects\s*\(\s*Palace\s*,\s*"Monster"\s*,\s*1200') {
    throw 'Diagnostic cleanup must not broadly delete Palace-area monsters or workers.'
}

$generatorSource = Get-Content -LiteralPath $generatorPath -Raw
if ($generatorSource -notmatch 'OriginalQuests\\GPLMx\\TaskModules\\Subtasks\\mx_make_attack\.gpl') {
    throw 'Combat override generator is not pinned to the Northern Expansion combat source.'
}
if ($generatorSource -notmatch 'LWS_CombatCredit') {
    throw 'Combat override generator does not inject the attribution hook.'
}
if ($generatorSource -notmatch "Name 'spelldamage'" -or $generatorSource -notmatch 'spellDamageFunction') {
    throw 'Combat override generator does not include direct spell damage attribution.'
}

$itemGeneratorSource = Get-Content -LiteralPath $itemGeneratorPath -Raw
if ($itemGeneratorSource -notmatch 'OriginalQuests\\GPLMx\\DecisionTrees\\Modules\\mx_Eval_Items\.gpl') {
    throw 'Item evaluation override generator is not pinned to the Northern Expansion source.'
}
if ($itemGeneratorSource -notmatch 'LWS_HealingPotion' -or $itemGeneratorSource -notmatch '#Max_Heal_Potions') {
    throw 'Item evaluation override does not protect the vanilla healing potion cap.'
}
if ($itemGeneratorSource -notmatch 'LWS_SelectDesiredSpecialItem' -or $itemGeneratorSource -notmatch 'LWS_ShouldRetrieveWeapon') {
    throw 'Item evaluation override does not filter inferior tiered equipment.'
}

if (-not (Test-Path -LiteralPath $bytecodePath -PathType Leaf)) {
    throw 'Diagnostic bytecode is missing.'
}
if ((Get-Item -LiteralPath $bytecodePath).Length -eq 0) {
    throw 'Diagnostic bytecode is empty.'
}

Write-Host 'Combat diagnostic validation passed.'
