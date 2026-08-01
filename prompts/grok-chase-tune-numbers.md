# Grok 4.5 — Auditor chase punish-window tune (concrete numbers)

You gave this recommendation last session, before seeing the real code:
"give ~0.6-0.8s extra before full chase speed (telegraph/ramp-in). Keep top
speed; delay when it peaks so retreat after trigger isn't an instant life
tax."

Now here is the ACTUAL current state machine (`src/boss/auditor.gd`),
verbatim values:

- `alert_time = 0.6` — ALERT state: boss freezes, faces player, plays a
  telegraph SFX. This already exists and already runs BEFORE the chase.
- At the instant ALERT ends, PURSUE begins at FULL `pursue_speed = 170.0`
  (scaled by phase: `patrol_speed / _base_patrol_speed`, so phase 1 = 1.0x,
  phase 3 = 1.5x) — no ramp-in on speed.
- Contact damage (`hitbox.monitorable/monitoring`) is set to `true` at the
  EXACT SAME instant PURSUE begins — the same frame the boss starts at full
  speed. So there is zero grace between "boss can now catch you" (speed)
  and "boss can now hurt you on touch" (hitbox) — they're the same trigger.
- The boss also jumps during PURSUE if the player is above or a wall
  blocks it (`jump_force = -430`, gated by `max_jump_gap = 110`).
- `pursue_duration = 4.0` (how long PURSUE lasts before forcing VULNERABLE).

Given the ALERT telegraph already exists and already satisfies "a beat
before the chase starts," the actual gap your last brief was reacting to is
likely: full speed AND live contact damage landing on the SAME frame PURSUE
starts, with no ramp between "he's now chasing" and "he can now hit you."

Give concrete numbers for ONE OR BOTH of:
1. A short ramp-in on `pursue_speed` itself (e.g. start PURSUE at X% of
   `pursue_speed` and linearly reach 100% over Y seconds) — name X and Y.
2. A short delay between PURSUE starting and the hitbox actually going live
   (contact-damage grace period) — name the delay in seconds.

Keep top speed and the live-tracking pursue design unchanged — this is a
first-couple-seconds fairness tune only, not a redesign. One paragraph,
concrete numbers, no code.
