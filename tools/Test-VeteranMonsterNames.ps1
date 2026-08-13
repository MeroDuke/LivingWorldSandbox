$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$generatorPath = Join-Path $repositoryRoot 'tools\New-VeteranNameCatalog.ps1'
$statePath = Join-Path $repositoryRoot 'GPL\LWS_MonsterState.gpl'
$gplCatalogPath = Join-Path $repositoryRoot 'GPL\Generated\LWS_VeteranNames.gpl'
$textCatalogPath = Join-Path $repositoryRoot 'Data\LWS_VeteranNames.xml'

& $generatorPath
$state = Get-Content -Raw -LiteralPath $statePath
$catalog = Get-Content -Raw -LiteralPath $gplCatalogPath
[xml]$textCatalog = Get-Content -Raw -LiteralPath $textCatalogPath

function Assert-Match([string]$Text, [string]$Pattern, [string]$Message) {
    if ($Text -notmatch $Pattern) { throw $Message }
}

Assert-Match $state 'Monster''s "LWS_Level" < 5' 'Veteran naming must start at level 5.'
Assert-Match $state 'Monster''s "LWS_VeteranNameKey" != ""' 'One-time/persistence guard is missing.'
Assert-Match $state '\$SpecifyName \( Monster, NameKey \);' 'Runtime display-name assignment is missing.'
Assert-Match $state '\$LWS_AssignVeteranName \( Monster \);' 'Level-up integration is missing.'
Assert-Match $state 'Monster''s "Title" == "Giant_Rat"' 'Rat-specific family routing is missing.'
Assert-Match $catalog 'Function LWS_VeteranNameKey' 'Generated GPL resolver is missing.'

$entries = @($textCatalog.Majesty.Language.Text)
if ($entries.Count -ne 700) { throw "Expected 700 generated veteran names, found $($entries.Count)." }
$ids = @($entries | ForEach-Object { $_.id })
if (($ids | Select-Object -Unique).Count -ne $ids.Count) { throw 'Veteran name text IDs are not unique.' }
if (-not ($entries | Where-Object { $_.'#text' -eq 'Mickey Destroyer of Cheese' })) {
    throw 'Expected Giant Rat example name is missing.'
}

foreach ($manifest in @('LivingWorldSandbox.mqxml', 'LWSCombatDiagnostic.mqxml')) {
    $manifestText = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot $manifest)
    Assert-Match $manifestText 'Data/LWS_VeteranNames.xml' "$manifest does not load the veteran name strings."
}

Write-Host 'Veteran monster name checks passed.'
