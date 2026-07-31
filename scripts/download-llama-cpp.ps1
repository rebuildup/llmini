param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\lib\Common.ps1"

Initialize-StackDirectories
$root = Get-StackRoot
$api = "https://api.github.com/repos/ggml-org/llama.cpp/releases/latest"
$manifestPath = Join-Path $root "state\manifests\llama-cpp.json"

Write-Host "Resolving latest llama.cpp release..."
$release = Invoke-RestMethod `
    -Headers @{ "User-Agent" = "local-ai-stack" } `
    -Uri $api

$engineAsset = $release.assets |
    Where-Object { $_.name -match "^llama-.*-bin-win-cuda-12\.4-x64\.zip$" } |
    Select-Object -First 1
$runtimeAsset = $release.assets |
    Where-Object { $_.name -eq "cudart-llama-bin-win-cuda-12.4-x64.zip" } |
    Select-Object -First 1

if (-not $engineAsset) {
    throw (
        "CUDA 12.4 Windows x64 llama.cpp asset was not found in release {0}." -f
        $release.tag_name
    )
}

if (-not $runtimeAsset) {
    throw (
        "CUDA 12.4 runtime asset was not found in release {0}." -f
        $release.tag_name
    )
}

$safeRelease = $release.tag_name -replace "[^A-Za-z0-9._-]", "-"
$preferredDirectory = Join-Path $root (
    "tools\llama-cpp-{0}" -f $safeRelease
)
$preferredServer = Join-Path $preferredDirectory "llama-server.exe"

if (-not $Force -and (Test-Path -LiteralPath $preferredServer)) {
    & $preferredServer --version

    if ($LASTEXITCODE -eq 0) {
        Set-RuntimeDirectoryPointer `
            -PointerFileName "llama-cpp-directory.txt" `
            -Directory $preferredDirectory

        Write-Host (
            "Using existing llama.cpp release {0} at {1}" -f
            $release.tag_name,
            $preferredDirectory
        )
        exit 0
    }
}

$downloadDir = Join-Path $root "downloads"
$engineZip = Join-Path $downloadDir $engineAsset.name
$runtimeZip = Join-Path $downloadDir $runtimeAsset.name

$engineSha = ""
if ($engineAsset.PSObject.Properties.Name -contains "digest" -and
    $engineAsset.digest -match "^sha256:(.+)$") {
    $engineSha = $Matches[1]
}

$runtimeSha = ""
if ($runtimeAsset.PSObject.Properties.Name -contains "digest" -and
    $runtimeAsset.digest -match "^sha256:(.+)$") {
    $runtimeSha = $Matches[1]
}

Invoke-FileDownload `
    -Url $engineAsset.browser_download_url `
    -Destination $engineZip `
    -ExpectedSha256 $engineSha

Invoke-FileDownload `
    -Url $runtimeAsset.browser_download_url `
    -Destination $runtimeZip `
    -ExpectedSha256 $runtimeSha

$stagingRoot = New-StagingDirectory -Prefix "llama-cpp"
$engineStaging = Join-Path $stagingRoot "engine"
$runtimeStaging = Join-Path $stagingRoot "runtime"

Ensure-Directory $engineStaging
Ensure-Directory $runtimeStaging

Write-Host ("Extracting llama.cpp into {0}" -f $stagingRoot)
Expand-Archive -LiteralPath $engineZip -DestinationPath $engineStaging -Force
Expand-Archive -LiteralPath $runtimeZip -DestinationPath $runtimeStaging -Force

$server = Get-ChildItem `
    -LiteralPath $engineStaging `
    -Filter "llama-server.exe" `
    -Recurse |
    Select-Object -First 1

if (-not $server) {
    throw "llama-server.exe was not found after extraction."
}

$payloadDirectory = $server.DirectoryName

Get-ChildItem -LiteralPath $runtimeStaging -File -Recurse |
    ForEach-Object {
        Copy-Item `
            -LiteralPath $_.FullName `
            -Destination (Join-Path $payloadDirectory $_.Name) `
            -Force
    }

$targetDirectory = $preferredDirectory

if (Test-Path -LiteralPath $targetDirectory) {
    $targetServer = Join-Path $targetDirectory "llama-server.exe"

    if ((Test-Path -LiteralPath $targetServer) -and -not $Force) {
        & $targetServer --version

        if ($LASTEXITCODE -eq 0) {
            Set-RuntimeDirectoryPointer `
                -PointerFileName "llama-cpp-directory.txt" `
                -Directory $targetDirectory

            Remove-DirectoryTreeBestEffort -Path $stagingRoot

            Write-Host (
                "Using existing llama.cpp release {0} at {1}" -f
                $release.tag_name,
                $targetDirectory
            )
            exit 0
        }
    }

    $targetDirectory = Join-Path $root (
        "tools\llama-cpp-{0}-repair-{1}" -f
        $safeRelease,
        [Guid]::NewGuid().ToString("N").Substring(0, 8)
    )
}

Move-Item -LiteralPath $payloadDirectory -Destination $targetDirectory

$installedServer = Join-Path $targetDirectory "llama-server.exe"
if (-not (Test-Path -LiteralPath $installedServer)) {
    throw (
        "llama-server.exe is unavailable after installation: {0}" -f
        $installedServer
    )
}

& $installedServer --version
if ($LASTEXITCODE -ne 0) {
    throw (
        "llama-server.exe verification failed with exit code {0}." -f
        $LASTEXITCODE
    )
}

Set-RuntimeDirectoryPointer `
    -PointerFileName "llama-cpp-directory.txt" `
    -Directory $targetDirectory

$manifest = @{
    Release = $release.tag_name
    Directory = $targetDirectory
    EngineAsset = $engineAsset.name
    RuntimeAsset = $runtimeAsset.name
    InstalledAt = (Get-Date).ToString("o")
} | ConvertTo-Json -Depth 4

[System.IO.File]::WriteAllText(
    $manifestPath,
    $manifest,
    (New-Object System.Text.UTF8Encoding($false))
)

Remove-DirectoryTreeBestEffort -Path $stagingRoot

Write-Host (
    "llama.cpp release {0} installed at {1}" -f
    $release.tag_name,
    $targetDirectory
)
