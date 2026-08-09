$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$rulesPath = Join-Path $repositoryRoot 'Docs\equipment-rarity.json'
$equipmentPath = Join-Path $repositoryRoot 'GPL\LWS_Equipment.gpl'
$rules = Get-Content -Raw $rulesPath | ConvertFrom-Json
$source = Get-Content -Raw $equipmentPath

$expectedTiers = @{ T1 = 0; T2 = 1; T3 = 2; T4 = 3 }
foreach ($tier in $expectedTiers.Keys) {
    if ([int]$rules.tierBasePower.$tier -ne $expectedTiers[$tier]) {
        throw "Unexpected base power for $tier."
    }
}
if ([int]$rules.affixPowerMultiplier.Weapon -ne 1 -or [int]$rules.affixPowerMultiplier.Armor -ne 2) {
    throw 'Weapon/armor affix multipliers do not match the Northern Expansion model.'
}

$bands = @($rules.rarityBands)
$expectedBands = @(
    @{ Name = 'Common'; Min = 0; Max = 1 },
    @{ Name = 'Uncommon'; Min = 2; Max = 3 },
    @{ Name = 'Rare'; Min = 4; Max = 6 },
    @{ Name = 'Epic'; Min = 7; Max = 10 }
)
for ($index = 0; $index -lt $expectedBands.Count; $index++) {
    $actual = $bands[$index]
    $expected = $expectedBands[$index]
    if ($actual.name -ne $expected.Name -or [int]$actual.minPower -ne $expected.Min -or [int]$actual.maxPower -ne $expected.Max) {
        throw "Unexpected rarity band at index $index."
    }
}
if ($rules.legendary.generatedByPowerBudget -ne $false -or $rules.legendary.requiresPredefinedUniqueItem -ne $true) {
    throw 'Legendary items must remain outside the random power budget.'
}
if (($rules.replacementOrder -join ',') -ne 'higherPower,higherAffix,higherTier') {
    throw 'Unexpected equipment replacement order.'
}

$requiredPatterns = @(
    'Function\s+LWS_EquipmentPower',
    'Function\s+LWS_EquipmentRarity',
    'AffixBonus\s*\*\s*2',
    'return\s+"Common"',
    'return\s+"Uncommon"',
    'return\s+"Rare"',
    'return\s+"Epic"',
    'ItemAffix\s*>\s*Hero''s\s+"LWS_WeaponAffixBonus"',
    'ItemAffix\s*>\s*Hero''s\s+"LWS_ArmorAffixBonus"',
    'Tier\s*==\s*1[^}]+Tier\s*=\s*2'
)
foreach ($pattern in $requiredPatterns) {
    if ($source -notmatch $pattern) {
        throw "Missing equipment rarity implementation pattern: $pattern"
    }
}

Write-Host 'Equipment rarity and power-budget validation passed.'
