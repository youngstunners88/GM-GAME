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
- **2026-07-19 · Cross-chain balance reads are a backend concern.** On-chain
  verification showed SMOKE on Base but DIAMONDS/GOLD on Ethereum; a wallet
  provider only reads its current chain. `/balances` reads each token on its
  own chain via a fixed server-side RPC map — stateless, address never
  stored/logged (the onboarding privacy copy depends on this), SSRF-safe.
- **2026-07-19 · Deploy is scripted, not manual.** `scripts/deploy-backend.sh`
  is the single deploy path (idempotent KV, secrets from env, URL-baked vars,
  E2E verification). Blocked only on a Cloudflare credential with account
  access; diagnosis recorded in the script header.
- **2026-07-19 · One AgentMail inbox for both roles (free-tier reality).**
  `smokering-notifications@agentmail.to` is sender AND support until the plan
  upgrade (org inbox cap hit; custom domains need paid tier). Code already
  falls back SENDER→SUPPORT, so this is config truth, not a code fork.
- **2026-07-20 · Deployed.** One-command script worked after two real-world
  fixes now baked in: `[ x ] &&` set-e landmines -> if/then, and KV-namespace
  creation via REST (wrangler refuses ALL commands while the toml id is empty
  — chicken-and-egg). Live URL in config.json; CI rebuilds carry it.
- **2026-07-20 · Kimi K3 stress-test gate held before itch.** 3 CRITICAL /
  10 HIGH triaged: fixed the real ones same-day, disproved with evidence
  (confirmed-gates, idempotency, empirical compile proof) the rest, deferred
  list documented. Disagreements recorded, not ignored (KIMI_AUDIT_FEEDBACK.md).
