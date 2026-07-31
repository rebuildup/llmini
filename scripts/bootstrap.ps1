param(
    [switch]$SkipModel,
    [switch]$SkipOpenClaw,
    [switch]$SkipHermes,
    [switch]$NoStart
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\lib\Common.ps1"

Initialize-StackDirectories
Get-StackSecrets | Out-Null

Write-Host "Local AI Stack root: $(Get-StackRoot)"
Write-Host ""

& "$PSScriptRoot\download-node.ps1"
& "$PSScriptRoot\download-llama-cpp.ps1"

if (-not $SkipModel) {
    & "$PSScriptRoot\download-model.ps1"
}

if (-not $SkipOpenClaw) {
    & "$PSScriptRoot\install-openclaw.ps1"
}

if (-not $SkipHermes) {
    Write-Host ""
    Write-Host "Installing Hermes Agent..."
    & "$PSScriptRoot\install-hermes.ps1"
}

& "$PSScriptRoot\configure-agents.ps1"

$git = Get-Command git.exe -ErrorAction SilentlyContinue
if ($git -and -not (Test-Path (Join-Path (Get-StackRoot) ".git"))) {
    & $git.Source -C (Get-StackRoot) init | Out-Null
    Write-Host "Initialized a Git repository. No commit was created."
}

if (-not $NoStart -and -not $SkipModel) {
    & "$PSScriptRoot\start-llama.ps1"
    & "$PSScriptRoot\test-api.ps1" -Prompt "Output exactly: Local AI is ready."
}

Write-Host ""
Write-Host "Bootstrap complete."
Write-Host "Use start.cmd / stop.cmd / status.cmd for daily management."
