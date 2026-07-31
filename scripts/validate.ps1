param(
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"

function Import-CompatiblePowerShellDataFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw ("Data file not found: {0}" -f $Path)
    }

    $nativeCommand = Get-Command `
        Import-PowerShellDataFile `
        -ErrorAction SilentlyContinue

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

$root = Split-Path -Parent $PSScriptRoot
$scriptsDirectory = Join-Path $root "scripts"
$configDirectory = Join-Path $root "config"
$settingsPath = Join-Path $configDirectory "settings.psd1"
$settingsExamplePath = Join-Path $configDirectory "settings.example.psd1"

if (-not (Test-Path -LiteralPath $settingsPath)) {
    if (-not (Test-Path -LiteralPath $settingsExamplePath)) {
        throw (
            "Settings and settings template are missing: {0}" -f
            $configDirectory
        )
    }

    if (-not (Test-Path -LiteralPath $configDirectory)) {
        New-Item `
            -ItemType Directory `
            -Path $configDirectory `
            -Force |
            Out-Null
    }

    Copy-Item `
        -LiteralPath $settingsExamplePath `
        -Destination $settingsPath `
        -Force

    Write-Host ("Created default settings file: {0}" -f $settingsPath)
}

$files = @()

$files += Get-ChildItem `
    -LiteralPath $scriptsDirectory `
    -Recurse `
    -File |
    Where-Object {
        $_.Extension.ToLowerInvariant() -eq ".ps1"
    }

$files += Get-ChildItem `
    -LiteralPath $configDirectory `
    -File |
    Where-Object {
        $_.Extension.ToLowerInvariant() -eq ".psd1"
    }

$hasErrors = $false

$readOnlyAssignmentPattern = (
    '(?im)^\s*\$(' +
    'HOME|Host|PID|PSVersionTable|ExecutionContext|' +
    'ShellId|StackTrace|NestedPromptLevel' +
    ')\s*='
)

foreach ($file in $files) {
    $tokens = $null
    $parseErrors = $null

    [System.Management.Automation.Language.Parser]::ParseFile(
        $file.FullName,
        [ref]$tokens,
        [ref]$parseErrors
    ) | Out-Null

    if ($parseErrors.Count -gt 0) {
        $hasErrors = $true

        Write-Host (
            "Parse errors in {0}" -f
            $file.FullName
        ) -ForegroundColor Red

        foreach ($parseError in $parseErrors) {
            Write-Host (
                "  Line {0}, column {1}: {2}" -f
                $parseError.Extent.StartLineNumber,
                $parseError.Extent.StartColumnNumber,
                $parseError.Message
            ) -ForegroundColor Red
        }

        continue
    }

    $source = [System.IO.File]::ReadAllText($file.FullName)
    $matches = [regex]::Matches(
        $source,
        $readOnlyAssignmentPattern
    )

    foreach ($match in $matches) {
        $hasErrors = $true
        $prefix = $source.Substring(0, $match.Index)
        $lineNumber = ($prefix -split "\r?\n").Count

        Write-Host (
            "Read-only automatic variable assignment in {0}" -f
            $file.FullName
        ) -ForegroundColor Red

        Write-Host (
            "  Line {0}: {1}" -f
            $lineNumber,
            $match.Value.Trim()
        ) -ForegroundColor Red
    }
}

if ($hasErrors) {
    Write-Host "Validation failed. Bootstrap was not started." `
        -ForegroundColor Red
    exit 1
}

$settings = Import-CompatiblePowerShellDataFile -Path $settingsPath

if (-not $settings.Node.Major) {
    Write-Host "Node.Major is missing from config/settings.psd1." `
        -ForegroundColor Red
    exit 1
}

if (-not $Quiet) {
    Write-Host (
        "Validation passed: {0} PowerShell files; Node major version {1}." -f
        $files.Count,
        $settings.Node.Major
    ) -ForegroundColor Green
}

exit 0
