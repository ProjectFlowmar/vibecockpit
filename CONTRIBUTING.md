# Contributing to VibeCockpit

Welcome! This project is small and opinionated on purpose. Read the README first to understand who it's for.

## Quick wins anyone can send

- **Add a persona.** If you're a "category" the project doesn't cover yet (designer-who-codes, data analyst, marketer with automations), open a PR adding your persona to `personas.json` + an extension list in `extensions/<your-persona>.txt`. We'll talk about the install list.
- **Fix a Windows quirk.** PowerShell 5.1 has many traps. If you hit one and figured out the workaround, send a PR — include the symptom in the commit message so the next person finds it.
- **Improve the README.** It's aimed at non-engineer vibe coders. If a section sounds too "developer-y" or assumes too much, simplify it.

## What we won't merge (without a heated discussion first)

- **Telemetry / phone-home of any kind.** VibeCockpit's promise is that your config lives in YOUR repo and nothing leaves your machine without you sending it. We won't add usage analytics, error reporting, or auto-update checks against a central server.
- **Adding Claude Code or any specific AI as a mandatory dependency.** The whole point of `vibe init` is that you pick your stack. We keep tools optional.
- **Cloud-hosted backend.** Stays a local CLI. If you want a SaaS version, fork it.

## Style

- **PowerShell scripts must be ASCII-only.** Windows PowerShell 5.1 reads `.ps1` files as Latin-1 without a BOM. UTF-8 emoji or arrows in script literals will break the parser at random lines.
- **No `2>&1` on native executables.** PS 5.1 wraps stderr as `NativeCommandError` even when the exit code is 0. Let stderr flow to the user's terminal.
- **No `Read-Host` in pasted multi-line snippets.** Always wrap interactive flows in a `.ps1` script file. Read-Host will swallow the rest of a clipboard paste as "user input."

## How to test a change

```powershell
# In a throwaway folder
git clone https://github.com/YourFork/vibecockpit.git test-cockpit
cd test-cockpit
.\vibe.ps1 init   # walk through the persona prompt
.\vibe.ps1 scan . # try the project scanner
```

Open an issue first if it's anything bigger than a small tweak — saves both of us time.

## Maintainer

[@ProjectFlowmar](https://github.com/ProjectFlowmar) (Omar Catlin). I write code with AI; I'm an INTP-style operator and a licensed insurance broker by day. The vibe of this project should match: practical, opinionated, friendly to non-engineers, no jargon dumps. Keep that vibe in PRs.
