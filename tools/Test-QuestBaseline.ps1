[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$definitionPath = Join-Path $repositoryRoot 'LivingWorldSandbox.mqxml'
$sourcePath = Join-Path $repositoryRoot 'GPL\LivingWorldSandbox.gpl'
$templatePath = Join-Path $repositoryRoot 'Quests\LivingWorldSandbox.q'
$bytecodePath = Join-Path $repositoryRoot 'Data\LivingWorldSandbox.bcd'

[xml]$definition = Get-Content -LiteralPath $definitionPath -Raw
$quest = $definition.Majesty.Quest

if ($quest.Name -ne 'LivingWorldSandbox') {
    throw 'Quest Name must match the GPL entry function.'
}
if ($quest.DataConfiguration.Dataset.Load.GPL.Target -ne 'Data/LivingWorldSandbox.bcd') {
    throw 'Quest definition does not load the canonical Data bytecode target.'
}
if ($quest.DataConfiguration.Dataset.Load.Template -ne 'Quests/LivingWorldSandbox.q') {
    throw 'Quest definition does not load the expected template.'
}
if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) {
    throw 'Quest template is missing.'
}

$source = Get-Content -LiteralPath $sourcePath -Raw
$requiredPatterns = @(
    'Function\s+LivingWorldSandbox\s*\(\s*\)',
    'LairCount\s*<\s*6',
    'MonsterCount\s*<\s*24',
    '"Goblin_Hovel"',
    '"Goblin_Camp"',
    '"Animal_Den"',
    '"BrokenSewerMain"',
    '"Giant_Rat"',
    '"Skeleton"',
    '"Goblin_Fighter"'
)
foreach ($pattern in $requiredPatterns) {
    if ($source -notmatch $pattern) {
        throw "Missing baseline source pattern: $pattern"
    }
}
if ($source -match 'LWS_Stage|LWS_Director|LWS_Level') {
    throw 'Non-baseline progression logic is present in the minimal bootstrap.'
}
if (-not (Test-Path -LiteralPath $bytecodePath -PathType Leaf)) {
    throw 'Compiled bytecode is missing from Data/.'
}
if ((Get-Item -LiteralPath $bytecodePath).Length -eq 0) {
    throw 'Compiled bytecode is empty.'
}

Write-Host 'Quest baseline validation passed.'
