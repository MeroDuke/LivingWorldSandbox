[CmdletBinding()]
param(
    [string]$PythonPath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
if (-not $PythonPath) {
    $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
    if (-not $pythonCommand) {
        throw 'Python was not found on PATH. Supply -PythonPath explicitly.'
    }
    $PythonPath = $pythonCommand.Source
}

$inspector = Join-Path $PSScriptRoot 'Inspect-MajestyCam.py'
$example = Join-Path $repositoryRoot 'Sdk\Example\Data\WrathOfKrolm_maindata.cam'
$json = & $PythonPath $inspector $example --summary
if ($LASTEXITCODE -ne 0) {
    throw "CAM inspector failed with exit code $LASTEXITCODE."
}

$report = $json | ConvertFrom-Json
if ($report.version -ne '1.1') {
    throw "Unexpected example CAM version: $($report.version)"
}
if ($report.sections.IMAG.entry_count -ne 5) {
    throw 'Unexpected IMAG entry count.'
}
if ($report.sections.TILE.entry_count -ne 638) {
    throw 'Unexpected TILE entry count.'
}
if ($report.sections.SPLT.entry_count -ne 12) {
    throw 'Unexpected SPLT entry count.'
}

Write-Host 'Majesty CAM inspector test passed.'
