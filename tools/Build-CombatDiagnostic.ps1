[CmdletBinding()]
param(
    [string]$SdkPath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$gplDirectory = Join-Path $repositoryRoot 'GPL'
$dataDirectory = Join-Path $repositoryRoot 'Data'
$temporaryBytecode = Join-Path $gplDirectory 'LWSCombatDiagnostic.bcd'
$targetBytecode = Join-Path $dataDirectory 'LWSCombatDiagnostic.bcd'
$curiosBuilder = Join-Path $PSScriptRoot 'Build-CuriosAndCharmsCam.py'
$curiosSource = Join-Path $repositoryRoot 'Assets\CuriosAndCharms\preview\curios-and-charms-l1-192-v3.png'
$curiosIcon = Join-Path $repositoryRoot 'Assets\CuriosAndCharms\curios-and-charms-build-icon.png'
$curiosCam = Join-Path $dataDirectory 'LWS_CuriosAndCharms.cam'
$curiosMiscdata = Join-Path $dataDirectory 'LWS_CuriosAndCharms_miscdata.cam'
$sdkExampleCam = Join-Path $repositoryRoot 'Sdk\Example\Data\WrathOfKrolm_maindata.cam'
$gameMiscdataCandidates = @(
    $env:MAJESTY_GAME,
    'J:\SteamLibrary\steamapps\common\Majesty HD'
) | Where-Object { $_ } | ForEach-Object { Join-Path $_ 'Data\miscdata.cam' }
$gameMiscdata = $gameMiscdataCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $gameMiscdata) {
    throw 'Installed Majesty Data\miscdata.cam was not found. Set MAJESTY_GAME to the game directory.'
}
$gameMainData = Join-Path (Split-Path -Parent $gameMiscdata) 'maindata.cam'
if (-not (Test-Path -LiteralPath $gameMainData -PathType Leaf)) {
    throw 'Installed Majesty Data\maindata.cam was not found.'
}

$pythonCommand = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCommand) {
    throw 'Python was not found on PATH; it is required to build the Curios and Charms CAM PoC.'
}
& $pythonCommand.Source $curiosBuilder $curiosSource $curiosIcon $sdkExampleCam $gameMainData $curiosCam
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $curiosCam -PathType Leaf)) {
    throw 'Curios and Charms CAM generation failed.'
}
& $pythonCommand.Source (Join-Path $PSScriptRoot 'Build-CuriosAndCharmsBdep.py') $gameMiscdata $curiosMiscdata
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $curiosMiscdata -PathType Leaf)) {
    throw 'Curios and Charms BDEP generation failed.'
}

& (Join-Path $PSScriptRoot 'New-VeteranNameCatalog.ps1')
& (Join-Path $PSScriptRoot 'New-CombatOverride.ps1') -SdkPath $SdkPath
& (Join-Path $PSScriptRoot 'New-ItemEvaluationOverride.ps1') -SdkPath $SdkPath
& (Join-Path $PSScriptRoot 'New-TreasureOverride.ps1') -SdkPath $SdkPath

$sdkCandidates = @()
if ($SdkPath) {
    $sdkCandidates += $SdkPath
}
if ($env:MAJESTYSDK) {
    $sdkCandidates += $env:MAJESTYSDK
}
$sdkCandidates += Join-Path $repositoryRoot 'SDK'

$compiler = $sdkCandidates |
    ForEach-Object { Join-Path $_ 'Gplbcc.exe' } |
    Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
    Select-Object -First 1
if (-not $compiler) {
    throw 'Gplbcc.exe was not found. Pass -SdkPath or set MAJESTYSDK.'
}
$compiler = (Resolve-Path -LiteralPath $compiler).Path

New-Item -ItemType Directory -Force -Path $dataDirectory | Out-Null
Push-Location $gplDirectory
try {
    & $compiler -in 'LWS_CombatDiagnostic.gplproj' -out (Split-Path -Leaf $temporaryBytecode) -stdout
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $temporaryBytecode -PathType Leaf)) {
        throw "Diagnostic GPL compilation failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}

Move-Item -LiteralPath $temporaryBytecode -Destination $targetBytecode -Force
Write-Host "Built $targetBytecode"
