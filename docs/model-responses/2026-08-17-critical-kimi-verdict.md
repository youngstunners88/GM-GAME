<!-- dispatched: moonshotai/kimi-k3
     prompt: prompts/crit-kimi3.md
     files inlined: 0
     tokens: 894 in / 5409 out
     cost: $0.0838
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
**(A) AGREE.** Gap closed 350→6.7 (S2) and 230→18.9 (S3); |dx|<60 for 52%/38% of ticks. Both bosses reach and *hold* the player's x. Pursuit works.

**(B) AGREE — and it's stronger than you state.** The Distributor's target (player + (0,−250)) is a *constant* offset, so once locked, its position relative to a player-following camera is mathematically fixed — apparent motion ≈ camera lag only. Measured vertical gap (mean 250, min 165) confirms it's parked exactly on that anchor. One unclosed link: you logged world coords only. Log camera x (or screen-space delta) for one session to make B airtight.

**(C) AGREE.** On the ground plane, x-lock *is* body overlap, which fires `boss_contact_restart()`. 4 reloads / 16s, max survival 4.07s — the fight ends before any post-lock behaviour can be observed. S2's 0 reloads / 18s survival confirms contact, not pursuit, is the killer.

**(D) AGREE.** Decisive tell: average path speed ≈98 px/s (S2) and ≈188 px/s (S3) against MIN_PURSUE_SPEED 345. Once locked, boss velocity is slaved to the player's, so speed/accel buffs only shortened the brief visible approach and lengthened the parked phase. Ten attempts pulled a speed lever on a targeting problem; the complaint had to migrate "doesn't chase" → "doesn't move."

**(E) AGREE, with one required correction.** A standoff implemented as a continuously-tracked offset (player.x ± D) has the *same* zero-relative-motion equilibrium as (0,−250) — you'd rebuild the freeze at a new radius. It must hold a **world-space anchor with a deadband** (re-position only when the player exits the threat ring) and attack from the ring.

**Standoff distances**
- **Distributor (hover, 240px wide, keep −250 vertical): 200px horizontal.** Reachable from either side anywhere in 700px (worst case: player at wall, boss center at 200, edge at 80 — clear), large enough to read as motion, small enough to share the screen.
- **Claim Jumper (ground): 150px center-to-center** — *conditional*. Minimum safe value is `boss_halfwidth + player_halfwidth + ~40px buffer`; those collision widths were not in your data. If the Claim Jumper is anywhere near 240px wide, 150 is inside its body — use the formula, which likely lands ~180–220.

**Single biggest backfire:** a standoff boss that holds station and *does nothing* at that range. The founder's report flips to "won't engage / refuses to attack," the next dev shrinks the standoff or raises aggression, and you're back at contact-lock within two iterations. The standoff only survives if something visibly *happens* from it — a telegraphed lunge or projectile fired from the ring — paired with the deadband so the player, not the boss, generates the relative motion between attacks.

**Missing data to close this out:** camera x trace (for B), and player + Claim Jumper collision widths (to finalise the ground standoff).