
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\lib\Common.ps1"

$settings = Get-StackSettings
foreach ($component in $settings.StartupComponents) {
    switch ($component.ToLowerInvariant()) {
        "llama"    { & "$PSScriptRoot\start-llama.ps1" }
        "openclaw" { & "$PSScriptRoot\start-openclaw.ps1" }
        "hermes"   { & "$PSScriptRoot\start-hermes.ps1" }
        default    { Write-Warning "Unknown startup component: $component" }
    }
}
