Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:StackRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

function Import-CompatiblePowerShellDataFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw ("Data file not found: {0}" -f $Path)
    }

    $nativeCommand = Get-Command Import-PowerShellDataFile -ErrorAction SilentlyContinue
    if ($nativeCommand) {
        return Import-PowerShellDataFile -LiteralPath $Path
    }

    $content = [System.IO.File]::ReadAllText($Path)
    $scriptBlock = [System.Management.Automation.ScriptBlock]::Create($content)
    $result = & $scriptBlock

    if ($result -isnot [hashtable]) {
        throw ("Data file did not return a hashtable: {0}" -f $Path)
    }

    return $result
}



function Get-StackRoot {
    return $script:StackRoot
}

function Ensure-StackSettingsFile {
    $configDirectory = Join-Path $script:StackRoot "config"
    $settingsPath = Join-Path $configDirectory "settings.psd1"
    $examplePath = Join-Path $configDirectory "settings.example.psd1"

    if (Test-Path -LiteralPath $settingsPath) {
        return $settingsPath
    }

    if (-not (Test-Path -LiteralPath $examplePath)) {
        throw ("Settings and settings template are missing: {0}" -f $configDirectory)
    }

    if (-not (Test-Path -LiteralPath $configDirectory)) {
        New-Item -ItemType Directory -Path $configDirectory -Force | Out-Null
    }

    Copy-Item -LiteralPath $examplePath -Destination $settingsPath -Force
    Write-Host ("Created default settings file: {0}" -f $settingsPath)
    return $settingsPath
}

function Get-StackSettings {
    $path = Ensure-StackSettingsFile
    return Import-CompatiblePowerShellDataFile -Path $path
}

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Resolve-StackRelativePath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return Join-Path $script:StackRoot $Path
}

function Get-RuntimeDirectoryFromPointer {
    param(
        [Parameter(Mandatory = $true)][string]$PointerFileName,
        [Parameter(Mandatory = $true)][string]$LegacyRelativePath
    )

    $pointerPath = Join-Path $script:StackRoot (
        "state\manifests\{0}" -f $PointerFileName
    )

    if (Test-Path -LiteralPath $pointerPath) {
        $storedPath = (
            [System.IO.File]::ReadAllText($pointerPath)
        ).Trim()

        if ($storedPath) {
            $resolvedPath = Resolve-StackRelativePath -Path $storedPath

            if (Test-Path -LiteralPath $resolvedPath) {
                return $resolvedPath
            }
        }
    }

    return Join-Path $script:StackRoot $LegacyRelativePath
}

