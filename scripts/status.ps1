
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\lib\Common.ps1"

$settings = Get-StackSettings
$secrets = Get-StackSecrets

Write-Host "Root: $(Get-StackRoot)"
Write-Host ""

foreach ($name in @("llama-server", "openclaw-gateway", "hermes-gateway")) {
    $process = Get-ManagedProcess $name
    if ($process) {
        Write-Host ("{0,-20} running  PID={1} CPU={2:n1}s RAM={3:n0}MB" -f `
            $name, $process.Id, $process.CPU, ($process.WorkingSet64 / 1MB))
    }
    else {
        Write-Host ("{0,-20} stopped" -f $name)
    }
}

Write-Host ""
$headers = @{ Authorization = "Bearer $($secrets.LlamaApiKey)" }
try {
    $models = Invoke-RestMethod -Uri "$(Get-LlamaBaseUrl)/v1/models" -Headers $headers -TimeoutSec 3
    Write-Host "llama API: ready"
    $models.data | ForEach-Object { Write-Host "  model: $($_.id)" }
}
catch {
    Write-Host "llama API: unavailable"
}

try {
    $null = Invoke-WebRequest -UseBasicParsing -Uri "http://$($settings.Hermes.ApiHost):$($settings.Hermes.ApiPort)/health" -TimeoutSec 3
    Write-Host "Hermes API: ready"
}
catch {
    Write-Host "Hermes API: unavailable"
}

$nvidiaSmi = Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
if ($nvidiaSmi) {
    Write-Host ""
    Write-Host "GPU:"
    & $nvidiaSmi.Source --query-gpu=name,utilization.gpu,utilization.memory,memory.used,memory.total,power.draw --format=csv,noheader
}
