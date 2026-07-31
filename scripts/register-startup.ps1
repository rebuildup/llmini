
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\lib\Common.ps1"

$root = Get-StackRoot
$taskName = "Local AI Stack"
$scriptPath = Join-Path $root "scripts\start-all.ps1"
$powerShell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

$action = New-ScheduledTaskAction `
    -Execute $powerShell `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`"" `
    -WorkingDirectory $root

$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Days 3650) `
    -MultipleInstances IgnoreNew

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description "Starts the Git-managed local llama.cpp / agent stack." `
    -Force | Out-Null

Write-Host "Registered startup task: $taskName"
Write-Host "Components: $((Get-StackSettings).StartupComponents -join ', ')"
