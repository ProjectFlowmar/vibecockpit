# =================================================================
# inventory.ps1 - snapshot this machine's dev environment
# =================================================================
# Captures installed tools, browsers, VS Code extensions, credential
# filenames, and git repos. Saves to inventories/<HOSTNAME>.json so
# the cockpit repo can diff machines.
#
# No secrets included - just filenames and version strings.
# =================================================================

$ErrorActionPreference = 'SilentlyContinue'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Locate VS Code 'code' command - handles PATH-missing case
$codeCmd = (Get-Command code -ErrorAction SilentlyContinue).Source
if (-not $codeCmd) {
    $candidates = @(
        "$env:USERPROFILE\AppData\Local\Programs\Microsoft VS Code\bin\code.cmd",
        "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd"
    )
    $codeCmd = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}
$extensions = @()
if ($codeCmd) {
    # cmd.exe wrapper required because code.cmd is a batch shim
    $extOutput = & cmd.exe /c "`"$codeCmd`" --list-extensions" 2>$null
    if ($extOutput) { $extensions = $extOutput | Where-Object { $_ -and $_.Trim() } }
}

# Detect installed browsers
$browsers = @{
    chrome = (Test-Path "$env:ProgramFiles\Google\Chrome\Application\chrome.exe") -or `
             (Test-Path "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe")
    brave  = (Test-Path "$env:ProgramFiles\BraveSoftware\Brave-Browser\Application\brave.exe")
    edge   = (Test-Path "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe")
    firefox = (Test-Path "$env:ProgramFiles\Mozilla Firefox\firefox.exe")
}

# Walk ~/.claude at depth 1 - names only, no contents
function Get-FileNames($path, $depth = 1) {
    if (-not (Test-Path $path)) { return @() }
    Get-ChildItem -Path $path -File -Recurse -Depth $depth -ErrorAction SilentlyContinue |
        ForEach-Object { $_.FullName.Replace($env:USERPROFILE, '~') }
}

# Git repos under home at depth 4
$gitRepos = Get-ChildItem -Path $env:USERPROFILE -Filter ".git" -Directory -Recurse -Depth 4 -ErrorAction SilentlyContinue |
    ForEach-Object { ($_.FullName -replace "\\.git$", "").Replace($env:USERPROFILE, '~') }

$inv = [ordered]@{
    hostname             = $env:COMPUTERNAME
    user                 = $env:USERNAME
    captured_at          = (Get-Date).ToString("o")
    os                   = (Get-CimInstance Win32_OperatingSystem | Select-Object -Expand Caption)
    powershell_version   = $PSVersionTable.PSVersion.ToString()
    node_version         = (node --version 2>$null)
    npm_version          = (npm --version 2>$null)
    git_version          = (git --version 2>$null)
    python_version       = (python --version 2>$null)
    gh_version           = (gh --version 2>$null | Select-Object -First 1)
    bw_version           = (bw --version 2>$null)
    code_path            = $codeCmd
    vscode_extensions    = $extensions
    browsers_installed   = $browsers
    claude_dir_present   = (Test-Path "$env:USERPROFILE\.claude")
    onedrive_path        = $env:OneDrive
    git_repos_under_home = $gitRepos
}

$outDir = Join-Path $scriptDir 'inventories'
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$outFile = Join-Path $outDir "$env:COMPUTERNAME.json"

$inv | ConvertTo-Json -Depth 6 | Out-File $outFile -Encoding utf8
Write-Host "[ok]   Inventory saved -> $outFile" -ForegroundColor Green
