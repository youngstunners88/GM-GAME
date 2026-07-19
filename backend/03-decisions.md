# backend — decision log (append-only)

- **2026-07-18 · One Worker, not microservices.** A single Cloudflare Worker +
  KV covers oracle/leaderboard/lore/email/analytics — matches the static-game
  scale, free tier, no server to babysit. Express port documented, not built.
- **2026-07-18 · Scores off-chain, badge on-chain.** Per-score gas kills
  submissions; wallet address = identity in KV, the opt-in badge NFT is the
  on-chain artifact. Documented trade-off (README + LAYER_SHIFT.md V2).
- **2026-07-18 · Keys live ONLY here.** Client never sees Mistral/AgentMail/
  OpenRouter keys; game → Worker → provider. Checklist F1/G4/H4 enforce.
- **2026-07-19 (PR #6 review) · Abuse posture.** Per-IP fixed-window limits on
  every mutating route; double opt-in before campaign mail; svix-style signed
  + replay-deduped webhooks; LLM auto-send requires question-class +
  confidence ≥0.7 + content checks. Unauthenticated scores = accepted,
  documented risk (F2b).
- **2026-07-19 · LLM cost ladder.** Mistral primary (quality/persona) →
  MISTRAL_API_KEY2 failover (rate-limit resilience) → Kimi K3 via OpenRouter
  (cheap bulk: triage fallback, 1-call/week digest blurb) → Grok last resort.
  Reasoning-model handling (effort:low, ≥1200 tokens, content||reasoning).
- **2026-07-19 · /oracle handler is frozen** (client constraint). Fallback
  tiers wire into marketing/support paths only; touching /oracle needs
  explicit client approval.
