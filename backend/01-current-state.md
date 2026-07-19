# backend — current state (2026-07-19)

## Built (code-complete, `node --check` clean, security Sections F/G/H green)
- Layer Shift APIs: /oracle (Mistral proxy, persona), /score + /leaderboard
  (top-20, rate-limited, documented untrusted-arcade trust model), /lore,
  /track. CORS env-driven; per-IP limits on all mutating routes.
- AgentMail engine: signup w/ MX validation + double opt-in, welcome 1-3,
  weekly digests (Drafts API, DIGEST_DRAFT_ONLY switch), milestones, founder
  digest, referral engine + follow-ups, support triage (signed + replay-safe
  webhook, confidence+content-gated auto-send), suppression at the send seam.
- Level-depth analytics: /event (allowlist, clamps), /player-analytics,
  /community-lore (least-served rotation), /hall-of-blaze; pstats 90-day TTL.
- Kimi K3 client (reasoning-model safe) + weekly cached realm-news blurb.

## In progress
- Mistral failover tier (MISTRAL_API_KEY2) in the support LLM chain (this batch).

## Blocked — deployment is client-gated
- NOT deployed. Needs (see `README.md`, ~5 min): `wrangler login`, KV
  namespace id, secrets (MISTRAL_API_KEY ×2 — both keys now validated —
  AGENTMAIL_API_KEY, WEBHOOK_SECRET, AGENTMAIL_WEBHOOK_SIGNING_KEY,
  OPENROUTER_API_KEY, optional XAI), `ALLOWED_ORIGIN` + vars, deploy, then
  paste the URL into `config.json.backend_base_url`.

## Known debt
- Scores unauthenticated by design (SIWE is the documented upgrade if the
  board ever pays out). KV eventual-consistency makes rate limits best-effort.
