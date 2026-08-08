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

& (Join-Path $PSScriptRoot 'New-CombatOverride.ps1') -SdkPath $SdkPath
& (Join-Path $PSScriptRoot 'New-ItemEvaluationOverride.ps1') -SdkPath $SdkPath

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
