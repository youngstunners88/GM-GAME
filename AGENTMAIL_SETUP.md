# AgentMail Marketing Engine — Setup & Reference

The game's email layer: player capture, weekly digests, welcome sequences,
milestone emails, two-way AI support, referrals, and the founder digest — all
via [AgentMail](https://docs.agentmail.to) (email API built for agents),
running inside the existing Cloudflare Worker (`backend/`). **Everything is
additive**: wallet connect, the Oracle, CI, and the security model are untouched.

---

## 1. Get an AgentMail API key

1. Sign up at [agentmail.to](https://agentmail.to) → dashboard → **API Keys**.
2. Store it as a Worker secret (NEVER in code or `wrangler.toml`):
   ```bash
   cd backend
   wrangler secret put AGENTMAIL_API_KEY
   wrangler secret put WEBHOOK_SECRET      # any long random string; gates the support webhook + previews
   wrangler secret put AGENTMAIL_WEBHOOK_SIGNING_KEY  # webhook signing secret from AgentMail (svix-style whsec_...)
   wrangler secret put XAI_API_KEY         # optional: Grok fallback for support triage (Mistral primary)
   ```

## 2. Configure the custom domain (smokering.game)

AgentMail Domains API (all calls Bearer-authed against `https://api.agentmail.to`):

```bash
# Create the domain
curl -X POST https://api.agentmail.to/v0/domains \
  -H "Authorization: Bearer $AGENTMAIL_API_KEY" -H "Content-Type: application/json" \
  -d '{"domain": "smokering.game", "feedback_enabled": true}'
# → returns a domain_id + the DNS verification records

# Fetch the ready-to-paste zone file
curl https://api.agentmail.to/v0/domains/<domain_id>/zone-file \
  -H "Authorization: Bearer $AGENTMAIL_API_KEY"

# After adding DNS records, trigger verification
curl -X POST https://api.agentmail.to/v0/domains/<domain_id>/verify \
  -H "Authorization: Bearer $AGENTMAIL_API_KEY"
```

### DNS records you'll add (exact values come from the API response)

| Type | Purpose | Typical shape |
|---|---|---|
| TXT (SPF) | Authorizes AgentMail to send for the domain | `v=spf1 include:<agentmail-spf> ~all` |
| CNAME/TXT ×2-3 (DKIM) | Cryptographic signing of every email | `<selector>._domainkey.smokering.game` |
| TXT (DMARC) | Tells receivers how to treat failures + where to report | `_dmarc.smokering.game` → `v=DMARC1; p=quarantine; rua=mailto:...` |
| MX (receiving) | Routes support@ replies INTO AgentMail | per API response |

All four must show **verified** in the domain status before real sends —
unverified domains land in spam or bounce.

## 3. Create the inboxes

```bash
# Sender identity for campaigns
curl -X POST https://api.agentmail.to/v0/inboxes \
  -H "Authorization: Bearer $AGENTMAIL_API_KEY" -H "Content-Type: application/json" \
  -d '{"username": "notifications", "domain": "smokering.game", "display_name": "Lil Blunt — Smoke Realm", "client_id": "smokering-notifications"}'

# Two-way support inbox
curl -X POST https://api.agentmail.to/v0/inboxes \
  -H "Authorization: Bearer $AGENTMAIL_API_KEY" -H "Content-Type: application/json" \
  -d '{"username": "support", "domain": "smokering.game", "display_name": "Smoke Realm Support", "client_id": "smokering-support"}'
```

Put the returned inbox ids in `backend/wrangler.toml` `[vars]`:
`SENDER_INBOX_ID`, `SUPPORT_INBOX_ID`, plus `AGENTMAIL_DOMAIN`, `ADMIN_EMAIL`
(founder digest recipient), `PUBLIC_BACKEND_URL` (the Worker's public URL) and
`POSTAL_ADDRESS` (CAN-SPAM footer). Then `wrangler deploy`.

## 4. Wire the support webhook (incoming email → AI triage)

```bash
curl -X POST https://api.agentmail.to/v0/inboxes/<SUPPORT_INBOX_ID>/webhooks \
  -H "Authorization: Bearer $AGENTMAIL_API_KEY" -H "Content-Type: application/json" \
  -d '{"url": "<PUBLIC_BACKEND_URL>/agentmail/webhook?secret=<WEBHOOK_SECRET>", "event_types": ["message.received"]}'
```

Incoming mail → Worker → Mistral (or Grok fallback) drafts a reply using the
game FAQ + the sender's play history → **Draft is created in AgentMail**:
- confidence ≥ 0.7 → draft is sent, thread labeled `auto_resolved`
- confidence < 0.7 → draft stays for review, labeled `human_review`
- `bug_report` / `feature_request` labels are added when detected

## 5. Template preview & testing

Every template renders in a browser without sending anything:

```
GET <PUBLIC_BACKEND_URL>/email/preview?secret=<WEBHOOK_SECRET>&tpl=digest
    tpl ∈ digest | missed | welcome1 | welcome2 | welcome3 | boss | top10 | referral | admin
```

To dry-run a full weekly digest without delivery, set `DIGEST_DRAFT_ONLY = "1"`
in `[vars]` — the cron then stops at the **Drafts** stage (human-in-the-loop);
review them in the AgentMail dashboard and send manually, or flip back to "0".

## 6. What runs when

| Trigger | What happens |
|---|---|
| Player opts in (in-game panel) | `POST /email/signup` → validated (regex + MX via DNS-over-HTTPS) → stored in KV → **Welcome 1** sent immediately, carrying the **double-opt-in confirm link** (`/confirm`). Campaign mail (digest, welcome 2/3, milestones) only ever goes to **confirmed** addresses. |
| Daily cron 09:00 UTC | **Welcome 2** (day 3, only if they haven't played), **Welcome 3** (day 7); referral follow-ups (clicked, no conversion, 48 h) |
| Monday cron 10:00 UTC | **Weekly digest** to every consenting subscriber (rank, delta, top 3, death stats + tip, CTAs) or the "we missed you" variant; **founder digest** to `ADMIN_EMAIL` |
| First Auditor kill | `POST /events {boss_defeat}` → milestone email (once ever, idempotent); top-10 entry adds a share draft |
| "Invite a Friend" in-game | `POST /referral` → branded invite; click + signup conversion tracked |
| Incoming support email | AgentMail webhook → AI triage → draft/send + labels |

### Sending rules (enforced in code, `backend/agentmail.js` + `marketing.js`)
- **Idempotency-Key on every send** — deterministic per logical email
  (`digest:<week>:<player>`, `welcome1:<pid>`, …) so retries/cron re-runs can't double-send.
- **Max 1 email per player per day** (welcome sequence exempt, per design).
- **429 → exponential backoff** (Retry-After honored, 3 attempts).
- **Opt-in only, double-confirmed**: no consent → 400; campaign mail requires
  the `/confirm` click from Welcome 1. Unsubscribed addresses are locally
  suppressed AND pushed to the AgentMail send **block list** (`lists/send/block`) —
  including referral invitees (their unsubscribe token maps to the referral record).
- **Abuse quotas** (per-IP fixed windows + per-address gates): signup 5/hr +
  1/address/day; referral 3/hr + 3/day/player + one invite per address ever;
  events 120/min. Support webhook: URL secret + svix-style signature
  (`AGENTMAIL_WEBHOOK_SIGNING_KEY`) + per-event replay dedup (24 h KV gate).
- **Support auto-send is constrained**: only category `question`, confidence
  ≥ 0.7, AND a content-checked answer (≤1200 chars, no third-party links, no
  email addresses) auto-sends; everything else stays a `human_review` draft.

## 7. Compliance (CAN-SPAM basics — implemented, not aspirational)

- ✅ **Explicit consent checkbox** at capture ("I agree to receive game updates
  and leaderboard notifications") — no pre-ticked boxes, signup is optional and skippable forever.
- ✅ **One-click unsubscribe link in every footer** → `GET /unsubscribe?token=…`
  works instantly, no login, no questions; also flips consent off and suppresses future sends.
- ✅ **Honest From**: `notifications@smokering.game` / `support@smokering.game` on a verified domain (SPF+DKIM+DMARC).
- ✅ **Who/why in every footer**: "You're getting this because you opted in in-game" + postal address (`POSTAL_ADDRESS` var).
- ✅ **No deceptive subjects** — templates say what they are.
- ⚠️ Set a real `POSTAL_ADDRESS` before the first production send.

## 8. Layer mapping (coach's framework)

| Feature | Layer | Why |
|---|---|---|
| Email capture + branded comms on smokering.game | 🎬 Movie | Context-specific production value — the brand, domain, and tone are yours |
| Founder Monday digest (players, wallets, CTA clicks, referral conversion, Oracle top questions) | 🎬 Movie | Distilled domain knowledge for protocol decisions — no generic tool knows what matters to SmokeRing |
| Weekly digest personalized from each player's OWN runs (rank, delta, deaths + tips) | 🎮 Video Game | Self-improving from game data: emails get better as the player plays |
| Welcome sequence branching on actual play behavior | 🎮 Video Game | Interactive: state advances from the player's actions, not a fixed drip |
| Two-way AI support grounded in FAQ + play history + labels | 🎮 Video Game | Bespoke, data-fed, improves with every thread |
| Referral engine with click/conversion tracking | 🎮 Video Game | A growth loop the game runs on its own data |

## 9. Excluded platforms (deliberate, revisit later)

- **Facebook/Instagram** — wrong demographic for a crypto-native game, strict
  ad rules around crypto, and organic reach is pay-to-play. Revisit only after
  X + email traction is proven with real numbers from the founder digest.
- **TikTok** — needs a dedicated short-video content pipeline (gameplay clips,
  meme edits) that doesn't exist yet. Add when clips are being produced anyway.

## 10. New backend endpoints (all additive)

| Method | Path | Purpose |
|---|---|---|
| POST | `/email/signup` | Opt-in capture (validates, stores, sends Welcome 1) |
| GET | `/confirm?token=` | Double-opt-in confirmation (from Welcome 1) — unlocks campaign mail |
| GET/POST | `/unsubscribe?token=` | One-click unsubscribe (players AND referral invitees) |
| POST | `/events` | Game events: `play_start`, `death`, `boss_defeat`, `wallet_connect` |
| POST | `/referral` | Send a friend invite |
| GET | `/ref?token=` | Referral click-through (tracked) → game |
| GET | `/go?cta=&to=` | CTA click tracker → allow-listed redirect (feeds founder digest) |
| POST | `/agentmail/webhook?secret=` | Incoming support email (AgentMail → AI triage) |
| GET | `/email/preview?secret=&tpl=` | Render any template in the browser |

Env reference: `AGENTMAIL_API_KEY`\*, `WEBHOOK_SECRET`\*, `XAI_API_KEY`\*
(secrets) · `AGENTMAIL_DOMAIN`, `ADMIN_EMAIL`, `SUPPORT_INBOX_ID`,
`SENDER_INBOX_ID`, `PUBLIC_BACKEND_URL`, `POSTAL_ADDRESS`, `DIGEST_DRAFT_ONLY`
(vars). \* = `wrangler secret put`, never committed.

Security posture for all of this: `docs/security/GAME_SECURITY_CHECKLIST.md`
**Section G** (email PII is now stored — consent, suppression, minimal data,
secret-gated webhook, open-redirect guard on `/go`).