function Set-RuntimeDirectoryPointer {
    param(
        [Parameter(Mandatory = $true)][string]$PointerFileName,
        [Parameter(Mandatory = $true)][string]$Directory
    )

    Initialize-StackDirectories

    $rootFullPath = [System.IO.Path]::GetFullPath($script:StackRoot)
    $directoryFullPath = [System.IO.Path]::GetFullPath($Directory)
    $storedPath = $directoryFullPath

    $rootPrefix = $rootFullPath.TrimEnd("\") + "\"

    if ($directoryFullPath.StartsWith(
        $rootPrefix,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        $storedPath = $directoryFullPath.Substring($rootPrefix.Length)
    }

    $pointerPath = Join-Path $script:StackRoot (
        "state\manifests\{0}" -f $PointerFileName
    )

    [System.IO.File]::WriteAllText(
        $pointerPath,
        $storedPath + [Environment]::NewLine,
        (New-Object System.Text.UTF8Encoding($false))
    )
}

function Get-NodeDirectory {
    return Get-RuntimeDirectoryFromPointer `
        -PointerFileName "node-directory.txt" `
        -LegacyRelativePath "tools\node"
}

function Get-LlamaCppDirectory {
    return Get-RuntimeDirectoryFromPointer `
        -PointerFileName "llama-cpp-directory.txt" `
        -LegacyRelativePath "tools\llama-cpp"
}

function New-StagingDirectory {
    param([Parameter(Mandatory = $true)][string]$Prefix)

    Initialize-StackDirectories

    $safePrefix = $Prefix -replace "[^A-Za-z0-9._-]", "-"
    $name = "{0}-{1}" -f (
        $safePrefix,
        [Guid]::NewGuid().ToString("N")
    )
    $path = Join-Path $script:StackRoot ("downloads\staging\{0}" -f $name)

    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}

function Remove-DirectoryTreeBestEffort {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    try {
        Remove-DirectoryTree -Path $Path
    }
    catch {
        Write-Warning (
            "Temporary directory cleanup was skipped: {0}. Details: {1}" -f
            $Path,
            $_.Exception.Message
        )
    }
}

function Unblock-PathBestEffort {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [switch]$Recurse
    )

    $unblockCommand = Get-Command Unblock-File -ErrorAction SilentlyContinue

    if (-not $unblockCommand) {
        return
    }

    try {
        if ($Recurse -and (Test-Path -LiteralPath $Path -PathType Container)) {
            Get-ChildItem -LiteralPath $Path -File -Recurse -Force |
                ForEach-Object {
                    Unblock-File -LiteralPath $_.FullName -ErrorAction SilentlyContinue
                }
        }
        elseif (Test-Path -LiteralPath $Path -PathType Leaf) {
            Unblock-File -LiteralPath $Path -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-Warning (
            "Could not remove file blocking metadata from {0}: {1}" -f
            $Path,
            $_.Exception.Message
        )
    }
}

function Remove-DirectoryTree {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [int]$RetryCount = 5
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $commandProcessor = $env:ComSpec

    if (-not $commandProcessor) {
        $commandProcessor = Join-Path $env:SystemRoot "System32\cmd.exe"
    }

    $lastError = $null

    for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
        try {
            [System.IO.Directory]::Delete($fullPath, $true)
        }
        catch {
            $lastError = $_
        }

        if (-not (Test-Path -LiteralPath $fullPath)) {
            return
        }

        try {
            $removeCommand = 'rd /s /q "{0}"' -f $fullPath
            & $commandProcessor /d /c $removeCommand | Out-Null
        }
        catch {
            $lastError = $_
        }

        if (-not (Test-Path -LiteralPath $fullPath)) {
            return
        }

        Start-Sleep -Milliseconds (250 * $attempt)
    }

    $message = "Unknown directory removal error."
    if ($lastError) {
        $message = $lastError.Exception.Message
    }

    throw (
        "Could not remove directory after {0} attempts: {1}. Last error: {2}" -f
        $RetryCount,
        $fullPath,
        $message
    )
}

function Install-DirectoryAtomically {
    param(
        [Parameter(Mandatory = $true)][string]$SourceDirectory,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    if (-not (Test-Path -LiteralPath $SourceDirectory)) {
        throw ("Source directory not found: {0}" -f $SourceDirectory)
    }

    $destinationParent = Split-Path -Parent $Destination
    Ensure-Directory $destinationParent

    $backup = $null

    if (Test-Path -LiteralPath $Destination) {
        $backup = "{0}.backup-{1}-{2}" -f (
            $Destination,
            (Get-Date -Format "yyyyMMddHHmmss"),
            $PID
        )

        try {
            Move-Item -LiteralPath $Destination -Destination $backup
        }
        catch {
            throw (
                "Could not move the existing installation out of the way: {0}. " +
                "Stop processes using it and retry. Details: {1}" -f
                $Destination,
                $_.Exception.Message
            )
        }
    }

    try {
        Move-Item -LiteralPath $SourceDirectory -Destination $Destination
    }
    catch {
        if ($backup -and (Test-Path -LiteralPath $backup) -and
            -not (Test-Path -LiteralPath $Destination)) {
            Move-Item -LiteralPath $backup -Destination $Destination
        }

        throw
    }

    if ($backup -and (Test-Path -LiteralPath $backup)) {
        try {
            Remove-DirectoryTree -Path $backup
        }
        catch {
            Write-Warning (
                "The previous installation remains at {0}. It can be removed later. Details: {1}" -f
                $backup,
                $_.Exception.Message
            )
        }
    }
}

function Initialize-StackDirectories {
    foreach ($relative in @(
        "apps", "tools", "models", "downloads", "state",
        "state\pids", "state\manifests", "workspace",
        "workspace\openclaw", "workspace\hermes", "logs"
    )) {
        Ensure-Directory (Join-Path $script:StackRoot $relative)
    }
}

function New-RandomHex {
    param([int]$Bytes = 32)
    $buffer = New-Object byte[] $Bytes
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $rng.GetBytes($buffer)
    }
    finally {
        $rng.Dispose()
    }
    return -join ($buffer | ForEach-Object { $_.ToString("x2") })
}

function Get-StackSecrets {
    Initialize-StackDirectories
    $path = Join-Path $script:StackRoot "state\secrets.psd1"
    if (-not (Test-Path $path)) {
        $llamaKey = New-RandomHex 24
        $hermesKey = New-RandomHex 24
        $gatewayToken = New-RandomHex 32
        $content = @"
@{
    LlamaApiKey         = "$llamaKey"
    HermesApiKey        = "$hermesKey"
    OpenClawGatewayToken = "$gatewayToken"
}
"@
        [System.IO.File]::WriteAllText($path, $content, (New-Object System.Text.UTF8Encoding($false)))
    }
    return Import-CompatiblePowerShellDataFile -Path $path
}

function Invoke-FileDownload {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$Destination,
        [string]$ExpectedSha256 = ""
    )

    Ensure-Directory (Split-Path -Parent $Destination)

    if (Test-Path $Destination) {
        if ($ExpectedSha256) {
            $current = (Get-FileHash -Algorithm SHA256 $Destination).Hash.ToLowerInvariant()
            if ($current -eq $ExpectedSha256.ToLowerInvariant()) {
                Write-Host "Already downloaded: $Destination"
                return
            }
            Write-Warning "Hash mismatch. Downloading again: $Destination"
            Remove-Item $Destination -Force
        }
        else {
            Write-Host "Already downloaded: $Destination"
            return
        }
    }

    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($curl) {
        Write-Host "Downloading: $Url"
        & $curl.Source -L --fail --retry 5 --retry-delay 2 -C - -o $Destination $Url
        if ($LASTEXITCODE -ne 0) {
            throw "curl failed with exit code $LASTEXITCODE"
        }
    }
    else {
        Write-Host "Downloading with Invoke-WebRequest: $Url"
        Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Destination
    }

    if ($ExpectedSha256) {
        $actual = (Get-FileHash -Algorithm SHA256 $Destination).Hash.ToLowerInvariant()
        if ($actual -ne $ExpectedSha256.ToLowerInvariant()) {
            Remove-Item $Destination -Force -ErrorAction SilentlyContinue
            throw "SHA256 mismatch for $Destination`nExpected: $ExpectedSha256`nActual:   $actual"
        }
    }
}

