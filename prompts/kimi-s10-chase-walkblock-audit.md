# Code audit — Lil Blunt Adventure S10: boss chase + walk-block collision

BUDGET DISCIPLINE: Answer question-by-question. Keep each answer to a few
sentences with concrete line references. Emit partial results rather than
deliberating silently — do NOT spend the whole token budget on hidden
reasoning. If you run low, output what you have.

## What the game is
Godot 4.3 HTML5 2D platformer. Two flying/ground bosses are inlined:
- `distributor.gd` — Stage 2 boss, a FLYING boss that hover-pursues the player
  in a bounded arena. The founder repeatedly reports "the 2nd boss doesn't
  chase — he hovers overhead." Many prior fixes (HOVER_ACCEL, MIN_PURSUE_SPEED,
  a climb lock + hysteresis). Still reported broken live, but never captured in
  a browser.
- `claim_jumper.gd` — Stage 3 FINAL boss, a GROUND boss that walks/hops toward
  the player, throws dynamite, has ledge-sense so he won't suicide off ledges.
  Founder now reports the final boss is "frozen / a statue — no jump, remains
  still" (a regression from an earlier working chase).

## Engine facts you must NOT "correct"
- Godot 4.3. `get_tree().get_first_node_in_group("player")` returns `Node`
  (typed); reading `.global_position` off it as `var x := ...` where the value
  is a Variant is a HARD parse error — must cast to a concrete type first.
- Collision: layer 1 = World, layer 2 = Player. Bosses use move_and_slide.
- `arena_min`/`arena_max` are set by the level BEFORE add_child (pre-add
  contract), so the clamp is live on frame 1. Zero-size = unset.
- Both bosses' node ORIGIN is the body's TOP-LEFT; the visible centre is
  origin + BODY/2. This has caused many off-by-half-body bugs.
- The boss's `_physics_process` runs AFTER the player's move_and_slide, so
  writing `player.velocity += ...` gets wiped — displacement uses
  move_and_collide instead.

## The bug class I'm hunting
Silent state-machine / arithmetic bugs that still compile and boot but make a
boss read as "not chasing": e.g. a state that never advances, a lock/flag that
stays armed and zeroes horizontal closing, a speed floor that a phase-2 cycle
nets out to ~0, a clamp that pins the boss to a wall, facing frozen while
velocity is ~0, or a ledge/hop guard that makes a GROUND boss pogo-in-place or
freeze on flat ground. This project has shipped ALL of these before.

## The questions

### Q1 — Stage 3 "frozen statue" (claim_jumper.gd) — HIGHEST PRIORITY
Trace `_physics_process` → `State.PATROL` → `_ground_chase`. Under what
concrete conditions could this boss end up **stationary on flat ground** (vx→0,
no hop) against a player standing a moderate distance away? Consider:
`TURN_DEAD_ZONE`, the `at_ledge` velocity.x=0 branch, the arena clamp zeroing
velocity.x, `_hop_cooldown`, and whether `direction` can get stuck. Give the
exact lines and the smallest fix that guarantees horizontal pursuit on flat
ground while keeping ledge-suicide protection.

### Q2 — Stage 3 hop/ledge interaction
Can the ledge-sense (`_ledge_ahead` zeroing vx) combined with the arena clamp
(`_clamp_to_arena` zeroing vx at a wall) leave him permanently pinned near an
arena edge reading as a statue? If so, what's the fix?

### Q3 — Stage 2 hover-not-chase (distributor.gd)
The current `_hover_pursue` has a climb lock with hysteresis (`_climb_locked`,
`_lock_cd`, `raw_lock`, `imminent`). Is there ANY remaining path where the lock
stays effectively engaged (to.x damped to 0.25 continuously) against a weaving+
hopping player, still zeroing net horizontal closing? Is 0.25 damping enough to
read as pursuit, or does the fight still net ~0 horizontal progress in phase 2?
Give concrete cycle math if you can, and the smallest change.

### Q4 — Test-only warp safety
I plan to add a `?boss=2` / `?boss=3` debug warp (read from the HTML5 query
string) that teleports the player straight into the boss arena so a Playwright
capture can record the fight. What must such a warp set to avoid a false
"chase works" or "chase broken" reading — i.e. what live state (arena bounds,
seal wall, camera limits, boss spawn) must be identical to the real approach?

## Output format
Q1–Q4, each a few sentences + exact line numbers + the minimal code change.
Rank the four by how likely each is the founder's actual live bug.

---

@include src/boss/claim_jumper.gd
@include src/boss/distributor.gd
@include src/level/level_03_gold_rush.gd
