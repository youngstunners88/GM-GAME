<!-- dispatched: moonshotai/kimi-k3
     prompt: prompts/kimi-tax-collector-audit.md
     files inlined: 2
     tokens: 3219 in / 20645 out
     cost: $0.3193
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## 1. Null-reference audit

- **verified safe — tax_collector.gd:101 vs 117–129** — `_player` is re-read at lines 117, 118, 120, 125, 129 after the entry guard at line 101 without a second validity check — safe as written: GDScript is single-threaded, there is no `await` and no call into external code between the guard and those reads, so nothing can free the player mid-call. `queue_free()` wouldn't take effect until frame end regardless. Fragile only if someone later inserts a call between 101 and 117 that can free the player.
- **verified — tax_collector.gd:101, 134, 140** — the freed-reference idiom is correct: a freed object is not `== null` in Godot 4, and all three read sites check `is_instance_valid()` in addition to null. Between 0.2s retarget ticks a freed player is caught at the next read; a player removed from the `"player"` group but not freed is pursued as a stale (still valid) node for ≤0.2s, then `_player` goes null and PURSUE exits cleanly. Benign.
- **low — tax_collector.gd:47–48 — `DifficultyManager.tax_speed_scale` is unverifiable** — the DifficultyManager script was not provided. If it's a typed autoload lacking that member this is a parse error; if untyped, a runtime error in `_ready`. Same for `GameManager`, `EffectSpawner`, `ScreenShake` in enemy_base.gd. Missing files: those four singleton scripts.
- No Timer nodes and no signal connections exist in tax_collector.gd — nothing to leak there. EnemyBase's tween lambdas capture only members and the tweens are node-owned, so freeing the enemy mid-flash kills the tween harmlessly.

## 2. State machine audit

- **verified — no deadlock** — every state has an unconditional exit: ALERT's timer decrements every frame (resolves in ≤ `alert_time`), PURSUE exits on invalid player or timeout, PATROL is the sink. No awaits anywhere.
- **med — tax_collector.gd:71–75, 83–84 — boundary stun-lock** — there is no hysteresis on the PATROL↔ALERT transition. A player strafing across the 200px line re-triggers ALERT on every entry, and each entry re-freezes the enemy for a fresh 0.5s (`_alert_timer = alert_time`). The enemy can be held in perpetual telegraph and never reaches PURSUE — the fairness telegraph becomes an exploit. `lose_interest_time` only protects PURSUE.
- **verified — tax_collector.gd:105–106 — `_out_of_range_timer` semantics** — any single in-range frame resets it, so a player who clips the boundary once per <3s keeps PURSUE alive indefinitely. That's standard hysteresis, but note "3s outside radius" means "3s *continuously* outside." No path resets the timer spuriously.
- **verified — ALERT→PATROL exit (line 84) is clean** — `velocity.x` was zeroed but `_do_patrol()` overwrites it next frame; `_alert_timer` is left stale but re-initialized on every ALERT entry; `_out_of_range_timer` is zeroed on PURSUE entry so no stale value can leak in. Facing is corrected by `_do_patrol`'s `_face` next frame. Nothing dangles.
- **low — tax_collector.gd:101–103 — player-invalid PURSUE exit does not re-anchor `start_x`** — the timeout path (line 114) re-anchors; the invalid path doesn't. The enemy then marches back toward its spawn anchor — the exact "forgot what it was doing" behavior the comment says re-anchoring exists to prevent. Inconsistent.
- **low — tax_collector.gd:75 — telegraph faces the player once, on entry only** — if the player crosses behind during the 0.5s freeze, the enemy telegraphs facing the wrong way until the first PURSUE frame corrects it. Cosmetic.

## 3. Jump-gap logic

- **med — tax_collector.gd:129 — the guard measures distance-to-player, not gap geometry, and overestimates jump capability** — kinematics from this file's own constants: `jump_force` 430 / `GRAVITY` 980 gives ~94px apex, ~0.88s airtime, ~92px max horizontal at `pursue_speed` 105 (less after the DifficultyManager scale; ~81px when landing on a +40px ledge). The guard admits 150px. Concrete kill scenario: player on a ledge 50px up and 120px away, across a 105px pit — `wants_up` true (dy=-50 < -40), `absf(dx)=120 <= 150` → jump fires → the enemy covers ~81px and lands in the pit. There is **no** raycast, floor-edge probe, or landing check anywhere in the file — `is_on_floor()` at line 126 gates only the takeoff. The comment's claim "beyond this the jump cannot land" is false for any gap of ~93–150px. Real bug; nothing else in the file prevents it.

