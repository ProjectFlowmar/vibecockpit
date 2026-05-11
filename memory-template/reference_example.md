---
name: Example reference (replace me)
description: Pointer to an external system — account, dashboard, vault, API. NEVER put actual secrets here.
type: reference
---

<!-- Reference files tell the AI WHERE to find things, never WHAT the secret values are.
     Actual credentials live in ~/.openclaw/credentials/ or your password manager — never in memory files. -->

**What this is:** [Name of the external system or account, e.g., "Stripe production account", "Cloudflare zone for example.com", "Bitwarden vault"]

**URL / endpoint:** [URL — fine to commit, it's not a secret]

**Account identifier:** [Email or account ID — also fine if not a secret in your context]

**Where the credentials live:**
- [Path to credential file in your vault, e.g., `~/.openclaw/credentials/stripe.env`]
- [Or: Bitwarden item name, e.g., `Get-Secret STRIPE_SECRET_KEY`]

**What this account is used for:**
- [Project A: production payments]
- [Project B: test mode for staging]

**Quotas / limits to be aware of:**
- [e.g., "API rate limit: 100 req/sec on the live account"]
- [e.g., "Free tier: 1000 requests/month"]

**Watchouts:**
- [Anything subtle the AI should know — e.g., "Production keys live in a separate Bitwarden item; never use test keys against live data."]

**How to apply:** when the user asks anything about this system, check the credential file path above first. If credentials are missing, ask the user — don't guess or try to invent values.
