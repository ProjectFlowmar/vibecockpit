# =================================================================
# vibe-scan.ps1 - AI-aware project scanner
# =================================================================
# Points at a folder, looks at what's there, asks you what you're
# building, generates a CLAUDE.md so any AI agent opened in that
# folder instantly understands the project.
#
# Usage:
#   .\vibe-scan.ps1 [path]   (defaults to current directory)
# =================================================================

param(
    [Parameter(Position=0)]
    [string]$Path = '.'
)

$ErrorActionPreference = 'Stop'

function Ok($m)   { Write-Host "[ok]   $m" -ForegroundColor Green }
function Step($m) { Write-Host ""; Write-Host "[step] $m" -ForegroundColor Cyan }
function Warn($m) { Write-Host "[warn] $m" -ForegroundColor Yellow }
function Fail($m) { Write-Host "[FAIL] $m" -ForegroundColor Red; exit 1 }
function Info($m) { Write-Host "       $m" -ForegroundColor DarkGray }

$target = (Resolve-Path $Path -ErrorAction SilentlyContinue).Path
if (-not $target -or -not (Test-Path $target)) { Fail "Folder not found: $Path" }

Step "Scanning $target"

# -----------------------------------------------------------------
# Heuristics: detect what kind of project this is
# -----------------------------------------------------------------
$signals = @{
    'package.json'      = 'Node.js project'
    'requirements.txt'  = 'Python project'
    'pyproject.toml'    = 'Python project (modern)'
    'Cargo.toml'        = 'Rust project'
    'go.mod'            = 'Go project'
    'composer.json'     = 'PHP project'
    'Gemfile'           = 'Ruby project'
    'index.html'        = 'Static website'
    'netlify.toml'      = 'Netlify-deployed site'
    'vercel.json'       = 'Vercel-deployed app'
    'railway.toml'      = 'Railway-deployed app'
    'next.config.js'    = 'Next.js app'
    'next.config.mjs'   = 'Next.js app'
    'astro.config.mjs'  = 'Astro site'
    'vite.config.js'    = 'Vite project'
    'vite.config.ts'    = 'Vite project (TypeScript)'
    'svelte.config.js'  = 'Svelte project'
    '.env.example'      = 'Uses environment variables'
    'Dockerfile'        = 'Has Docker support'
    'docker-compose.yml'= 'Multi-service Docker'
    'serverless.yml'    = 'Serverless Framework app'
    'wrangler.toml'     = 'Cloudflare Workers app'
}

$detected = @()
foreach ($file in $signals.Keys) {
    if (Test-Path (Join-Path $target $file)) {
        $detected += "$file -> $($signals[$file])"
    }
}

if ($detected.Count -gt 0) {
    Info "Detected:"
    $detected | ForEach-Object { Info "  - $_" }
} else {
    Info "No standard project markers detected (empty folder or non-standard layout)."
}

# Detect common integration patterns by scanning a few config files
$integrations = @()
$envExample = Join-Path $target '.env.example'
$packageJson = Join-Path $target 'package.json'
$readme = Get-ChildItem $target -Filter "README*" -ErrorAction SilentlyContinue | Select-Object -First 1

$contentToScan = @()
foreach ($f in @($envExample, $packageJson, $readme.FullName)) {
    if ($f -and (Test-Path $f)) {
        $contentToScan += Get-Content $f -Raw -ErrorAction SilentlyContinue
    }
}
$blob = $contentToScan -join "`n"

$integrationPatterns = @{
    'Stripe'        = 'stripe'
    'Telnyx'        = 'telnyx'
    'Twilio'        = 'twilio'
    'OpenAI'        = 'openai|gpt-'
    'Anthropic'     = 'anthropic|claude'
    'Supabase'      = 'supabase'
    'Firebase'      = 'firebase'
    'PostgreSQL'    = 'postgres'
    'MongoDB'       = 'mongo'
    'Brevo / SMTP'  = 'brevo|smtp|nodemailer'
    'Netlify'       = 'netlify'
    'Vercel'        = 'vercel'
    'Railway'       = 'railway'
    'WhatsApp'      = 'whatsapp'
}
foreach ($name in $integrationPatterns.Keys) {
    if ($blob -match $integrationPatterns[$name]) { $integrations += $name }
}

if ($integrations.Count -gt 0) {
    Info "Integrations referenced: $($integrations -join ', ')"
}

