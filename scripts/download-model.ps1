param([switch]$Force)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\lib\Common.ps1"

Initialize-StackDirectories
$settings = Get-StackSettings
$model = $settings.Model
$destination = Join-Path (Get-StackRoot) "models\$($model.FileName)"

if ($Force -and (Test-Path $destination)) {
    Remove-Item $destination -Force
}

Invoke-FileDownload -Url $model.Url -Destination $destination -ExpectedSha256 $model.Sha256

$hash = (Get-FileHash -Algorithm SHA256 $destination).Hash.ToLowerInvariant()
$manifest = @{
    Id = $model.Id
    DisplayName = $model.DisplayName
    FileName = $model.FileName
    SourceUrl = $model.Url
    Sha256 = $hash
    SizeBytes = (Get-Item $destination).Length
    InstalledAt = (Get-Date).ToString("o")
} | ConvertTo-Json -Depth 4
$manifestPath = Join-Path (Get-StackRoot) "state\manifests\model.json"
[System.IO.File]::WriteAllText($manifestPath, $manifest, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "Model ready: $destination"
Write-Host "SHA256: $hash"
