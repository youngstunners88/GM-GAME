Role: L1 DEATH PATH + STAGE 2 CHASE NUMBERS, re-derived independently in the
REAL shipped arena — no memory of any prior session's conclusions. This is
the same role that previously found the Phase-2-never-tested gate gap in
this exact boss; do the same level of independent verification here, not a
plausible-sounding guess.

Two independent questions on a Godot 4.3 2D platformer (GM-GAME):

## Question 1 — Level 1 boss: "Lil Blunt dies without touching the boss"

Founder, this session: "There's a glitch when fighting the boss in level 1
as Lil Blunt will die completely without even touching the boss for some
reason."

"Dies" here means GameManager.boss_contact_restart() fired (full run wipe —
score/coins/rings/smoke to zero, level restart) — this ONLY fires from
auditor.gd's `_on_hitbox_body_entered`, which only fires when the player's
physics body enters the boss's Hitbox Area2D. There is no other death path
in this file for a non-contact cause (no DoT, no separate hazard node in
this scene).

Facts already established, verify or extend them, don't just repeat them:
- Hitbox shape = 168x168, offset (84,84) local — IDENTICAL to the boss's own
  CharacterBody2D collision shape. `monitoring = true` for the WHOLE fight.
- Visible sprite art is 131x150px source, opaque bbox (7,0)-(127,143)
  (~120px of actual character), scaled 1.12x by BossSprite._fit() to match
  size.y=168 → on-screen character ~134-147px wide, centered in the 168px
  hurtbox. That's a real ~15-20px hurtbox pad per side beyond the visible
  character.
- CHARGE state moves the boss at up to 430px/s via move_and_slide() straight
  at a cached `charge_target` (player position captured up to 1.4s
  earlier — the player has likely moved by the time the charge lands).
- LEAP (patrol) fires at velocity.y = -620 when blocked or when the player is
  90px+ above him, then move_and_slide() carries him through the arc while
  the Hitbox stays live the whole time.

Re-derive from the actual file below: is the ~15-20px hurtbox pad ALONE
sufficient to explain a death the player perceives as "not touching", or is
there a compounding mechanism — e.g. does CHARGE's stale `charge_target`
plus 430px/s cause the boss's hitbox to sweep across a spot the player
already vacated visually but where the discrete per-frame overlap check
still catches a trailing edge? Walk the actual frame-by-frame geometry, not
a hand-wave. State the single most likely root cause and the exact numeric
fix (new hurtbox size/offset, or whatever else you find) with your
reasoning shown.

@include src/boss/auditor.gd
@include src/boss/auditor.tscn
@include src/boss/boss_sprite.gd

## Question 2 — Stage 2 boss (Distributor): still not chasing, LIVE, per founder

Founder, this session, again: "The 2nd boss is still not chasing Lil Blunt
you CUNT!!!" This is AFTER a prior session already raised MIN_PURSUE_SPEED
265->315 and CLIMB_SPEED to 400, proved a positive net closing rate in
Phase 2 on both an open-ground test and the real bounded level_02 arena, and
those gates are currently passing.

Founder's standing decision for this session: "Yes — push further. Still
not chasing live. Close distance in the shipped arena. Prefer stronger
pursuit over leaving him outrunnable."

Independently re-derive the FULL multi-phase chase cycle from the file
below — not just Phase 2, all three phases, all five states
(PATROL/GRAVITY_TELL/HOARD_GRAVITY/SHARD_THROW/VULNERABLE) — against a
player holding sprint (240px/s) the entire time, in BOTH open ground and the
real arena_min/arena_max clamp. Specifically check:
1. Does the CLIMB lock (`climbing` in `_hover_pursue`, triggered whenever
   the boss and player are near the same height) re-trigger often enough in
   a REAL fight — not an idealized one — to still net out near zero despite
   CLIMB_SPEED=400, because the boss and player spend more time at similar
   heights than the open-ground test modeled?
2. Is VULNERABLE_DRIFT (120px/s, deliberately half-sprint) or the vulnerable
   window's DURATION (vulnerable_time - phase scaling) now the dominant drag
   term, and if the founder wants stronger pursuit without touching the
   "fair hit window" everyone liked last time, what's the least-invasive
   number to move (e.g. shorten GRAVITY_TELL or SHARD_THROW's duration
   instead of speeding up VULNERABLE) that would measurably increase net
   closing rate across a full real-arena multi-phase fight?
3. Give concrete before/after numbers for whatever you recommend changing,
   derived from the actual constants in the file — not estimates.

@include src/boss/distributor.gd

Be concise, but show your arithmetic — that is the whole value of this
pass. If something needed to answer this with confidence isn't in the files
provided, say exactly what's missing.
