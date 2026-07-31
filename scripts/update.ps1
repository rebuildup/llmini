param(
    [switch]$SkipLlama,
    [switch]$SkipOpenClaw,
    [switch]$SkipHermes
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\lib\Common.ps1"

& "$PSScriptRoot\stop-all.ps1"

if (-not $SkipLlama) {
    & "$PSScriptRoot\download-llama-cpp.ps1"
}
if (-not $SkipOpenClaw) {
    & "$PSScriptRoot\install-openclaw.ps1"
}
if (-not $SkipHermes) {
    Set-HermesEnvironment
    $exe = Join-Path $env:HERMES_HOME "hermes-agent\venv\Scripts\hermes.exe"
    if (Test-Path $exe) {
        & $exe update
    }
    else {
        & "$PSScriptRoot\install-hermes.ps1"
    }
}

& "$PSScriptRoot\configure-agents.ps1"
Write-Host "Update complete. Run start.cmd when needed."
