# Kimi K3 — post-tune audit of the Auditor chase fairness fix (findings-first)

A fairness tune was just applied to `src/boss/auditor.gd`'s PURSUE state
per a Grok 4.5 feel review: PURSUE now ramps speed 55%->100% over 0.7s
(`_pursue_elapsed`, `ramp = lerpf(0.55, 1.0, clampf(_pursue_elapsed/0.7,
0,1))`, multiplied into `velocity.x`), and the Hitbox's
`monitorable`/`monitoring` enable is delayed 0.35s into PURSUE via a
`_pursue_hitbox_live` one-shot guard, instead of enabling on the same frame
PURSUE starts. Top speed, phase scaling, live player tracking, jump-gap
gating (`absf(dx) <= max_jump_gap`), and throw cadence were all intended to
stay untouched.

Audit the ACTUAL current file (inlined below) for regressions:

1. Does the hitbox-grace delay ever leave the hitbox in the WRONG state on
   a state transition — e.g. if PURSUE exits (player null, or reaching
   VULNERABLE) before 0.35s elapsed, is the hitbox correctly left/set
   disabled, not stuck half-configured?
2. Confirm `_pursue_elapsed`/`_pursue_hitbox_live` are reset every time
   ALERT->PURSUE fires (not just the first time) so re-entering PURSUE in a
   later phase or after VULNERABLE->PATROL->ALERT->PURSUE again gets the
   grace/ramp again, not a stale "already live" flag from a previous chase.
3. Confirm jump-gap gating (`absf(dx) <= max_jump_gap`) and the throw
   cadence (`throw_timer`) are unaffected by the ramp — they should still
   fire on the same conditions as before.
4. Any float-edge case in the `lerpf`/`clampf` ramp expression itself
   (division by 0.7 is a constant, not user input, but check anyway).
5. Confirm the jump VELOCITY itself (`jump_force = -430`, vertical) is not
   accidentally scaled by `ramp` (it shouldn't be — `ramp` should only
   apply to `velocity.x`).

Findings-first: SEVERITY — file:line — issue — fix. Short.

## File

@include src/boss/auditor.gd
