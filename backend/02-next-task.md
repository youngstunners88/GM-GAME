# backend — next task

**Single next action (CLIENT):** deploy the Worker. Everything else in this
track is waiting behind it.

## Steps (copy-paste, `backend/README.md` has detail)
```bash
cd backend && npm i -g wrangler && wrangler login
wrangler kv:namespace create GAME_KV          # paste id into wrangler.toml
wrangler secret put MISTRAL_API_KEY           # validated key #1
wrangler secret put MISTRAL_API_KEY2          # validated key #2 (failover)
wrangler secret put OPENROUTER_API_KEY        # Kimi K3 tier
wrangler secret put WEBHOOK_SECRET            # long random string
# AgentMail secrets when DNS is ready (AGENTMAIL_SETUP.md)
wrangler deploy                               # copy the printed URL
```
Then set `ALLOWED_ORIGIN` + `PUBLIC_BACKEND_URL` in `wrangler.toml` [vars],
put the URL in `../config.json.backend_base_url`, push (CI rebuilds the game).

## Acceptance criteria
- [ ] `curl <url>/leaderboard` returns `[]` (not an error)
- [ ] `curl -X POST <url>/oracle -d '{"question":"what is blaze mode?"}'`
      returns an in-character answer (proves Mistral key live server-side)
- [ ] Game menu Oracle answers in the browser build
- [ ] Rate limit check: 11 rapid /oracle calls → 11th returns 429

**Agent-side follow-up after deploy:** re-audit checklist F2/F3 as LIVE, run
an end-to-end signup→welcome-email test with a real inbox.
