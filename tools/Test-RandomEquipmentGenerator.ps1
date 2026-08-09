$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$generator = Get-Content -Raw (Join-Path $repositoryRoot 'Docs\equipment-generator.json') | ConvertFrom-Json
$compatibility = Get-Content -Raw (Join-Path $repositoryRoot 'Docs\equipment-compatibility.json') | ConvertFrom-Json
$lootSource = Get-Content -Raw (Join-Path $repositoryRoot 'GPL\LWS_Loot.gpl')
$equipmentSource = Get-Content -Raw (Join-Path $repositoryRoot 'GPL\LWS_Equipment.gpl')
$prototypeSource = Get-Content -Raw (Join-Path $repositoryRoot 'GPL\LWS_LootPrototypes.dat')
$descriptionSource = Get-Content -Raw (Join-Path $repositoryRoot 'Data\LWS_Descriptions.xml')

$generatedWeaponFamilies = (@($generator.weaponFamilies) | Sort-Object) -join ','
$compatibleWeaponFamilies = (@($compatibility.weaponFamilies) | Sort-Object) -join ','
if ($generatedWeaponFamilies -ne $compatibleWeaponFamilies) {
    throw 'Random weapon families differ from the compatibility matrix.'
}
$generatedArmorFamilies = (@($generator.armorFamilies) | Sort-Object) -join ','
$compatibleArmorFamilies = (@($compatibility.armorFamilies) | Sort-Object) -join ','
if ($generatedArmorFamilies -ne $compatibleArmorFamilies) {
    throw 'Random armor families differ from the compatibility matrix.'
}
if ($generator.legendaryUsesGenericCarrier -ne $false -or $generator.legendaryCatalogPending -ne $false) {
    throw 'Legendary drops must use the completed named Unique catalog.'
}
foreach ($type in @('Weapon', 'Armor')) {
    $prototype = $generator.carrierPrototypes.$type
    if ($prototypeSource -notmatch [regex]::Escape("[$prototype]") -or $descriptionSource -notmatch ('ID="' + [regex]::Escape($prototype) + '"')) {
        throw "Missing generic $type carrier: $prototype"
    }
}

$tierBase = @(0, 0, 1, 2, 3)
$bands = @(
    @{ Rarity = 1; Min = 0; Max = 1 },
    @{ Rarity = 2; Min = 2; Max = 3 },
    @{ Rarity = 3; Min = 4; Max = 6 },
    @{ Rarity = 4; Min = 7; Max = 10 }
)
foreach ($type in @('Weapon', 'Armor')) {
    foreach ($band in $bands) {
        foreach ($tierRoll in 0..99) {
            $tier = if ($band.Rarity -eq 1) { 1 + ($tierRoll % 2) } else { 1 + ($tierRoll % 4) }
            foreach ($powerRoll in 0..99) {
                $power = $band.Min + ($powerRoll % ($band.Max - $band.Min + 1))
                if ($power -lt $tierBase[$tier]) { $power = $tierBase[$tier] }
                if ($type -eq 'Armor' -and (($power - $tierBase[$tier]) % 2) -ne 0) {
                    if ($power -lt $band.Max) { $power++ } else { $power-- }
                }
                $affix = if ($type -eq 'Armor') { ($power - $tierBase[$tier]) / 2 } else { $power - $tierBase[$tier] }
                $effective = $tierBase[$tier] + $(if ($type -eq 'Armor') { 2 * $affix } else { $affix })
                if ($tier -lt 1 -or $tier -gt 4 -or $affix -lt 0 -or $effective -lt $band.Min -or $effective -gt $band.Max) {
                    throw "Invalid generated $type combination for rarity $($band.Rarity): T$tier +$affix = $effective"
                }
            }
        }
    }
}

foreach ($pattern in @(
    'Function\s+LWS_RandomWeaponFamily',
    'Function\s+LWS_RandomArmorFamily',
    'Function\s+LWS_GeneratedEquipmentTier',
    'Function\s+LWS_GeneratedEquipmentAffix',
    'Function\s+LWS_SpawnRandomEquipment',
    'OmitCandidate\s*=\s*\$RandomNumber\s*\(\s*3\s*\)'
)) {
    if ($lootSource -notmatch $pattern) { throw "Missing random generator pattern: $pattern" }
}
if ($equipmentSource -notmatch 'Function\s+LWS_ConfigureEquipmentDrop') {
    throw 'Runtime equipment carrier configuration is missing.'
}
Write-Host 'Random equipment generator validation passed.'
