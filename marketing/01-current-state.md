# marketing — current state (2026-07-19)

## Built
- Full email engine (see backend track): welcome sequence, weekly personal
  digests w/ death-stat coaching + Kimi realm-news blurb, milestone emails,
  founder Monday digest (players/wallets/CTA clicks/referral conversion/
  top Oracle questions), two-way AI support inbox.
- Referral loop: in-game invite → branded email → click + conversion
  tracking → 48h follow-up → secret-wall referral codes (+50 pts).
- Share surfaces: snapshot moments (pre-filled X intent), victory screen,
  digest CTAs routed through /go for most-clicked-CTA analytics.
- Community loop: lore submissions → secret walls + Hall of Blaze graffiti.

## In progress / newly REAL (2026-07-19)
- Sender inbox LIVE: `smokering-notifications@agentmail.to` — pipeline proven
  with a delivered test email to the founder.
- Content engine RUNNING: Kimi K3 produced this week's 10 share taglines
  (`marketing/assets/taglines_week_2026-W29.json`), 5 X drafts for
  @smokering25 (`x_drafts_week_2026-W29.md`), and a newsletter draft now
  sitting in AgentMail with `needs_approval` — human approves before send.
- Socials confirmed + wired everywhere: x.com/smokering25, t.me/LilBluntdotWin
  (source of truth: `docs/SOCIAL_LINKS.md`).

## 🟢 LIVE (2026-07-20)
- Backend deployed — welcome sequence, digests, milestones, referrals,
  support triage all ACTIVE on `smokering-notifications@agentmail.to`
  (Phase 1 default domain; DIGEST_DRAFT_ONLY=1 for the first Monday).
- Production signup E2E proven (founder received Welcome 1 w/ confirm link).

## Still waiting on client
1. AgentMail PLAN UPGRADE → support@ + smokering.game custom domain (Phase 2).
2. Discord URL still empty in `config.json.social`.
3. First-Monday digest approval (then flip DIGEST_DRAFT_ONLY to 0).

## Measurement (once live)
Founder digest lands every Monday 10:00 UTC; funnel counters in KV
(`cta:*`, `track:*`, referral records). First KPIs: email opt-in rate,
digest CTA click-through, referral conversion %.
