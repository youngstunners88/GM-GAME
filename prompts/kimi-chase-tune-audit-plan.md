# Kimi K3 — post-tune audit plan for Auditor chase (pre-implementation)

We are about to apply a small fairness tune to `src/boss/auditor.gd`'s
PURSUE state: likely either (a) a brief speed ramp-in when PURSUE starts,
and/or (b) a short grace delay before the Hitbox becomes monitorable/
monitoring after PURSUE begins, per a Grok feel brief. Top speed,
live-tracking (re-reading player position every frame), throw-while-moving,
and the jump-gap gating all stay unchanged — this is a "first couple
seconds fairer" tune, not a redesign.

Before the tune is applied, tell us what a POST-TUNE audit must check to
confirm no regression, given the real current code (inlined below):

1. Does a speed ramp-in (velocity.x scaled by an elapsed-time fraction)
   risk breaking the existing jump-gap gating (`max_jump_gap = 110`,
   checked against `absf(dx)`) if dx is computed against a slower current
   velocity than the eventual target speed?
2. Does a hitbox-activation delay risk letting the player "hug" the boss
   during the grace window in a way that reads as exploitable (e.g. contact
   damage from `_on_hitbox_body_entered` never fires, but is anything ELSE
   gated on `hitbox.monitoring` that would also get suppressed and shouldn't
   be)?
3. Confirm the throw-while-chasing cadence (`throw_timer`) and the
   jump logic are untouched by whichever tune is applied — they must still
   fire during the ramp/grace window, not get skipped.
4. Any interaction with `_jump_cooldown` or `state_timer` (which still
   counts down toward forced VULNERABLE) that a ramp/delay could disturb.

Findings-first, short. This is a pre-implementation checklist, not a
post-hoc audit — a second pass will re-run this against the actual diff
once applied.

## File

@include src/boss/auditor.gd
