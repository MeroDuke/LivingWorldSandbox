[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$matrixPath = Join-Path $repositoryRoot 'Docs\equipment-compatibility.json'
$equipmentPath = Join-Path $repositoryRoot 'GPL\LWS_Equipment.gpl'
$basePath = Join-Path $repositoryRoot 'SDK\OriginalQuests\Data\M_Characters.xml'
$expansionPath = Join-Path $repositoryRoot 'SDK\OriginalQuests\DataMX\MX_Characters.xml'

$matrix = Get-Content -LiteralPath $matrixPath -Raw | ConvertFrom-Json
[xml]$baseXml = Get-Content -LiteralPath $basePath -Raw
[xml]$expansionXml = Get-Content -LiteralPath $expansionPath -Raw
$equipmentSource = Get-Content -LiteralPath $equipmentPath -Raw

if ($matrix.dataset -ne 'MajestyExpansion') {
    throw 'Equipment compatibility must target MajestyExpansion.'
}

$descriptions = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
foreach ($description in $baseXml.Majesty.Description) {
    $canUse = @($description.Engine.CanUse | ForEach-Object { $_.value })
    $menus = @($description.Engine.Menu | ForEach-Object { $_.value })
    if ($canUse -contains 'HumanPlayer' -and $menus -contains '6') {
        $descriptions[[string]$description.ID] = $description
    }
}
foreach ($description in $expansionXml.Majesty.Description) {
    $canUse = @($description.Engine.CanUse | ForEach-Object { $_.value })
    $menus = @($description.Engine.Menu | ForEach-Object { $_.value })
    if ($canUse -contains 'HumanPlayer' -and $menus -contains '6') {
        $descriptions[[string]$description.ID] = $description
    }
}

if ($matrix.heroes.Count -ne $descriptions.Count) {
    throw "Compatibility hero count differs from SDK: matrix=$($matrix.heroes.Count), SDK=$($descriptions.Count)"
}

$weaponFamilies = @($matrix.weaponFamilies)
$armorFamilies = @($matrix.armorFamilies)
foreach ($hero in $matrix.heroes) {
    if (-not $descriptions.ContainsKey([string]$hero.descriptionId)) {
        throw "Unknown SDK hero description: $($hero.descriptionId)"
    }
    $description = $descriptions[[string]$hero.descriptionId]
    if ($description.Name -ne $hero.title) {
        throw "Hero title mismatch for $($hero.descriptionId): matrix=$($hero.title), SDK=$($description.Name)"
    }

    $sdkWeapons = @($description.Game.AllowedWeapon | ForEach-Object { $_.value })
    $sdkArmor = @($description.Game.AllowedArmor | ForEach-Object { $_.value })
    if (Compare-Object -ReferenceObject @($sdkWeapons | Sort-Object) -DifferenceObject @($hero.weapon.allowed | Sort-Object)) {
        throw "Allowed weapon mismatch for $($hero.title)"
    }
    if (Compare-Object -ReferenceObject @($sdkArmor | Sort-Object) -DifferenceObject @($hero.armor.allowed | Sort-Object)) {
        throw "Allowed armor mismatch for $($hero.title)"
    }

    $expectedForbiddenWeapons = @($weaponFamilies | Where-Object { $_ -notin $hero.weapon.allowed } | Sort-Object)
    $expectedForbiddenArmor = @($armorFamilies | Where-Object { $_ -notin $hero.armor.allowed } | Sort-Object)
    if (Compare-Object -ReferenceObject $expectedForbiddenWeapons -DifferenceObject @($hero.weapon.forbidden | Sort-Object)) {
        throw "Forbidden weapon list is incomplete for $($hero.title)"
    }
    if (Compare-Object -ReferenceObject $expectedForbiddenArmor -DifferenceObject @($hero.armor.forbidden | Sort-Object)) {
        throw "Forbidden armor list is incomplete for $($hero.title)"
    }

    if ($equipmentSource -notmatch [regex]::Escape('"' + $hero.title + '"')) {
        throw "Runtime compatibility does not mention hero: $($hero.title)"
    }
}

foreach ($requiredPattern in @(
    'Function\s+LWS_HeroWeaponFamily',
    'Function\s+LWS_HeroArmorFamily',
    'Function\s+LWS_IsEquipmentCompatible',
    'LWS_EquipmentFamily',
    '\$LWS_IsEquipmentCompatible\s*\(\s*Hero\s*,\s*Item\s*\)\s*==\s*FALSE'
)) {
    if ($equipmentSource -notmatch $requiredPattern) {
        throw "Missing runtime compatibility pattern: $requiredPattern"
    }
}

Write-Host 'Northern Expansion equipment compatibility validation passed.'