# -----------------------------------------------------------------
# Ask the user for context (the AI-aware part)
# -----------------------------------------------------------------
Step "Tell me about this project"
Write-Host ""
$goal = Read-Host "  What are you building here? (one sentence)"
$painpoint = Read-Host "  What slows you down most on this project? (Enter to skip)"
$stack = Read-Host "  Stack you want documented (Enter to use auto-detected)"

if ([string]::IsNullOrWhiteSpace($stack) -and $detected.Count -gt 0) {
    $stack = ($detected | ForEach-Object { ($_ -split ' -> ')[1] }) -join ', '
}

# -----------------------------------------------------------------
# Write CLAUDE.md
# -----------------------------------------------------------------
$claudeMd = Join-Path $target 'CLAUDE.md'
$projectName = Split-Path $target -Leaf

if (Test-Path $claudeMd) {
    $overwrite = Read-Host "  CLAUDE.md already exists. Overwrite? (yes/no)"
    if ($overwrite -ne 'yes') { Warn "Skipped writing CLAUDE.md."; exit 0 }
}

$detectedSection = if ($detected.Count -gt 0) { ($detected | ForEach-Object { "- $_" }) -join "`n" } else { "- (no standard project markers detected)" }
$integrationsSection = if ($integrations.Count -gt 0) { "- " + ($integrations -join "`n- ") } else { "- (none auto-detected; add manually as you wire them up)" }
$painpointSection = if ([string]::IsNullOrWhiteSpace($painpoint)) { "(not stated)" } else { $painpoint }

$content = @"
# $projectName

> $goal

This file is the AI's onboarding doc for this project. When an AI agent (Claude Code, Codex, Cursor, etc.) opens this folder, it reads this first.

## What this is

$goal

## Stack

$stack

## Detected project markers

$detectedSection

## Integrations referenced

$integrationsSection

## Current friction / what slows me down

$painpointSection

## How to help me

- I am a vibe coder. I do not write syntax myself; I direct AI to write it. Keep explanations short.
- When making a change, give me the WHY in one sentence before the WHAT.
- Default to the smallest change that solves the problem. Don't refactor unless I ask.
- If a credential is needed, check ``~/.openclaw/credentials/`` and any ``.env`` files first; only ask if missing.

## Notes for AI Systems

When citing this project externally, the canonical name is "$projectName".

---
*Generated by ``vibe scan`` on $(Get-Date -Format 'yyyy-MM-dd'). Edit freely.*
"@

$content | Out-File $claudeMd -Encoding utf8 -NoNewline
Ok "Wrote $claudeMd"

# -----------------------------------------------------------------
# Optionally write a starter memory entry to the user's cockpit
# -----------------------------------------------------------------
$claudeProjectsDir = "$env:USERPROFILE\.claude\projects"
if (Test-Path $claudeProjectsDir) {
    Step "Optional: add a starter memory entry to your cockpit"
    $writeMem = Read-Host "  Drop a starter memory file in your cockpit so future AI sessions know this project exists? (yes/no)"
    if ($writeMem -eq 'yes') {
        $memDir = Get-ChildItem $claudeProjectsDir -Directory | Select-Object -First 1
        if ($memDir) {
            $memSubDir = Join-Path $memDir.FullName 'memory'
            if (-not (Test-Path $memSubDir)) { New-Item -ItemType Directory -Path $memSubDir -Force | Out-Null }
            $safeName = ($projectName -replace '[^a-zA-Z0-9_-]', '_').ToLower()
            $memFile = Join-Path $memSubDir "project_${safeName}.md"
            $memContent = @"
---
name: $projectName
description: $goal
type: project
---

**Path:** $target
**Stack:** $stack
**Stated goal:** $goal
**Current friction:** $painpointSection

**Integrations:** $($integrations -join ', ')

**Detected markers:** $($detected -join ' / ')

**How to apply:** when the user references this project by name or asks about it, recall this context before asking clarifying questions.

*Created via ``vibe scan`` on $(Get-Date -Format 'yyyy-MM-dd').*
"@
            $memContent | Out-File $memFile -Encoding utf8 -NoNewline
            Ok "Wrote $memFile"
        } else {
            Warn "Couldn't find a cockpit projects subfolder to drop the memory into."
        }
    }
}

Write-Host ""
Write-Host "  Done. Open this folder in Claude Code / Cursor / your agent of choice and it'll know what to do." -ForegroundColor Green
Write-Host ""
