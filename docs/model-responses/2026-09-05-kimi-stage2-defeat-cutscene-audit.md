<!-- dispatched: moonshotai/kimi-k3
     prompt: prompts/kimi-stage2-defeat-cutscene-audit.md
     files inlined: 2
     tokens: 5082 in / 10046 out
     cost: $0.1659
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## Verdict: no real defects found

I traced all five questions against the named historical bug classes. Findings per question below — each is an explicit "nothing found," with the evidence you asked for.

### 1. Null-safety of cross-beat references — NO DEFECT

Every `is_instance_valid` call in the new file, and what it covers:

- Beat 1 loop: `if is_instance_valid(_pickaxe)` before the `swing` tween — covers the `_pop_pickaxe()` early-return path (missing `PICKAXE_TEX` leaves `_pickaxe` null).
- Beat 2: `if is_instance_valid(_pickaxe)` before the `smash` tween.
- Beat 3: `if is_instance_valid(_pickaxe)` before the `final_hit` tween.
- Beat 4: `if is_instance_valid(_vault_door)` before the `open` tween — covers the `_reveal_vault_door()` early-return path.
- `_shatter_boss()`: **two independent guards**, one for `_boss_body`, one for `_boss_head` — both sides of that interaction covered, which is exactly the Stage 1 gap.

Specific traces you requested:

- **`_shatter_boss()` loop:** each `piece` is a function-local created and consumed (`add_child`, tween setup, `tween_callback(piece.queue_free)`) with **no `await` between creation and use** — it cannot be null or freed at bind time. Same for `shard` in `_spawn_shard()` and `flash` in `_flash_impact()`.
- **`_reveal_vault_door()`:** the `reveal` tween targets the node created two lines earlier, no suspension point in between; the only path that leaves `_vault_door` null is the `ResourceLoader.exists` early-return, and the Beat 4 guard covers the later `open` tween.
- **`_tint` / `_boss_body` / `_boss_head`** are constructed with no early-return path, and nothing frees children individually except the self-`queue_free` tween callbacks on shards/flash/pieces. `wash.tween_property(_tint, ...)` is unguarded but has no reachable null/freed state while the cutscene lives; if the cutscene itself is freed, the coroutine dies with it (see Q2).

### 2. `finished` emission vs. early abort — NO DEFECT

The deadline `SceneTreeTimer` is **owned by the SceneTree, not the cutscene node**, and is connected before `_run()` is called. A runtime error or stall inside `_run()` cannot touch it; it fires `_finish` at 12.0s regardless. The only thing that disconnects it is freeing the cutscene node, and the only free path is `_finish()` itself — which does `finished.emit()` **before** `queue_free()`. Since awaited signals resume synchronously during emission, the `await cutscene.finished` in `distributor.gd::die()` resolves before the free lands. That ordering is precisely what defuses your historical "coroutine awaits a signal on a node that frees itself first" class — the node emits first, then frees. If the whole scene were torn down mid-cutscene by an external scene change, the distributor is freed with it, so no stranded await is observable there either.

### 3. Ten `ColorRect` burst pieces vs. the physics-churn crash class — NO DEFECT

That gotcha class is physics-server churn: `Area2D`/`CollisionShape2D` create/free in tight loops, where shape/body creation and teardown collides with broadphase and flush queries on the non-threaded web build. The `_shatter_boss()` pieces are `Control`/`ColorRect` — pure `CanvasItem`. No physics server objects, no shapes, no queries; the tweens run in the scene-tree tween system, not physics. Ten short-lived canvas items in one frame is trivial scene-tree churn. Different pattern, safe.

### 4. Double-emit race on `_done` — NO DEFECT

`_finish()` contains **no `await`** between the `_done` check and the `_done = true` set, so the check-and-set is atomic: GDScript is single-threaded and signal/callback delivery is serialized. If the deadline timer and the normal `_run()` tail fire in the same frame, they execute sequentially and the second call sees `_done == true` and returns. A second `queue_free()` would additionally be harmless. No interleaving is possible.

### 5. GDScript 4.3 API usage — NO DEFECT

Checked each: `"color:a"` / `"modulate:a"` are valid tween property subpaths; backslash continuation for `.set_trans(...).set_ease(...)` chains is valid; sequential vs. `parallel()` tween calls are used correctly (the `swing` and `open` sequences are intentionally sequential); `shard.size / 2.0` is valid `Vector2 / float` scalar division for `pivot_offset`; `randf_range` / `deg_to_rad` / `cos` / `sin` are valid `@GlobalScope` functions; `shard.queue_free` / `piece.queue_free` as first-class Callables in `tween_callback` is valid GDScript 4; `create_timer(t, true, false, true)` matches the documented idiom's argument order; `_vault_door.modulate.a = 0.0` is legal sub-property assignment on a value-type property in GDScript (unlike C#).

### Historical-class checklist (all four named classes)

- Collider enabled during shrink-to-zero: `hitbox` is `set_deferred`-disabled before the scale tween in `die()` — out of scope per constraints, but confirmed correct.
- Coroutine awaiting a self-freeing node's signal: defused by emit-before-free ordering (Q2).
- `SceneTreeTimer` missing `process_always`: every timer in both files uses `(t, true, false, true)`.
- Two-node tween guarded on one side only: every multi-node interaction here guards each node independently (Q1).

Nothing to change. The file matches the Stage 1 spine and closes the one gap Stage 1 originally had.