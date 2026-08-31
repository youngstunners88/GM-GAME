Re-root-cause two boss bugs in a Godot 4.3 platformer. Be CONCISE — lead with
the answer, minimal preamble. Two questions only.

## Q1 — Stage 2 boss (distributor.gd): founder says STILL not chasing, and the
crystal attack "looks the same as the Stage 1 boss".
KEY FACT (verified): `_throw_crystal_shards` and `_throw_shards` BOTH
instantiate the SAME `boss_projectile.tscn`, which draws `fx_dot.png` (a plain
dot) recolored by `tint`. The Stage-1 boss's clipboard ALSO uses
boss_projectile.tscn with a tint. So all three "attacks" are the same dot
sprite in different colors — that is almost certainly why the founder says
"same as boss 1". Confirm this is the real bug and give the concrete fix (a
visually distinct crystal-shard projectile — new sprite or a Polygon2D shard
shape — not a recolored dot). Separately, from distributor.gd's state machine,
is the chase against a KITING (fleeing) player actually positive in the real
arena, or only against a stationary target? Give the net closing-rate
arithmetic and a fix if negative.

## Q2 — Stage 3 boss (claim_jumper.gd + dynamite.gd): three sub-bugs.
VERIFIED FACT: `sprite_boss_bandit-cart.png` visually faces RIGHT, and
claim_jumper.tscn leaves `art_faces_right` at its default true — so that is
CORRECT; do NOT flip it. `set_facing` is only called when
`absf(velocity.x) > 12`.
(a) Back-facing: given the above, confirm the cause is the velocity-gated
facing freezing when he stops, and that the fix is to face the player every
frame regardless of velocity. Give the exact code.
(b) "Doesn't move beyond this point, only jumps straight up": walk the
PATROL/THROW/VULNERABLE state machine + `_ground_chase` ledge-sense +
`_clamp_to_arena`. What zeroes his horizontal advance and leaves only a
vertical hop? Give the minimal fix that restores horizontal pursuit WITHOUT
re-enabling the ledge-fall-death bug.
(c) Dynamite explosion "no damage": `_explode()` creates an Area2D then does
`await get_tree().physics_frame` then `get_overlapping_bodies()`. Is the await
reading pre-overlap-registration state (so it always returns empty)? Confirm
and give the synchronous `intersect_shape` replacement.

@include /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/s4ex/distributor.gd
@include /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/s4ex/claim_jumper.gd
@include /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/s4ex/dynamite.gd
