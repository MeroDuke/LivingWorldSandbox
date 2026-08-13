[CmdletBinding()]
param(
    [switch]$Build,
    [string]$SdkPath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$outputRoot = Join-Path $repositoryRoot 'output'

if ($Build) {
    & (Join-Path $PSScriptRoot 'Build-Quest.ps1') -SdkPath $SdkPath
    & (Join-Path $PSScriptRoot 'Build-CombatDiagnostic.ps1') -SdkPath $SdkPath
}

& (Join-Path $PSScriptRoot 'Test-QuestBaseline.ps1')
& (Join-Path $PSScriptRoot 'Test-CombatDiagnostic.ps1')
& (Join-Path $PSScriptRoot 'Test-VeteranMonsterNames.ps1')

$packages = @(
    [pscustomobject]@{
        Name = 'LivingWorldSandbox'
        Files = @(
            'LivingWorldSandbox.mqxml'
            'Data\LivingWorldSandbox.bcd'
            'Data\LWS_Descriptions.xml'
            'Data\LWS_EquipmentDropDescriptions.xml'
            'Data\LWS_Text.xml'
            'Data\LWS_VeteranNames.xml'
            'Data\LWS_EquipmentDropText.xml'
            'Quests\LivingWorldSandbox.q'
        )
    },
    [pscustomobject]@{
        Name = 'LWSCombatDiagnostic'
        Files = @(
            'LWSCombatDiagnostic.mqxml'
            'Data\LWSCombatDiagnostic.bcd'
            'Data\LWS_Descriptions.xml'
            'Data\LWS_EquipmentDropDescriptions.xml'
            'Data\LWS_Text.xml'
            'Data\LWS_VeteranNames.xml'
            'Data\LWS_EquipmentDropText.xml'
            'Quests\LivingWorldSandbox.q'
        )
    }
)

New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null

foreach ($package in $packages) {
    $packageRoot = Join-Path $outputRoot $package.Name
    if (Test-Path -LiteralPath $packageRoot) {
        $resolvedOutput = (Resolve-Path -LiteralPath $outputRoot).Path
        $resolvedPackage = (Resolve-Path -LiteralPath $packageRoot).Path
        if (-not $resolvedPackage.StartsWith($resolvedOutput + [IO.Path]::DirectorySeparatorChar)) {
            throw "Refusing to clean package outside output: $resolvedPackage"
        }
        Remove-Item -LiteralPath $resolvedPackage -Recurse -Force
    }

    foreach ($relativePath in $package.Files) {
        $source = Join-Path $repositoryRoot $relativePath
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            throw "Package source is missing: $relativePath"
        }
        $destination = Join-Path $packageRoot $relativePath
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
        Copy-Item -LiteralPath $source -Destination $destination
    }

    Write-Host "Ready-to-copy package: $packageRoot"
}
