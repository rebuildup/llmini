$ErrorActionPreference = "Stop"
. "$PSScriptRoot\lib\Common.ps1"

$nodeDirectory = Get-NodeDirectory
$llamaDirectory = Get-LlamaCppDirectory

Write-Host ("Node.js directory:  {0}" -f $nodeDirectory)
Write-Host ("llama.cpp directory: {0}" -f $llamaDirectory)

$nodeExe = Join-Path $nodeDirectory "node.exe"
$npmCmd = Join-Path $nodeDirectory "npm.cmd"
$llamaServer = Join-Path $llamaDirectory "llama-server.exe"

if (Test-Path -LiteralPath $nodeExe) {
    & $nodeExe --version
}
else {
    Write-Warning ("node.exe is unavailable: {0}" -f $nodeExe)
}

if (Test-Path -LiteralPath $npmCmd) {
    & $npmCmd --version
}
else {
    Write-Warning ("npm.cmd is unavailable: {0}" -f $npmCmd)
}

if (Test-Path -LiteralPath $llamaServer) {
    & $llamaServer --version
}
else {
    Write-Warning ("llama-server.exe is unavailable: {0}" -f $llamaServer)
}
