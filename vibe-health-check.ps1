# =================================================================
# vibe-health-check.ps1 - daily sync system health check
# =================================================================
# Registered as a Windows Scheduled Task by vibe-install-tasks.ps1.
# Runs once a day at 08:00 local time.
#   1. Runs vibe-sync-test.ps1 to verify the whole stack
#   2. Logs the result to logs/vibe-health-check.log
#   3. If any test fails: writes logs/SYNC-ALERT.txt as a flag file.
#      Next time you open PowerShell, the profile loader checks for
#      this file and warns you.
# =================================================================

$ErrorActionPreference = 'Continue'
$claudeDir = "$env:USERPROFILE\.claude"
$logDir = Join-Path $claudeDir 'logs'
$logFile = Join-Path $logDir 'vibe-health-check.log'
$alertFlag = Join-Path $logDir 'SYNC-ALERT.txt'

if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Locate vibe-sync-test.ps1 - check ~/.claude first, then this script's dir
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$testScript = $null
foreach ($base in @($claudeDir, $here)) {
    $p = Join-Path $base 'vibe-sync-test.ps1'
    if (Test-Path $p) { $testScript = $p; break }
}
if (-not $testScript) {
    Add-Content $logFile "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$env:COMPUTERNAME] ERROR: vibe-sync-test.ps1 not found in $claudeDir or $here"
    exit 1
}

$result = & powershell -NoProfile -ExecutionPolicy Bypass -File $testScript 2>&1
$failCount = ($result | Select-String -Pattern '\[FAIL\]').Count
$passLine  = $result | Select-String -Pattern 'RESULT:' | Select-Object -First 1

Add-Content $logFile "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$env:COMPUTERNAME] $($passLine.Line.Trim()) - $failCount failure(s)"

if ($failCount -gt 0) {
    # Write the flag file the profile loader will detect
    $failedTests = $result | Select-String -Pattern '\[FAIL\]' | ForEach-Object { $_.Line.Trim() }
    @"
SYNC HEALTH ALERT on $env:COMPUTERNAME - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

$failCount test(s) failed in the daily sync health check:

$($failedTests -join "`n")

Run this manually for full output:
  cd `$env:USERPROFILE\.claude
  .\vibe-sync-test.ps1

Delete this file (or run any passing health check) to clear the alert.
"@ | Out-File $alertFlag -Encoding utf8 -NoNewline

} else {
    # All passed - clear any stale alert
    if (Test-Path $alertFlag) {
        Remove-Item $alertFlag -Force
    }
}
