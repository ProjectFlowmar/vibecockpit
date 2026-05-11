# =================================================================
# setup-bitwarden.ps1 - interactive Bitwarden CLI setup
# =================================================================
# Walks through API-key login + first unlock + persistent session.
# Prompts for credentials at runtime so nothing gets pasted into
# chat / commit history / scrollback as plain text.
#
# Usage (in PowerShell):
#   .\setup-bitwarden.ps1
# =================================================================

$ErrorActionPreference = 'Stop'

function Ok($m)   { Write-Host "[ok]   $m" -ForegroundColor Green }
function Step($m) { Write-Host ""; Write-Host "[step] $m" -ForegroundColor Cyan }
function Warn($m) { Write-Host "[warn] $m" -ForegroundColor Yellow }
function Fail($m) { Write-Host "[FAIL] $m" -ForegroundColor Red; exit 1 }

# -----------------------------------------------------------------
Step "Step 1/6 - Check Bitwarden CLI is installed"
$bw = Get-Command bw -ErrorAction SilentlyContinue
if (-not $bw) { Fail "bw not found on PATH. Install: winget install --id Bitwarden.CLI --scope user" }
$bwVer = (& bw --version 2>$null)
Ok "bw $bwVer at $($bw.Source)"

# -----------------------------------------------------------------
Step "Step 2/6 - Check existing login state"
$existingStatus = (& bw status 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue).status
if ($existingStatus -in @('locked','unlocked')) {
    Warn "Already logged in (status: $existingStatus). Running 'bw logout' to start clean."
    & bw logout 2>$null | Out-Null
}
Ok "Clean slate confirmed"

# -----------------------------------------------------------------
Step "Step 3/6 - Confirm you've rotated the previously-leaked API key"
Write-Host "  Earlier in this conversation, a client_secret was pasted into chat." -ForegroundColor Yellow
Write-Host "  Before continuing, go to vault.bitwarden.com:" -ForegroundColor Yellow
Write-Host "    Account Settings -> Security -> Keys -> View API Key -> " -ForegroundColor Yellow -NoNewline
Write-Host "Rotate" -ForegroundColor White
Write-Host ""
$confirmed = Read-Host "  Have you generated a NEW client_id and client_secret? (yes/no)"
if ($confirmed -ne 'yes') { Fail "Aborted. Rotate the key at vault.bitwarden.com, then re-run this script." }
Ok "Rotation confirmed"

# -----------------------------------------------------------------
Step "Step 4/6 - Collect new credentials (typed/pasted directly into PowerShell, never into chat)"
$clientId = Read-Host "  Paste the NEW client_id (starts with 'user.')"
if ($clientId -notmatch '^user\.[0-9a-f-]{36}$') {
    Warn "client_id doesn't look like the standard shape (user.<uuid>). Continuing anyway."
}
$secureSecret = Read-Host "  Paste the NEW client_secret" -AsSecureString
$clientSecret = [System.Net.NetworkCredential]::new('', $secureSecret).Password
if ([string]::IsNullOrWhiteSpace($clientSecret)) { Fail "Empty client_secret. Aborting." }
Ok "Credentials captured"

# -----------------------------------------------------------------
Step "Step 5/6 - Write to vault file + log in via API key"
$credPath = "$env:USERPROFILE\.openclaw\credentials\bitwarden.env"
$credDir = Split-Path $credPath -Parent
if (-not (Test-Path $credDir)) { New-Item -ItemType Directory -Path $credDir -Force | Out-Null }
@"
BW_CLIENTID=$clientId
BW_CLIENTSECRET=$clientSecret
"@ | Out-File $credPath -Encoding utf8 -NoNewline
Ok "Wrote $credPath"

$env:BW_CLIENTID = $clientId
$env:BW_CLIENTSECRET = $clientSecret
# NOTE: no 2>&1 — Windows PowerShell 5.1 wraps native stderr in RemoteException
# even on exit-code 0, which kills downstream pipeline. Let bw's stderr go to
# the user's terminal directly.
& bw login --apikey
if ($LASTEXITCODE -ne 0) {
    Fail "bw login failed. Check the client_id / client_secret on vault.bitwarden.com and try again."
}
Ok "Logged in"

# -----------------------------------------------------------------
Step "Step 6/6 - Unlock the vault with your master password"
Write-Host "  bw will prompt for your master password - type carefully." -ForegroundColor Yellow
Write-Host "  This is the only step where the master password is entered; it stays in your terminal." -ForegroundColor Yellow
Write-Host ""
# Same fix here — capture stdout only, leave stderr (prompt) flowing to terminal.
$session = & bw unlock --raw
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($session)) {
    Fail "bw unlock failed. Check the master password and try again."
}
[System.Environment]::SetEnvironmentVariable('BW_SESSION', $session, 'User')
$env:BW_SESSION = $session
Ok "Session token saved to BW_SESSION user env var (persists across reboots)"

# -----------------------------------------------------------------
# Update MASTER_INDEX.env if it exists
$idx = "$env:USERPROFILE\.openclaw\credentials\MASTER_INDEX.env"
if (Test-Path $idx) {
    $content = Get-Content $idx -Raw
    if ($content -notmatch 'BITWARDEN') {
        Add-Content $idx "`nBITWARDEN=$credPath  # API key login + Get-Secret helpers"
        Ok "Updated MASTER_INDEX.env"
    }
}

# -----------------------------------------------------------------
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host " Bitwarden ready on $env:COMPUTERNAME" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
& bw status
Write-Host ""
Write-Host "Test it:" -ForegroundColor Cyan
Write-Host "  Get-Secret OPENAI_API_KEY    # retrieves a stored secret" -ForegroundColor Gray
Write-Host "  Set-Secret TEST_KEY testval  # stores a new one" -ForegroundColor Gray
Write-Host "  Lock-Vault                   # locks vault + clears BW_SESSION" -ForegroundColor Gray

# Clear local variables holding secrets
$clientSecret = $null
$session = $null
$secureSecret = $null
[GC]::Collect()
