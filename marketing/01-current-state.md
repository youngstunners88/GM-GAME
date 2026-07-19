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

## In progress
- Nothing agent-side; the whole track idles armed.

## Blocked (in unlock order)
1. Backend deploy (backend/02-next-task.md) — everything routes through it.
2. AgentMail key + smokering.game DNS (SPF/DKIM/DMARC) + 2 inboxes +
   `POSTAL_ADDRESS` var — then email goes live (`../AGENTMAIL_SETUP.md`).
3. Telegram link is live already; Discord URL empty in `config.json.social`.

## Measurement (once live)
Founder digest lands every Monday 10:00 UTC; funnel counters in KV
(`cta:*`, `track:*`, referral records). First KPIs: email opt-in rate,
digest CTA click-through, referral conversion %.
