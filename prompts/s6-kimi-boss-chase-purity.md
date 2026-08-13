@include prompts/_s6_facts.md

@include src/boss/claim_jumper.gd

# YOUR ROLE: Kimi K3 — boss numbers & projectile purity (real-arena reasoning)

TWO tightly-scoped questions. Reason from the included claim_jumper.gd source.

## Q1 — S3 horizontal chase (jump-in-place)
The Claim Jumper still "only jumps in one spot" live. Using the actual
constants in the included file (patrol_speed 290, TURN_DEAD_ZONE 34, HOP_VELOCITY
-620, gravity 980, _hop_cooldown 0.7, the PATROL hop block), reason through the
exact sequence that produces a stationary vertical hop when the player kites
roughly overhead or just above. Then give the MINIMAL constant/logic change so
that across ~6s of a player kiting horizontally, the boss travels a meaningful
horizontal distance (state a target px). Do NOT reintroduce ledge suicide (the
arena clamp + _gap_crossable gates must stay). Give a concrete px/s number and
the exact line(s) to change.

## Q2 — S2 projectile purity
The S2 boss's redirectable ETH-orb volley renders as blue circles (fx_dot).
Confirm the minimal way to make EVERY active S2 projectile carry distinct
diamond/shard geometry (hide base dot via tint alpha 0 + add a Polygon2D child),
matching the existing `_throw_crystal_shards` pattern, WITHOUT breaking the
redirect/homing mechanic. State the one assertion a gate should check to prove
"no circle projectile in the active rotation."

Be terse. Output numbers and line-level changes, not prose.
