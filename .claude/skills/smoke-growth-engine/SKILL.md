---
name: smoke-growth-engine
description: Distribution playbook, Layer 3 advancement roadmap, and growth strategy for Lil Blunt — The Smoke Realm. Covers content creator programs, community activation, AI-assisted content ops, and systematic data-driven expansion — sequenced by what's actually deployed and gated on legal review where the idea touches cannabis retail or token distribution.
metadata:
  author: GM-GAME Team
  version: 2.0.0
  layer: Video Game (Layer 3)
---

# Smoke Growth Engine

> Systematic expansion of Lil Blunt from a single marketing asset into a self-improving, community-driven, multi-channel growth platform — sequenced from "buildable this week on the live stack" to "needs the founder's lawyer before anyone touches it."

## When to activate

- Founder wants to know "what's next" now that the stack is live
- Preparing a roadmap conversation (not yet a funding pitch — see Section 7)
- Evaluating whether a new distribution idea is worth building
- Deciding whether an experimental feature (AI agents, on-chain leaderboard, etc.) earns its build time

## Philosophy

**Layer 3 means the system improves itself.** Every player, every email open, every death in Level 2 feeds back into smarter design. Distribution isn't "post links and hope" — it's engineered touchpoints where the channel adapts to the game and the game adapts to the channel.

**Sequencing rule:** an idea only earns a build slot after answering three questions:
1. Does the infrastructure for it already exist (referral system, analytics, email engine)?
2. Does it touch cannabis retail, a token distribution promise, or securities-adjacent language ("earn," "airdrop for completing a task," "trading competition")? If yes → **legal-review gate**, not a build ticket.
3. Is the timeline realistic against what one engineer + one LLM collaborator can actually ship in that window?

---

## ⚠️ Legal-review gate (read this before touching anything below)

The following categories of idea are **NOT engineering decisions**. They require the founder's own cannabis-compliance and securities counsel before any code is written, in any state:

- Anything that ties a cannabis dispensary (QR codes, kiosks, geo-fencing, in-store promotion) to a crypto token or wallet action. Cannabis advertising/loyalty-program law varies sharply by state and most restrict exactly this pattern.
- Anything framed as "Learn & Earn," "quiz to earn SMOKE," "exchange partnership," or any flow where completing an action triggers a token payout to a wallet. This is the fact pattern regulators watch for.
- Any token-supply commitment, vesting schedule, or "% of SMOKE supply" language in a founder-facing pitch, even informally.

Ideas in this bucket are listed in **Section 8 (Deferred — Legal Gate)** so they aren't lost, but they are explicitly NOT sequenced into a build roadmap here. Do not present them to the founder as "next" without a compliance sign-off attached.

---

## 1. Phase 0 — This Week (uses only what's already deployed)

Nothing here needs new infrastructure. The referral engine, email engine, analytics pipeline, secret walls, and content-engine scripts are all live.

| Move | Execution | Effort |
|---|---|---|
| **Creator seed outreach** | DM 5–10 small crypto/cannabis-culture creators the itch.io link + a referral code each. Track via existing `/referral` conversion data. | 1 afternoon |
| **Screenshot-to-share push** | Snapshot Moments (F12/P) already generate a shareable X intent. Prompt the Oracle NPC once to remind players about it mid-run. | 30 min (copy tweak only) |
| **Lore-driven content calendar** | Community lore submissions + Hall of Blaze already surface real player content. Kimi K3's `social_post_drafts.js` turns the week's best lore into X post drafts — run it weekly, founder approves. | Already built — just run it on a cadence |
| **Death-heatmap rage clip prompts** | The analytics pipeline already tracks per-boss/per-obstacle deaths. Weekly digest generator can flag "most players died here" as a content brief for creators without any new endpoint. | Extend `weekly_digest_generator.js` output, no new infra |

**Why this order:** it's the only bucket where "ship it" and "founder sees results" happen in the same week, and none of it touches the legal-review gate.

---

## 2. Phase 1 — Content Creator Program (Month 1)

Builds on the referral system already in `backend/marketing.js`. No new legal surface — creators are compensated for content, not for driving wallet-connects-for-token-payout (that distinction matters).

