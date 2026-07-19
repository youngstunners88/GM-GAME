# backend — the control plane

**One job:** every server capability the game and marketing need, in one
Cloudflare Worker + KV. Holds ALL secrets; the client bundle holds none.

**Layers served:** 🎬 Movie (branded Oracle persona, founder digest, badge/
perk wiring) + 🎮 Video Game (analytics, adaptive-difficulty data, community
lore, self-improving email campaigns).

**Physical location (this folder IS the code — plus these ICM files):**
- `worker.js` — router: /oracle /score /leaderboard /lore /track + delegation
- `marketing.js` — email engine + /event /player-analytics /community-lore
  /hall-of-blaze + crons (Mon 10:00 UTC digests; daily 09:00 welcome/referral)
- `agentmail.js` / `email_templates.js` — AgentMail client + all templates
- `kimi_client.js` — Kimi K3 via OpenRouter (cost tier) · `wrangler.toml` — config

**LLM chain:** Mistral (primary) → Mistral key 2 (failover) → Kimi K3
(cost tier) → Grok (last resort). Keys are Worker secrets, never client-side.

**Depends on:** AgentMail, Mistral/OpenRouter/XAI APIs, Cloudflare KV, DNS-
over-HTTPS (MX checks). **Depended on by:** godot-client (via Web3Bridge),
marketing (campaign delivery + funnel data).

**House rules:** every mutating route rate-limited per-IP; consent + double
opt-in before campaign mail; Idempotency-Key on every send; CORS via
`ALLOWED_ORIGIN`; `node --check` before commit.
