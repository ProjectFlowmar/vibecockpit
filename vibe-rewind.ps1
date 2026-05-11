# =================================================================
# vibe-rewind.ps1 - time-travel your cockpit config
# =================================================================
# Restores your ~/.claude (memory + commands + config) to a past
# point. Useful when you broke something with a recent edit or want
# to see what was true on a previous day.
#
# Usage:
#   .\vibe-rewind.ps1 1hour       Last hour
#   .\vibe-rewind.ps1 6hours      6 hours ago
#   .\vibe-rewind.ps1 1day        Yesterday
#   .\vibe-rewind.ps1 1week       7 days ago
#   .\vibe-rewind.ps1 "2026-05-01" Specific date
#   .\vibe-rewind.ps1 list        Show recent restore points
# =================================================================

param(
    [Parameter(Position=0, Mandatory=$true)]
    [string]$When
)

$ErrorActionPreference = 'Stop'

function Ok($m)   { Write-Host "[ok]   $m" -ForegroundColor Green }
function Step($m) { Write-Host ""; Write-Host "[step] $m" -ForegroundColor Cyan }
function Warn($m) { Write-Host "[warn] $m" -ForegroundColor Yellow }
function Fail($m) { Write-Host "[FAIL] $m" -ForegroundColor Red; exit 1 }
function Info($m) { Write-Host "       $m" -ForegroundColor DarkGray }

$claudeDir = Join-Path $env:USERPROFILE '.claude'
if (-not (Test-Path (Join-Path $claudeDir '.git'))) {
    Fail "Your ~/.claude is not a git repo. Rewind only works on git-versioned cockpits. Run 'vibe init' first."
}

Push-Location $claudeDir
try {
    # ---------------------------------------------------------------
    # List mode
    if ($When.ToLower() -eq 'list') {
        Step "Recent restore points (last 20 commits)"
        & git log --oneline --decorate -20
        Write-Host ""
        Write-Host "  Restore one with: .\vibe-rewind.ps1 <duration|date>" -ForegroundColor DarkGray
        Pop-Location
        exit 0
    }

    # ---------------------------------------------------------------
    # Parse the time spec
    Step "Resolving '$When' to a commit"

    $targetSha = $null
    $description = $null

    # Direct date format
    if ($When -match '^\d{4}-\d{2}-\d{2}') {
        $targetSha = & git rev-list -1 --before="$When 23:59:59" HEAD 2>$null
        $description = "as of $When"
    }
    # Duration shortcuts
    elseif ($When -match '^(\d+)(hour|hours|day|days|week|weeks|month|months)$') {
        $n = [int]$Matches[1]
        $unit = $Matches[2]
        $gitSpec = switch -wildcard ($unit) {
            'hour*'  { "$n hours ago" }
            'day*'   { "$n days ago" }
            'week*'  { "$($n*7) days ago" }
            'month*' { "$($n*30) days ago" }
        }
        $targetSha = & git rev-list -1 --before="$gitSpec" HEAD 2>$null
        $description = "as of $gitSpec"
    }
    else {
        Fail "Couldn't parse '$When'. Examples: 1hour, 6hours, 1day, 1week, 2026-05-01, list"
    }

    if (-not $targetSha) {
        Fail "No commit found $description. Your repo may not go back that far. Try '.\vibe-rewind.ps1 list' to see what's available."
    }

    $targetMsg = (& git log -1 --format="%s" $targetSha)
    $targetDate = (& git log -1 --format="%ai" $targetSha)
    Ok "Target commit: $targetSha"
    Info "Message: $targetMsg"
    Info "Date:    $targetDate"

    # ---------------------------------------------------------------
    Step "Safety: stash any uncommitted changes"
    $localChanges = & git status --short
    if ($localChanges) {
        Warn "You have uncommitted local changes. Stashing them so rewind doesn't lose them."
        & git stash push -u -m "vibe-rewind auto-stash $(Get-Date -Format 'yyyyMMdd-HHmmss')" 2>&1 | ForEach-Object { Info $_ }
        Info "Recover later with: git stash pop"
    } else {
        Ok "No uncommitted changes."
    }

    # ---------------------------------------------------------------
    Step "Restoring memory + commands to that point"
    # Only restore the safe paths (memory, commands) — leave settings.json and other local-only files alone
    $paths = @(
        'projects',
        'commands',
        'CLAUDE.md'
    )
    foreach ($p in $paths) {
        if (& git cat-file -e "${targetSha}:$p" 2>$null) {
            Info "restoring $p"
            & git checkout $targetSha -- $p 2>$null
        }
    }
    Ok "Restored. Local working tree is now at '$description'."

    Write-Host ""
    Write-Host "  Your memory + commands are restored to that point." -ForegroundColor Green
    Write-Host "  If this fixed things and you want to keep it:" -ForegroundColor White
    Write-Host "    git add -A; git commit -m `"rewind to $When`"; git push" -ForegroundColor DarkGray
    Write-Host "  If you want to go back to where you were before this rewind:" -ForegroundColor White
    Write-Host "    git checkout HEAD -- projects commands CLAUDE.md" -ForegroundColor DarkGray
    Write-Host ""
} finally {
    Pop-Location
}
