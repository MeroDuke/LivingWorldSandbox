[CmdletBinding()]
param(
    [string]$BaseCharacterPath,
    [string]$ExpansionCharacterPath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$matrixPath = Join-Path $repositoryRoot 'Docs\equipment-compatibility.json'
$equipmentPath = Join-Path $repositoryRoot 'GPL\LWS_Equipment.gpl'
if (-not $BaseCharacterPath) {
    $BaseCharacterPath = Join-Path $repositoryRoot 'SDK\OriginalQuests\Data\M_Characters.xml'
}
if (-not $ExpansionCharacterPath) {
    $ExpansionCharacterPath = Join-Path $repositoryRoot 'SDK\OriginalQuests\DataMX\MX_Characters.xml'
}

$matrix = Get-Content -LiteralPath $matrixPath -Raw | ConvertFrom-Json
$equipmentSource = Get-Content -LiteralPath $equipmentPath -Raw

if ($matrix.dataset -ne 'MajestyExpansion') {
    throw 'Equipment compatibility must target MajestyExpansion.'
}

$weaponFamilies = @($matrix.weaponFamilies)
$armorFamilies = @($matrix.armorFamilies)
if ($weaponFamilies.Count -eq 0 -or $armorFamilies.Count -eq 0) {
    throw 'Equipment family lists must not be empty.'
}
if (@($weaponFamilies | Select-Object -Unique).Count -ne $weaponFamilies.Count) {
    throw 'Weapon family list contains duplicates.'
}
if (@($armorFamilies | Select-Object -Unique).Count -ne $armorFamilies.Count) {
    throw 'Armor family list contains duplicates.'
}

$heroTitleSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$heroIdSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($hero in $matrix.heroes) {
    if (-not $heroTitleSet.Add([string]$hero.title)) {
        throw "Compatibility matrix contains duplicate hero title: $($hero.title)"
    }
    if (-not $heroIdSet.Add([string]$hero.descriptionId)) {
        throw "Compatibility matrix contains duplicate description ID: $($hero.descriptionId)"
    }
}

foreach ($hero in $matrix.heroes) {
    foreach ($family in @($hero.weapon.allowed) + @($hero.weapon.forbidden)) {
        if ($family -notin $weaponFamilies) {
            throw "Unknown weapon family for $($hero.title): $family"
        }
    }
    foreach ($family in @($hero.armor.allowed) + @($hero.armor.forbidden)) {
        if ($family -notin $armorFamilies) {
            throw "Unknown armor family for $($hero.title): $family"
        }
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
    'Function\s+LWS_EquipmentPickupDirector',
    '"LWS_EquipmentDrop"',
    'LWS_EquipmentFamily',
    '\$LWS_IsEquipmentCompatible\s*\(\s*Hero\s*,\s*Item\s*\)\s*==\s*FALSE'
)) {
    if ($equipmentSource -notmatch $requiredPattern) {
        throw "Missing runtime compatibility pattern: $requiredPattern"
    }
}

$hasBaseSdk = Test-Path -LiteralPath $BaseCharacterPath -PathType Leaf
$hasExpansionSdk = Test-Path -LiteralPath $ExpansionCharacterPath -PathType Leaf
if ($hasBaseSdk -and $hasExpansionSdk) {
    [xml]$baseXml = Get-Content -LiteralPath $BaseCharacterPath -Raw
    [xml]$expansionXml = Get-Content -LiteralPath $ExpansionCharacterPath -Raw
    $descriptions = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)

    foreach ($description in @($baseXml.Majesty.Description) + @($expansionXml.Majesty.Description)) {
        $canUse = @($description.Engine.CanUse | ForEach-Object { $_.value })
        $menus = @($description.Engine.Menu | ForEach-Object { $_.value })
        if ($canUse -contains 'HumanPlayer' -and $menus -contains '6') {
            $descriptions[[string]$description.ID] = $description
        }
    }

    if ($matrix.heroes.Count -ne $descriptions.Count) {
        throw "Compatibility hero count differs from SDK: matrix=$($matrix.heroes.Count), SDK=$($descriptions.Count)"
    }

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
    }
    Write-Host 'Northern Expansion equipment compatibility SDK cross-check passed.'
}
else {
    Write-Host 'Northern Expansion SDK character XML is unavailable; SDK cross-check skipped.'
}

Write-Host 'Equipment compatibility matrix and runtime validation passed.'
