# Lessons learned shipping VibeCockpit

Things that cost real time when I built this. Writing them down so the next person (or the next me) doesn't repeat them.

---

## Windows PowerShell 5.1 traps

PS 5.1 is the default shell on Windows 11, and it has at least three landmines worth knowing.

### 1. `2>&1` on native executables wraps stderr as exceptions

```powershell
$out = git fetch origin 2>&1   # BAD on PS 5.1
```

When PS 5.1 redirects a native command's stderr, every line gets wrapped in a `RemoteException` / `NativeCommandError`. `$LASTEXITCODE` may still be 0, but the variable is now full of exception objects, downstream parsing breaks, and you spend 45 minutes debugging "why is my git fetch failing" when it isn't.

**Fix:** don't `2>&1` on native commands. Capture the stream you want; let the other one flow to the user's terminal.

```powershell
git fetch origin            # progress goes to stderr -> terminal
$head = git rev-parse HEAD  # stdout captured cleanly
```

### 2. `Read-Host` swallows pasted multi-line snippets as input

```powershell
$x = Read-Host "Password" -AsSecureString
$y = $next_line_of_my_pasted_snippet     # ← becomes part of "password"
```

If you hand a user a multi-line snippet to paste into PowerShell where the first line opens an interactive prompt, the prompt eats the rest of the paste as the user's "input". The remaining lines of code never execute.

**Fix:** don't ship multi-line snippets that contain `Read-Host`. Put them in a `.ps1` file and have the user run the file as one command. The file gets read by the parser, not the prompt.

### 3. `.ps1` files need ASCII or a UTF-8 BOM

PS 5.1 reads `.ps1` files as Latin-1 / cp1252 if there's no byte-order mark. Unicode glyphs in script literals (✓ → ✗ ═ —) get decoded as multi-byte mojibake. The mojibake usually contains a stray quote which breaks the parser at apparently-random line numbers.

**Fix:** ASCII-only output (`[ok]`, `[step]`, `[FAIL]`, `===`). Or save with UTF-8 BOM. ASCII is more bulletproof.

---

## In-place git migration when files are locked

You want to convert an existing folder into a git clone, but some files inside are held open by a running process (cache files, plugin DLLs, lockfiles). `Move-Item` fails with "you do not have sufficient access rights."

**Don't:** move the folder out, clone fresh in, restore. Locked files block the move.

**Do:** clone in place by initializing git inside the existing folder.

```powershell
cd $folder
git init -b main
git remote add origin $repoUrl
git fetch origin
git reset --soft origin/main         # tell git "you're at this commit"
git checkout -f origin/main -- .     # overlay repo files onto live folder
```

Existing files with the same name as repo files get overwritten. Files unique to the folder stay put. The repo's `.gitignore` (whitelist style) makes git invisible to everything else.

Bonus: the next `git push` will fail with "no upstream branch" the first time. Self-heal with:
```powershell
git push --set-upstream origin main
```

---

## Whitelist `.gitignore` for credential safety

The default approach to `.gitignore` is blacklist: list things to exclude. This fails open — anything you forget to list gets committed. For a repo that lives in `~/.claude/`, that's a recipe for leaked OAuth tokens.

**Whitelist instead:** ignore everything by default, then explicitly allow only what you want to sync.

```gitignore
# Ignore everything
*

# Re-include the gitignore + readme
!.gitignore
!README.md

# Re-include memory + commands (the only real payload)
!projects/
!projects/*/
!projects/*/memory/
!projects/*/memory/**
!commands/
!commands/**
```

Now `git add -A` will silently skip every secret, every cache file, every conversation transcript. You can't accidentally commit them.

---

## Credential routing — one rule eliminates ambiguity

Once you have multiple credential systems (Bitwarden + Drive folder + machine-local), you constantly ask "which one does this go in?" Resolve it once:

| Shape | Channel |
|---|---|
| Single string ≤200 chars (API key, password) | Bitwarden |
| Multi-line file (.json, .pem, .env) | Cloud-drive folder, local junction |
| Refreshes per-machine (OAuth token, session) | Machine-local, never synced |

Decide by **shape**, not by service. "What is the credential?" → instant answer to "where does it go?"

---

## Never accept credentials via chat

If you're directing an AI assistant and a credential is needed, never paste it into the chat. The chat is logged on the AI provider's servers, in your local transcript, and (on Windows) in PSReadLine history.

**The pattern:**
- You write the credential to a vault file (Bitwarden, encrypted folder, etc.)
- The AI reads it from disk when needed

**The anti-pattern:**
- You type "OPENAI_API_KEY=sk-..." into chat
- That string is now in 3+ places forever and must be rotated

We learned this the hard way during VibeCockpit's own Bitwarden setup. Twice.

---

## Sync system architecture: one repo + one cloud drive

VibeCockpit's sync model intentionally uses two channels:

- **Git repo** for code-shaped things: scripts, slash commands, memory files, README. Versioned, conflict-detected, easy to revert (`vibe rewind`).
- **Cloud drive folder** for file-shaped things: credentials, large binary assets, anything you don't want in git history.

These two channels are **independent**. The cloud drive holds files that should never enter git; the git repo holds files that should never enter the drive's folder. A whitelist `.gitignore` enforces the boundary.

The result: edit a memory file → it syncs via git (with version history). Add an API key → it syncs via cloud drive (no git history, but encrypted at rest). Two channels, both ambient, neither requires you to think about it.

---

## Daemons + flag files for ambient operations

VibeCockpit's `vibe install-tasks` registers two Windows Scheduled Tasks:

- `VibeCockpitSyncDaemon` runs every 10 min: pulls + auto-commits + pushes
- `VibeCockpitHealthCheck` runs daily at 08:00: runs the self-test, drops a flag file if anything fails

The PowerShell profile checks for that flag file on every shell open. If sync broke at 03:00 and you open a terminal at 09:00, you get a yellow warning across the top — no email, no push notification, no app. Just a file the next shell session reads.

This pattern (flag files + opportunistic detection) is much simpler than running an alerting service and works fine for a single user.

---

*— Omar Catlin / [@ProjectFlowmar](https://github.com/ProjectFlowmar), shipped 2026-05-11. PRs that add lessons or correct mistakes welcome.*