## 4. Performance

- **clean** — the only scene-tree search is correctly throttled to 0.2s (lines 62–64). No per-frame heap allocation beyond Vector2 temporaries, no per-frame tween or Timer creation (EnemyBase tweens fire only on damage/death, guarded by `is_flashing`/`is_dead`). Multiple concurrent collectors are fine. No finding.

## 5. Edge cases

- **verified safe** — player freed mid-pursuit: see task 1; the post-guard reads at 117–129 cannot observe a freed player within the call.
- **med — pit falls: zero self-preservation in either file** — no kill-y check, no raycast, no respawn. An airborne collector accumulates `velocity.y` unbounded (the clamp at line 52 applies only on-floor), falls forever, and keeps running `_physics_process` plus the 0.2s group search permanently; if it lands on a pit floor it re-anchors and patrols the pit. I cannot compare against other enemies — only EnemyBase was inlined, and it has no pit handling either. Missing: the other enemy scripts (the EnemyBase comment references "fly"/"vine"), and any level kill-zone script. Whether this is survivable depends entirely on level content I can't see.
- **confirmed out of scope — ladders** — neither file contains any ladder reference; no interaction is coded, so absence is not a bug. Side effect worth knowing: a climbing player inside the detection box triggers ALERT/PURSUE, and with dy < -40 and |dx| ≤ 150 the enemy hops in place every 0.8s beneath the ladder. Cosmetic/design.

## 6. Gate compatibility (gdparse / can_instantiate)

- **high — tax_collector.gd:148 against enemy_base.gd:21 — `sprite.scale.x` on a `CanvasItem`-typed reference is a hard compile error** — `CanvasItem` has no `scale` property (`scale` lives on `Node2D`/`Control`); statically typed access to a nonexistent member fails the analyzer ("Cannot find member 'scale' in base 'CanvasItem'"), so tax_collector.gd does not parse, `can_instantiate()` fails, and the script is silently unattached — precisely the failure mode the EnemyBase comment describes for bosses 2 and 3. The runtime object (a Sprite2D) would have `scale`; it's the declared type that kills it. EnemyBase itself compiles because it only touches `modulate`, which *is* a CanvasItem property. Nothing else in the file runs until `_face` narrows the type.
- **low — tax_collector.gd:64 — `get_first_node_in_group` returns `Node`, assigned to `Node2D`-typed `_player`** — a permitted downcast with a runtime type check, not a parse blocker; it only errors if the `"player"` group ever contains a non-Node2D.
- **verified** — no member shadowing against EnemyBase (`start_x`, `moving_right`, `state`, timers, `_player`, `GRAVITY`, `State` enum all collision-free; `sprite` is correctly *not* redeclared). `super._ready()`, enum typing, ternaries, `signf`/`absf`, and the EnemyBase lambdas are all valid 4.3. Indentation is consistent 4-space as inlined — tabs/spaces mixing can't be verified from a paste.
- **low — tax_collector.gd:148 — `_face` hardcodes `scale.x = ±1.0`** — it overwrites rather than preserves any authored scale on the Sprite node. Whether that breaks art depends on the .tscn, which was not provided (missing file).

## 7. Verdict

Not safe to ship. The `_face()` access of `scale` on a `CanvasItem`-typed `sprite` is a hard parse error — as written, the script never compiles, never attaches, and none of the AI exists at runtime, which is exactly the silent-AI-loss failure mode EnemyBase's own comment warns about. Once that one-line type narrowing is fixed, the state machine itself is logically sound — no deadlock, clean ALERT exits, working PURSUE hysteresis, correct freed-reference guards, good performance hygiene — but release should still be gated on the two med items: the jump guard checks distance-to-player rather than gap geometry and overestimates real jump range (~92px flat vs the 150px guard) with no pit protection in either file, and there is no pit-fall handling anywhere in the provided sources, so whether collectors suicide into pits is currently delegated entirely to level design I cannot see. The lows (boundary stun-lock, telegraph facing, missing re-anchor on the player-invalid exit, authored-scale stomping, and the unverified `DifficultyManager`/`GameManager`/`EffectSpawner`/`ScreenShake` members) can ride a follow-up ticket.