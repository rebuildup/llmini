param(
    [switch]$OpenBrowser
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\lib\Common.ps1"

& "$PSScriptRoot\start-openclaw.ps1"
Set-OpenClawEnvironment

$settings = Get-StackSettings
$secrets = Get-StackSecrets
$root = Get-StackRoot
$cli = Join-Path $root "apps\openclaw\node_modules\.bin\openclaw.cmd"
$packageRoot = Join-Path $root "apps\openclaw\node_modules\openclaw"
$controlUiIndex = Join-Path $packageRoot "dist\control-ui\index.html"
$dashboardUrl = "http://$($settings.OpenClaw.GatewayHost):$($settings.OpenClaw.GatewayPort)/"
$gatewayUrl = "ws://$($settings.OpenClaw.GatewayHost):$($settings.OpenClaw.GatewayPort)"

if (-not (Test-Path -LiteralPath $cli)) {
    throw "OpenClaw CLI is unavailable. Run bootstrap.cmd."
}

Write-Host "OpenClaw verification"
Write-Host ("  Dashboard: {0}" -f $dashboardUrl)
Write-Host ("  Gateway:   {0}" -f $gatewayUrl)
Write-Host ("  UI assets: {0}" -f $controlUiIndex)

if (-not (Test-Path -LiteralPath $controlUiIndex)) {
    Write-Warning (
        "OpenClaw Control UI assets are missing. The gateway may run while the browser UI remains unavailable. " +
        "Reinstall OpenClaw with install scripts enabled."
    )
}
else {
    Write-Host "  UI assets: present"
}

Write-Host ""
Write-Host "Gateway RPC probe"
& $cli gateway status `
    --url $gatewayUrl `
    --token $secrets.OpenClawGatewayToken `
    --require-rpc `
    --timeout 10000

if ($LASTEXITCODE -ne 0) {
    throw ("OpenClaw RPC probe failed with exit code {0}." -f $LASTEXITCODE)
}

Write-Host ""
Write-Host "Dashboard HTTP probe"
try {
    $response = Invoke-WebRequest `
        -UseBasicParsing `
        -Uri $dashboardUrl `
        -TimeoutSec 10

    Write-Host ("  HTTP status: {0}" -f [int]$response.StatusCode)
    Write-Host ("  Content-Type: {0}" -f $response.Headers["Content-Type"])

    if ([int]$response.StatusCode -ne 200) {
        throw ("Unexpected dashboard HTTP status: {0}" -f $response.StatusCode)
    }
}
catch {
    throw ("OpenClaw dashboard probe failed: {0}" -f $_.Exception.Message)
}

if ($OpenBrowser) {
    $clipboard = Get-Command Set-Clipboard -ErrorAction SilentlyContinue
    if ($clipboard) {
        Set-Clipboard -Value $secrets.OpenClawGatewayToken
        Write-Host "Gateway token copied to the clipboard."
    }
    else {
        Write-Host ("Gateway token: {0}" -f $secrets.OpenClawGatewayToken)
    }

    Start-Process $dashboardUrl
    Write-Host "Opened the OpenClaw Control UI. Paste the gateway token if requested."
}

Write-Host ""
Write-Host "OpenClaw verification passed."
