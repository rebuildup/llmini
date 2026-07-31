param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\lib\Common.ps1"

Set-HermesEnvironment
$exe = Join-Path $env:HERMES_HOME "hermes-agent\venv\Scripts\hermes.exe"
if (-not (Test-Path $exe)) {
    throw "Hermes is not installed. Run bootstrap.cmd."
}

& $exe @Arguments
exit $LASTEXITCODE
