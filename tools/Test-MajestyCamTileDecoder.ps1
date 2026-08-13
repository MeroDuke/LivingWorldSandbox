[CmdletBinding()]
param(
    [string]$PythonPath
)

$ErrorActionPreference = 'Stop'
if (-not $PythonPath) {
    $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
    if (-not $pythonCommand) {
        throw 'Python was not found on PATH. Supply -PythonPath explicitly.'
    }
    $PythonPath = $pythonCommand.Source
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$decoder = Join-Path $PSScriptRoot 'Decode-MajestyCamTile.py'
$example = Join-Path $repositoryRoot 'Sdk\Example\Data\WrathOfKrolm_maindata.cam'
$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('lws-cam-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $temporaryRoot | Out-Null

try {
    $dust = Join-Path $temporaryRoot 'dust.png'
    $fire = Join-Path $temporaryRoot 'fire.png'
    & $PythonPath $decoder $example $dust --tile-index 0
    if ($LASTEXITCODE -ne 0) { throw 'Dust tile decode failed.' }
    & $PythonPath $decoder $example $fire --tile-index 21
    if ($LASTEXITCODE -ne 0) { throw 'Fire tile decode failed.' }

    Add-Type -AssemblyName System.Drawing
    $dustImage = [System.Drawing.Image]::FromFile($dust)
    $fireImage = [System.Drawing.Image]::FromFile($fire)
    try {
        if ($dustImage.Width -ne 82 -or $dustImage.Height -ne 78) {
            throw "Unexpected Dust tile dimensions: $($dustImage.Width)x$($dustImage.Height)"
        }
        if ($fireImage.Width -ne 26 -or $fireImage.Height -ne 29) {
            throw "Unexpected Fire tile dimensions: $($fireImage.Width)x$($fireImage.Height)"
        }
    }
    finally {
        $dustImage.Dispose()
        $fireImage.Dispose()
    }
}
finally {
    Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
}

Write-Host 'Majesty CAM TILE decoder test passed.'
