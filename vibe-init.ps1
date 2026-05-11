# =================================================================
# vibe-init.ps1 - persona-driven fresh-machine bootstrap
# =================================================================
# Asks ONE question. Installs the right stack. Sets up your cockpit
# repo. About 5 minutes start to finish on a good connection.
# =================================================================

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Ok($m)   { Write-Host "[ok]   $m" -ForegroundColor Green }
function Step($m) { Write-Host ""; Write-Host "[step] $m" -ForegroundColor Cyan }
function Warn($m) { Write-Host "[warn] $m" -ForegroundColor Yellow }
function Fail($m) { Write-Host "[FAIL] $m" -ForegroundColor Red; exit 1 }
function Info($m) { Write-Host "       $m" -ForegroundColor DarkGray }

# -----------------------------------------------------------------
Write-Host ""
Write-Host "  ===============================================================" -ForegroundColor Cyan
Write-Host "   VibeCockpit init - $env:COMPUTERNAME" -ForegroundColor Cyan
Write-Host "  ===============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Your dev workspace, portable as a backpack." -ForegroundColor White
Write-Host "  This installs your stack. ~5 minutes." -ForegroundColor DarkGray
Write-Host ""

# -----------------------------------------------------------------
Step "Phase 1/5 - Pick your persona"

$personasFile = Join-Path $scriptDir 'personas.json'
if (-not (Test-Path $personasFile)) { Fail "personas.json not found at $personasFile" }
$personasData = Get-Content $personasFile -Raw | ConvertFrom-Json
$personas = $personasData.personas

Write-Host ""
for ($i = 0; $i -lt $personas.Count; $i++) {
    $p = $personas[$i]
    Write-Host "    [$($i+1)] $($p.name)" -ForegroundColor White
    Write-Host "        $($p.tagline)" -ForegroundColor DarkGray
    Write-Host ""
}

$pick = Read-Host "  Which persona fits you? (number 1-$($personas.Count))"
if ($pick -notmatch '^\d+$' -or [int]$pick -lt 1 -or [int]$pick -gt $personas.Count) {
    Fail "Invalid choice. Re-run and pick a number between 1 and $($personas.Count)."
}
$persona = $personas[[int]$pick - 1]
Ok "Persona: $($persona.name)"

# -----------------------------------------------------------------
Step "Phase 2/5 - Install core tools via winget"

$wingetExe = Get-Command winget -ErrorAction SilentlyContinue
if (-not $wingetExe) { Fail "winget not found. Update Windows 11 or install App Installer from the Microsoft Store, then retry." }

foreach ($pkg in $persona.winget_packages) {
    Info "installing $pkg"
    & winget install --id $pkg --silent --accept-package-agreements --accept-source-agreements 2>$null | Out-Null
}
Ok "Core tools installed (or already present)"

# -----------------------------------------------------------------
Step "Phase 3/5 - Install VS Code extensions"

# Locate code command
$codeCmd = (Get-Command code -ErrorAction SilentlyContinue).Source
if (-not $codeCmd) {
    $candidates = @(
        "$env:USERPROFILE\AppData\Local\Programs\Microsoft VS Code\bin\code.cmd",
        "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd"
    )
    $codeCmd = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}

$extFile = Join-Path $scriptDir "extensions\$($persona.extensions_file)"
if (-not (Test-Path $extFile)) {
    Warn "Extension list not found at $extFile - skipping VS Code extensions"
} elseif (-not $codeCmd) {
    Warn "VS Code 'code' command not found - skipping. Install VS Code first, then re-run."
} else {
    $extensions = Get-Content $extFile | Where-Object { $_ -and -not $_.StartsWith('#') -and $_.Trim() }
    foreach ($ext in $extensions) {
        Info "installing extension $ext"
        & cmd.exe /c "`"$codeCmd`" --install-extension $ext --force" 2>$null | Out-Null
    }
    Ok "Installed $($extensions.Count) extensions"
}

# -----------------------------------------------------------------
Step "Phase 4/5 - Set up the cockpit repo at ~/.claude/"

$claudeDir = Join-Path $env:USERPROFILE '.claude'
$repoUrl = Read-Host "  GitHub URL of your private cockpit repo (or press Enter to skip)"
if ([string]::IsNullOrWhiteSpace($repoUrl)) {
    Info "Skipped. Create one later with:"
    Info "  gh repo create yourname/my-cockpit --private --clone"
    Info "  Use VibeCockpit's whitelist .gitignore as a starting point."
} else {
    if (Test-Path $claudeDir) {
        $backup = "$claudeDir.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Warn "$claudeDir exists - backing up to $backup"
        Rename-Item $claudeDir $backup
    }
    Info "Cloning your cockpit into $claudeDir"
    & git clone $repoUrl $claudeDir 2>$null
    if ($LASTEXITCODE -eq 0) {
        Ok "Cockpit cloned"
    } else {
        Warn "Clone failed - is the URL correct and are you 'gh auth login'-ed? Continuing."
    }
}

# Drop memory templates (only if the cockpit didn't already have memory files)
$memDest = Join-Path $claudeDir "projects\C--Users-$env:USERNAME\memory"
$memTemplate = Join-Path $scriptDir 'memory-template'
if ((Test-Path $memTemplate) -and -not (Test-Path $memDest)) {
    New-Item -ItemType Directory -Path $memDest -Force | Out-Null
    foreach ($f in $persona.starter_memory) {
        $src = Join-Path $memTemplate $f
        if (Test-Path $src) {
            Copy-Item $src (Join-Path $memDest $f)
        }
    }
    # Always copy the index
    $indexSrc = Join-Path $memTemplate 'MEMORY.md'
    if (Test-Path $indexSrc) { Copy-Item $indexSrc (Join-Path $memDest 'MEMORY.md') }
    Ok "Dropped starter memory templates into $memDest"
}

# -----------------------------------------------------------------
Step "Phase 5/5 - Capture an inventory snapshot"

$invScript = Join-Path $scriptDir 'inventory.ps1'
if (Test-Path $invScript) {
    & $invScript
    Ok "Inventory captured"
} else {
    Warn "inventory.ps1 not found - skipping"
}

# -----------------------------------------------------------------
Write-Host ""
Write-Host "  ===============================================================" -ForegroundColor Green
Write-Host "   Done. Welcome to VibeCockpit." -ForegroundColor Green
Write-Host "  ===============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Next:" -ForegroundColor White
Write-Host "    $($persona.post_install_hint)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Daily use:" -ForegroundColor White
Write-Host "    .\vibe.ps1 sync       # pull / push your config across machines" -ForegroundColor DarkGray
Write-Host "    .\vibe.ps1 scan <dir> # generate a CLAUDE.md for a project" -ForegroundColor DarkGray
Write-Host "    .\vibe.ps1 rewind 1day # if you broke something" -ForegroundColor DarkGray
Write-Host ""
