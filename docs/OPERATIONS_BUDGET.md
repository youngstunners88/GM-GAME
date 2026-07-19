# Operations Budget — Lil Blunt: The Smoke Realm

Monthly running costs at launch scale (est. first 1,000 monthly players).
Movie-Layer doc: these numbers ARE the domain knowledge — what a chill
crypto game actually costs to operate.

| Service | Monthly Cost | Why |
|---|---|---|
| Cloudflare Worker + KV | $0–5 | Free tier: 100k requests/day + 1k KV writes/day covers launch; the $5 paid tier removes the write ceiling |
| AgentMail | $0–20 | Free tier proven working (3 inboxes, shared domain); paid tier needed for `support@smokering.game` + custom sending domain + volume (~1,000 emails/mo) |
| Mistral API | $5–15 | Oracle NPC + support drafting (two keys = two quota buckets, failover wired) |
| Kimi K3 (OpenRouter) | $0–10 | Cost tier: triage fallback, 1-call/week digest blurb, weekly taglines/X drafts — pennies per call by design |
| X API v2 (Essential) | $0 | Free tier fine while posts are human-pasted from drafts; automation later may need Basic ($200/mo — defer until ROI proven) |
| itch.io | $0 | Free hosting, optional rev-share only if the game ever charges |
| Domain (smokering.game) | ~$1/mo | ~$12/year at the registrar |
| Unstoppable Domain (smokering.crypto) | ~$20 one-time | Optional web3 vanity; no renewal |
| **TOTAL** | **~$10–50/month** | |

## Scaling curve

- **At 10,000 monthly players:** scale to **~$100/month** — Workers paid plan
  ($5), KV write volume, AgentMail volume tier (~$30–50), LLM spend roughly
  triples (Oracle is the driver; the per-player email design deliberately
  avoids per-player LLM cost).
- **At 100,000 players:** **~$400/month** — the LLM + email lines dominate;
  at that point rate-limit tuning and Oracle answer caching become budget
  features, not just abuse controls.

## Buffers & rules

- **Emergency buffer: keep $200 in API credits** (Mistral + OpenRouter)
  to prevent service interruption — a viral weekend must not brick the Oracle.
- The Oracle's per-IP limit (10/min) is ALSO the cost ceiling: worst-case
  Mistral spend is bounded by rate limits, not hope.
- `DIGEST_DRAFT_ONLY=1` on first Monday run — review drafts before the send
  volume becomes a bill.
- Cost review cadence: check the founder digest's player count monthly
  against this table; upgrade tiers BEFORE hitting free-tier walls.
