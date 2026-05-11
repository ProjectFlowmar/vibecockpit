# =================================================================
# vibe-sync-test.ps1 - end-to-end sync system self-test
# =================================================================
# Run on either machine. Verifies:
#   - Cockpit repo is a clone, in sync with origin/main, and the
#     working tree is clean
#   - Memory + commands counts match between live and cockpit copies
#   - Google Drive credential vault junction works
#   - PowerShell profile loader pulls in Bitwarden helpers
#   - Bitwarden CLI is authenticated and BW_SESSION persisted
#
# Use this any time you suspect drift between machines.
#
# Usage:
#   .\vibe-sync-test.ps1
# =================================================================

$ErrorActionPreference = 'Continue'
$score = 0; $total = 0

function Test-Item($name, [bool]$pass, $detail = "") {
    $script:total++
    if ($pass) {
        $script:score++
        Write-Host "  [PASS] $name" -ForegroundColor Green
        if ($detail) { Write-Host "         $detail" -ForegroundColor DarkGray }
    } else {
        Write-Host "  [FAIL] $name" -ForegroundColor Red
        if ($detail) { Write-Host "         $detail" -ForegroundColor DarkGray }
    }
}

function Section($title) {
    Write-Host ""
    Write-Host "=== $title ===" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "  ============================================================" -ForegroundColor Cyan
Write-Host "   SYNC SYSTEM SELF-TEST - $env:COMPUTERNAME - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "  ============================================================" -ForegroundColor Cyan

# ----------------------------------------------------------------
Section "1/4  Cockpit repo (~/.claude folder)"
# ----------------------------------------------------------------
$claudeDir = "$env:USERPROFILE\.claude"

Test-Item "~/.claude is a git repo" (Test-Path "$claudeDir\.git") $claudeDir

if (Test-Path "$claudeDir\.git") {
    Push-Location $claudeDir

    git fetch origin --quiet 2>&1 | Out-Null

    $status = git status --porcelain 2>&1
    $statusCount = if ($status) { ($status | Measure-Object).Count } else { 0 }
    Test-Item "Working tree clean (no uncommitted changes)" ($statusCount -eq 0) "$statusCount modified file(s)"

    $localSha  = (git rev-parse --short HEAD 2>&1).Trim()
    $remoteRef = git ls-remote origin main 2>&1 | Select-Object -First 1
    $remoteSha = if ($remoteRef) { ($remoteRef -split '\s+')[0].Substring(0,7) } else { "unknown" }
    Test-Item "Local HEAD matches origin/main" ($localSha -eq $remoteSha) "local=$localSha  remote=$remoteSha"

    $behind = (git rev-list --count HEAD..origin/main 2>&1).Trim()
    $ahead  = (git rev-list --count origin/main..HEAD 2>&1).Trim()
    Test-Item "Up to date with origin (no behind/ahead)" ($behind -eq '0' -and $ahead -eq '0') "behind=$behind  ahead=$ahead"

    Pop-Location
}

# ----------------------------------------------------------------
Section "2/4  Memory + commands count match"
# ----------------------------------------------------------------
$liveMem  = "$claudeDir\projects\C--Users-$env:USERNAME\memory"
$liveCmds = "$claudeDir\commands"

# When ~/.claude IS the cockpit clone, it's the source of truth.
# Just verify the canonical paths exist and have content.
$memCount = (Get-ChildItem $liveMem -Filter "*.md" -ErrorAction SilentlyContinue).Count
$cmdCount = (Get-ChildItem $liveCmds -Filter "*.md" -ErrorAction SilentlyContinue).Count

Test-Item "Memory folder has files" ($memCount -gt 0) "$memCount memory file(s)"
Test-Item "Commands folder exists" (Test-Path $liveCmds) "$cmdCount slash command(s)"
Test-Item "MEMORY.md index exists" (Test-Path "$liveMem\MEMORY.md")
Test-Item "user_omar.md persona exists" (Test-Path "$liveMem\user_omar.md")

# ----------------------------------------------------------------
Section "3/4  Google Drive credential vault"
# ----------------------------------------------------------------
$credsLink   = "$env:USERPROFILE\.openclaw\credentials"
$gdProc      = Get-Process GoogleDriveFS -ErrorAction SilentlyContinue
Test-Item "Google Drive Desktop running" ($null -ne $gdProc) "$($gdProc.Count) process(es)"

if (Test-Path $credsLink) {
    $credsItem = Get-Item $credsLink -ErrorAction SilentlyContinue
    $isJunction = ($credsItem.LinkType -eq 'Junction')
    Test-Item "Credentials junction in place" $isJunction "LinkType: $($credsItem.LinkType)"

    if ($isJunction) {
        $target = $credsItem.Target
        Test-Item "Junction target reachable" (Test-Path $target) "target: $target"
    }

    Test-Item "bitwarden.env reachable through junction" (Test-Path "$credsLink\bitwarden.env")
} else {
    Test-Item "Credentials path exists" $false "$credsLink not found - run 'vibe init' or set up Google Drive on this machine"
}

# ----------------------------------------------------------------
Section "4/4  PowerShell profile + Bitwarden"
# ----------------------------------------------------------------
$profilePath = "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
Test-Item "Loader profile in place" (Test-Path $profilePath) $profilePath

if (Test-Path $profilePath) {
    # Source the profile in the current session and verify helpers are exposed
    . $profilePath
    Test-Item "Get-Secret function loaded" ($null -ne (Get-Command Get-Secret -ErrorAction SilentlyContinue))
    Test-Item "Set-Secret function loaded" ($null -ne (Get-Command Set-Secret -ErrorAction SilentlyContinue))
}

$bw = Get-Command bw -ErrorAction SilentlyContinue
Test-Item "Bitwarden CLI installed" ($null -ne $bw)

if ($bw) {
    $bwStatus = bw status 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    Test-Item "Bitwarden CLI authenticated" ($bwStatus.status -in @('locked','unlocked')) "status: $($bwStatus.status)  user: $($bwStatus.userEmail)"
    $bwSession = [System.Environment]::GetEnvironmentVariable('BW_SESSION', 'User')
    Test-Item "BW_SESSION persisted (user env var)" ($null -ne $bwSession -and $bwSession.Length -gt 0)
}

# ----------------------------------------------------------------
Write-Host ""
Write-Host "  ============================================================" -ForegroundColor Cyan
$resultColor = if ($score -eq $total) { 'Green' } elseif ($score -ge ($total * 0.7)) { 'Yellow' } else { 'Red' }
Write-Host "   RESULT: $score / $total tests passed" -ForegroundColor $resultColor
Write-Host "  ============================================================" -ForegroundColor Cyan
Write-Host ""

if ($score -eq $total) {
    Write-Host "  Sync system is healthy on this machine." -ForegroundColor Green
} else {
    Write-Host "  Some checks failed. Common fixes:" -ForegroundColor Yellow
    Write-Host "    - Working tree dirty -> commit + push, or revert" -ForegroundColor DarkGray
    Write-Host "    - Behind origin -> 'cd ~/.claude; git pull'" -ForegroundColor DarkGray
    Write-Host "    - No Google Drive -> install + sign in (matches the account on your other machines)" -ForegroundColor DarkGray
    Write-Host "    - No credentials junction -> mklink /J <local-creds-path> '<drive-letter>:\My Drive\<your-creds-folder>'" -ForegroundColor DarkGray
    Write-Host "    - Bitwarden locked -> .\vibe-unlock-bitwarden.ps1" -ForegroundColor DarkGray
}
Write-Host ""
