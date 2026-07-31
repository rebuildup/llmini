param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\lib\Common.ps1"

Initialize-StackDirectories
$settings = Get-StackSettings
$major = [int]$settings.Node.Major
$root = Get-StackRoot
$indexUrl = "https://nodejs.org/dist/latest-v$major.x/SHASUMS256.txt"

function Invoke-NativeCapture {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$ArgumentList = @()
    )

    $outputFile = Join-Path $root (
        "downloads\native-output-{0}.txt" -f [Guid]::NewGuid().ToString("N")
    )
    $errorFile = Join-Path $root (
        "downloads\native-error-{0}.txt" -f [Guid]::NewGuid().ToString("N")
    )

    try {
        $process = Start-Process `
            -FilePath $FilePath `
            -ArgumentList $ArgumentList `
            -WindowStyle Hidden `
            -RedirectStandardOutput $outputFile `
            -RedirectStandardError $errorFile `
            -PassThru `
            -Wait

        $stdout = ""
        $stderr = ""

        if (Test-Path -LiteralPath $outputFile) {
            $stdout = [System.IO.File]::ReadAllText($outputFile).Trim()
        }

        if (Test-Path -LiteralPath $errorFile) {
            $stderr = [System.IO.File]::ReadAllText($errorFile).Trim()
        }

        return @{
            ExitCode = [int]$process.ExitCode
            Stdout = $stdout
            Stderr = $stderr
        }
    }
    catch {
        return @{
            ExitCode = -1
            Stdout = ""
            Stderr = $_.Exception.Message
        }
    }
    finally {
        Remove-Item -LiteralPath $outputFile -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $errorFile -Force -ErrorAction SilentlyContinue
    }
}

function Get-NodeRuntimeInfo {
    param(
        [Parameter(Mandatory = $true)][string]$Directory,
        [switch]$VerboseFailure
    )

    $nodeExe = Join-Path $Directory "node.exe"
    $npmCli = Join-Path $Directory "node_modules\npm\bin\npm-cli.js"

    if (-not (Test-Path -LiteralPath $nodeExe)) {
        if ($VerboseFailure) {
            Write-Warning ("node.exe is missing: {0}" -f $nodeExe)
        }
        return $null
    }

    if (-not (Test-Path -LiteralPath $npmCli)) {
        if ($VerboseFailure) {
            Write-Warning ("npm-cli.js is missing: {0}" -f $npmCli)
        }
        return $null
    }

    Unblock-PathBestEffort -Path $nodeExe
    Unblock-PathBestEffort -Path $npmCli

    $nodeResult = Invoke-NativeCapture `
        -FilePath $nodeExe `
        -ArgumentList @("--version")

    if ($nodeResult.ExitCode -ne 0) {
        if ($VerboseFailure) {
            Write-Warning (
                "node.exe verification failed. Exit code: {0}. Error: {1}" -f
                $nodeResult.ExitCode,
                $nodeResult.Stderr
            )
        }
        return $null
    }

    $npmResult = Invoke-NativeCapture `
        -FilePath $nodeExe `
        -ArgumentList @($npmCli, "--version")

    if ($npmResult.ExitCode -ne 0) {
        if ($VerboseFailure) {
            Write-Warning (
                "npm verification failed. Exit code: {0}. Error: {1}" -f
                $npmResult.ExitCode,
                $npmResult.Stderr
            )
        }
        return $null
    }

    $nodeVersion = ($nodeResult.Stdout -split "\r?\n")[0].Trim()
    $npmVersion = ($npmResult.Stdout -split "\r?\n")[0].Trim()

    if (-not $nodeVersion -or $nodeVersion -notmatch "^v([0-9]+)\.") {
        if ($VerboseFailure) {
            Write-Warning (
                "Unexpected node.exe version output: {0}" -f
                $nodeResult.Stdout
            )
        }
        return $null
    }

    $detectedMajor = [int]$Matches[1]

    return @{
        Directory = $Directory
        Node = $nodeVersion
        Npm = $npmVersion
        Major = $detectedMajor
    }
}

Write-Host "Resolving latest Node.js v$major..."
$checksums = (Invoke-WebRequest -UseBasicParsing -Uri $indexUrl).Content -split "`n"
$line = $checksums |
    Where-Object { $_ -match " node-v$major\..*-win-x64\.zip$" } |
    Select-Object -First 1

if (-not $line) {
    throw (
        "Could not resolve a Windows x64 Node.js archive from {0}" -f
        $indexUrl
    )
}

$parts = $line.Trim() -split "\s+"
$sha = $parts[0]
$fileName = $parts[-1]
$version = ($fileName -replace "^node-", "" -replace "-win-x64\.zip$", "")
$url = "https://nodejs.org/dist/$version/$fileName"
$directoryName = $fileName -replace "\.zip$", ""
$preferredDirectory = Join-Path $root ("tools\{0}" -f $directoryName)

if (-not $Force) {
    $preferredInfo = Get-NodeRuntimeInfo -Directory $preferredDirectory

    if ($preferredInfo -and $preferredInfo.Major -eq $major) {
        Set-RuntimeDirectoryPointer `
            -PointerFileName "node-directory.txt" `
            -Directory $preferredDirectory

        Write-Host (
            "Using portable Node.js {0} with npm {1} at {2}" -f
            $preferredInfo.Node,
            $preferredInfo.Npm,
            $preferredDirectory
        )
        exit 0
    }

    $currentDirectory = Get-NodeDirectory
    $currentInfo = Get-NodeRuntimeInfo -Directory $currentDirectory

    if ($currentInfo -and
        $currentInfo.Major -eq $major -and
        $currentInfo.Node -eq ("v{0}" -f $version)) {
        Set-RuntimeDirectoryPointer `
            -PointerFileName "node-directory.txt" `
            -Directory $currentDirectory

        Write-Host (
            "Using portable Node.js {0} with npm {1} at {2}" -f
            $currentInfo.Node,
            $currentInfo.Npm,
            $currentDirectory
        )
        exit 0
    }
}

$archive = Join-Path $root "downloads\$fileName"
Invoke-FileDownload -Url $url -Destination $archive -ExpectedSha256 $sha
Unblock-PathBestEffort -Path $archive

$stagingRoot = New-StagingDirectory -Prefix "node"
Write-Host ("Extracting Node.js into {0}" -f $stagingRoot)
Expand-Archive -LiteralPath $archive -DestinationPath $stagingRoot -Force
Unblock-PathBestEffort -Path $stagingRoot -Recurse

$inner = Get-ChildItem -LiteralPath $stagingRoot -Directory |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "node.exe") } |
    Select-Object -First 1

