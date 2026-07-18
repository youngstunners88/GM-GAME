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

## ⚠️ Blockers to go live (as of this build)
1. **The `MISTRAL_API_KEY` in the dev environment returns `Unauthorized`** —
   the Oracle proxy is correct but needs a valid key at `wrangler secret put`
   time. Verify with:
   `curl -s https://api.mistral.ai/v1/models -H "Authorization: Bearer $KEY"`
2. **`config.json` contract addresses are empty** — the on-chain badge and
   token-gated perks stay inert (game plays normally) until real deployed
   SmokeRing/DIAMONDS/GoldMine + Survivor-Badge addresses are filled in.
   Never hardcode them in GDScript (CLAUDE.md Global Rule) — only `config.json`.

## 🔒 Security hardening — do BEFORE production (checklist Section F)
The Worker ships dev-friendly defaults. Two items are **live P0s the moment you
deploy** (see `docs/security/GAME_SECURITY_CHECKLIST.md` F2/F3):
1. **Rate-limit the abuse surfaces (F2).** `/oracle` spends real Mistral credits
   per call; `/lore` and `/track` are unauthenticated POSTs. Add a Cloudflare
   WAF rate-limiting rule (or a KV per-IP counter) before going live — e.g.
   `/oracle` ≤ ~10/min/IP. `/lore` is already length-capped (≤200 chars, client
   + server) but should also be rate-limited against spam.
2. **Tighten CORS (F3).** `worker.js` currently returns
   `Access-Control-Allow-Origin: *` for local dev. Before production, restrict it
   to the game's real origins (the itch.io CDN host + your Vercel/Pages mirror).

The API key is already safe: `MISTRAL_API_KEY` is read only server-side from
`env` and never returned to the client (F1) — keep it that way.

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
