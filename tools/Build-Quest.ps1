[CmdletBinding()]
param(
    [string]$SdkPath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$gplDirectory = Join-Path $repositoryRoot 'GPL'
$dataDirectory = Join-Path $repositoryRoot 'Data'
$projectFile = Join-Path $gplDirectory 'LivingWorldSandbox.gplproj'
$temporaryBytecode = Join-Path $gplDirectory 'LivingWorldSandbox.bcd'
$targetBytecode = Join-Path $dataDirectory 'LivingWorldSandbox.bcd'

& (Join-Path $PSScriptRoot 'New-CombatOverride.ps1') -SdkPath $SdkPath

$compilerCandidates = @()
if ($SdkPath) {
    $compilerCandidates += Join-Path $SdkPath 'Gplbcc.exe'
}
if ($env:MAJESTYSDK) {
    $compilerCandidates += Join-Path $env:MAJESTYSDK 'Gplbcc.exe'
}
$compilerCandidates += Join-Path $repositoryRoot 'SDK\Gplbcc.exe'

$compiler = $compilerCandidates |
    Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
    Select-Object -First 1

if (-not $compiler) {
    throw 'Gplbcc.exe was not found. Pass -SdkPath or set MAJESTYSDK.'
}
$compiler = (Resolve-Path -LiteralPath $compiler).Path

New-Item -ItemType Directory -Force -Path $dataDirectory | Out-Null

Push-Location $gplDirectory
try {
    & $compiler -in (Split-Path -Leaf $projectFile) -out (Split-Path -Leaf $temporaryBytecode) -stdout
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $temporaryBytecode -PathType Leaf)) {
        throw "GPL compilation failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}

Move-Item -LiteralPath $temporaryBytecode -Destination $targetBytecode -Force
Write-Host "Built $targetBytecode"
