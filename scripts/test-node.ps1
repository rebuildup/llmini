$ErrorActionPreference = "Stop"
. "$PSScriptRoot\lib\Common.ps1"

$nodeDirectory = Get-NodeDirectory
$node = Join-Path $nodeDirectory "node.exe"
$npmCli = Join-Path $nodeDirectory "node_modules\npm\bin\npm-cli.js"

Write-Host ("Node directory: {0}" -f $nodeDirectory)
Write-Host ("node.exe:      {0}" -f $node)
Write-Host ("npm-cli.js:    {0}" -f $npmCli)

if (-not (Test-Path -LiteralPath $node)) {
    throw ("node.exe is missing: {0}" -f $node)
}

if (-not (Test-Path -LiteralPath $npmCli)) {
    throw ("npm-cli.js is missing: {0}" -f $npmCli)
}

Unblock-PathBestEffort -Path $node
Unblock-PathBestEffort -Path $npmCli

Write-Host ""
Write-Host "node.exe --version"
& $node --version
Write-Host ("Exit code: {0}" -f $LASTEXITCODE)

Write-Host ""
Write-Host "node.exe npm-cli.js --version"
& $node $npmCli --version
Write-Host ("Exit code: {0}" -f $LASTEXITCODE)
