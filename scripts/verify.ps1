param(
    [switch]$OpenOpenClaw
)

$ErrorActionPreference = "Stop"

Write-Host "Local AI Stack verification"
Write-Host "==========================="
Write-Host ""

& "$PSScriptRoot\test-api.ps1" -Prompt "Reply with exactly LLAMA_OK."

Write-Host ""
Write-Host "---------------------------"
Write-Host ""

& "$PSScriptRoot\test-openclaw.ps1" -OpenBrowser:$OpenOpenClaw

Write-Host ""
Write-Host "---------------------------"
Write-Host ""

& "$PSScriptRoot\test-hermes.ps1"

Write-Host ""
Write-Host "All verification checks passed."