function Expand-ZipClean {
    param(
        [Parameter(Mandatory = $true)][string]$ZipPath,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    if (Test-Path -LiteralPath $Destination) {
        Remove-DirectoryTree -Path $Destination
    }

    Ensure-Directory $Destination
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $Destination -Force
}

function Wait-HttpEndpoint {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [hashtable]$Headers = @{},
        [int]$TimeoutSeconds = 180
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        try {
            Invoke-RestMethod -Method Get -Uri $Url -Headers $Headers -TimeoutSec 5 | Out-Null
            return $true
        }
        catch {
            Start-Sleep -Milliseconds 750
        }
    } while ((Get-Date) -lt $deadline)
    return $false
}

function Wait-TcpPort {
    param(
        [Parameter(Mandatory = $true)][string]$HostName,
        [Parameter(Mandatory = $true)][int]$Port,
        [int]$TimeoutSeconds = 90
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $client = New-Object System.Net.Sockets.TcpClient
        try {
            $async = $client.BeginConnect($HostName, $Port, $null, $null)
            if ($async.AsyncWaitHandle.WaitOne(750, $false) -and $client.Connected) {
                $client.EndConnect($async)
                return $true
            }
        }
        catch {
        }
        finally {
            $client.Close()
        }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)
    return $false
}

