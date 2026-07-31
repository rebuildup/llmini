
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\lib\Common.ps1"

$prompt = @"
Write a TypeScript function that satisfies these requirements.
Remove duplicate strings, perform a stable sort by Unicode code point order,
exclude empty strings, and return the result. Briefly explain the complexity.
"@

& "$PSScriptRoot\test-api.ps1" -Prompt $prompt
