[CmdletBinding()]
param([string]$PythonPath)

$ErrorActionPreference = 'Stop'
if (-not $PythonPath) {
    $command = Get-Command python -ErrorAction SilentlyContinue
    if (-not $command) { throw 'Python was not found on PATH.' }
    $PythonPath = $command.Source
}

$root = Split-Path -Parent $PSScriptRoot
$builder = Join-Path $PSScriptRoot 'Build-CuriosAndCharmsCam.py'
$inspector = Join-Path $PSScriptRoot 'Inspect-MajestyCam.py'
$image = Join-Path $root 'Assets\CuriosAndCharms\preview\curios-and-charms-l1-192-v3.png'
$icon = Join-Path $root 'Assets\CuriosAndCharms\curios-and-charms-build-icon.png'
$krolmCam = Join-Path $root 'Sdk\Example\Data\WrathOfKrolm_maindata.cam'
$sdkCam = 'J:\SteamLibrary\steamapps\common\Majesty HD\Data\maindata.cam'
if (-not (Test-Path -LiteralPath $sdkCam -PathType Leaf)) {
    throw 'Installed Majesty Data\maindata.cam was not found for the CAM test.'
}
$temporary = Join-Path ([System.IO.Path]::GetTempPath()) ('lws-curios-' + [guid]::NewGuid() + '.cam')
try {
    & $PythonPath $builder $image $icon $krolmCam $sdkCam $temporary
    if ($LASTEXITCODE -ne 0) { throw 'Curios and Charms CAM build failed.' }
    $json = & $PythonPath $inspector $temporary --summary
    if ($LASTEXITCODE -ne 0) { throw 'Generated CAM inspection failed.' }
    $report = $json | ConvertFrom-Json
    if ($report.sections.IMAG.entry_count -ne 1 -or
        $report.sections.TILE.entry_count -ne 17236 -or
        $report.sections.SPLT.entry_count -lt 104) {
        throw 'Generated CAM does not contain the expected IMAG/TILE/SPLT entries.'
    }
    & $PythonPath (Join-Path $PSScriptRoot 'Test-CuriosAndCharmsCamHeader.py') $temporary $sdkCam
    if ($LASTEXITCODE -ne 0) { throw 'Generated TILE does not reference its SPLT palette.' }
}
finally {
    if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
}
Write-Host 'Curios and Charms isolated CAM test passed.'
