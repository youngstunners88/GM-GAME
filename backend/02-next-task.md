# backend — next task

**Single next action (CLIENT, ~1 minute):** give the deploy script a usable
Cloudflare credential, then run it.

1. dash.cloudflare.com → copy your **Account ID** (right sidebar) → set env
   `CLOUDFLARE_ACCOUNT_ID=<id>` — OR mint a token with
   [Workers Scripts:Edit, Workers KV Storage:Edit, Account Settings:Read].
2. Run: `./scripts/deploy-backend.sh`   (does EVERYTHING: KV, secrets, vars,
   deploy, E2E curls, config.json update)

## Acceptance criteria (the script prints these checks)
- [ ] `/health` returns `{"ok":true}`
- [ ] `/oracle` answers in character (live Mistral — keys already validated)
- [ ] `/balances?owner=0x…` returns real multi-chain balances
- [ ] `config.json.backend_base_url` filled → push → CI rebuilds the game

**Then (agent):** "Verify Oracle live" in the browser build, flip checklist
F2/F3 to LIVE, tighten `ALLOWED_ORIGIN`, register the AgentMail webhook.
