$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$generator = Get-Content -Raw (Join-Path $repositoryRoot 'Docs\equipment-generator.json') | ConvertFrom-Json
$compatibility = Get-Content -Raw (Join-Path $repositoryRoot 'Docs\equipment-compatibility.json') | ConvertFrom-Json
$lootSource = Get-Content -Raw (Join-Path $repositoryRoot 'GPL\LWS_Loot.gpl')
$equipmentSource = Get-Content -Raw (Join-Path $repositoryRoot 'GPL\LWS_Equipment.gpl')
$catalogPrototypeSource = Get-Content -Raw (Join-Path $repositoryRoot 'GPL\LWS_EquipmentDropPrototypes.dat')
$catalogResolverSource = Get-Content -Raw (Join-Path $repositoryRoot 'GPL\LWS_EquipmentDropCatalog.gpl')
[xml]$catalogDescriptions = Get-Content -Raw (Join-Path $repositoryRoot 'Data\LWS_EquipmentDropDescriptions.xml')
[xml]$catalogText = Get-Content -Raw (Join-Path $repositoryRoot 'Data\LWS_EquipmentDropText.xml')

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
$prototypeTitles = @([regex]::Matches($catalogPrototypeSource, '(?m)^\[(LWSD[WA]_[^\]\r\n]+)\]\r?$') | ForEach-Object { $_.Groups[1].Value })
$descriptionRecords = @($catalogDescriptions.Majesty.Description)
$descriptionIds = @($descriptionRecords | ForEach-Object { $_.ID })
$textIds = @($catalogText.Majesty.Language.Text | ForEach-Object { $_.id })
if ($prototypeTitles.Count -ne 422 -or $descriptionIds.Count -ne 422 -or $textIds.Count -ne 422) {
    throw "Static equipment catalog counts are invalid: prototypes=$($prototypeTitles.Count), descriptions=$($descriptionIds.Count), text=$($textIds.Count)."
}
foreach ($title in $prototypeTitles) {
    $description = @($descriptionRecords | Where-Object { $_.ID -eq $title })
    if ($description.Count -ne 1 -or $description[0].Name -ne $title) {
        throw "Static equipment Description must use ID == Name: $title"
    }
    if (("IDTXT_${title}_HELP") -notin $textIds) {
        throw "Static equipment help text is missing: $title"
    }
    if ($catalogResolverSource -notmatch ('return\s+"' + [regex]::Escape($title) + '"')) {
        throw "Static equipment resolver literal is missing: $title"
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
    'DropTitle\s*=\s*\$LWS_StaticEquipmentDropTitle',
    'OmitCandidate\s*=\s*\$RandomNumber\s*\(\s*3\s*\)'
)) {
    if ($lootSource -notmatch $pattern) { throw "Missing random generator pattern: $pattern" }
}
if ($equipmentSource -notmatch 'Function\s+LWS_ConfigureEquipmentDrop') {
    throw 'Runtime equipment carrier configuration is missing.'
}
if ($catalogResolverSource -notmatch 'Function\s+LWS_StaticEquipmentDropTitle') {
    throw 'Static equipment resolver entry point is missing.'
}
Write-Host 'Random equipment generator validation passed.'
