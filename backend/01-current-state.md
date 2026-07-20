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
- Nothing — track is one credential away from fully live.

## 🟢 DEPLOYED (2026-07-20) — LIVE at
## https://lil-blunt-backend.teacherchris37.workers.dev
- E2E verified live: /health 200 · /leaderboard [] · /oracle answering
  in-character via Mistral (3/3 attempts) · /balances real multi-chain reads ·
  /email/signup delivered Welcome 1 to the founder · /event→/player-analytics
  loop closed (death heatmap round-trip) · crons registered (Mon 10:00 +
  daily 09:00) · support webhook ep_3GlLobMdwUvQeXaNRUb5xIo2gdL registered.
- Kimi K3 architecture audit hardening deployed same day: Oracle daily
  circuit-breaker + link-stripping, /balances 60s cache, referral
  confirmed-subscriber gate + 10 lifetime cap, /data-delete POST-confirm,
  analytics reads gated to CSPRNG ids. Full trail: ../KIMI_AUDIT_FEEDBACK.md.

## Historical: the resolved blocker
- Deploy attempted 2026-07-19: the `CLOUDFLARE_API_KEY` token is valid but
  has NO account access (`/accounts` empty, `/memberships` denied) and no
  `CLOUDFLARE_ACCOUNT_ID` is set — wrangler cannot target an account.
- **Everything else is pre-staged in `scripts/deploy-backend.sh`** (KV
  create, all secrets from env incl. both validated Mistral keys + the
  validated AgentMail key, vars, deploy, redeploy with URL, full E2E curls,
  config.json update). One command once credentials land.
- NEW since last update: `/health` + multi-chain `/balances` endpoints;
  AgentMail infra REAL (sender inbox `smokering-notifications@agentmail.to`
  created; pipeline proven with a delivered test email; free plan caps:
  no 2nd inbox, no custom domain — upgrade for support@ + smokering.game).
- Contracts VERIFIED on-chain and in `config.json` (SMOKE=Base,
  DIAMONDS+GOLD=Ethereum — hence the `/balances` cross-chain endpoint).

## Known debt
- Scores unauthenticated by design (SIWE is the documented upgrade if the
  board ever pays out). KV eventual-consistency makes rate limits best-effort.
