[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$outputRoot = Join-Path $repositoryRoot 'output'

$expectedPackages = @{
    LivingWorldSandbox = @(
        'LivingWorldSandbox.mqxml'
        'Data\LivingWorldSandbox.bcd'
        'Data\LWS_Descriptions.xml'
        'Data\LWS_Text.xml'
        'Quests\LivingWorldSandbox.q'
    )
    LWSCombatDiagnostic = @(
        'LWSCombatDiagnostic.mqxml'
        'Data\LWSCombatDiagnostic.bcd'
        'Data\LWS_Descriptions.xml'
        'Data\LWS_Text.xml'
        'Quests\LivingWorldSandbox.q'
    )
}

foreach ($packageName in $expectedPackages.Keys) {
    $packageRoot = Join-Path $outputRoot $packageName
    if (-not (Test-Path -LiteralPath $packageRoot -PathType Container)) {
        throw "Package directory is missing: $packageName"
    }

    $actualFiles = Get-ChildItem -LiteralPath $packageRoot -File -Recurse |
        ForEach-Object { $_.FullName.Substring($packageRoot.Length + 1) } |
        Sort-Object
    $expectedFiles = $expectedPackages[$packageName] | Sort-Object

    if (Compare-Object -ReferenceObject $expectedFiles -DifferenceObject $actualFiles) {
        throw "Package contents differ from the allowlist: $packageName"
    }

    foreach ($relativePath in $expectedFiles) {
        $source = Join-Path $repositoryRoot $relativePath
        $packaged = Join-Path $packageRoot $relativePath
        if ((Get-FileHash -LiteralPath $source).Hash -ne (Get-FileHash -LiteralPath $packaged).Hash) {
            throw "Packaged file differs from its source: $packageName/$relativePath"
        }
    }
}

Write-Host 'Ready-to-copy quest package validation passed.'

& (Join-Path $PSScriptRoot 'Test-EquipmentCompatibility.ps1')
& (Join-Path $PSScriptRoot 'Test-EquipmentRarity.ps1')
& (Join-Path $PSScriptRoot 'Test-MonsterLootPolicy.ps1')
