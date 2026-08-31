<!-- dispatched: deepseek/deepseek-v4-pro
     prompt: prompts/2026-08-19-boss-shared-rootcause.md
     files inlined: 4
     tokens: 39140 in / 7807 out
     cost: $0.0826
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
**1. The "shared clamp" hypothesis is refuted for Boss 1, confirmed for Bosses 2/3 only when the player is outside the arena.**

- **Boss 1 (Auditor) has no arena bounds.** The file `auditor.gd` defines no `arena_min`/`arena_max` variables, and the level (`level_01_smoke_realm.gd`) passes `(0,0)` as the arena bounds (hard evidence). The Auditor is a bare `CharacterBody2D` with no `_clamp_to_arena()` call. Therefore, the hypothesis that the boss freezes against a clamp **cannot explain Stage 1’s behaviour** – there is no clamp to freeze against.  
- **Bosses 2 and 3** *do* have arena bounds (`distributor.gd:308-310`, `claim_jumper.gd:232-234`) and a `_clamp_to_arena()` that zeroes velocity when the body centre hits the boundary (`distributor.gd:334-346`, `claim_jumper.gd:245-257`). The founder’s screenshot shows the Stage 2 player at world x ≈ 3109, **591 px west of the arena’s `start_x` (3700)**, while the boss is pinned at its west clamp (3820). The headless data confirms that when the player is *inside* the arena, Bosses 2 and 3 track well (positive scores, 0% clamp). Thus, the mechanism: **player leaves arena → seal wall drops → player can kite from outside → boss is clamped and cannot reach the player → “does not move”.** This is the shared root for Stages 2 and 3, but not Stage 1.

**What the hypothesis fails to explain:** the negative tracking score of Stage 1 (–0.20) and its 33% freeze, which occur even with the player inside the arena. These are caused by the Auditor’s own state-machine bugs (see #2), not by any arena clamp.

---

**2. Stage 1’s negative tracking score is caused by the `CHARGE` state capturing a static `charge_target` and the `VULNERABLE` state’s delta‑less brake.**

In `auditor.gd`, the `CHARGE` state is entered from `PATROL` at line 212:
```gdscript
charge_target = p.global_position
```
Once captured, the boss moves toward that fixed point (line 216‑217):
```gdscript
var dir := global_position.direction_to(charge_target)
velocity.x = dir.x * charge_speed
```
The player is kiting, so the `charge_target` is a **past position**. The boss then moves toward that point, which may be behind the player’s current direction of travel, producing **movement opposite to the player** → negative correlation.  
The `VULNERABLE` state (line 223‑224) uses
```gdscript
velocity.x = move_toward(velocity.x, 0.0, 200.0)
```
with **no `delta` scaling** – the boss stops in a single frame, contributing to the measured 33% frozen time, but the negative tracking is driven by the outdated target.

---

**3. Minimal shared fix: make the arena seal wall permanent while the boss is alive, and drop it only on player death.**

**Rationale:** The seal wall is common to all arenas (`level_0X_*` scripts). If the player cannot leave the arena while the boss lives, the boss is never left outside the player’s reachable area, and the clamp‑freeze scenario is avoided entirely. This also works for Stage 1 (where the boss has no clamp) because the player is kept inside the arena, so the Auditor’s chase cannot be trivially escaped.

**Implementation sketch (single change in the level scripts):**
- The seal is raised when the player enters the arena (as now).
- The seal is **only removed** when the player goes back west of `start_x - 40` **if the boss is already defeated** (i.e., `is_dead` or equivalent).  
- **Soft‑lock prevention:** when the player dies, the seal is immediately removed (or the respawn logic is augmented to drop the seal). This ensures the player can respawn outside the arena and re‑enter. The boss fight is still active, but the seal removal on death is safe because the player must re‑approach the arena and the boss will be reset to its spawn position (or the fight resumes normally).

This is **not** a stage‑specific hack; it is a single rule change in the seal‑wall management that applies to all levels. No teleporting, infinite detection, or speed adjustments are needed.

*Alternative considered but rejected:*  
- Having the boss’s clamp follow the player outside the arena would allow the boss to leave the fight area, possibly breaking other level geometry.  
- Suspending/resetting the fight when the player leaves would be a UX regression (the player could trivially reset the fight at any time).

---

**4. Boss speeds (290–385 px/s) vs. player top speed (240 px/s) combined with instant‑restart on contact is survivable – the intended counter‑play is agility and attack‑pattern exploitation.**

The player is not meant to outrun the boss in a straight line. The boss is faster, but:
- The player can **jump** over the boss (the bosses have body sizes and the player can clear them with a well‑timed jump).
- The boss’s own **attack cycles** create openings: the Auditor’s `CHARGE` leaves it vulnerable, the Distributor’s `HOARD GRAVITY` pulls the player but also gives a tell, the Claim Jumper’s dynamite zones are telegraphed.
- The **vulnerable windows** allow the player to deal damage while the boss is slowed or distracted.
- The **spawn grace** (1.2 s) prevents instant death on fight start.

The speed values are therefore **not inherently unfair**; the unfairness arises when the AI fails to pursue (making the fight too easy) or when the arena clamps the boss (making it impossible to avoid). The combination is survivable if the AI and arena rules are correctly implemented, as the player has tools to avoid contact.

---

**5. “Stage 3 boss too easy to defeat” is perfectly consistent with “does not move” – the player was killing a wall‑pinned, motionless boss with no damage gate.**

The bugs in the old `claim_jumper.gd` code (now fixed, but the source of the reports):
- `current_state` **never left `PATROL`** (the `_throw_dynamite()` function never set it to `THROW`), so the boss never entered the `VULNERABLE` state and its attack cycle was dead.
- `take_damage()` **had no state gate**, so the player could hit the boss at any time, from any range.
- The boss’s health was either **6 HP** (the old `max_health`) or **1 HP** (because `health` was not explicitly set, inheriting the default from `EnemyBase`).
- The `VULNERABLE` state **froze the boss in place** (the old `velocity.x = move_toward(velocity.x, 0.0, 200.0)` with no delta).

Thus, the player encountered a boss that did not move, had no effective attacks, and could be killed in a few hits from a safe distance – exactly “too easy” and “does not move.” The current code (with `max_health = 18`, a proper state machine, damage cap, and `VULNERABLE_DRIFT`) addresses all of these, so the report is a historical artefact of the buggy version.