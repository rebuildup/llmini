param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\lib\Common.ps1"

Set-OpenClawEnvironment
$cli = Join-Path (Get-StackRoot) "apps\openclaw\node_modules\.bin\openclaw.cmd"
if (-not (Test-Path $cli)) {
    throw "OpenClaw is not installed. Run bootstrap.cmd."
}

& $cli @Arguments
exit $LASTEXITCODE
