<!-- dispatched: moonshotai/kimi-k3
     prompt: prompts/kimi-stage3-defeat-cutscene-audit.md
     files inlined: 2
     tokens: 6248 in / 19097 out
     cost: $0.3052
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
# Audit result: 0 real defects

I traced all six questions against the file as committed. Findings per question below — each is an explicit "nothing found," with the trace evidence.

---

## Q1 — `_pop_fuse_warning()` looping tween vs `_fuse` freed in `_wreck_cart()`: NO DEFECT

**No, the pulse tween is never explicitly killed. It doesn't need to be.**

Timing trace (all values from the file):

- Pulse starts at t≈0.0s (beat 1). Duration = `set_loops(4)` × (0.2s up + 0.2s down) = **1.6s**, self-terminating at t≈1.6s.
- `_wreck_cart()` frees `_fuse` in beat 3, after awaits of 2.2 + 0.7 + 1.6 + 0.9 = **t≈5.4s**.

The tween has been finished for ~3.8s before its target is freed. `set_loops(4)` is finite, so there is no still-looping tween at free time.

Defense-in-depth, even if someone later changes it to `set_loops()` (infinite):

1. Every tween in the file is created via the cutscene's own `create_tween()`, so each is bound to the cutscene node and is killed automatically when the cutscene is freed — no tween outlives the layer.
2. In Godot 4.x, a PropertyTweener resolves its target by ObjectID each step and terminates that step silently if the target is gone. Freeing a tween's *target* mid-tween is not a crash or an error-spam path.

## Q2 — Two-node tween guards: NO DEFECT (the Stage 1 gap class is absent)

Every `is_instance_valid` in the file, enumerated:

| Construct | Nodes touched | Guard |
|---|---|---|
| Beat 2 `hook` | `_pickaxe` + `_lever` | `is_instance_valid(_pickaxe) and is_instance_valid(_lever)` — **both sides** |
| Beat 2 `divert` | `_cart` only | `is_instance_valid(_cart)` — single-node, correct |
| Beat 3 token free | `t` only | `is_instance_valid(t)` — single-node, correct |
| `_wreck_cart` | `_fuse`, `_cart` separately | one guard each — single-node, correct |
| Beat 4 `descend_cart` | `_exit_cart` + `_shaft` | `is_instance_valid(_exit_cart) and is_instance_valid(_shaft)` — **both sides** |
| Beat 4 `descend_rider` | `_miner_portrait` + `_shaft` | `is_instance_valid(_miner_portrait) and is_instance_valid(_shaft)` — **both sides** |

Additionally, the creation-time guard can't be undercut by a mid-tween free: nothing in the file frees `_pickaxe`, `_lever`, `_exit_cart`, `_shaft`, or `_miner_portrait` individually. The only free that can catch them is the cutscene's own `queue_free()`, which simultaneously kills every tween bound to it. Both sides of the hole are closed.

## Q3 — `_throw_btc_tokens()` array handling: NO DEFECT

Re-read the function body as instructed: it contains exactly two `tween_property` calls per token (scale 0.15s, then position 0.5s) and `tokens.append(token)`. **There is no `tween_callback` and no `queue_free` anywhere in `_throw_btc_tokens()`** — tokens never free themselves. The sole free site is the caller's loop in beat 3.

- Empty array (`BTC_TEX` missing → `return []`): `for t in []:` is a no-op. Safe.
- Stale/invalid ref: impossible in practice (nothing else references the tokens), but `if is_instance_valid(t)` covers it anyway.
- Ordering: token tweens complete at 0.65s; the caller frees after a 0.9s wait. No live tween on a freed token.

## Q4 — Can `finished` ever fail to emit: NO

Two independent emission paths, either sufficient alone:

1. **Normal path**: `_run()` ends in `_finish()`. Every await in `_run()` is a `get_tree().create_timer(t, true, false, true)` — process_always + ignore_time_scale — so no pause or time-scale state can stall the sequence. Nominal runtime: 2.2+0.7+1.6+0.9+2.2+0.5+1.6 = **9.7s**, inside the test's 13.0s gate and the 15.0s deadline.
2. **Deadline path**: the hard-deadline SceneTreeTimer is created in `play()` *before* `_run()` is invoked and is connected directly to `_finish`. It has no dependency on `_run()`'s progress — if `_run()` errors out mid-beat or is otherwise aborted, the timer still fires `_finish()` at 15.0s. It survives an early abort of `_run()` by construction.

The only code that frees the cutscene is `_finish()` itself; there is no external free path in the `die()` wiring that could destroy the node before either path fires.

## Q5 — Double-emit/double-free race on `_done`: NO DEFECT

- Both callers (`_run()` tail, deadline timer) funnel through `_finish()`. `_done = true` is set **before** `finished.emit()`, so even re-entrant emission from a listener would early-return.
- Same-frame near-simultaneous firing: GDScript signal dispatch is synchronous and single-threaded here; the second `_finish()` call sees `_done` and returns. `queue_free()` is idempotent against an already-queued node regardless.
- Post-free callback: after `queue_free()`, the deadline timer's connection to the freed instance is auto-removed by the engine, so no call-after-free.
- Worst-case same-frame interleave (deadline fires, then a beat timer resumes `_run()` before the deferred free lands at end-of-frame): the node is still valid, `_run()` harmlessly spawns a few nodes/tweens that get freed at end-of-frame, and its terminal `_finish()` is `_done`-guarded. No observable failure.

## Q6 — GDScript 4.3 API misuse: NONE FOUND

Each construct checked:

- `_fuse.size / 2.0`, `piece.size / 2.0` — `Vector2 / float` component-wise division: valid.
- `randf_range`, `deg_to_rad`, `cos`, `sin` — valid @GlobalScope functions; `Vector2(cos(angle), sin(angle)) * dist` — `Vector2 * float`: valid.
- Chaining: `tween_property(...).set_trans(...).set_ease(...)` (PropertyTweener methods), `.parallel()`, `set_loops(4)` — all valid. Sequential vs parallel grouping verified per tween: `hook` (0.3→0.25 sequential), `collapse` (three parallel, step = 0.6s), `arc` (0.15→0.5 sequential), debris `burst` (parallel pair, then `tween_callback` lands after the 0.7s step as intended).
- `tween_callback(flash.queue_free)` / `tween_callback(piece.queue_free)` — method-reference Callables: valid in GDScript 4.
- Subpaths `"color:a"` (ColorRect.color), `"modulate:a"` (CanvasItem), `"position:y"` — all valid tween subnames; direct subproperty assignment `_miner_portrait.modulate.a = 0.0` is valid GDScript 4 get-modify-set.
- `tween_property(_exit_cart, "global_position", _shaft.global_position, 1.2)` — settable on Sprite2D, readable on Control. The same-frame read of `_shaft.global_position` immediately after `add_child` + `position` set is sound: CanvasItem updates its global transform synchronously on transform change while in the tree, and the CanvasLayer transform is identity here.
- `create_timer(t, true, false, true)` matches the 4.3 signature (process_always, process_in_physics, ignore_time_scale) — the project idiom, applied uniformly including the hard deadline.
- `set_anchors_preset(PRESET_FULL_RECT)`, `MOUSE_FILTER_IGNORE`, theme overrides, alignment enums — all valid.

---

**Summary: zero defects — CRITICAL/HIGH/MEDIUM/LOW counts are all 0.** The failure-safety spine (process_always timers, independent hard deadline, `_done` guard, both-sided `is_instance_valid` checks on every two-node tween, no self-freeing nodes that a caller also frees) is intact, and the one tween that targets a node later freed individually (`pulse` → `_fuse`) is provably complete ~3.8s before the free. No changes proposed to the cutscene, the gate, or the `bandit_boss.gd` tail.