if (-not $inner) {
    throw "Unexpected Node.js archive layout."
}

$targetDirectory = $preferredDirectory

if (Test-Path -LiteralPath $targetDirectory) {
    $targetInfo = Get-NodeRuntimeInfo -Directory $targetDirectory

    if ($targetInfo -and -not $Force) {
        Set-RuntimeDirectoryPointer `
            -PointerFileName "node-directory.txt" `
            -Directory $targetDirectory

        Remove-DirectoryTreeBestEffort -Path $stagingRoot

        Write-Host (
            "Using portable Node.js {0} with npm {1} at {2}" -f
            $targetInfo.Node,
            $targetInfo.Npm,
            $targetDirectory
        )
        exit 0
    }

    $targetDirectory = Join-Path $root (
        "tools\{0}-repair-{1}" -f
        $directoryName,
        [Guid]::NewGuid().ToString("N").Substring(0, 8)
    )
}

Move-Item -LiteralPath $inner.FullName -Destination $targetDirectory
Unblock-PathBestEffort -Path $targetDirectory -Recurse

Set-RuntimeDirectoryPointer `
    -PointerFileName "node-directory.txt" `
    -Directory $targetDirectory

$installed = Get-NodeRuntimeInfo `
    -Directory $targetDirectory `
    -VerboseFailure

if (-not $installed -or $installed.Major -ne $major) {
    throw (
        "Portable Node.js verification failed at {0}. See the warnings above for the exact node.exe or npm failure." -f
        $targetDirectory
    )
}

Remove-DirectoryTreeBestEffort -Path $stagingRoot

Write-Host (
    "Node.js installed: {0}; npm {1}; path {2}" -f
    $installed.Node,
    $installed.Npm,
    $targetDirectory
)
