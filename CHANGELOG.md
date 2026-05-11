# Changelog

## v0.2 — 2026-05-11

Same-day follow-up to v0.1. Three things:

### Added — ambient sync via Scheduled Tasks
- `vibe install-tasks` registers two Windows Scheduled Tasks per machine:
  - **VibeCockpitSyncDaemon** runs every 10 minutes: pulls + auto-commits + pushes. No more "remember to git pull before working" or "did I push before closing the lid?"
  - **VibeCockpitHealthCheck** runs once a day at 08:00: executes `vibe-sync-test`, drops `logs/SYNC-ALERT.txt` if anything fails. The PowerShell profile checks for that flag on every shell open and prints a yellow warning if present.
- `vibe-sync-daemon.ps1` — the daemon itself. Self-heals missing upstream tracking on first push.
- `vibe-health-check.ps1` — the health check.

### Added — Bitwarden CLI integration
- `vibe setup-bitwarden` walks through API-key login + first unlock + persistent `BW_SESSION` user env var. Uses `Read-Host -AsSecureString` for masked input so credentials never enter scrollback.
- `vibe unlock-bitwarden` re-unlocks after reboot or `bw lock`. Includes a length sanity check on captured input — catches accidental paste-the-wrong-thing.
- Both walk you through API-key flow specifically (not master password) because API keys are designed for headless setups.

### Added — `vibe test`
- Promoted `vibe-sync-test.ps1` from a v0.1 file to a first-class subcommand. End-to-end self-test in 4 sections (cockpit repo · memory + commands · cloud drive vault · PowerShell profile + Bitwarden). Prints `[PASS]` / `[FAIL]` per check, ends with `RESULT: X / Y tests passed`.

### Added — LESSONS.md
- Hard-won knowledge from shipping this in one day: PowerShell 5.1 traps, in-place git migration when files are locked, whitelist `.gitignore`, credential routing rule, no-creds-via-chat, daemon + flag-file architecture.

### Changed
- `vibe.ps1` dispatcher now exposes 9 commands (was 5). Reorganized help into "Daily" / "One-time setup" / "Health + diagnostics".
- All scripts ASCII-only output (PS 5.1 reads `.ps1` as Latin-1 without a BOM; UTF-8 glyphs break the parser).
- Daemon uses local `git config user.email/name` if set, falls back to a generic `vibecockpit-daemon@localhost` identity if not. No more hardcoded identities.

---

## v0.1 — 2026-05-11

Initial public release.

### Added
- `vibe init` — persona-driven fresh-machine bootstrap (5 personas)
- `vibe sync` — pull + commit + push your private cockpit repo
- `vibe scan` — AI-aware project scanner, generates CLAUDE.md
- `vibe rewind` — time-travel your config to a past point
- `vibe inventory` — per-machine snapshot for diffing
- 5 personas (AI Operator, Web Vibe Coder, Solo Founder, Terminal Native, Curious Beginner)
- Per-persona VS Code extension lists
- Memory templates (user, feedback, project, reference)
- Whitelist `.gitignore` — secrets cannot leak
- MIT license, telemetry-free
