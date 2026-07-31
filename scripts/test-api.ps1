param(
    [string]$Prompt = "Introduce yourself in exactly one short sentence."
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\lib\Common.ps1"

& "$PSScriptRoot\start-llama.ps1"
$settings = Get-StackSettings
$secrets = Get-StackSecrets

$body = @{
    model = $settings.Model.Id
    messages = @(
        @{
            role = "user"
            content = $Prompt
        }
    )
    max_tokens = 128
    temperature = 0.2
    stream = $false
} | ConvertTo-Json -Depth 8

$response = Invoke-RestMethod `
    -Method Post `
    -Uri "$(Get-LlamaBaseUrl)/v1/chat/completions" `
    -Headers @{ Authorization = "Bearer $($secrets.LlamaApiKey)" } `
    -ContentType "application/json; charset=utf-8" `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) `
    -TimeoutSec 300

Write-Host $response.choices[0].message.content
if ($response.timings) {
    Write-Host ""
    Write-Host ("Prompt: {0:n1} tok/s" -f $response.timings.prompt_per_second)
    Write-Host ("Output: {0:n1} tok/s" -f $response.timings.predicted_per_second)
}
