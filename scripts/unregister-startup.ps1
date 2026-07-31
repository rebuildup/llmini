
$ErrorActionPreference = "Stop"
$taskName = "Local AI Stack"
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($task) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "Removed startup task: $taskName"
}
else {
    Write-Host "Startup task is not registered."
}
