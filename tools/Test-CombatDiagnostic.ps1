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
$equipmentDescriptionPath = Join-Path $repositoryRoot 'Data\LWS_EquipmentDropDescriptions.xml'
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
[xml]$descriptionXml = Get-Content -LiteralPath $equipmentDescriptionPath -Raw
foreach ($itemId in @('LWSDW_U_Longsword_3_1', 'LWSDA_R_Plate_3_1')) {
    $itemDescription = @($descriptionXml.Majesty.Description | Where-Object { $_.ID -eq $itemId })
    if ($itemDescription.Count -ne 1 -or $itemDescription[0].Name -ne $itemId) {
        throw "Custom item Description must repeat its prototype ID in Name: $itemId"
    }
}
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
    'Function\s+LWS_ResolveMonsterLoot',
    'Function\s+LWS_SpawnLootItem',
    'Function\s+LWS_LootMinimumRarity',
    'Function\s+LWS_LootMaximumRarity',
    'Function\s+LWS_LootGuaranteesEpic',
    'Function\s+LWS_IsLegendaryLootSource',
    'Function\s+LWS_HealingPotion_Birth',
    'Function\s+LWS_HealingPotion_Transfer',
    'LWS_LootResolved',
    'LWS_LootSlotsUsed"\s*>=\s*2',
    'ChanceRoll\s*<\s*8',
    '\$AdjustAttribute\s*\(\s*NewOwnerAgent\s*,\s*#ATTRIB_NumHealingPotions\s*,\s*1',
    '\$DeleteInventoryItem\s*\(\s*AttributeID\s*,\s*NewOwnerAgent',
    '\$SpawnUnit\s*\(\s*Defender\s*,\s*DropTitle[^;]+"Override"[^;]+\$MakeInventoryAttribute\s*\(\s*DropTitle',
    'Function\s+LWS_TryDiagnosticWeaponSlot',
    'LWS_DiagnosticWeaponDropChance',
    'LWS_T2_Longsword_Plus6',
    'Function\s+LWS_TryDiagnosticArmorSlot',
    'LWS_DiagnosticArmorDropChance',
    'LWS_T2_Armor_Plus6'
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
    'Function\s+LWS_ArmorTierBaseBonus',
    'Function\s+LWS_ArmorEffectiveBonus',
    'Function\s+LWS_HeroWeaponFamily',
    'Function\s+LWS_HeroArmorFamily',
    'Function\s+LWS_IsEquipmentCompatible',
    'Function\s+LWS_ShouldRetrieveWeapon',
    'Function\s+LWS_ShouldRetrieveArmor',
    'Function\s+LWS_ShouldRetrieveEquipment',
    'Function\s+LWS_SelectDesiredSpecialItem',
    'Function\s+LWS_EquipWeaponTransfer',
    'LWS_WeaponTier',
    'LWS_WeaponAffixBonus',
    'LWS_WeaponBaseDamage',
    'LWS_ArmorTier',
    'LWS_ArmorAffixBonus',
    'LWS_ArmorEnchantBonus',
    'LWS_EquipmentFamily',
    'Function\s+BlackSmith_Check',
    'Function\s+Obtain_Upgrade',
    'Function\s+LWS_ExperimentalWizGuildCheck',
    'Function\s+LWS_ExperimentalObtainEnchantment',
    'Function\s+LWS_SyncArmorMagicBonus',
    'Tier\s*==\s*2[^}]+Tier\s*=\s*3',
    'Tier\s*==\s*3[^}]+Tier\s*=\s*4',
    '#ATTRIB_Weapon_Struct_Bonus\s*,\s*\$LWS_WeaponTierBaseBonus\s*\(\s*Tier',
    '#ATTRIB_Weapon_Basic_Damage\s*,\s*ThisAgent''s\s+"LWS_WeaponBaseDamage"\s*\+\s*AffixBonus',
    '#ATTRIB_Armor_Struct_Bonus\s*,\s*\$LWS_ArmorTierBaseBonus\s*\(\s*Tier',
    'Hero''s\s+"LWS_ArmorAffixBonus"\s*\+\s*Hero''s\s+"LWS_ArmorEnchantBonus"'
)
foreach ($pattern in $requiredEquipmentPatterns) {
    if ($equipmentSource -notmatch $pattern) {
        throw "Missing tiered equipment pattern: $pattern"
    }
}
foreach ($itemName in @('LWS_T2_Longsword_Plus6', 'LWS_T3_Longsword_Plus1')) {
    if ($lootPrototypeSource -notmatch [regex]::Escape("[$itemName]") -or $descriptionSource -notmatch ('ID="' + [regex]::Escape($itemName) + '"')) {
        throw "Tiered weapon item is incomplete: $itemName"
    }
}
foreach ($itemName in @('LWS_T2_Armor_Plus6', 'LWS_T3_Armor_Plus1')) {
    if ($lootPrototypeSource -notmatch [regex]::Escape("[$itemName]") -or $descriptionSource -notmatch ('ID="' + [regex]::Escape($itemName) + '"')) {
        throw "Tiered armor item is incomplete: $itemName"
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
    'LWS_ResolveMonsterLoot'
)
foreach ($pattern in $requiredCombatPatterns) {
    if ($combatSource -notmatch $pattern) {
        throw "Missing combat progression pattern: $pattern"
    }
}

$requiredHookPatterns = @(
    'Function\s+LWS_RunTwoSlotDiagnostic',
    'LWS_RandomWeaponFamily\s*\(\s*8\s*\)\s*!=\s*"Hammer"',
    'LWS_RandomArmorFamily\s*\(\s*3\s*\)\s*!=\s*"Chaos"',
    'LWS_StaticEquipmentDropTitle\s*\(\s*"Weapon"\s*,\s*"Longsword"\s*,\s*1\s*,\s*7\s*\)\s*!=\s*"LWSDW_E_Longsword_1_7"',
    'LWS_StaticEquipmentDropTitle\s*\(\s*"Armor"\s*,\s*"Plate"\s*,\s*3\s*,\s*1\s*\)\s*!=\s*"LWSDA_R_Plate_3_1"',
    'LWS_RandomLegendaryTitle\s*\(\s*5\s*\)\s*!=\s*"LWS_StonebacksShield"',
    'LWS_LootSlotsUsed"\s*!=\s*2',
    'LWSDA_R_Plate_3_1',
    'LWS_WandOfImmolation',
    'Function\s+LWS_EnsurePalacePeasantSpawner',
    'Palace''s\s+"num_peasants"\s*=\s*\$ListSize',
    '\$RunThread\s*\(\s*Palace''s\s+"peasant_spawn"',
    '\$LWS_EnsureMonsterState\s*\(\s*Attacker\s*\)',
    '\$LWS_ClassFromLevelXP\s*\(\s*2001\s*\)\s*!=\s*5',
    '\$LWS_KillsRequired\s*\(\s*5\s*,\s*1\s*\)\s*!=\s*20',
    'Function\s+LWS_PrepareClassShowcase',
    'Function\s+LWS_RunLootDiagnostic',
    'Function\s+LWS_RunSpellAttributionDiagnostic',
    'Function\s+LWS_SetupWizardEnchantArena',
    '\$SpawnUnit\s*\(\s*Palace\s*,\s*"Wizards_Guild3"',
    '\$SpawnUnit\s*\(\s*WarriorsGuild\s*,\s*"Paladin"',
    '#ATTRIB_StoredGold\s*,\s*1000',
    '#ATTRIB_Intelligence\s*,\s*31',
    '#ATTRIB_Weapon_Magic_Bonus\s*,\s*3',
    'Paladin''s\s+"LWS_ArmorTier"\s*=\s*3',
    'Paladin''s\s+"LWS_ArmorAffixBonus"\s*=\s*0',
    'Paladin''s\s+"LWS_ArmorEnchantBonus"\s*=\s*0',
    'Paladin''s\s+"Upgrade_Armor_Chance"\s*=\s*101',
    'Paladin''s\s+"Upgrade_Weapon_Chance"\s*=\s*101',
    '\$spelldamage\s*\(\s*SpellMonster\s*,\s*EnemyTarget\s*,\s*1\s*,\s*1\s*\)',
    '\$spelldamage\s*\(\s*SpellMonster\s*,\s*FriendlyTarget\s*,\s*1\s*,\s*1\s*\)',
    'RequiredKills\s*=\s*\$LWS_KillsRequired',
    'SpellMonster''s\s+"LWS_Level"\s*!=\s*2',
    'LWS_ResolveMonsterLoot\s*\(\s*NoDropVictim\s*,\s*1\s*,\s*99\s*,\s*99\s*,\s*99\s*\)',
    'LWS_ResolveMonsterLoot\s*\(\s*DropVictim\s*,\s*1\s*,\s*0\s*,\s*99\s*,\s*99\s*\)',
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
    '\$LWS_RunCombatDiagnostic\s*\(\s*AIRootAgent\s*,\s*Palace\s*\)',
    '\$LWS_SetupWizardEnchantArena\s*\(\s*Palace\s*\)'
)
foreach ($pattern in $requiredHookPatterns) {
    if ($hookSource -notmatch $pattern) {
        throw "Missing diagnostic hook pattern: $pattern"
    }
}
if ($hookSource -match '\$NewThread\s*\(\s*\$LWS_RunCombatDiagnostic') {
    throw 'Diagnostic callback must not be passed directly to NewThread.'
}
if ($hookSource -match 'Function\s+LWS_ForceWizardEnchantVisit' -or
    $hookSource -match '\$Use_Building\s*\(\s*Paladin\s*\)' -or
    $hookSource -match '\$Purchase_Equipment\s*\(\s*Paladin\s*\)' -or
    $hookSource -match 'LWS_ForceEnchantScript' -or
    $hookSource -match 'LWS_EnchantObserverScript') {
    throw 'Wizard arena must not invoke hero decision modules outside the Paladin AI thread.'
}
if ($hookSource -match '\$SpawnUnit\s*\([^;]+"LWS_T3_Armor_Plus1"') {
    throw 'Wizard arena must remain item-free until the native enchant transaction completes.'
}
if ($hookSource -match 'EnemyCount\s*<|PotionCount\s*<|PeasantCount\s*<') {
    throw 'Legacy crowd and potion arena setup must remain removed.'
}
if ($hookSource -match 'LWS_SetupEquipmentArena|LWS_SpawnExplorationChest') {
    throw 'The completed visible test arenas must remain removed.'
}
if ($hookSource -match '\$SpawnUnit\s*\([^;]+"LWSDW_U_Longsword_3_1"' -or
    $hookSource -match '\$SpawnUnit\s*\([^;]+"LWSDW_U_Longbow_3_1"' -or
    $hookSource -match '\$SpawnUnit\s*\([^;]+"LWSDA_R_Plate_3_1"') {
    throw 'Legacy direct inspection equipment must not be spawned in the chest arena.'
}
if ($hookSource -match '\$SpawnUnit\s*\([^;]+"Peasant"') {
    throw 'Diagnostic checks must not spawn real Palace peasants.'
}
if ($hookSource -match 'LWS_TestRuntimeEquipmentCarrier|LWS_RunLegendaryCatalogDiagnostic') {
    throw 'Hidden loot diagnostics must not spawn a roster of real heroes.'
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
if ($itemGeneratorSource -notmatch 'LWS_SelectDesiredSpecialItem' -or $itemGeneratorSource -notmatch 'LWS_ShouldRetrieveEquipment') {
    throw 'Item evaluation override does not filter inferior tiered equipment.'
}
if ($itemGeneratorSource -notmatch '\$DeleteGamePiece\s*\(Target\)') {
    throw 'Item evaluation override does not break the inferior-equipment retrieval loop.'
}

if (-not (Test-Path -LiteralPath $bytecodePath -PathType Leaf)) {
    throw 'Diagnostic bytecode is missing.'
}
if ((Get-Item -LiteralPath $bytecodePath).Length -eq 0) {
    throw 'Diagnostic bytecode is empty.'
}

Write-Host 'Combat diagnostic validation passed.'
