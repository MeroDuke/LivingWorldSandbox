[CmdletBinding()]
param(
    [string]$SdkRoot
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$resolvedSdkRoot = if ($SdkRoot) { $SdkRoot } else { Join-Path $repositoryRoot 'SDK' }
$equipmentPath = Join-Path $repositoryRoot 'GPL\LWS_Equipment.gpl'
$chestPath = Join-Path $repositoryRoot 'GPL\LWS_Chest.gpl'
$sdkDecisionPath = Join-Path $resolvedSdkRoot 'OriginalQuests\GPLMx\DecisionTrees\Modules\mx_Purchase_Equipment.gpl'
$sdkTaskPath = Join-Path $resolvedSdkRoot 'OriginalQuests\GPLMx\TaskModules\Buildings\mx_Enchant_Equipment.gpl'

$equipment = Get-Content -LiteralPath $equipmentPath -Raw
$chest = Get-Content -LiteralPath $chestPath -Raw

$requiredEquipmentPatterns = @(
    'Function\s+LWS_TierFromStructBonus',
    'Function\s+LWS_ClampWizardEnchantBonus',
    'Function\s+LWS_EnsureArmorEquipmentState',
    'HadTier\s*=\s*\$HasAttribute\s*\(\s*"LWS_ArmorTier"',
    'EnchantBonus\s*-=\s*Hero''s\s+"LWS_ArmorAffixBonus"',
    'EnchantBonus\s*=\s*\$LWS_ClampWizardEnchantBonus',
    'LWS_ArmorEnchantBonus',
    'Function\s+LWS_SyncArmorMagicBonus',
    '#ATTRIB_Armor_Magic_Bonus\s*,\s*Hero''s\s+"LWS_ArmorAffixBonus"\s*\+\s*Hero''s\s+"LWS_ArmorEnchantBonus"',
    'Function\s+WizGuild_Check',
    'Bonus\s*=\s*ThisAgent''s\s+"LWS_ArmorEnchantBonus"',
    'Function\s+Obtain_Enchantment',
    '\$IsValidGamePiece\s*\(\s*ThisBuilding\s*\)\s*==\s*FALSE',
    'What_To_Upgrade\s*!=\s*#ATTRIB_Weapon_Magic_Bonus',
    'What_To_Upgrade\s*!=\s*#ATTRIB_Armor_Magic_Bonus',
    '\$InsideBuilding\s*\(\s*ThisAgent\s*\)',
    '\$GetBuildingContainer\s*\(\s*ThisAgent\s*\)',
    '\$Exit_Building\s*\(\s*ThisAgent\s*,\s*BuildingContainer\s*\)',
    '\$Reset_Tasks\s*\(\s*ThisAgent\s*\)',
    'CurrentBonus\s*=\s*ThisAgent''s\s+"LWS_ArmorEnchantBonus"',
    'ThisAgent''s\s+"LWS_ArmorEnchantBonus"\s*=\s*Upgrade',
    'Function\s+Obtain_Upgrade[\s\S]+?What_To_Upgrade\s*==\s*#ATTRIB_Armor_Struct_Bonus[\s\S]+?\$LWS_SyncArmorMagicBonus\s*\(\s*ThisAgent\s*\)',
    'Function\s+LWS_EquipArmorTransfer[\s\S]+?\$LWS_SyncArmorMagicBonus\s*\(\s*NewOwnerAgent\s*\)'
)
foreach ($pattern in $requiredEquipmentPatterns) {
    if ($equipment -notmatch $pattern) {
        throw "Missing Wizard Guild compatibility pattern: $pattern"
    }
}

if ($chest -notmatch 'Function\s+LWS_ApplyLockedArmorReward[\s\S]+?\$LWS_SyncArmorMagicBonus\s*\(\s*Hero\s*\)') {
    throw 'Chest armor rewards do not preserve and recompute the Wizard Guild enchantment.'
}

if ($equipment -match '#ATTRIB_Armor_Magic_Bonus\s*,\s*AffixBonus') {
    throw 'A direct armor-affix write would erase the separate Wizard Guild enchantment.'
}

if ((Test-Path -LiteralPath $sdkDecisionPath -PathType Leaf) -and
    (Test-Path -LiteralPath $sdkTaskPath -PathType Leaf)) {
    $sdkDecision = Get-Content -LiteralPath $sdkDecisionPath -Raw
    $sdkTask = Get-Content -LiteralPath $sdkTaskPath -Raw

    foreach ($pattern in @('Function\s+WizGuild_Check', '#Cost_Per_Magic_Enchantment1', '#Cost_Per_Magic_Enchantment2', '#Cost_Per_Magic_Enchantment3')) {
        if ($sdkDecision -notmatch $pattern) {
            throw "Northern Expansion Wizard Guild decision contract changed: $pattern"
        }
    }
    if ($sdkTask -notmatch 'Function\s+Obtain_Enchantment') {
        throw 'Northern Expansion Wizard Guild transaction contract changed.'
    }
}
else {
    Write-Host 'Northern Expansion SDK is unavailable; skipping the optional read-only SDK contract cross-check.'
}

Write-Host 'Wizard Guild enchant compatibility validation passed.'