### Tier system
| Tier | Requirement | Reward |
|---|---|---|
| **Seed** | 1 post about Lil Blunt | Shoutout + referral code |
| **Sprout** | 3 posts, 1,000 views total | Exclusive in-game skin (cosmetic, not a token payout) |
| **Blaze** | 10 posts, 10,000 views, 50 referral clicks | Custom NPC line written for them (Oracle already has a persona system) |
| **OG** | 25 posts, 100,000 views, 500 referrals | Advisory conversation with the founder + permanent Hall of Blaze feature |

Keep rewards **cosmetic and in-game** at first (skins, NPC callouts, leaderboard features) rather than token payouts — this sidesteps the legal-review gate entirely while still being a real incentive, and it's buildable on the existing skin/cosmetic system.

### Weekly content briefs (Kimi K3 generates, founder approves)
Already partially built via `content_engine/`. Extend to surface:
- "47 players died to the Rolling Boulder in the same spot this week — rage-compilation bait."
- "First player to clear the Fort Knox Vault was [truncated wallet] — interview angle."
- Trending Telegram meme topics, pulled from `players_week` + `cta` counters already in KV.

**Implementation:** no new backend routes. Extend `backend/content_engine/weekly_digest_generator.js` to also emit a creator-brief block; save to `marketing/assets/creator-brief-week-N.md`.

---

## 3. Phase 2 — Community & Predictive Systems (Month 2–3)

This is where Layer 3 (self-improving) actually compounds — it's the highest-leverage phase and the least legally sensitive, so it should come before anything token-facing.

| Feature | What it does | Data input (already collected) |
|---|---|---|
| **Churn signal → re-engagement email** | Flag players with 3+ days no login or 2+ skipped digest emails → trigger the existing "we missed you" template (`weeklyDigest` already has this branch — just needs a scheduled trigger). | `pemail`, `pstats`, digest send logs |
| **A/B test on power-up timing / level pacing** | Test two variants of a drop rate or checkpoint placement, compare completion/retry rates from `/player-analytics`. | Existing analytics schema, no new collection |
| **Snapshot-moment prompt tuning** | Use share-click data (`cta:*` counters) to find which checkpoint locations actually generate shares, weight future level design toward those spots. | Existing `/go` CTA tracking |
| **Community lore weighting** | Lore snippets are already served least-served-first; add a lightweight upvote signal so the algorithm favors what players actually react to. | New: 1 field on the lore KV record, no new endpoint class |

**Why before token mechanics:** this phase makes the *existing* game and email engine smarter using data you already have permission to collect (checklist Sections F/G/H already cover this). It needs zero new legal review.

---

## 4. Phase 3 — On-Chain Credibility (Month 3–5)

The one on-chain feature worth prioritizing from the original roadmap, kept because it's low-risk: it doesn't distribute tokens, it just makes existing scores verifiable.

| Feature | What it does | Why it's safe |
|---|---|---|
| **On-chain leaderboard submission (opt-in)** | Player can choose to submit their score as a transaction instead of the current off-chain KV record — same pattern as the existing badge-mint flow (user-signed, no approvals requested). | Reuses the exact wallet-connect + user-signed-tx pattern already shipped and audited (`DEFI_REVIEW.md` M-DEFI-2 already covers this posture). |
| **Badge NFT expansion** | More badge types (per-boss, per-level) using the same `mint()` pattern already wired for the Survivor badge. | No new contract-interaction pattern, just more badge variants once a contract exists. |

Everything else from the original "Phase 3: Cross-Protocol Economy" (multi-token quests with buy-pressure framing, NFT renting) goes to **Section 8 — Deferred, Legal Gate** — "creates buy pressure across all three tokens" is exactly the kind of promotional-token-mechanics language that needs counsel before it's a roadmap item.

---

## 5. AI Agent Spectator Mode — kept mostly as-is

This section of the original doc was correctly self-restrained and I'm preserving that judgment:

**Verdict: build it as a side feature, not a core pillar, and only after 1,000 human wallet connects.**

- **Why it works (limited):** genuine novelty content ("AI vs AI speedrun"), useful for exploit-finding, a real press hook.
- **Why it's a distraction if overbuilt:** doesn't onboard humans, doesn't need to exist before the human funnel is proven, technical overhead for uncertain ROI.
- **The right shape when the trigger fires:**
  ```
  AI Agent Leaderboard (Spectator Only)
  ├── Separate from the human leaderboard entirely
  ├── Agents play on a delay, not live (prevents exploitation)
  ├── Humans vote on strategy, not outcome
  ├── Top human predictor wins an in-game reward (not a token payout)
  └── Named after community members or crypto memes
  ```

