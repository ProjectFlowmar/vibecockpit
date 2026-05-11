# =================================================================
# vibe.ps1 - VibeCockpit dispatcher
# =================================================================
# Single entry point for all subcommands. Routes to vibe-*.ps1 files.
#
# Usage:
#   .\vibe.ps1 init                 Fresh-machine setup (persona-driven)
#   .\vibe.ps1 sync                 Pull + commit + push memory/config
#   .\vibe.ps1 scan [path]          AI-aware project scan + CLAUDE.md generator
#   .\vibe.ps1 rewind <when>        Restore memory/config to a past point
#   .\vibe.ps1 inventory            Snapshot this machine for diffing
#   .\vibe.ps1 test                 Run end-to-end sync system self-test
#   .\vibe.ps1 install-tasks        Register the auto-sync + health-check Scheduled Tasks
#   .\vibe.ps1 setup-bitwarden      One-time Bitwarden CLI login
#   .\vibe.ps1 unlock-bitwarden     Unlock the Bitwarden vault for this session
#   .\vibe.ps1 help                 Show this help
# =================================================================

param(
    [Parameter(Position=0)]
    [string]$Command = 'help',

    [Parameter(Position=1, ValueFromRemainingArguments=$true)]
    [string[]]$RemainingArgs
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Show-Help {
    Write-Host ""
    Write-Host "  VibeCockpit - your dev workspace, portable as a backpack" -ForegroundColor Cyan
    Write-Host "  ----------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Daily commands:" -ForegroundColor White
    Write-Host "    init              " -NoNewline -ForegroundColor Green
    Write-Host "Fresh-machine setup. Asks you one question, installs the rest."
    Write-Host "    sync              " -NoNewline -ForegroundColor Green
    Write-Host "Pull + commit + push your cockpit repo (memory + config)."
    Write-Host "    scan [path]       " -NoNewline -ForegroundColor Green
    Write-Host "Look at a project folder. Generate a CLAUDE.md so AI agents know what it is."
    Write-Host "    rewind <when>     " -NoNewline -ForegroundColor Green
    Write-Host "Time-travel your config. Examples: '1hour', '2days', '1week'."
    Write-Host "    inventory         " -NoNewline -ForegroundColor Green
    Write-Host "Snapshot this machine to inventories/<HOSTNAME>.json."
    Write-Host ""
    Write-Host "  One-time setup:" -ForegroundColor White
    Write-Host "    install-tasks     " -NoNewline -ForegroundColor Green
    Write-Host "Register Scheduled Tasks for ambient auto-sync + daily health check."
    Write-Host "    setup-bitwarden   " -NoNewline -ForegroundColor Green
    Write-Host "Bitwarden CLI login (uses API key, not master password in chat/scrollback)."
    Write-Host ""
    Write-Host "  Health + diagnostics:" -ForegroundColor White
    Write-Host "    test              " -NoNewline -ForegroundColor Green
    Write-Host "End-to-end sync system self-test."
    Write-Host "    unlock-bitwarden  " -NoNewline -ForegroundColor Green
    Write-Host "Re-unlock the Bitwarden vault if locked (after reboot, etc.)."
    Write-Host ""
    Write-Host "    help              " -NoNewline -ForegroundColor Green
    Write-Host "This message."
    Write-Host ""
    Write-Host "  Learn more: https://github.com/ProjectFlowmar/vibecockpit" -ForegroundColor DarkGray
    Write-Host ""
}

switch ($Command.ToLower()) {
    'init'             { & "$scriptDir\vibe-init.ps1" @RemainingArgs }
    'sync'             { & "$scriptDir\vibe-sync.ps1" @RemainingArgs }
    'scan'             { & "$scriptDir\vibe-scan.ps1" @RemainingArgs }
    'rewind'           { & "$scriptDir\vibe-rewind.ps1" @RemainingArgs }
    'inventory'        { & "$scriptDir\inventory.ps1" @RemainingArgs }
    'test'             { & "$scriptDir\vibe-sync-test.ps1" @RemainingArgs }
    'install-tasks'    { & "$scriptDir\vibe-install-tasks.ps1" @RemainingArgs }
    'setup-bitwarden'  { & "$scriptDir\vibe-setup-bitwarden.ps1" @RemainingArgs }
    'unlock-bitwarden' { & "$scriptDir\vibe-unlock-bitwarden.ps1" @RemainingArgs }
    'help'             { Show-Help }
    '--help'           { Show-Help }
    '-h'               { Show-Help }
    default {
        Write-Host "Unknown command: $Command" -ForegroundColor Red
        Show-Help
        exit 1
    }
}
