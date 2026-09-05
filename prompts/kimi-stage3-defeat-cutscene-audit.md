# Code audit: Stage 3 FINAL boss-defeat cutscene wiring (Episode 1 close)

## What the game is

Lil Blunt Adventure, Godot 4.3, 2D platformer, web-exported (non-threaded
HTML5). I've shipped two equivalent cutscenes already (PR #63): Stage 1
(one real null-safety gap found and fixed, one false Kimi finding rejected
with empirical evidence) and Stage 2 (clean audit, zero findings — every
cross-node interaction guarded on both sides from the start). This is the
third and richest: the FINAL boss (Claim Jumper, boss_id "bandit") defeated,
closing Episode 1. Same historical bug classes to hunt: a collider enabled
during shrink-to-zero, a coroutine awaiting a signal on a node that frees
itself first, a SceneTreeTimer missing process_always, a two-node tween
guarded on only one side.

## What exists right now

### The insertion point in `src/boss/bandit_boss.gd` (full relevant tail of `die()`)

```gdscript
func die() -> void:
	is_dead = true
	set_physics_process(false)
	GameManager.add_score(2000)
	ScreenShake.shake(0.8, 12.0)
	hitbox.monitorable = false
	hitbox.monitoring = false
	StateMachine.change_state(StateMachine.State.LEVEL_COMPLETE)
	ScreenShake.zoom_to(1.0, 0.6)
	ScreenShake.heavy()
	GameManager.save_session()
	if is_instance_valid(health_bar):
		health_bar.queue_free()
	health_bar = null
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 1.0)
	tween.parallel().tween_property(self, "rotation", PI * 4, 1.0)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 1.0)
	await tween.finished
	var cutscene := preload("res://src/level/stage3_boss_defeat_cutscene.gd").new()
	get_tree().current_scene.add_child(cutscene)
	cutscene.play()
	await cutscene.finished
	SceneRouter.load_scene("res://src/ui/main_menu.tscn", SceneRouter.Transition.DIAMOND)
	queue_free()
```

Note the tail order: `SceneRouter.load_scene()` happens BEFORE `queue_free()`
here (this project's Distributor boss does the opposite order, per its own
Kimi-audit comment about "free BEFORE the scene load" for a *mid-level*
transition) — this is deliberate and pre-existing, not something the
cutscene touches: this is the LAST level, routing to the main menu, not to
another in-game scene, so the ordering concern that applies to a same-game
scene swap doesn't apply here. Do not flag this ordering as a defect unless
you can show a concrete failure mode specific to routing to the main menu.

`StateMachine.change_state(LEVEL_COMPLETE)` happens before any of this UI
work, and `player.gd`'s `_physics_process` returns immediately unless
`StateMachine.is_playing()` — player input has been frozen since well
before the cutscene starts.

### The new file, `src/level/stage3_boss_defeat_cutscene.gd` (complete)

@include src/level/stage3_boss_defeat_cutscene.gd

### The gate, `tests/stage3_defeat_cutscene_test.gd` (complete)

@include tests/stage3_defeat_cutscene_test.gd

## Engine facts you must not "correct"

- `get_tree().create_timer(t, true, false, true)` is this project's
  hardened idiom.
- `CanvasLayer` children render in that layer's own screen-space transform.
- `AudioManager.play_voice(id)` is a pre-existing autoload method; assume it
  exists and no-ops safely on a missing file.
- Static typing a variable as a builtin engine base class (`CanvasLayer`)
  while assigning it a script-subclass instance dispatches dynamically at
  runtime in GDScript 4.3 — not an error. (A prior Kimi dispatch on Stage 1
  incorrectly flagged this as a hard parse error; it was empirically
  disproven by running the exact committed file twice. Do not re-assert it.)
- `Tween.set_loops(n)` is a valid PropertyTweener/Tween chain method in
  Godot 4.3 for repeating a tween sequence n times.

## The actual question

1. `_pop_fuse_warning()` uses `pulse.set_loops(4)` on a tween with two
   sequential `tween_property` calls (scale up, scale down). Trace: does
   this tween get explicitly killed/cleaned up anywhere before the cutscene
   frees `_fuse` in `_wreck_cart()`? If not, what actually happens to a
   still-looping Tween when its target node (`_fuse`) is freed mid-loop —
   does Godot handle that safely, or is this a real defect?
2. Every `is_instance_valid` guard in the file — confirm each two-node
   tween interaction (the `hook`/`_lever`+`_pickaxe` pair in beat 2, the
   `descend_cart`/`_shaft`+`_exit_cart` pair and `descend_rider`/`_shaft`+
   `_miner_portrait` pair in beat 4) guards BOTH sides, not just one — this
   is the exact class of gap Stage 1 shipped with.
3. `_throw_btc_tokens()` returns an `Array` of possibly-empty or
   possibly-invalid Sprite2D refs (empty if `BTC_TEX` is missing). The
   caller does `for t in tokens: if is_instance_valid(t): t.queue_free()`
   — confirm this is safe against an empty array and against a token that
   already freed itself via its own tween (it doesn't have a
   self-queue_free callback in this file — verify that's actually true by
   reading `_throw_btc_tokens()` again, don't assume).
4. Can `finished` ever fail to emit, independent of the hard-deadline timer
   saving it? Same trace as before: does the deadline timer survive an
   early abort of `_run()`?
5. Double-emit/double-free race on `_done` — same question as the prior two
   audits.
6. Any GDScript 4.3 API misuse: `Vector2 / float` for `pivot_offset`,
   `randf_range`/`deg_to_rad`/`cos`/`sin` global functions, tween chaining,
   property subpaths (`"color:a"`, `"modulate:a"`, `"position:y"`).

## Hard constraints

- Do not propose changing `bandit_boss.gd`'s existing tween, scoring, or
  the final `SceneRouter.load_scene()` + `queue_free()` tail — only the
  cutscene insertion between the tween and that tail is in scope.
- Do not propose a rendered video — same reasoning as Stage 1/2.
- Do not propose inventing a Stage 4 — there isn't one; routing to the main
  menu is correct.

## Output format

A numbered list of real defects only. For each: exact line/construct, the
failure scenario, and severity (CRITICAL/HIGH/MEDIUM/LOW). If a question
above finds nothing, say so explicitly rather than inventing a finding.
