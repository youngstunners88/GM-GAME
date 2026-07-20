# backend — next task

**Single next action:** first-week live watch.

- [ ] Monday 10:00 UTC: review the DIGEST_DRAFT_ONLY=1 drafts in AgentMail,
      approve/send, then flip the var to "0" and `wrangler deploy`.
- [ ] Tighten `ALLOWED_ORIGIN` from "*" to the itch.io CDN host + mirror
      (checklist F3) once the itch page is public and its serving host is
      confirmed in the browser devtools.
- [ ] Watch `spend:oracle:*` + rate-limit counters in the founder digest;
      raise ORACLE_DAILY_CAP if real players hit it.

**After that:** next-sprint deferred list in ../KIMI_AUDIT_FEEDBACK.md
(use-after-free guards batch 2, Durable Objects trigger, SIWE trigger).
