param(
    [Parameter(Position = 0)]
    [ValidateSet(
        "bootstrap", "start", "stop", "status", "test", "benchmark",
        "update", "register-startup", "unregister-startup",
        "cleanup-legacy", "validate"
    )]
    [string]$Action = "status",

    [string]$Prompt = "Reply with exactly: llmini is ready.",
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $root "config\settings.psd1"
$stateDir = Join-Path $root "state"
$binDir = Join-Path $root "bin"
$cacheDir = Join-Path $root "cache"
$modelDir = Join-Path $root "models"
$logDir = Join-Path $root "logs"
$pidPath = Join-Path $stateDir "llama-server.pid"
$runtimePointer = Join-Path $stateDir "runtime.txt"

function Ensure-Directory([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Initialize-Directories {
    foreach ($path in @($stateDir, $binDir, $cacheDir, $modelDir, $logDir)) {
        Ensure-Directory $path
    }
}

function Get-Settings {
    if (-not (Test-Path -LiteralPath $configPath)) {
        throw ("Settings not found: {0}" -f $configPath)
    }
    return (Import-PowerShellDataFile -LiteralPath $configPath)
}

function Get-ServerBaseUrl {
    $settings = Get-Settings
    return "http://$($settings.Server.Host):$($settings.Server.Port)"
}

function Get-RuntimeDirectory {
    if (Test-Path -LiteralPath $runtimePointer) {
        $stored = [System.IO.File]::ReadAllText($runtimePointer).Trim()
        if ($stored) {
            $path = if ([System.IO.Path]::IsPathRooted($stored)) {
                $stored
            } else {
                Join-Path $root $stored
            }
            if (Test-Path -LiteralPath (Join-Path $path "llama-server.exe")) {
                return $path
            }
        }
    }
    return $null
}

function Set-RuntimeDirectory([string]$Directory) {
    $rootFull = [System.IO.Path]::GetFullPath($root).TrimEnd("\") + "\"
    $dirFull = [System.IO.Path]::GetFullPath($Directory)
    $stored = $dirFull
    if ($dirFull.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        $stored = $dirFull.Substring($rootFull.Length)
    }
    [System.IO.File]::WriteAllText($runtimePointer, $stored + [Environment]::NewLine)
}

function Download-File([string]$Url, [string]$Destination, [string]$Sha256 = "") {
    Ensure-Directory (Split-Path -Parent $Destination)
    if (Test-Path -LiteralPath $Destination) {
        if (-not $Sha256 -or (Get-FileHash -Algorithm SHA256 $Destination).Hash.ToLowerInvariant() -eq $Sha256.ToLowerInvariant()) {
            Write-Host ("Already downloaded: {0}" -f $Destination)
            return
        }
        Remove-Item -LiteralPath $Destination -Force
    }
    & curl.exe -L --fail --retry 5 --retry-delay 2 -o $Destination $Url
    if ($LASTEXITCODE -ne 0) { throw ("Download failed: {0}" -f $Url) }
    if ($Sha256) {
        $actual = (Get-FileHash -Algorithm SHA256 $Destination).Hash.ToLowerInvariant()
        if ($actual -ne $Sha256.ToLowerInvariant()) {
            Remove-Item -LiteralPath $Destination -Force
            throw ("SHA256 mismatch for {0}" -f $Destination)
        }
    }
}

function Install-LlamaCpp([switch]$ForceInstall) {
    Initialize-Directories
    $release = Invoke-RestMethod -Headers @{ "User-Agent" = "llmini" } -Uri "https://api.github.com/repos/ggml-org/llama.cpp/releases/latest"
    $engine = $release.assets | Where-Object { $_.name -match "^llama-.*-bin-win-cuda-12\.4-x64\.zip$" } | Select-Object -First 1
    $cuda = $release.assets | Where-Object { $_.name -eq "cudart-llama-bin-win-cuda-12.4-x64.zip" } | Select-Object -First 1
    if (-not $engine -or -not $cuda) { throw "Required Windows CUDA 12.4 release assets were not found." }

    $safeTag = $release.tag_name -replace "[^A-Za-z0-9._-]", "-"
    $target = Join-Path $binDir ("llama.cpp-{0}" -f $safeTag)
    $server = Join-Path $target "llama-server.exe"
    if (-not $ForceInstall -and (Test-Path -LiteralPath $server)) {
        Set-RuntimeDirectory $target
        Write-Host ("Using llama.cpp {0}" -f $release.tag_name)
        return
    }

    $engineZip = Join-Path $cacheDir $engine.name
    $cudaZip = Join-Path $cacheDir $cuda.name
    Download-File $engine.browser_download_url $engineZip
    Download-File $cuda.browser_download_url $cudaZip

    $stage = Join-Path $cacheDir ("stage-{0}" -f [Guid]::NewGuid().ToString("N"))
    $engineStage = Join-Path $stage "engine"
    $cudaStage = Join-Path $stage "cuda"
    Ensure-Directory $engineStage
    Ensure-Directory $cudaStage
    Expand-Archive -LiteralPath $engineZip -DestinationPath $engineStage -Force
    Expand-Archive -LiteralPath $cudaZip -DestinationPath $cudaStage -Force

    $foundServer = Get-ChildItem -LiteralPath $engineStage -Filter "llama-server.exe" -Recurse | Select-Object -First 1
    if (-not $foundServer) { throw "llama-server.exe was not found in the release archive." }
    $payload = $foundServer.DirectoryName
    Get-ChildItem -LiteralPath $cudaStage -File -Recurse | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $payload $_.Name) -Force
    }

    if (Test-Path -LiteralPath $target) {
        $target = Join-Path $binDir ("llama.cpp-{0}-{1}" -f $safeTag, [Guid]::NewGuid().ToString("N").Substring(0, 8))
    }
    Move-Item -LiteralPath $payload -Destination $target
    Set-RuntimeDirectory $target
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    & (Join-Path $target "llama-server.exe") --version
}

function Install-Model {
    $settings = Get-Settings
    $destination = Join-Path $modelDir $settings.Model.FileName
    Download-File $settings.Model.Url $destination $settings.Model.Sha256
}

function Get-ManagedProcess {
    if (-not (Test-Path -LiteralPath $pidPath)) { return $null }
    $managedPid = [int]([System.IO.File]::ReadAllText($pidPath).Trim())
    $process = Get-Process -Id $managedPid -ErrorAction SilentlyContinue
    if (-not $process) { Remove-Item -LiteralPath $pidPath -Force -ErrorAction SilentlyContinue }
    return $process
}

function Stop-Server {
    $process = Get-ManagedProcess
    if (-not $process) { Write-Host "llama-server is not running."; return }
    & taskkill.exe /PID $process.Id /T /F | Out-Null
    Remove-Item -LiteralPath $pidPath -Force -ErrorAction SilentlyContinue
    Write-Host "llama-server stopped."
}

function Start-Server {
    Initialize-Directories
    $existing = Get-ManagedProcess
    if ($existing) { Write-Host ("llama-server is already running (PID {0})." -f $existing.Id); return }

    $settings = Get-Settings
    $runtime = Get-RuntimeDirectory
    if (-not $runtime) { throw "llama.cpp is not installed. Run bootstrap.cmd." }
    $server = Join-Path $runtime "llama-server.exe"
    $model = Join-Path $modelDir $settings.Model.FileName
    if (-not (Test-Path -LiteralPath $model)) { throw "Model is not installed. Run bootstrap.cmd." }

    $arguments = @(
        "--model", $model,
        "--alias", $settings.Model.Id,
        "--host", $settings.Server.Host,
        "--port", [string]$settings.Server.Port,
        "--ctx-size", [string]$settings.Model.ContextLength,
        "--n-gpu-layers", [string]$settings.Server.GpuLayers,
        "--threads", [string]$settings.Server.Threads,
        "--threads-batch", [string]$settings.Server.BatchThreads,
        "--threads-http", [string]$settings.Server.HttpThreads,
        "--parallel", [string]$settings.Server.Parallel,
        "--batch-size", [string]$settings.Server.BatchSize,
        "--ubatch-size", [string]$settings.Server.MicroBatchSize,
        "--cache-type-k", $settings.Server.CacheTypeK,
        "--cache-type-v", $settings.Server.CacheTypeV,
        "--poll", [string]$settings.Server.Poll,
        "--jinja", "--cache-prompt", "--no-webui"
    )
    if ($settings.Server.FlashAttention) { $arguments += @("--flash-attn", "on") }

    $stdout = Join-Path $logDir "llama-server.out.log"
    $stderr = Join-Path $logDir "llama-server.err.log"
    $process = Start-Process -FilePath $server -ArgumentList $arguments -WorkingDirectory $runtime -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
    try { $process.PriorityClass = $settings.Server.ProcessPriority } catch {}
    [System.IO.File]::WriteAllText($pidPath, [string]$process.Id)

    $deadline = (Get-Date).AddMinutes(4)
    do {
        try {
            Invoke-RestMethod -Uri "$(Get-ServerBaseUrl)/health" -TimeoutSec 3 | Out-Null
            Write-Host ("llama-server ready: {0}/v1" -f (Get-ServerBaseUrl))
            return
        } catch { Start-Sleep -Milliseconds 500 }
    } while ((Get-Date) -lt $deadline)
    throw ("llama-server did not become ready. See {0}" -f $stderr)
}

function Test-Api([string]$UserPrompt) {
    Start-Server
    $settings = Get-Settings
    $body = @{
        model = $settings.Model.Id
        messages = @(@{ role = "user"; content = $UserPrompt })
        max_tokens = [int]$settings.Model.MaxTokens
        temperature = 0.2
        stream = $false
    } | ConvertTo-Json -Depth 6
    $response = Invoke-RestMethod -Method Post -Uri "$(Get-ServerBaseUrl)/v1/chat/completions" -ContentType "application/json" -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 600
    Write-Host $response.choices[0].message.content
    if ($response.timings) {
        Write-Host ("Prompt: {0:n1} tok/s" -f $response.timings.prompt_per_second)
        Write-Host ("Output: {0:n1} tok/s" -f $response.timings.predicted_per_second)
    }
}

function Show-Status {
    $process = Get-ManagedProcess
    if ($process) { Write-Host ("llama-server: running, PID {0}, RAM {1:n0} MB" -f $process.Id, ($process.WorkingSet64 / 1MB)) }
    else { Write-Host "llama-server: stopped" }
    try {
        $models = Invoke-RestMethod -Uri "$(Get-ServerBaseUrl)/v1/models" -TimeoutSec 3
        Write-Host ("API: ready, model {0}" -f $models.data[0].id)
    } catch { Write-Host "API: unavailable" }
    $nvidia = Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
    if ($nvidia) {
        & $nvidia.Source --query-gpu=name,utilization.gpu,memory.used,memory.total,power.draw --format=csv,noheader
    }
}

function Validate-Files {
    $files = @($PSCommandPath, $configPath)
    $failed = $false
    foreach ($file in $files) {
        $tokens = $null; $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tokens, [ref]$errors) | Out-Null
        foreach ($error in $errors) {
            $failed = $true
            Write-Host ("{0}:{1}:{2}: {3}" -f $file, $error.Extent.StartLineNumber, $error.Extent.StartColumnNumber, $error.Message) -ForegroundColor Red
        }
    }
    if ($failed) { exit 1 }
    $settings = Get-Settings
    if (-not $settings.Model.Id -or -not $settings.Server.Port) { throw "Invalid settings." }
    Write-Host "Validation passed."
}

function Register-Startup {
    $taskName = "llmini"
    $startCmd = Join-Path $root "start.cmd"
    $actionObject = New-ScheduledTaskAction -Execute $env:ComSpec -Argument ("/d /c `"{0}`"" -f $startCmd) -WorkingDirectory $root
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Days 3650) -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName $taskName -Action $actionObject -Trigger $trigger -Settings $taskSettings -Description "Start llmini llama-server at logon." -Force | Out-Null
    Write-Host "Startup task registered: llmini"
}

function Unregister-Startup {
    $task = Get-ScheduledTask -TaskName "llmini" -ErrorAction SilentlyContinue
    if ($task) { Unregister-ScheduledTask -TaskName "llmini" -Confirm:$false; Write-Host "Startup task removed." }
    else { Write-Host "Startup task is not registered." }
}

function Cleanup-Legacy {
    foreach ($name in @("openclaw-gateway", "hermes-gateway", "llama-server")) {
        $oldPid = Join-Path $root ("state\pids\{0}.pid" -f $name)
        if (Test-Path -LiteralPath $oldPid) {
            try { & taskkill.exe /PID ([int]([System.IO.File]::ReadAllText($oldPid).Trim())) /T /F | Out-Null } catch {}
        }
    }
    try {
        $settings = Get-Settings
        $listeners = Get-NetTCPConnection -LocalPort $settings.Server.Port -State Listen -ErrorAction SilentlyContinue
        foreach ($listener in $listeners) {
            $listenerProcess = Get-Process -Id $listener.OwningProcess -ErrorAction SilentlyContinue
            if ($listenerProcess -and $listenerProcess.ProcessName -like "llama-server*") {
                & taskkill.exe /PID $listenerProcess.Id /T /F | Out-Null
            }
        }
    }
    catch {}

    $legacyTask = Get-ScheduledTask -TaskName "Local AI Stack" -ErrorAction SilentlyContinue
    if ($legacyTask) { Unregister-ScheduledTask -TaskName "Local AI Stack" -Confirm:$false }

    $targets = @(
        "apps", "tools", "workspace", "nixos", "downloads",
        "state\openclaw", "state\hermes", "state\pids", "state\manifests",
        "logs\openclaw-gateway.out.log", "logs\openclaw-gateway.err.log",
        "logs\hermes-gateway.out.log", "logs\hermes-gateway.err.log",
        "TROUBLESHOOTING.md", "hermes.cmd", "install-hermes.cmd",
        "open-openclaw.cmd", "openclaw.cmd", "repair-integrations.cmd",
        "runtime-paths.cmd", "test-hermes.cmd", "test-node.cmd",
        "test-openclaw.cmd", "update-node.cmd", "verify.cmd",
        "config\settings.example.psd1", "scripts\lib",
        "scripts\benchmark.ps1", "scripts\bootstrap.ps1",
        "scripts\configure-agents.ps1", "scripts\download-llama-cpp.ps1",
        "scripts\download-model.ps1", "scripts\download-node.ps1",
        "scripts\install-hermes.ps1", "scripts\install-openclaw.ps1",
        "scripts\invoke-hermes.ps1", "scripts\invoke-openclaw.ps1",
        "scripts\open-openclaw.ps1", "scripts\register-startup.ps1",
        "scripts\repair-integrations.ps1", "scripts\runtime-paths.ps1",
        "scripts\start-all.ps1", "scripts\start-hermes.ps1",
        "scripts\start-llama.ps1", "scripts\start-openclaw.ps1",
        "scripts\status.ps1", "scripts\stop-all.ps1",
        "scripts\test-api.ps1", "scripts\test-hermes.ps1",
        "scripts\test-node.ps1", "scripts\test-openclaw.ps1",
        "scripts\unregister-startup.ps1", "scripts\update.ps1",
        "scripts\validate.ps1", "scripts\verify.ps1",
        "apps\.gitkeep", "downloads\.gitkeep", "tools\.gitkeep",
        "workspace\.gitkeep", "models\.gitkeep", "logs\.gitkeep",
        "state\.gitkeep"
    )
    foreach ($relative in $targets) {
        $path = Join-Path $root $relative
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction Continue
        }
    }
    Get-ChildItem -LiteralPath (Join-Path $root "cache") -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "node|hermes|openclaw" } | Remove-Item -Recurse -Force -ErrorAction Continue
    Get-ChildItem -LiteralPath (Join-Path $root "downloads") -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "node|hermes|openclaw" } | Remove-Item -Recurse -Force -ErrorAction Continue
    Write-Host "Legacy agent files and obsolete repository files were removed."
}

switch ($Action) {
    "bootstrap" {
        Validate-Files
        Initialize-Directories
        Install-LlamaCpp -ForceInstall:$Force
        Install-Model
        Start-Server
        Test-Api $Prompt
    }
    "start" { Start-Server }
    "stop" { Stop-Server }
    "status" { Show-Status }
    "test" { Test-Api $Prompt }
    "benchmark" { Test-Api "Write a compact TypeScript function that removes duplicates and sorts strings by Unicode code point order. Explain complexity in two sentences." }
    "update" { Stop-Server; Install-LlamaCpp -ForceInstall:$Force; Start-Server }
    "register-startup" { Register-Startup }
    "unregister-startup" { Unregister-Startup }
    "cleanup-legacy" { Cleanup-Legacy }
    "validate" { Validate-Files }
}
