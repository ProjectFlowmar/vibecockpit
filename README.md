# VibeCockpit

**Your dev workspace, portable as a backpack.**

Run one command on any Windows machine. Five minutes later your full AI-coding setup is there — same editor, same extensions, same Claude/Codex/Cursor memory, same slash commands. Walk away from your desk, open your laptop somewhere else, keep working.

After v0.2: it also keeps itself synced in the background. You stop thinking about `git pull` / `git push` entirely.

```powershell
.\vibe.ps1 init           # one-time setup
.\vibe.ps1 install-tasks  # one-time: enable ambient auto-sync
```

Built by [@ProjectFlowmar](https://github.com/ProjectFlowmar) (Omar Catlin) — a licensed insurance broker who codes with AI. Made for people in the same situation.

📋 [What's new in v0.2](CHANGELOG.md) · 📚 [Lessons learned shipping this](LESSONS.md)

---

## Who this is for

You, if:

- You direct AI to write code rather than writing it yourself ("vibe coder")
- You work on **multiple Windows machines** — home desktop + travel laptop, or office PC + personal
- You use Claude Code, Codex, Cursor, Aider, openclaw, Continue, or any combination — and you're tired of re-doing your setup every time you switch
- You're an **operator, solo founder, or small-biz owner** who picked up coding because AI made it possible — not a career developer

You, if not:

- You only have one machine (you'll get less out of this; come back when you get a laptop)
- You're a career engineer with a polished dotfiles setup you love. Use [chezmoi](https://chezmoi.io). It's better for you.

---

## What's actually in the box

```
vibecockpit/
├── vibe.ps1                 ← single entry point. Dispatches to the others.
├── vibe-init.ps1            ← asks one question, installs your stack
├── vibe-sync.ps1            ← pull + commit + push between machines
├── vibe-scan.ps1            ← AI-aware project scanner. Generates a CLAUDE.md.
├── vibe-rewind.ps1          ← time-travel your config to a past point
├── inventory.ps1            ← per-machine snapshot for diffing
├── personas.json            ← 5 starter personas; add your own
├── extensions/              ← VS Code extension list per persona
├── memory-template/         ← starter memory files for new users
└── .gitignore               ← whitelist: secrets cannot leak
```

---

## The 5 commands

### `vibe init`

Fresh-machine setup. Asks **one question** — "which persona fits you?" — then installs the right stack.

Personas in v1:

| Persona | For |
|---|---|
| **AI Operator** | Small-biz operators running multiple AI automations |
| **Web Vibe Coder** | Static sites, landing pages, marketing micro-apps |
| **Solo Founder** | Full-stack: backend + payments + lead capture |
| **Terminal Native** | "Just give me the shell, no GUI" |
| **Curious Beginner** | "I've never coded; install the minimum to try AI safely" |

Each persona = a different `winget install` list + a different VS Code extension set. Mix-and-match later, swap personas any time.

```powershell
.\vibe.ps1 init
```

### `vibe sync`

Pull memory + config from the other machine, commit any changes you made here, push back. The whole cross-machine workflow in one command.

```powershell
.\vibe.ps1 sync
```

### `vibe scan [folder]`

Point it at any project folder. It looks at what's there (package.json? netlify.toml? .env.example?), asks you **"what are you building and what slows you down?"**, then writes a `CLAUDE.md` to the folder so any AI agent that opens it instantly knows the project.

Optionally drops a starter memory entry into your cockpit so future AI sessions across all your machines know this project exists.

```powershell
.\vibe.ps1 scan C:\Users\me\my-project
```

### `vibe rewind <when>`

You broke something with a recent config edit? Time-travel your `~/.claude/` back to where it was.

```powershell
.\vibe.ps1 rewind 1hour
.\vibe.ps1 rewind 1day
.\vibe.ps1 rewind 1week
.\vibe.ps1 rewind 2026-05-01
.\vibe.ps1 rewind list      # show recent restore points
```

Only touches memory + commands + CLAUDE.md. Settings.json (which has your tokens) stays put. Reversible — `git checkout HEAD` puts you right back.

### `vibe inventory`

Snapshots this machine to `inventories/<HOSTNAME>.json`. Commit it. When you set up a new machine, you can diff it against this one and see exactly what's missing.

```powershell
.\vibe.ps1 inventory
```

### `vibe install-tasks` *(v0.2)*

Registers two Windows Scheduled Tasks per machine — turns `vibe sync` from a thing you remember to run into ambient infrastructure you don't think about:

- **VibeCockpitSyncDaemon** — every 10 min: `git pull`, auto-commit anything new, `git push`.
- **VibeCockpitHealthCheck** — daily at 08:00: runs `vibe test`, drops a `SYNC-ALERT.txt` flag file if anything fails. Your PowerShell profile checks for that flag on shell open and prints a yellow warning.

```powershell
.\vibe.ps1 install-tasks
```

No admin needed. Idempotent. Safe to re-run.

### `vibe test` *(v0.2)*

End-to-end self-test. Verifies the cockpit repo, memory + commands counts, cloud-drive credential vault junction, PowerShell profile + Bitwarden helpers. Use anytime drift is suspected.

```powershell
.\vibe.ps1 test
```

### `vibe setup-bitwarden` / `vibe unlock-bitwarden` *(v0.2)*

One-time Bitwarden CLI login (uses API key, never master password in chat) + a re-unlock helper for after a reboot.

```powershell
.\vibe.ps1 setup-bitwarden    # one-time per machine
.\vibe.ps1 unlock-bitwarden   # after reboot or 'bw lock'
```

After this, `Get-Secret OPENAI_API_KEY` works from anywhere — small password-style secrets handled separately from the cloud-drive credential folder. See `LESSONS.md` for the routing rule.

---

## How sync actually works

VibeCockpit doesn't have a cloud backend. There are no servers. **The "sync" is just git push/pull on your own private GitHub repo.**

Setup:
1. Create a private repo (suggested name: `your-name-cockpit`).
2. Clone it into `~/.claude/` on every machine you want synced.
3. Run `vibe sync` before you leave a machine; run `vibe sync` when you arrive at the next one.

What gets synced:
- Memory files (`projects/*/memory/*.md`)
- Custom slash commands (`commands/*.md`)
- Root-level `CLAUDE.md` if you have one
- Bootstrap scripts and machine inventories

What's never synced (the whitelist `.gitignore` enforces this):
- `settings.json` (has your OAuth token)
- `.credentials.json` (Anthropic OAuth)
- Conversation transcripts, history, cache, statsig
- Any `.env` files or `*.key` / `*.pem`

### Running multiple parallel AI sessions

Running 2-3 Claude Code (or Codex / Cursor) sessions in parallel terminals works **if and only if each session is in a different working directory**. Claude namespaces memory by the directory you launched from — so `cd ~/proj-A; claude` and `cd ~/proj-B; claude` write to separate memory folders and never conflict.

If you start two sessions in the **same** working directory, they share memory and the sync-daemon will hit silent merge conflicts on `MEMORY.md` roughly every 10 minutes. See [LESSONS.md](LESSONS.md) for the full breakdown and rules.

---

## Credentials — the safe way

Three tiers:

1. **GitHub OAuth tokens, MCP server configs** → stay machine-local in `~/.claude/settings.json` (gitignored). Use `gh auth login` on each machine.

2. **API keys for projects (Stripe, OpenAI, Telnyx, etc.)** → file-based vault at `~/.openclaw/credentials/<service>.env`. Symlink this folder from a cloud drive (Google Drive Desktop, OneDrive) so it auto-syncs across machines without ever entering git.

3. **Small password-style tokens** → Bitwarden CLI. `vibe init` installs `bw`; use `Get-Secret <KEY_NAME>` from any project to retrieve. See `vibe-setup-bitwarden.ps1` (coming in v0.2) for setup.

The whitelist `.gitignore` prevents accidental commits of any of these.

---

## Telemetry, privacy, sovereignty

This project does not phone home. It has no analytics. It does not check for updates against any server. It does not upload your config anywhere except the private GitHub repo *you* configure as the remote.

The maintainer cannot see who installs it, who uses it, or what's in your cockpit. That is by design and we will refuse PRs that change this.

---

## What's NOT here yet (roadmap)

- **Cross-platform** — currently Windows / PowerShell only. macOS + Linux is on the list as a Node CLI rewrite (`npx vibecockpit init`).
- **GUI** — no plans. The whole point is one command.
- **Plugin system** — maybe, if multiple people ask. For now, fork it.
- **Cursor / JetBrains-specific flows** — currently focused on VS Code + the CLI agents. PRs welcome.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The bar is low — PRs that add personas, fix PowerShell quirks, or improve the README for non-engineers are immediately welcome.

---

## Why I built this

I'm a licensed insurance broker. I'm an INTP. I don't write code well, but I direct AI to write code constantly — for my own business, for client work, for one-off automations. I run Claude Code on my office desktop and my Lenovo Yoga laptop, and I kept losing context every time I switched machines.

I built `claude-config-sync` (private) to fix it for myself. After it worked for a week, I extracted the generic parts here so anyone else in the same situation can have the same fix.

If that's you, welcome. If it helps, give the repo a star — that's the only "telemetry" I'll ever ask for.

— Omar
