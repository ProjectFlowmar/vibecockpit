# =================================================================
# unlock-bitwarden.ps1 - finish the bw login flow (just the unlock)
# =================================================================
# Assumes 'bw login --apikey' already succeeded (status: locked).
# Prompts for master password via SecureString (paste-safe, masked),
# converts to env var, unlocks via --passwordenv (avoids the broken
# interactive prompt path), persists BW_SESSION, wipes secrets.
# =================================================================

$ErrorActionPreference = 'Stop'

function Ok($m)   { Write-Host "[ok]   $m" -ForegroundColor Green }
function Step($m) { Write-Host ""; Write-Host "[step] $m" -ForegroundColor Cyan }
function Fail($m) { Write-Host "[FAIL] $m" -ForegroundColor Red; exit 1 }

Step "Verifying bw is in 'locked' state"
$status = (& bw status 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue).status
if ($status -eq 'unauthenticated') { Fail "bw is unauthenticated. Run setup-bitwarden.ps1 first." }
if ($status -eq 'unlocked')       { Ok "Already unlocked. Nothing to do."; exit 0 }
Ok "Status: locked - ready to unlock"

Step "Type your master password at the next prompt (masked)"
Write-Host "  IMPORTANT: type the password directly. Do NOT paste a multi-line snippet." -ForegroundColor Yellow
Write-Host "  Press Enter when done. You'll see a length number for sanity check (not the password itself)." -ForegroundColor Yellow
Write-Host ""

$secure = Read-Host "Master password" -AsSecureString
$plain  = [System.Net.NetworkCredential]::new('', $secure).Password
$len    = $plain.Length

Write-Host ""
Write-Host "  Captured input length: $len characters" -ForegroundColor Cyan
if ($len -lt 8) {
    Fail "Only $len characters captured. That's not your master password. Aborting (nothing leaked)."
}
if ($len -gt 64) {
    Write-Host "  WARNING: $len characters is unusually long for a master password." -ForegroundColor Yellow
    Write-Host "  If you pasted a different secret by accident, type 'no' to abort." -ForegroundColor Yellow
    $ok = Read-Host "  Continue with this input? (yes/no)"
    if ($ok -ne 'yes') { $plain = $null; [GC]::Collect(); Fail "Aborted by user." }
}

Step "Unlocking vault via --passwordenv (bypasses broken interactive prompt)"
$env:BW_PASSWORD = $plain
try {
    $session = & bw unlock --passwordenv BW_PASSWORD --raw
    $code = $LASTEXITCODE
} finally {
    # Wipe the env var the moment bw is done with it
    $env:BW_PASSWORD = $null
    Remove-Item Env:\BW_PASSWORD -ErrorAction SilentlyContinue
}

if ($code -ne 0 -or [string]::IsNullOrWhiteSpace($session)) {
    $plain = $null; [GC]::Collect()
    Fail "bw unlock failed. The password you typed doesn't decrypt the vault. Re-verify on vault.bitwarden.com that you can log in there with the same password, then retry."
}
Ok "Vault unlocked. Session token captured."

Step "Persisting BW_SESSION across reboots"
[System.Environment]::SetEnvironmentVariable('BW_SESSION', $session, 'User')
$env:BW_SESSION = $session
Ok "BW_SESSION saved to user env var"

# Wipe in-memory copies
$plain = $null
$session = $null
$secure = $null
[GC]::Collect()

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host " Bitwarden ready on $env:COMPUTERNAME" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
& bw status
Write-Host ""
Write-Host "Test it:" -ForegroundColor Cyan
Write-Host "  Get-Secret OPENAI_API_KEY    # retrieves a stored secret" -ForegroundColor Gray
Write-Host "  Set-Secret TEST_KEY testval  # stores a new one" -ForegroundColor Gray
