# =================================================================
# vibe-sync.ps1 - pull, commit, push your cockpit repo
# =================================================================
# Run on the machine you're about to leave, then again on the next
# machine you arrive at. That's the whole workflow.
# =================================================================

$ErrorActionPreference = 'Stop'

function Ok($m)   { Write-Host "[ok]   $m" -ForegroundColor Green }
function Step($m) { Write-Host ""; Write-Host "[step] $m" -ForegroundColor Cyan }
function Warn($m) { Write-Host "[warn] $m" -ForegroundColor Yellow }
function Fail($m) { Write-Host "[FAIL] $m" -ForegroundColor Red; exit 1 }
function Info($m) { Write-Host "       $m" -ForegroundColor DarkGray }

$claudeDir = Join-Path $env:USERPROFILE '.claude'
if (-not (Test-Path (Join-Path $claudeDir '.git'))) {
    Fail "Your ~/.claude is not a git clone of a cockpit repo. Run 'vibe init' first."
}

Push-Location $claudeDir
try {
    # ---------------------------------------------------------------
    Step "Pulling latest from remote"
    & git pull --rebase 2>&1 | ForEach-Object { Info $_ }
    if ($LASTEXITCODE -ne 0) {
        Fail "git pull --rebase failed. Resolve any conflicts manually in $claudeDir, then retry."
    }
    Ok "Pulled cleanly"

    # ---------------------------------------------------------------
    Step "Checking for local changes"
    $status = & git status --short
    if (-not $status) {
        Ok "Nothing to sync. You're already up to date."
        Pop-Location
        exit 0
    }
    Info "Changes detected:"
    $status | ForEach-Object { Info $_ }

    # ---------------------------------------------------------------
    Step "Staging and committing"
    & git add -A
    $diffStat = & git diff --cached --stat
    Info ($diffStat | Out-String).Trim()

    $defaultMsg = "sync: " + (& git diff --cached --name-only | Select-Object -First 3) -join ', '
    if ($defaultMsg.Length -gt 72) { $defaultMsg = $defaultMsg.Substring(0, 69) + '...' }
    $msg = Read-Host "  Commit message (Enter to use: $defaultMsg)"
    if ([string]::IsNullOrWhiteSpace($msg)) { $msg = $defaultMsg }

    & git commit -m $msg
    if ($LASTEXITCODE -ne 0) { Fail "git commit failed." }
    Ok "Committed"

    # ---------------------------------------------------------------
    Step "Pushing to remote"
    & git push 2>&1 | ForEach-Object { Info $_ }
    if ($LASTEXITCODE -ne 0) { Fail "git push failed. Check 'gh auth status'." }
    Ok "Pushed"

    Write-Host ""
    Write-Host "  Synced. Your other machines can pull this now with 'vibe sync'." -ForegroundColor Green
    Write-Host ""
} finally {
    Pop-Location
}
