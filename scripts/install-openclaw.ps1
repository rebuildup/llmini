$ErrorActionPreference = "Stop"
. "$PSScriptRoot\lib\Common.ps1"

Initialize-StackDirectories
$settings = Get-StackSettings

if (-not $settings.OpenClaw.Enabled) {
    Write-Host "OpenClaw is disabled in settings."
    exit 0
}

$nodeDirectory = Get-NodeDirectory
$node = Join-Path $nodeDirectory "node.exe"
$npmCli = Join-Path $nodeDirectory "node_modules\npm\bin\npm-cli.js"

if (-not (Test-Path -LiteralPath $node) -or
    -not (Test-Path -LiteralPath $npmCli)) {
    throw (
        "Portable Node.js or npm is unavailable. Run download-node.ps1 first. Node directory: {0}" -f
        $nodeDirectory
    )
}

Unblock-PathBestEffort -Path $node
Unblock-PathBestEffort -Path $npmCli

$prefix = Join-Path (Get-StackRoot) "apps\openclaw"
Ensure-Directory $prefix

$env:PATH = "$nodeDirectory;$env:PATH"

& $node `
    $npmCli `
    install `
    --prefix $prefix `
    openclaw@latest `
    --no-audit `
    --no-fund

if ($LASTEXITCODE -ne 0) {
    throw (
        "OpenClaw npm installation failed with exit code {0}." -f
        $LASTEXITCODE
    )
}

$cli = Join-Path $prefix "node_modules\.bin\openclaw.cmd"

if (-not (Test-Path -LiteralPath $cli)) {
    throw ("OpenClaw CLI was not found at {0}" -f $cli)
}

Set-OpenClawEnvironment
& $cli --version

if ($LASTEXITCODE -ne 0) {
    throw (
        "OpenClaw CLI verification failed with exit code {0}." -f
        $LASTEXITCODE
    )
}

Write-Host ("OpenClaw installed at {0}" -f $prefix)
