param(
    [switch]$OpenDashboard
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\lib\Common.ps1"

$root = Get-StackRoot
$settingsFiles = @(
    (Join-Path $root "config\settings.psd1"),
    (Join-Path $root "config\settings.example.psd1")
)
$requiredContext = 65536

Write-Host "Repairing local agent integrations"

foreach ($settingsFile in $settingsFiles) {
    if (-not (Test-Path -LiteralPath $settingsFile)) {
        continue
    }

    $source = [System.IO.File]::ReadAllText($settingsFile)
    $pattern = '(?m)^(\s*ContextLength\s*=\s*)\d+(\s*)$'
    $match = [regex]::Match($source, $pattern)

    if (-not $match.Success) {
        throw ("ContextLength was not found in {0}" -f $settingsFile)
    }

    $currentContext = [int]([regex]::Match(
        $match.Value,
        '\d+'
    ).Value)

    if ($currentContext -lt $requiredContext) {
        $replacement = '${1}' + [string]$requiredContext + '${2}'
        $source = [regex]::Replace(
            $source,
            $pattern,
            $replacement,
            1
        )

        [System.IO.File]::WriteAllText(
            $settingsFile,
            $source,
            (New-Object System.Text.UTF8Encoding($false))
        )

        Write-Host (
            "Updated {0}: context {1} -> {2}" -f
            $settingsFile,
            $currentContext,
            $requiredContext
        )
    }
    else {
        Write-Host (
            "Context is already sufficient in {0}: {1}" -f
            $settingsFile,
            $currentContext
        )
    }
}

Write-Host ""
Write-Host "Stopping managed processes..."
& "$PSScriptRoot\stop-all.ps1"

Write-Host ""
Write-Host "Regenerating agent configurations..."
& "$PSScriptRoot\configure-agents.ps1"

Write-Host ""
Write-Host "Starting llama-server with 64K context..."
& "$PSScriptRoot\start-llama.ps1"

Write-Host ""
Write-Host "Starting OpenClaw..."
& "$PSScriptRoot\start-openclaw.ps1"

Write-Host ""
Write-Host "Starting Hermes Agent..."
& "$PSScriptRoot\start-hermes.ps1"

Write-Host ""
Write-Host "Verifying OpenClaw..."
& "$PSScriptRoot\test-openclaw.ps1" -OpenBrowser:$OpenDashboard

Write-Host ""
Write-Host "Verifying Hermes Agent..."
& "$PSScriptRoot\test-hermes.ps1"

Write-Host ""
Write-Host "Integration repair completed."