**Trigger, unchanged from the original: 1,000 human wallet connects.** Before that, every hour on this is an hour not spent on the human funnel.

---

## 6. Measurement & Iteration Framework

### North Star metrics — kept, but Month-1 targets tightened to match a freshly-launched game, not a funded studio's month 1

| Metric | Month 1 | Month 3 | Month 6 |
|---|---|---|---|
| Monthly Active Players | 100 | 750 | 3,000 |
| Wallet Connect Rate | 10% | 20% | 30% |
| Email Capture Rate | 30% | 45% | 55% |
| Social Share Rate | 3% | 8% | 12% |
| Referral Conversion | 2% | 4% | 6% |
| Creator Partners | 3 | 10 | 30 |

(The original doc's Month-3/6/12 targets — 3,000/15,000 MAP — assume paid acquisition or a funded team; keep them as an aspirational ceiling, not a plan input, until Phase 0–1 data exists to calibrate against.)

### Weekly ritual (Kimi K3 ↔ Claude Code ↔ founder) — kept from the original, it's operationally sound
1. **Monday:** Kimi K3 reads the week's analytics export + social sentiment.
2. **Monday PM:** Kimi K3 drafts creator briefs, email copy, new taglines.
3. **Tuesday:** Claude Code implements any technical changes.
4. **Wednesday:** Founder approves or edits Kimi's drafts.
5. **Thursday:** Content goes out.
6. **Friday:** Security audit + hotfix deploys (already automated via `security-audit.ts` + sentinel).
7. **Weekend:** Monitor only, no deploys.

### The handoff model — kept verbatim, it accurately describes what's built
```
Kimi K3 (Strategic Brain)
├── Reads: analytics, social sentiment, market trends
├── Produces: strategy docs, creative briefs, copy, market analysis
└── Reviews: Claude Code's technical implementation for blind spots

Claude Code (Implementation Engine)
├── Reads: Kimi K3's strategy docs
├── Produces: working code, deployed features, operational systems
└── Reviews: Kimi K3's recommendations for technical feasibility

Founder (Human Tiebreaker + Legal Gate Owner)
├── Approves or rejects strategy shifts
├── Approves content before send
├── Owns the legal-review decision for anything in Section 8
└── Decides which experiments get budget
```

---

## 7. Founder Roadmap Presentation

Use this when talking to the founder about "what's next" — note it's split into buildable-now vs. needs-your-lawyer, which the original doc didn't do.

> **Live today:** Game deployed, backend live (Oracle/leaderboard/analytics/email all E2E-verified), security-audited (sentinel + secure-build-checklist gates), Kimi K3 content pipeline running.
>
> **Buildable in the next 4–6 weeks, no new legal exposure:** Creator program (cosmetic rewards), predictive re-engagement emails, A/B-tested level pacing, community-weighted lore, on-chain-optional score submission using the badge-mint pattern already shipped.
>
> **Needs your compliance/securities counsel before we touch it:** anything involving dispensary partnerships, token-for-action promotions ("Learn & Earn," quiz airdrops), or cross-token "buy pressure" mechanics. These are real ideas with real upside — they're gated on legal review, not rejected.
>
> **Ask:** [Set by founder relationship — this skill doesn't presume a number. See the separate pricing note delivered alongside this roadmap.]

---

## 8. Deferred — Legal Gate (ideas worth keeping, not worth building yet)

These are preserved from the original doc because they're good ideas — they're gated, not discarded.

- Cannabis dispensary QR/kiosk/geo-fenced token drops (receipt QR, waiting-room tablets, strain tie-ins)
- Exchange "Learn & Earn" quiz-for-airdrop flows
- P2E guild scholar programs with token-reward leaderboards
- Multi-token "buy pressure" quests, NFT renting
- Campus ambassador programs with per-referral cash payouts (the payout structure, not the ambassador concept itself, is what needs review)

**Next step for any of these:** founder brings a cannabis-compliance or securities lawyer into the conversation. Once cleared, they slot into a future phase using the same referral/analytics infrastructure already built — the engineering isn't the blocker, the legal posture is.

---

## Files

- `SKILL.md` — this file (v2.0.0, rewritten 2026-07-20 with legal-review gating and live-stack-first sequencing)
