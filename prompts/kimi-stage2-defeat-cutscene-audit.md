# Code audit: Stage 2 boss-defeat cutscene wiring

## What the game is

Lil Blunt Adventure, Godot 4.3, 2D platformer, web-exported (non-threaded
HTML5). I already shipped an equivalent Stage 1 cutscene (PR #63) with the
same architecture; you (or a prior Kimi K3 dispatch) audited that one and
found two things: (1) a real null-safety gap in a two-node tween that had
already been self-caught and fixed, and (2) a claimed "hard parse error" in
the test file's base-class typing that turned out to be FALSE — the exact
committed test ran twice and printed genuine computed PASS results both
times, which a parse error cannot produce. I'm telling you this up front so
you don't re-assert that same false claim about static typing on a builtin
base class holding a script instance — GDScript 4.3 dispatches such calls
dynamically at runtime; it does not hard-error.

This is the SAME class of scripted sequence — this project has a long,
expensive history of shipped freeze/soft-lock bugs in exactly this pattern
(a collider left enabled during a shrink-to-zero; a coroutine awaiting a
signal on a node that frees itself first; a SceneTreeTimer missing
process_always that never fires once frozen; a two-node tween where only
one side is guarded valid). Hunt specifically for those classes in the NEW
code below.

## What exists right now

### The insertion point in `src/boss/distributor.gd` (full relevant tail of `die()`)

```gdscript
func die() -> void:
	is_dead = true
	BossVoiceSystem.say(self, BOSS_ID, "death", true)
	BossVoiceSystem.clear_active()
	set_physics_process(false)
	get_tree().call_group("boss_projectile", "queue_free")
	for prism in _prisms:
		if is_instance_valid(prism):
			prism.queue_free()
	_prisms.clear()
	GameManager.add_score(1000)
	ScreenShake.shake(0.6, 10.0)
	hitbox.set_deferred("monitorable", false)
	hitbox.set_deferred("monitoring", false)
	StateMachine.change_state(StateMachine.State.LEVEL_COMPLETE)
	ScreenShake.zoom_to(1.0, 0.6)
	AudioManager.play_voice("victory")
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
	var cutscene := preload("res://src/level/stage2_boss_defeat_cutscene.gd").new()
	get_tree().current_scene.add_child(cutscene)
	cutscene.play()
	await cutscene.finished
	queue_free()
	SceneRouter.load_scene(GameManager.next_level_scene(2), SceneRouter.Transition.DIAMOND)
```

Key existing facts: `StateMachine.change_state(LEVEL_COMPLETE)` happens
before any of this UI/cutscene work, and `player.gd`'s `_physics_process`
returns immediately unless `StateMachine.is_playing()` — player input has
been frozen since well before the cutscene starts, exactly like Stage 1.

### The new file, `src/level/stage2_boss_defeat_cutscene.gd` (complete)

@include src/level/stage2_boss_defeat_cutscene.gd

### The gate, `tests/stage2_defeat_cutscene_test.gd` (complete)

@include tests/stage2_defeat_cutscene_test.gd

## Engine facts you must not "correct"

- `get_tree().create_timer(t, true, false, true)` is this project's
  hardened idiom (process_always, ignore-physics-only, ignore-time-scale).
- `CanvasLayer` children (`ColorRect`, `Sprite2D`) render in that layer's
  own screen-space transform — no world-space actors are touched.
- `AudioManager.play_voice(id)` is a pre-existing autoload method; assume it
  exists and no-ops safely on a missing file.
- Static typing a variable as a builtin engine base class (`CanvasLayer`)
  while assigning it a script-subclass instance is fine in GDScript 4.3 —
  method/signal access on it dispatches dynamically. Do not flag this as an
  error; see the note above.

## The actual question

1. In `_run()`, is there ANY point where a coroutine could throw on a null
   dereference because one side of a two-node interaction (or a tween
   target) isn't validity-checked? List every `is_instance_valid` call
   present and confirm each risky read is actually covered — including
   inside `_shatter_boss()`'s loop and `_reveal_vault_door()`'s tween.
2. Can `finished` ever fail to emit, independent of the hard-deadline timer
   saving it? Trace whether the deadline timer (`get_tree().create_timer`
   connected before `_run()` is called) truly survives an early abort of
   `_run()`.
3. `_shatter_boss()` creates 10 short-lived `ColorRect` nodes each with
   their own `Tween` and a `tween_callback(piece.queue_free)`. Given this
   project's own documented gotcha about creating/freeing many short-lived
   physics objects in a tight loop crashing Godot 4.3 outright (see
   `docs/engine-reference/godot/gdscript-gotchas.md` #2 if you can infer its
   shape from context) — does this construct (non-physics `ColorRect`s, not
   `Area2D`/`CollisionShape2D`) fall into that same crash class, or is it a
   different, safe pattern? Be specific about why.
4. Double-emit/double-free race on `_finish()`'s `_done` guard, same
   question as last time: can the hard-deadline timer and the normal
   `_run()` completion both fire in the same frame in a way that races past
   the guard?
5. Any GDScript 4.3 API misuse: invalid property-subpath strings, tween
   chaining, `Vector2 / float` division for `pivot_offset`, `randf_range` /
   `deg_to_rad` global function usage.

## Hard constraints

- Do not propose changing `distributor.gd`'s existing tween, VO, scoring,
  or the final `queue_free()` + `SceneRouter.load_scene()` call — only the
  cutscene insertion between the tween and that final pair is in scope.
- Do not propose a rendered video — same reasoning as Stage 1 (muted-only
  Ogg Theora on this project's web export).

## Output format

A numbered list of real defects only. For each: exact line/construct, the
failure scenario, and severity (CRITICAL/HIGH/MEDIUM/LOW). If a question
above finds nothing, say so explicitly rather than inventing a finding.
