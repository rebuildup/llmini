param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\lib\Common.ps1"

Initialize-StackDirectories
$settings = Get-StackSettings

if (-not $settings.Hermes.Enabled) {
    Write-Host "Hermes is disabled in settings."
    exit 0
}

Set-HermesEnvironment

$root = Get-StackRoot
$hermesHome = $env:HERMES_HOME
$installDir = Join-Path $hermesHome "hermes-agent"
$exe = Join-Path $installDir "venv\Scripts\hermes.exe"
$installerPath = Join-Path $root "downloads\hermes-install.ps1"
$installerLog = Join-Path $root "logs\hermes-install.log"
$installerUrl = "https://hermes-agent.nousresearch.com/install.ps1"

function Test-HermesExecutable {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        & $Path --version *> $null
        return ($LASTEXITCODE -eq 0)
    }
    catch {
        return $false
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

if (-not $Force -and (Test-HermesExecutable -Path $exe)) {
    & $exe --version
    Write-Host ("Hermes Agent is already installed under {0}" -f $hermesHome)
    exit 0
}

Write-Host "Downloading the official Hermes Agent Windows installer..."
$previousProgressPreference = $ProgressPreference
$ProgressPreference = "SilentlyContinue"

try {
    Invoke-WebRequest `
        -UseBasicParsing `
        -Uri $installerUrl `
        -OutFile $installerPath
}
finally {
    $ProgressPreference = $previousProgressPreference
}

if (-not (Test-Path -LiteralPath $installerPath)) {
    throw ("Hermes installer was not downloaded: {0}" -f $installerPath)
}

$powerShellHost = (Get-Process -Id $PID).Path
if (-not $powerShellHost -or -not (Test-Path -LiteralPath $powerShellHost)) {
    $pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue
    $windowsPowerShell = Get-Command powershell.exe -ErrorAction SilentlyContinue

    if ($pwsh) {
        $powerShellHost = $pwsh.Source
    }
    elseif ($windowsPowerShell) {
        $powerShellHost = $windowsPowerShell.Source
    }
    else {
        throw "No PowerShell executable was found for the Hermes installer."
    }
}

$installerArguments = @(
    "-NoLogo",
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $installerPath,
    "-SkipSetup",
    "-NonInteractive",
    "-Json",
    "-HermesHome", $hermesHome,
    "-InstallDir", $installDir
)

Write-Host ("Running Hermes installer with {0}..." -f $powerShellHost)

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"

try {
    & $powerShellHost @installerArguments 2>&1 |
        Tee-Object -FilePath $installerLog
    $installerExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}

if ($installerExitCode -ne 0) {
    throw (
        "Hermes Agent installer exited with code {0}. See {1}" -f
        $installerExitCode,
        $installerLog
    )
}

if (-not (Test-HermesExecutable -Path $exe)) {
    throw (
        "Hermes installer exited successfully, but the executable is unavailable: {0}. See {1}" -f
        $exe,
        $installerLog
    )
}

& $exe --version
Write-Host ("Hermes Agent installed under {0}" -f $hermesHome)
