
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\lib\Common.ps1"

Initialize-StackDirectories
$settings = Get-StackSettings
$secrets = Get-StackSecrets
$root = Get-StackRoot

$llamaDirectory = Get-LlamaCppDirectory

$server = Join-Path $llamaDirectory "llama-server.exe"
$model = Join-Path $root "models\$($settings.Model.FileName)"

if (-not (Test-Path $server)) {
    throw "llama-server.exe is missing. Run bootstrap.cmd."
}
if (-not (Test-Path $model)) {
    throw "Model is missing: $model. Run bootstrap.cmd."
}

$serverArguments = @(
    "--model", $model,
    "--alias", $settings.Model.Id,
    "--host", $settings.Llama.Host,
    "--port", [string]$settings.Llama.Port,
    "--ctx-size", [string]$settings.Model.ContextLength,
    "--n-gpu-layers", [string]$settings.Llama.GpuLayers,
    "--threads", [string]$settings.Llama.Threads,
    "--threads-batch", [string]$settings.Llama.BatchThreads,
    "--threads-http", [string]$settings.Llama.HttpThreads,
    "--parallel", [string]$settings.Llama.Parallel,
    "--batch-size", [string]$settings.Llama.BatchSize,
    "--ubatch-size", [string]$settings.Llama.MicroBatchSize,
    "--cache-type-k", $settings.Llama.CacheTypeK,
    "--cache-type-v", $settings.Llama.CacheTypeV,
    "--poll", [string]$settings.Llama.Poll,
    "--prio", "-1",
    "--api-key", $secrets.LlamaApiKey,
    "--jinja",
    "--cache-prompt",
    "--metrics",
    "--no-webui"
)

if ($settings.Llama.FlashAttention) {
    $serverArguments += @("--flash-attn", "on")
}

Start-ManagedProcess `
    -Name "llama-server" `
    -FilePath $server `
    -ArgumentList $serverArguments `
    -WorkingDirectory (Split-Path -Parent $server) `
    -Priority $settings.Llama.ProcessPriority | Out-Null

$headers = @{ Authorization = "Bearer $($secrets.LlamaApiKey)" }
$url = "$(Get-LlamaBaseUrl)/v1/models"
if (-not (Wait-HttpEndpoint -Url $url -Headers $headers -TimeoutSeconds 240)) {
    throw "llama-server did not become ready. Check logs\llama-server.err.log"
}

Write-Host "llama-server is ready: $(Get-LlamaBaseUrl)/v1"
