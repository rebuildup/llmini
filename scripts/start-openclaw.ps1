
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\lib\Common.ps1"

$settings = Get-StackSettings
if (-not $settings.OpenClaw.Enabled) {
    Write-Host "OpenClaw is disabled."
    exit 0
}

& "$PSScriptRoot\start-llama.ps1"
Set-OpenClawEnvironment

$root = Get-StackRoot
$cli = Join-Path $root "apps\openclaw\node_modules\.bin\openclaw.cmd"
if (-not (Test-Path $cli)) {
    throw "OpenClaw is not installed. Run bootstrap.cmd."
}

$configPath = $env:OPENCLAW_CONFIG_PATH
if (-not (Test-Path $configPath)) {
    & "$PSScriptRoot\configure-agents.ps1"
}

$command = "`"$cli`" gateway run --compact"
Start-ManagedProcess `
    -Name "openclaw-gateway" `
    -FilePath "$env:SystemRoot\System32\cmd.exe" `
    -ArgumentList @("/d", "/s", "/c", $command) `
    -WorkingDirectory (Join-Path $root "workspace\openclaw") `
    -Priority "BelowNormal" | Out-Null

if (-not (Wait-TcpPort -HostName $settings.OpenClaw.GatewayHost -Port $settings.OpenClaw.GatewayPort -TimeoutSeconds 120)) {
    throw "OpenClaw Gateway did not become ready. Check logs\openclaw-gateway.err.log"
}
Write-Host "OpenClaw Gateway is listening on port $($settings.OpenClaw.GatewayPort)."
