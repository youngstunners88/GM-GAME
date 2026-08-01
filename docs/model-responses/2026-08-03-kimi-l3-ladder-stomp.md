<!-- dispatched: moonshotai/kimi-k3
     prompt: prompts/kimi-l3-ladder-stomp-edge-cases.md
     files inlined: 4
     tokens: 12608 in / 27477 out
     cost: $0.4500
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## Part A — ladder fix

**PASS — level_03_gold_rush.gd:84-88 — arithmetic is correct.**
Target = `(1480 + 120/2, 420 - 20)` = `(1540, 400)`. Offset = `(1540-1465, 400-350)` = `(75, 50)`. ✓

**PASS — (1540,400) is on the platform's reachable surface.**
Platform x-span [1480,1600]; 1540 is dead centre (60px from each edge). y=400 is 20px above the surface (420). With the 28×28 player box (per the comment at player.gd:455-458 region), a centre-origin player spans y 386–414 there: no overlap, settles 6px onto the surface. If the origin is top-left (can't confirm — player.tscn not provided), the box is embedded 8px and the bounded nudge loop at player.gd:467-470 (8 × 4px = 32px) lifts it clear. Works under either convention.

**PASS — this is the right platform; no better candidate exists.**
- Ground segments confirm the gap: `(1020,650,480,70)` ends at x=1500; `(1600,650,380,70)` starts at x=1600 → gap 1500–1600, gate x=1520 sits in it. ✓
- The chosen platform spans x 1480–1600, i.e. it *is* the ledge bridging the gap directly over the gate, and it's the only platform overlapping the gate's x. Next candidates: `(1180,300,100,20)` ends at x=1280 (185px left of the ladder, plate side); `(1780,250,100,20)` starts at x=1780 (past the gate, gold-lane side). Ladder top (1465,350) → this platform is nearest by a wide margin (Δ≈(15,70)).
- Path continuity: ledge right edge (1600,420) → first gold-lane one-way (1700,460): 100px gap, 40px drop — trivial hop. Ladder base (1465,650) lands on ground segment (1020–1500, y=650), 35px before the gap edge. ✓

**LOW — level_03_gold_rush.gd:82 — comment arithmetic error.**
"lands at (1465,330), … AND 70px above its surface (420)": 420−330 = **90px**, not 70. 70px is top_y(350)→420; the comment conflates the ladder top with the default exit point. Applied offset is unaffected. Fix: change "70px" to "90px".

**INFO — geometry is 1px-tight while climbing past the ledge.**
Ladder shaft at x=1465 vs platform left edge 1480 = 15px; a 28px-wide centre-origin player climbing at x=1465 clears the platform edge by 1px while passing y 392–448. Functional, fragile. Consider ladder x=1455. (Caveat: player.tscn collision offset not provided.)

## Part B — stomp edge cases

**B1 — UNVERIFIED (HIGH if absent) — auditor.tscn:12 — root node declares no `groups=["boss"]`.**
In Godot 4.3 scene format, persisted groups appear as `[node name="Auditor" type="CharacterBody2D" groups=["boss"]]` — not present. Membership can only come from `auditor.gd` (**not provided**). If `add_to_group("boss")` isn't there, player.gd:584 never trips and the stomp bypasses the VULNERABLE contract. Same for `claim_jumper.tscn/.gd` — the boss Level 3 actually spawns (level_03_gold_rush.gd:112) — not provided at all. Fix if missing: add `groups=["boss"]` to the .tscn root or `add_to_group("boss")` in a shared boss base `_ready()`.

**B2 — PASS with one cosmetic window.**
A stomp cannot fire while passing up through a one-way platform from below:
- Velocity gate: rising → `velocity.y < 0`, and `_last_fall_speed = velocity.y` is rewritten every airborne frame (player.gd:152), so `falling` (player.gd:590-592) is false for the entire rise. No stale fall speed can linger in normal gravity state.
- Position gate: `global_position.y < body.global_position.y - 8` (player.gd:594) is origin-to-origin; a player below the platform has a larger y than any enemy standing on it, so the check fails regardless of platform thickness (one_way_platform.tscn not provided — non-decisive, since thickness never enters either gate).
- `body_entered` fires once, on first overlap (during the rise) → `_try_stomp` returns false → normal `deal_damage` path. It does not refire at the apex while still overlapping.

Residual (LOW): if the player rises fully clear of the enemy, then descends, the stomp fires cleanly — that reads as a normal head-landing. The inverse unfairness exists but is standard: the player takes contact damage while phasing up through a platform an enemy stands on. No fix needed for the stomp side.

**B3 — MEDIUM — player.gd:583-604 — `_try_stomp` can fire while `_climbing`, and the fall-speed gate is stale for the whole climb.**
Two holes:
1. Climbing down drives `velocity.y = vertical * climb_speed` = 150 (player.gd:431) > `stomp_min_fall_speed` (40) → `falling` is true while descending a ladder.
2. Worse: climb entry (player.gd:124-137) zeroes `velocity` but **not** `_last_fall_speed`, and the `_climbing` early-return (player.gd:121-123) skips the branch that maintains it. Any fall >40px/s before grabbing the ladder leaves `_last_fall_speed > 40` for the *entire climb* — including climbing up or idle. Any enemy contact with the player's origin ≥8px above the enemy's then stomps it.
The bounce is also broken feedback: `_try_stomp` sets `velocity.y = -300` (player.gd:598) but never clears `_climbing`, so `_update_climb` overwrites `velocity.y` the very next frame — enemy takes damage, player stays glued to the ladder, no bounce. (Same staleness applies to the fly state, which also early-returns at player.gd:114-116, though fly-sink at 90px/s reads acceptably.)
Fix: add `if _climbing: return false` as the first gate in `_try_stomp` (climb contact should use the enemy's normal `deal_damage` contract), and add `_last_fall_speed = 0.0` at player.gd:126 next to `velocity = Vector2.ZERO`.

**B4 — PASS — no double damage; the flag clear is effective, not cosmetic.**
Timeline: `_resolve_ground_pound()` only runs from the pound block (player.gd:236-239) when `is_on_floor()` — which reflects the *previous* `move_and_slide` — is true. On the impact frame that check runs *before* `move_and_slide()` (player.gd:246), so resolve cannot run that frame. The hurtbox signal (and thus `_ground_pounding = false` at player.gd:597) is delivered during the impact frame's physics flush, strictly before frame N+1's `_physics_process`, where the pound block is now skipped. The AoE `take_damage` at player.gd:315 therefore never executes after a successful stomp. ✓

Two residuals:
- **LOW (design confirmation)** — a pound that lands on an enemy's head converts to a plain stomp and silently drops the pound's entire payoff: no shake, no block-break, no 120px AoE stun for *other* nearby enemies. The comment at player.gd:597 says this is intended; confirm design agrees.
- **MEDIUM — player.gd:311-315 — the pound AoE has no boss exclusion.** `_resolve_ground_pound` damages everything in group `"enemy"` within 120px with no `is_in_group("boss")` check — the exact VULNERABLE-window bypass the stomp guard exists to prevent. Bosses are almost certainly in `"enemy"` (player.gd:563 requires it for boss contact to register at all), but group membership lives in auditor.gd/claim_jumper.gd — not provided. Fix: add `and not enemy.is_in_group("boss")` to the AoE condition at player.gd:312-314.

## Missing files (needed to close the UNVERIFIED items)

- `src/boss/auditor.gd` — `add_to_group("boss")` / `add_to_group("enemy")` (B1, B4-pound).
- `src/boss/claim_jumper.tscn` + `.gd` — Level 3's actual boss, not provided (B1, B4-pound).
- `src/level/ladder.gd` — confirm `top_exit_position()` composes `global_position + top_exit_offset`, `top_y()`, default offset (0,-20), and that `height` extends downward 350→650 (Part A full verification; arithmetic above assumes this composition).
- `src/level/timed_door.tscn` — door collision extent vs the y 420–530 space between ledge and gate origin (Part A "approach ledge" confirmation).
- `src/player/player.tscn` — player CollisionShape2D offset (origin convention) for the 6px-settle vs nudge-loop path and the 1px climb clearance.
- `src/level/one_way_platform.tscn` — thickness (non-decisive for B2 as shown).