function Get-PidPath {
    param([Parameter(Mandatory = $true)][string]$Name)
    return Join-Path $script:StackRoot "state\pids\$Name.pid"
}

function Get-ManagedProcess {
    param([Parameter(Mandatory = $true)][string]$Name)
    $pidPath = Get-PidPath $Name
    if (-not (Test-Path $pidPath)) {
        return $null
    }

    $managedPid = [int](Get-Content $pidPath -Raw).Trim()
    $process = Get-Process -Id $managedPid -ErrorAction SilentlyContinue
    if (-not $process) {
        Remove-Item $pidPath -Force -ErrorAction SilentlyContinue
        return $null
    }
    return $process
}

function Start-ManagedProcess {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [string]$Priority = "BelowNormal"
    )

    Initialize-StackDirectories
    $existing = Get-ManagedProcess $Name
    if ($existing) {
        Write-Host "$Name is already running (PID $($existing.Id))."
        return $existing
    }

    $outLog = Join-Path $script:StackRoot "logs\$Name.out.log"
    $errLog = Join-Path $script:StackRoot "logs\$Name.err.log"

    $process = Start-Process `
        -FilePath $FilePath `
        -ArgumentList $ArgumentList `
        -WorkingDirectory $WorkingDirectory `
        -WindowStyle Hidden `
        -RedirectStandardOutput $outLog `
        -RedirectStandardError $errLog `
        -PassThru

    try {
        $process.PriorityClass = $Priority
    }
    catch {
        Write-Warning ("Could not set process priority for {0}: {1}" -f $Name, $_.Exception.Message)
    }

    [System.IO.File]::WriteAllText((Get-PidPath $Name), [string]$process.Id)
    Write-Host "Started $Name (PID $($process.Id))."
    return $process
}

function Stop-ManagedProcess {
    param([Parameter(Mandatory = $true)][string]$Name)

    $process = Get-ManagedProcess $Name
    if (-not $process) {
        Write-Host "$Name is not running."
        return
    }

    & taskkill.exe /PID $process.Id /T /F | Out-Null
    Remove-Item (Get-PidPath $Name) -Force -ErrorAction SilentlyContinue
    Write-Host "Stopped $Name."
}

function Set-OpenClawEnvironment {
    $settings = Get-StackSettings
    $secrets = Get-StackSecrets
    $nodeDir = Get-NodeDirectory
    $stateDir = Join-Path $script:StackRoot "state\openclaw"

    $env:PATH = "$nodeDir;$env:PATH"
    $env:OPENCLAW_HOME = $script:StackRoot
    $env:OPENCLAW_STATE_DIR = $stateDir
    $env:OPENCLAW_CONFIG_PATH = Join-Path $stateDir "openclaw.json"
    $env:OPENCLAW_WORKSPACE_DIR = Join-Path $script:StackRoot "workspace\openclaw"
    $env:OPENCLAW_GATEWAY_TOKEN = $secrets.OpenClawGatewayToken
}

function Set-HermesEnvironment {
    $hermesHome = Join-Path $script:StackRoot "state\hermes"
    $nodeDir = Get-NodeDirectory
    $env:HERMES_HOME = $hermesHome
    $env:PATH = "$(Join-Path $hermesHome 'hermes-agent\venv\Scripts');$(Join-Path $hermesHome 'bin');$nodeDir;$env:PATH"
}

function Get-LlamaBaseUrl {
    $settings = Get-StackSettings
    return "http://$($settings.Llama.Host):$($settings.Llama.Port)"
}
