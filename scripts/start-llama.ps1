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

$existingServer = Get-ManagedProcess "llama-server"
if ($existingServer) {
    $propsUrl = "$(Get-LlamaBaseUrl)/props"
    $propsHeaders = @{ Authorization = "Bearer $($secrets.LlamaApiKey)" }
    $restartExistingServer = $false

    try {
        $props = Invoke-RestMethod `
            -Method Get `
            -Uri $propsUrl `
            -Headers $propsHeaders `
            -TimeoutSec 5

        $runningContext = [int]$props.default_generation_settings.n_ctx

        if ($runningContext -ne [int]$settings.Model.ContextLength) {
            Write-Host (
                "Restarting llama-server: running context {0}, configured context {1}." -f
                $runningContext,
                $settings.Model.ContextLength
            )
            $restartExistingServer = $true
        }
    }
    catch {
        Write-Warning (
            "The managed llama-server did not answer /props and will be restarted: {0}" -f
            $_.Exception.Message
        )
        $restartExistingServer = $true
    }

    if ($restartExistingServer) {
        Stop-ManagedProcess "hermes-gateway"
        Stop-ManagedProcess "openclaw-gateway"
        Stop-ManagedProcess "llama-server"
    }
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
