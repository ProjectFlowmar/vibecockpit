# =================================================================
# vibe-sync-daemon.ps1 - background sync for the cockpit repo
# =================================================================
# Registered as a Windows Scheduled Task by vibe-install-tasks.ps1.
# Runs every 10 min:
#   1. Pull from origin (fast-forward only, autostash uncommitted)
#   2. If there are local commits, push them
#   3. If there are uncommitted local changes, commit + push
#   4. Clean up tmp/ files older than 7 days
#   5. Log to logs/vibe-sync-daemon.log (rotated when > 1 MB)
#
# Safe to run on both machines simultaneously. Last writer wins on
# any rare conflict; one machine's push will fail, next run pulls
# the other side's changes and resyncs.
# =================================================================

$ErrorActionPreference = 'Continue'
$claudeDir = "$env:USERPROFILE\.claude"
$logDir = Join-Path $claudeDir 'logs'
$logFile = Join-Path $logDir 'vibe-sync-daemon.log'

if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Log($msg) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  [$env:COMPUTERNAME]  $msg"
    Add-Content -Path $logFile -Value $line -Encoding utf8
}

# Rotate log if > 1 MB
if ((Test-Path $logFile) -and (Get-Item $logFile).Length -gt 1MB) {
    Move-Item $logFile "$logFile.old" -Force
}

if (-not (Test-Path "$claudeDir\.git")) {
    Log "ERROR: ~/.claude is not a git repo - cannot sync"
    exit 1
}

Push-Location $claudeDir
try {
    # ----- Pull -----
    git fetch origin --quiet 2>&1 | Out-Null
    $behind = (git rev-list --count HEAD..origin/main 2>&1).Trim()
    if ($behind -ne '0') {
        $pullOut = git pull --rebase --autostash 2>&1
        if ($LASTEXITCODE -eq 0) {
            Log "Pulled $behind commit(s) from origin"
        } else {
            Log "PULL FAILED: $($pullOut -join ' | ')"
            # Try to recover from a rebase-in-progress state
            git rebase --abort 2>&1 | Out-Null
            Pop-Location
            exit 1
        }
    }

    # ----- Commit local changes if any -----
    $status = git status --porcelain
    if ($status) {
        $changedCount = ($status | Measure-Object).Count
        git add -A 2>&1 | Out-Null
        $msg = "auto-sync: $changedCount file(s) on $env:COMPUTERNAME at $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
        $commitOut = git -c user.email=projectflowmar@gmail.com -c user.name=ProjectFlowmar commit -m $msg 2>&1
        if ($LASTEXITCODE -eq 0) {
            Log "Committed $changedCount file(s)"
        } else {
            Log "COMMIT FAILED: $($commitOut -join ' | ')"
        }
    }

    # ----- Push -----
    $ahead = (git rev-list --count origin/main..HEAD 2>&1).Trim()
    if ($ahead -ne '0') {
        # Self-heal: if no upstream tracking, set it on first push
        $upstreamSet = git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null
        if (-not $upstreamSet) {
            $pushOut = git push --set-upstream origin main 2>&1
        } else {
            $pushOut = git push 2>&1
        }
        if ($LASTEXITCODE -eq 0) {
            Log "Pushed $ahead commit(s) to origin"
        } else {
            Log "PUSH FAILED: $($pushOut -join ' | ')"
        }
    }
} finally {
    Pop-Location
}

# ----- Clean up old tmp/ files (>7 days) -----
$tmpDir = Join-Path $claudeDir 'tmp'
if (Test-Path $tmpDir) {
    $cutoff = (Get-Date).AddDays(-7)
    $old = Get-ChildItem $tmpDir -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoff }
    if ($old) {
        $old | Remove-Item -Force -ErrorAction SilentlyContinue
        Log "Cleaned $($old.Count) old file(s) from tmp/"
    }
}
