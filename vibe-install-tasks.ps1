# =================================================================
# vibe-install-tasks.ps1 - register the background sync tasks
# =================================================================
# Run ONCE per machine. Registers two Windows Scheduled Tasks:
#
#   VibeVibeCockpitSyncDaemon  - runs vibe-sync-daemon.ps1 every 10 minutes
#   VibeVibeCockpitHealthCheck - runs vibe-health-check.ps1 once a day at 08:00
#
# Idempotent - safe to re-run; deletes and re-creates the tasks.
# Does NOT require admin (uses user-scope tasks).
#
# The scripts can live next to this one OR in ~/.claude (legacy layout).
# Search order: parent script dir, then ~/.claude
#
# Usage (in any PowerShell window):
#   cd <wherever you cloned vibecockpit>
#   .\vibe.ps1 install-tasks
# =================================================================

$ErrorActionPreference = 'Stop'

function Ok($m)   { Write-Host "[ok]   $m" -ForegroundColor Green }
function Step($m) { Write-Host ""; Write-Host "[step] $m" -ForegroundColor Cyan }

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$claudeDir = "$env:USERPROFILE\.claude"

function Find-Script($name) {
    foreach ($base in @($here, $claudeDir)) {
        $p = Join-Path $base $name
        if (Test-Path $p) { return $p }
    }
    return $null
}

$daemonScript = Find-Script 'vibe-sync-daemon.ps1'
$healthScript = Find-Script 'vibe-health-check.ps1'

if (-not $daemonScript) { throw "vibe-sync-daemon.ps1 not found in $here or $claudeDir" }
if (-not $healthScript) { throw "vibe-health-check.ps1 not found in $here or $claudeDir" }

# ----------------------------------------------------------------
Step "Registering VibeCockpitSyncDaemon (every 10 min)"

$taskName = 'VibeCockpitSyncDaemon'

# Remove existing if any
$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing) { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false }

$action  = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$daemonScript`""

$trigger1 = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$trigger2 = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2) `
    -RepetitionInterval (New-TimeSpan -Minutes 10)

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -MultipleInstances IgnoreNew

$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $taskName `
    -Action $action `
    -Trigger @($trigger1, $trigger2) `
    -Settings $settings `
    -Principal $principal `
    -Description "Cockpit auto-sync: pull/commit/push every 10 min" | Out-Null

Ok "Registered $taskName (every 10 min + at logon)"

# ----------------------------------------------------------------
Step "Registering VibeCockpitHealthCheck (daily at 08:00)"

$taskName2 = 'VibeCockpitHealthCheck'

$existing2 = Get-ScheduledTask -TaskName $taskName2 -ErrorAction SilentlyContinue
if ($existing2) { Unregister-ScheduledTask -TaskName $taskName2 -Confirm:$false }

$action2  = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$healthScript`""

$trigger3 = New-ScheduledTaskTrigger -Daily -At 08:00

$settings2 = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -MultipleInstances IgnoreNew

Register-ScheduledTask -TaskName $taskName2 `
    -Action $action2 `
    -Trigger $trigger3 `
    -Settings $settings2 `
    -Principal $principal `
    -Description "Cockpit health check: runs vibe-sync-test daily, alerts on failure" | Out-Null

Ok "Registered $taskName2 (daily at 08:00)"

# ----------------------------------------------------------------
Step "Triggering one immediate run of sync-daemon"
Start-ScheduledTask -TaskName 'VibeCockpitSyncDaemon'
Start-Sleep -Seconds 3
$logPath = Join-Path $claudeDir 'logs\vibe-sync-daemon.log'
if (Test-Path $logPath) {
    Write-Host "       Last log lines:" -ForegroundColor DarkGray
    Get-Content $logPath -Tail 3 | ForEach-Object { Write-Host "         $_" -ForegroundColor DarkGray }
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host " Sync tasks installed on $env:COMPUTERNAME" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  View tasks:    Get-ScheduledTask Cockpit*" -ForegroundColor DarkGray
Write-Host "  View logs:     Get-Content `$env:USERPROFILE\.claude\logs\sync-daemon.log -Tail 20" -ForegroundColor DarkGray
Write-Host "  Run manually:  Start-ScheduledTask -TaskName VibeCockpitSyncDaemon" -ForegroundColor DarkGray
Write-Host "  Disable:       Disable-ScheduledTask -TaskName VibeCockpitSyncDaemon" -ForegroundColor DarkGray
Write-Host ""
