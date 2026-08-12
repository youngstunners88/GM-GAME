Role: RE-ROOT-CAUSE, from scratch, with no memory of any prior session's
conclusions. This is a Godot 4.3 2D platformer. Three independent questions.
Show your arithmetic for all three — that is the entire value of this pass.

## Question 1 — Stage 2 boss: "still does not chase, still not firing
crystals" LIVE, despite a prior session's fix

A previous session raised `MIN_PURSUE_SPEED` 265->315->345 and added a 3-way
action rotation (pull / ETH-orb volley / crystal-shard volley) to
`distributor.gd`, proved it in an open-ground test AND in a REAL bounded-arena
test (kiting inside `arena_min`/`arena_max`), and shipped it. **The founder
reports it still fails live, in both respects — still doesn't chase, and no
crystal shards are visible.** Treat the prior fix as unverified until you
re-derive it yourself.

Re-derive the FULL fight timeline (all 3 HP phases, all 5 states: PATROL,
GRAVITY_TELL, HOARD_GRAVITY, SHARD_THROW, VULNERABLE) using the REAL Stage 2
arena geometry given in the shared facts below (not an idealized open field):
boss spawns at (4050,550), arena clamp is x[3700,4400] y[230,670], single
flat floor at y=650 the whole arena width, no obstructing platforms. The
Distributor's physical body doesn't collide with World geometry (mask
excludes World) — he flies.

Specifically check:
1. Does the y-clamp (230..670) interact badly with `HOVER_ABOVE`/the CLIMB
   lock in a way the open-ground and bounded-x-only tests never modeled? Walk
   through what happens if the player stands still near y=650 (on the ground)
   vs jumps — does the boss's targeting ever get the y-clamp fighting the
   climb-lock in a way that stalls him?
2. Is there any code path where `current_phase_state` can get stuck (never
   reaching a pursuing state) specifically in a fresh, undamaged fight (Phase
   1) — since a live player's FIRST impression is Phase 1, before any damage
   is dealt? Re-check `_ready()`'s initial values (`throw_timer=2.2`,
   `current_phase_state=PATROL`) and the very first few seconds frame by
   frame.
3. Is the crystal-shard action (`_throw_crystal_shards`, 1-in-3 of the
   rotation, `_cadence()`-gated) actually reachable within a realistic first
   engagement window (say, 15-20 real seconds), or does something about the
   real cadence numbers make it rarer than it looks on paper?
4. Any other plausible explanation for "looks completely unchanged live" that
   isn't a chase-speed issue at all — e.g., something that would make the
   ENTIRE `_physics_process` silently no-op, or the boss failing to leave
   PATROL, or a state ping-ponging every frame without net progress?

State your single most likely explanation and the exact fix, with numbers.

## Question 2 — Stage 3 boss: "too easy to kill" — a DPS/exposure problem,
not (necessarily) a chase-speed one

Real combat economy (see shared facts for full detail): player has 3 HP max,
deals 1 damage per axe hit on a 0.4s cooldown (up to 2.5 DPS), from range.
Claim Jumper has 18 HP, 3 phases, and his ONLY attack is telegraphed dynamite
(1 damage, 100px radius, 1.3-2.0s dodgeable fuse). **Critically:
`claim_jumper.gd::take_damage()` has no state gating at all** — he can be
damaged in ANY state, at any range the axe reaches, unlike `auditor.gd` and
`distributor.gd` which both gate incoming damage to an explicit
VULNERABLE/telegraphed window.

Compute: at max player DPS (2.5/s) with zero gating, what's the time-to-kill
for 18 HP? Compare that to how many dynamite throws the boss can realistically
land on a player who is standing at axe range and mostly dodging the
telegraphed fuse (use his `throw_cooldown` and phase scaling from the shared
facts). Does the founder's "too easy" read as consistent with this
zero-gating design? Propose the concrete, minimal-risk fix — e.g. a
VULNERABLE-style gated window (state it exactly: when does he become
vulnerable, for how long, what closes it) vs a flat damage-reduction-outside-
window approach vs something else — and give the exact new time-to-kill under
realistic play with your fix. Constraint: must NOT reintroduce the ledge-fall
bug (his `_clamp_to_arena`/ledge-sense logic must stay exactly as-is;
this is a damage-gating change only, not a movement change).

## Question 3 — Vault soft-lock re-check for an EXPANDED interior

Last session's Diamond Vault / Fort Knox (single floor tier, ladder exit,
proven no-soft-lock) are being expanded into multi-tier interiors with
platforms, hazards, and interactables — you don't have the final new geometry
yet (a parallel implementation-planning pass is proposing it). Instead, give
the GENERAL soft-lock-proofing rules the expanded design must satisfy, derived
from the real constraints in the shared facts:
1. The kill band (y 825-1225, full level width) bounds how deep any tier can
   go — restate the safe vertical budget (650 to 825 = ~175px) and what
   happens if that's violated.
2. If multiple platform tiers exist, what's the rule for guaranteeing EVERY
   reachable tier still has a path to the exit ladder (not just the floor
   tier)? What's the failure mode to explicitly test for (a player reaching an
   upper tier a jump can't return from, with the ladder unreachable from
   there)?
3. Given a hazard is being added (crystal threat / security guard), what
   collision-layer/damage rule keeps it from being ABLE to knock the player
   into the kill band or off a tier into an unrecoverable position (vs. it
   being allowed to just cost health/reset progress safely)?

Show arithmetic where numbers matter. If a needed fact isn't in the shared
facts, name it.

@include prompts/_session3_facts.md

--- Stage 2 boss, full file ---
@include src/boss/distributor.gd

--- Stage 3 boss, full file ---
@include src/boss/claim_jumper.gd

--- Current vault implementation, full file (context for Q3) ---
@include src/level/protocol_vault.gd
