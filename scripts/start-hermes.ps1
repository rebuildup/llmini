
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\lib\Common.ps1"

$settings = Get-StackSettings
if (-not $settings.Hermes.Enabled) {
    Write-Host "Hermes is disabled."
    exit 0
}

& "$PSScriptRoot\start-llama.ps1"
Set-HermesEnvironment

$root = Get-StackRoot
$exe = Join-Path $env:HERMES_HOME "hermes-agent\venv\Scripts\hermes.exe"
if (-not (Test-Path $exe)) {
    throw "Hermes is not installed. Run bootstrap.cmd."
}

if (-not (Test-Path (Join-Path $env:HERMES_HOME "config.yaml"))) {
    & "$PSScriptRoot\configure-agents.ps1"
}

Start-ManagedProcess `
    -Name "hermes-gateway" `
    -FilePath $exe `
    -ArgumentList @("gateway") `
    -WorkingDirectory (Join-Path $root "workspace\hermes") `
    -Priority "BelowNormal" | Out-Null

if (-not (Wait-TcpPort -HostName $settings.Hermes.ApiHost -Port $settings.Hermes.ApiPort -TimeoutSeconds 180)) {
    Write-Warning "Hermes process started, but API port $($settings.Hermes.ApiPort) was not detected. Check logs\hermes-gateway.err.log"
}
else {
    Write-Host "Hermes Agent API is listening on port $($settings.Hermes.ApiPort)."
}
