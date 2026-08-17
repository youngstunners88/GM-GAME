You are Kimi K3 with the skill `model-kimi-chase-geometry`. The founder has now
said MORE THAN TEN TIMES that the Stage 2 (Distributor) and Stage 3 (Claim
Jumper) bosses "still don't fucking MOVE / still don't chase". Every previous
"FIXED" claim is REJECTED. Re-derive from the live files with ZERO trust in any
prior fix or any comment in the file claiming something was already solved.

Note the exact wording escalated from "doesn't chase" to "doesn't MOVE".

@include src/boss/distributor.gd

Player sprint = walk_speed 200 * SPRINT_MULTIPLIER 1.2 = 240 px/s.
Stage 2 arena: boss_arena start_x/end_x from level_02_data.tres; the level sets
boss.arena_min = Vector2(start_x, spawn.y - 400) and
boss.arena_max = Vector2(end_x, spawn.y + 60) BEFORE add_child.
The level ALSO calls arm_boss_arena_seal(), which raises a World-layer
StaticBody wall at boss_arena.start_x. NOTE: level_01 deliberately does NOT arm
that seal, with this comment: "the Auditor's own collision_mask is 13, which
includes bit 1 (World) — so that wall caged the BOSS too... that is precisely
the founder's 'the Auditor is still unable to move beyond this point'."

FALSIFIABLE QUESTIONS — answer each with exact line/constant evidence:
1. Does the Distributor's collision_mask include the World bit? If it does, does
   arm_boss_arena_seal()'s wall cage HIM the same way it caged the Auditor on
   Level 1 — i.e. is the level-1 bug still live on levels 2/3? This is my
   leading hypothesis; confirm or kill it.
2. `_clamp_to_arena()` zeroes velocity.x/velocity.y when it clamps. With
   HOVER_ABOVE = BODY/2 + HOVER_CLEARANCE = 250 and a player standing on ground
   at y~650, the boss's TARGET centre y is ~400. Is arena_min.y/arena_max.y ever
   tighter than the target, so he is permanently clamped and velocity is zeroed
   every single frame → visually frozen?
3. The climb lock: `too_low` is `body_bottom > player.y - CLIMB_CLEAR_MARGIN`.
   If the boss is clamped by the arena at a y he cannot leave, can `_climb_locked`
   become PERMANENT (raw_lock true forever, never releasing), pinning him to
   `to.x *= 0.5` and CLIMB_SPEED vertical-only motion — i.e. he hovers and never
   closes? Show the exact condition chain.
4. Is there ANY state or code path where he ends up with zero net horizontal
   movement for most of a full multi-phase cycle in the REAL bounded arena
   (not open ground)?
5. What is the MINIMAL change (numeric or state-machine, no new states) that
   makes him visibly close distance on a moving player in the real arena?

Also give me a gate design that FAILS on the current code and PASSES after your
fix, driven in the REAL level scene, not a synthetic box.
Be concise and specific. Lead with your single highest-confidence root cause.
