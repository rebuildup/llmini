
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\lib\Common.ps1"

Stop-ManagedProcess "hermes-gateway"
Stop-ManagedProcess "openclaw-gateway"
Stop-ManagedProcess "llama-server"
