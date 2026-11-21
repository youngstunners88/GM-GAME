# Lil Blunt — Layer Shift Backend

The one server that powers the Video-Game-Layer features and keeps every secret
off the client. A Cloudflare Worker (`worker.js`) + KV. Zero secrets in the game
export; the game only knows the Worker's public URL (set in `../config.json`).

## Endpoints
| Method | Path | Body | Returns |
|---|---|---|---|
| POST | `/oracle` | `{question, wallet_address}` | `{answer}` — Mistral, in the Smoke Oracle persona |
| POST | `/score` | `{score, level, wallet_address}` | `{ok}` |
| GET | `/leaderboard` | — | top 20 `[{addr, score, level, ts}]` |
| POST | `/lore` | `{text, wallet_address}` | `{ok}` |
| POST | `/track` | `{event}` | `{ok}` — anonymous funnel counts |

## Deploy (≈5 min)
```bash
cd backend
npm i -g wrangler
wrangler login
wrangler kv:namespace create GAME_KV   # paste the id into wrangler.toml
wrangler secret put MISTRAL_API_KEY    # a WORKING Mistral key (see note)
wrangler deploy                        # copy the https URL it prints
```
Then put that URL in `../config.json` → `backend_base_url`, rebuild the game.

## Production status

On 21 November 2026 the configured Worker responded to GET /health and /leaderboard. The deployed script had the GAME_KV binding, provider secret bindings, weekly and daily schedules, draft-only digests and a placeholder postal address. Confirm the approved mailing address before selecting automatic weekly digest delivery. Verify the current provider configuration in Cloudflare Workers and AgentMail.

## 🔒 Security hardening (checklist Section F) — status
1. **Rate limiting (F2): ✅ implemented in `worker.js`.** Per-IP fixed-window
   KV counters on every mutating path: `/oracle` 10/min (spends Mistral
   credits), `/lore` 10/min, `/score` 30/min, `/track` 60/min. Over-limit
   returns 429. Best-effort (KV is eventually consistent) — you can layer a
   Cloudflare WAF rate rule on top for hard guarantees.
2. **CORS (F3): ✅ env-driven.** Defaults to `*` for local dev; set
   `ALLOWED_ORIGIN` in `wrangler.toml` `[vars]` (comma-separated origins, e.g.
   the itch.io CDN host + your Vercel/Pages mirror) **before production** and
   the Worker echoes only allow-listed origins.
3. **Leaderboard trust model (explicit):** `/score` is client-supplied and
   unauthenticated — an untrusted, best-effort arcade board by design (gas-free,
   no signup); the wallet is a pseudonymous label. If it ever needs to be
   trustworthy, gate submissions behind a wallet signature (SIWE) — noted in
   `worker.js` at the handler.

The API key is safe by construction: `MISTRAL_API_KEY` is read only server-side
from `env` and never returned to the client (F1) — keep it that way.

## Node/Express equivalent
If you prefer Node over Cloudflare: the same five handlers port 1:1 to an
Express app (`app.post('/oracle', ...)` etc.) reading `process.env.MISTRAL_API_KEY`
and a JSON/SQLite store instead of KV. The Worker is recommended (free tier,
global edge, no server to babysit) and matches the game's static-hosting model.

## Cost / gas tradeoff (leaderboard)
Scores are stored in KV (free, instant), NOT on-chain — an on-chain write per
score would cost the player gas for a arcade score, which kills submissions.
The *wallet address* ties the score to identity; the badge NFT (mint = one gas
fee, opt-in) is the real on-chain artifact. This is the documented tradeoff:
verifiable identity + cheap high-frequency scores, on-chain where it matters.
