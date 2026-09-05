<!-- dispatched: moonshotai/kimi-k3
     prompt: prompts/kimi-stage1-defeat-cutscene-audit.md
     files inlined: 2
     tokens: 5009 in / 23208 out
     cost: $0.3631
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
# Audit result: 2 real defects

## Defects

**1. Unguarded `_miner_portrait` dereference in beat 3 — `_run()` aborts mid-sequence if the miner texture is missing**
- **Construct:** in `_run()`:
  ```gdscript
  _reveal_miner_portrait()
  if is_instance_valid(_pickaxe):
      var claim := create_tween()
      claim.tween_property(_pickaxe, "global_position", _miner_portrait.global_position, 0.7)
  ```
  The guard checks `_pickaxe` only. `_reveal_miner_portrait()` early-returns without creating anything when `ResourceLoader.exists(MINER_TEX)` is false, leaving `_miner_portrait == null`.
- **Failure scenario:** export/load succeeds for `sprite_item_pickaxe.png` but not for `sprite_lil-blunt_miner.png` (the exact asset-missing case the file's own `ResourceLoader.exists` guards contemplate). At ~t=3.0s, `_miner_portrait.global_position` raises "Invalid access to property or key 'global_position' on a base object of type 'Nil'", and GDScript aborts `_run()` at that line. Everything after is skipped: the claim tween, `player.set_outfit(Player.Outfit.MINER)`, the BLUNT VO, all of beat 4, and the normal `_finish()` call. The screen then sits on the tint+vault+pickaxe frame for ~11s until the hard deadline fires `_finish` at t=14s.
- **Why not worse:** the deadline timer is independent of `_run()` (see Q1 below), so this cannot soft-lock — `finished` still emits and the victory hand-off happens. Per the header comment, `level_02_crystal_caverns.gd` re-applies MINER on its own `_ready()`, so the skipped outfit call is not persistent. `_pickaxe` leaking is harmless (child of the cutscene, freed with it).
- **Severity: MEDIUM** — latent (requires a missing asset in an otherwise intact export), bounded by the deadline, but when triggered it's a visible ~11s frozen frame plus an aborted sequence. Fix is one clause: `if is_instance_valid(_pickaxe) and is_instance_valid(_miner_portrait):`.

**2. The gate test does not parse under Godot 4.3 static typing — the entire gate is dead**
- **Constructs (all in `tests/stage1_defeat_cutscene_test.gd`):**
  - `var cutscene: CanvasLayer = CUTSCENE.new()` (in both `_run_without_player()` and `_run_with_player()`), followed by `cutscene.play()` and `await cutscene.finished` — `play()` and `finished` are not members of `CanvasLayer`. Hard parse errors: "Function 'play()' not found in base 'CanvasLayer'" / "Cannot find member 'finished' in base 'CanvasLayer'".
  - `var player: CharacterBody2D = preload("res://src/player/player.tscn").instantiate()`, followed by `player.current_outfit` — not a member of `CharacterBody2D`. Hard parse error.
- **Failure scenario:** always, on load. GDScript resolves members against the *declared* type; annotating with the base class hides the script's own methods/signals. The scene won't instantiate, so none of the failure-safety checks can ever run. Note `auditor.gd` itself is fine — it uses `:=`, which infers `Stage1BossDefeatCutscene` from the preload.
- **Severity: HIGH (test-only)** — no shipped-code impact, but this is the only automated net over a sequence class this project has repeatedly shipped freezes in, and as written it can never pass. Fix: `var cutscene := CUTSCENE.new()` (or `: Stage1BossDefeatCutscene`) and `var player := ...` (or `: Player`).

## Questions with no findings

**Q1 — can `finished` be lost with the deadline also failing? No.** Traced: the deadline is a `SceneTreeTimer` owned by the SceneTree, not the node, created with `process_always=true, ignore_time_scale=true`. It lives in the tree's timer list and is completely independent of `_run()`'s coroutine state — if `_run()` aborts at any runtime error (GDScript aborts the function, not the frame loop), nothing cancels the timer, and at t=14s it calls `_finish()` → emit → free. The only way the deadline becomes a no-op is the cutscene node being freed first (connections to freed objects are auto-removed), and the only free path in the shown code is `_finish()` itself, which emits *before* `queue_free()`. An external free (scene reload tearing down `current_scene`) would also free the Auditor, killing its coroutine — no dangling awaiter. Also verified: no missed-signal race — `auditor.die()` registers `await cutscene.finished` synchronously after `play()` with no yield in between, and the earliest possible emission is seconds later.

**Q2 — double-emit/double-free race past `_done`? No.** Single-threaded (doubly so on non-threaded HTML5): there is no `await` between the `_done` check and `_done = true`, so `_finish` cannot be re-entered in that window, and `_done` is set *before* `finished.emit()`, so even synchronous re-entry from a signal handler hits the guard. `queue_free()` called twice in a frame is a no-op the second time. Nominal completion is ~8.4s vs the 14s deadline; even a pathological hitch that fires the deadline and `_run()`'s final timer in the same frame is serialized through the guard.

**Q3 — `_shaft.pivot_offset = Vector2(60, 0)`: inert, no defect.** `pivot_offset` only sets the transform origin for `rotation`/`scale`. `_shaft` is only ever tweened on `size`, which grows the rect from its position corner and never consults the pivot. It's dead code, not a visual or layout bug.

**Q4 — mid-sequence player lookup: guard is sufficient.** `get_first_node_in_group()` returns `null` when the group is empty, and freed nodes are removed from groups at free time, so it cannot hand back a dangling instance — `is_instance_valid` covers absence, `has_method` covers a wrong-type node. There is no `await` between the guard and the `set_outfit` call, so no check-to-use window exists. If the whole scene reloads before beat 3, the cutscene (a child of `current_scene`) is freed with it and the line never executes against a stale tree. No gap found.

**Q5 — other API usage: clean.** `"color:a"` / `"modulate:a"` are valid Color-channel subpaths (same pattern already shipped in `auditor.gd`); `.set_trans().set_ease()` chains correctly on `tween_property()`'s `PropertyTweener` return; `create_timer(t, true, false, true)` argument order matches the project idiom; `_pickaxe` and `_shaft` are guarded on every interrupted-path read and `_tint` is built unconditionally first. The only defect in this category is #1 above.

---

## Claude's verification (per the multi-model-orchestrator "verify before believing" rule)

**Defect #1: CONFIRMED, already fixed before this PR was opened.** Caught
independently in a self-review pass before dispatching this audit; the
committed `stage1_boss_defeat_cutscene.gd` already has the two-clause guard
`is_instance_valid(_pickaxe) and is_instance_valid(_miner_portrait)` at the
line Kimi flagged. Good convergent signal — an independent audit reaching
the same defect is exactly the value this dispatch is for.

**Defect #2: REJECTED — factually wrong, and the proposed "fix" would
reintroduce a real bug.** Kimi claims `var cutscene: CanvasLayer =
CUTSCENE.new()` followed by `cutscene.play()` / `await cutscene.finished`
is a hard GDScript parse error ("Function 'play()' not found in base
'CanvasLayer'"). This is empirically false: the exact committed test file
was run headless twice (once on the `nightly/hardening-2026-09-02` base,
once after restarting the branch from current `origin/master`) and both
runs printed all six real, computed PASS results — including
`player.current_outfit == Player.Outfit.MINER`, which can only be true if
`cutscene.play()` actually executed the full sequence and
`player.current_outfit` actually read back correctly. A hard parse error
would prevent the script from loading at all (confirmed separately: an
*actual* parse error earlier in this same session, from using the freshly
added `class_name Stage1BossDefeatCutscene` as a static type before Godot's
global class cache had indexed it, produced literal
`SCRIPT ERROR: Parse Error: Could not find type "..." in the current scope`
and the test hung with zero output — a completely different failure
signature from what shipped). GDScript 4.3 does not statically closed-world
type-check calls against a variable typed to a builtin engine base class
(`CanvasLayer`, `CharacterBody2D`) when the actual instance carries a script
— it dispatches dynamically at runtime, which is exactly why typing by base
class (the fix for the REAL parse error above) works. Kimi's suggested "fix"
— re-annotating with the custom class name — is the literal thing that
caused the actual bug earlier in this session; applying it would not fix
anything and would risk reintroducing a real failure. No change made to the
test file.