param(
    [string]$Prompt = "Reply with exactly HERMES_OK."
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\lib\Common.ps1"

& "$PSScriptRoot\start-hermes.ps1"

$settings = Get-StackSettings
$secrets = Get-StackSecrets
$baseUrl = "http://$($settings.Hermes.ApiHost):$($settings.Hermes.ApiPort)"
$headers = @{ Authorization = "Bearer $($secrets.HermesApiKey)" }

Write-Host "Hermes Agent verification"
Write-Host ("  API base: {0}/v1" -f $baseUrl)
Write-Host "  Browser UI: none; Hermes exposes an OpenAI-compatible API."

Write-Host ""
Write-Host "Health probe"
$health = Invoke-RestMethod `
    -Method Get `
    -Uri "$baseUrl/health" `
    -Headers $headers `
    -TimeoutSec 10

Write-Host ("  Status: {0}" -f $health.status)
if ($health.status -ne "ok") {
    throw ("Unexpected Hermes health status: {0}" -f $health.status)
}

Write-Host ""
Write-Host "Capability probe"
$capabilities = Invoke-RestMethod `
    -Method Get `
    -Uri "$baseUrl/v1/capabilities" `
    -Headers $headers `
    -TimeoutSec 10

Write-Host ("  Platform: {0}" -f $capabilities.platform)
Write-Host ("  Model:    {0}" -f $capabilities.model)

Write-Host ""
Write-Host "Model discovery"
$models = Invoke-RestMethod `
    -Method Get `
    -Uri "$baseUrl/v1/models" `
    -Headers $headers `
    -TimeoutSec 10

$modelId = $null
if ($models.data -and $models.data.Count -gt 0) {
    $modelId = [string]$models.data[0].id
}
if (-not $modelId) {
    $modelId = "hermes-agent"
}
Write-Host ("  Advertised model: {0}" -f $modelId)

Write-Host ""
Write-Host "End-to-end agent request"
$body = @{
    model = $modelId
    messages = @(
        @{
            role = "user"
            content = $Prompt
        }
    )
    max_tokens = 64
    temperature = 0
    stream = $false
} | ConvertTo-Json -Depth 8

$response = Invoke-RestMethod `
    -Method Post `
    -Uri "$baseUrl/v1/chat/completions" `
    -Headers $headers `
    -ContentType "application/json; charset=utf-8" `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) `
    -TimeoutSec 600

$content = [string]$response.choices[0].message.content
Write-Host ("  Response: {0}" -f $content)

if (-not $content.Trim()) {
    throw "Hermes returned an empty response."
}

Write-Host ""
Write-Host "Hermes Agent verification passed."
