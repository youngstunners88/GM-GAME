# marketing — next task

**Single next action (CLIENT):** activate AgentMail on `smokering.game`
(blocked behind backend deploy — do that first).

## Steps (~20 min, copy-paste detail in `../AGENTMAIL_SETUP.md`)
1. AgentMail dashboard → API key → `wrangler secret put AGENTMAIL_API_KEY`
   (+ `AGENTMAIL_WEBHOOK_SIGNING_KEY`).
2. `POST /v0/domains {"domain":"smokering.game"}` → add the returned
   SPF/DKIM/DMARC/MX records at the DNS host → `POST .../verify`.
3. Create `notifications@` + `support@` inboxes → ids into `wrangler.toml`
   vars (`SENDER_INBOX_ID`, `SUPPORT_INBOX_ID`) + `ADMIN_EMAIL` +
   `POSTAL_ADDRESS` → `wrangler deploy`.
4. Register the support webhook (URL + `?secret=`).

## Acceptance criteria
- [ ] Domain shows fully verified in AgentMail (all records green)
- [ ] Test signup in-game → Welcome 1 arrives with working confirm link
- [ ] `/email/preview?tpl=digest&secret=…` renders in a browser
- [ ] Email to support@ gets an AI draft with correct labels in AgentMail
- [ ] Unsubscribe link works instantly (no login)

**Agent-side follow-up once live:** flip `DIGEST_DRAFT_ONLY=1` for the first
Monday run, human-review the drafts, then set to 0 for steady state.
