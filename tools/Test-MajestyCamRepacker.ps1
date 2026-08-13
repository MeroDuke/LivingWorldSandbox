[CmdletBinding()]
param([string]$PythonPath)

$ErrorActionPreference = 'Stop'
if (-not $PythonPath) {
    $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
    if (-not $pythonCommand) { throw 'Python was not found on PATH.' }
    $PythonPath = $pythonCommand.Source
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $repositoryRoot 'Sdk\Example\Data\WrathOfKrolm_maindata.cam'
$repacker = Join-Path $PSScriptRoot 'Repack-MajestyCam.py'
$temporary = Join-Path ([System.IO.Path]::GetTempPath()) ('lws-repack-' + [guid]::NewGuid() + '.cam')
try {
    & $PythonPath $repacker $source $temporary
    if ($LASTEXITCODE -ne 0) { throw 'CAM repacker failed.' }
    $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
    $rebuiltHash = (Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash
    if ($sourceHash -ne $rebuiltHash) {
        throw "CAM repack was not byte-identical: $sourceHash != $rebuiltHash"
    }
}
finally {
    if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
}
Write-Host 'Majesty CAM byte-identical repacker test passed.'
