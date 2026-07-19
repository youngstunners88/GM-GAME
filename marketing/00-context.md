# marketing — reach, retention, community

**One job:** turn play into community and community into players. Email
campaigns, X sharing, referrals, funnels, and the founder's decision data.

**Layers served:** 🎬 Movie (branded comms on smokering.game, founder digest =
distilled domain knowledge) + 🎮 Video Game (campaigns personalized by each
player's OWN runs; community lore feeding back into the level).

**Physical location (catalog holds no books — this is a routing node):**
- Delivery engine: `../backend/marketing.js` + `email_templates.js` +
  `agentmail.js` (campaigns, referrals, support, funnel counters)
- In-game surfaces: email capture panel, INVITE A FRIEND, snapshot-moment X
  shares, secret-wall referral codes, JOIN THE SMOKERING (all in `../src/ui/`
  + `../src/level/`, wired through Web3Bridge)
- Playbooks: `../AGENTMAIL_SETUP.md` (email), `../LAYER_SHIFT.md` (funnel V4)
- Tooling: `../scripts/kimi-review.sh` pattern for cheap LLM copy drafting

**Depends on:** backend (delivery + data), godot-client (capture surfaces),
AgentMail (once DNS verifies). **Depended on by:** nobody — this is the leaf
that turns the flywheel.

**House rules:** consent + double opt-in before any campaign; one-click
unsubscribe honored at the send seam; 1 email/player/day (welcome exempt);
anonymous funnel events only (no PII); Facebook/Instagram/TikTok deliberately
excluded until X + email traction is proven (rationale in AGENTMAIL_SETUP.md).
