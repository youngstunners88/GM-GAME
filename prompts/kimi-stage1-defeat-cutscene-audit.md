# Code audit: Stage 1 boss-defeat cutscene wiring

## What the game is

Lil Blunt Adventure, Godot 4.3, 2D platformer, web-exported (non-threaded
HTML5). This project has a long, expensive history of shipped freeze/soft-lock
bugs in exactly this kind of scripted sequence:

- A collider left ENABLED while its node was mid-shrink-to-zero (a
  disabled-body zero-scale freeze).
- A coroutine that `await`s a signal on a node, then that node frees itself
  before the signal ever fires — the coroutine hangs forever.
- A `SceneTreeTimer` created without `process_always=true` that silently never
  fires once the game is paused/frozen.
- State flags (`_climbing`, `_dying`, etc.) set true and never cleared on every
  exit path, stranding the player.

I just wired a new ~8-second in-engine cutscene into `Auditor.die()` (the
Stage 1 boss), between its existing death tween and the `victory_screen.tscn`
hand-off. Hunt specifically for the bug classes above, in this new code.

## What exists right now (paste of the actual files, not a description)

### The insertion point in `src/boss/auditor.gd` (full `die()` function)

```gdscript
func die() -> void:
	current_state = State.DEFEATED
	if _health_bar:
		_health_bar.queue_free()
		_health_bar = null
	BossVoiceSystem.say(self, BOSS_ID, "death", true)
	BossVoiceSystem.clear_active()
	GameManager.add_score(500)
	ScreenShake.shake(0.5, 8.0)
	hitbox.monitorable = false
	hitbox.monitoring = false
	StateMachine.change_state(StateMachine.State.LEVEL_COMPLETE)
	Web3Bridge.report_event("boss_defeat", {
		"boss": "tax", "score": GameManager.total_score, "first_time": true})
	var lvl := get_tree().current_scene
	if lvl != null and "level_start_ms" in lvl:
		Web3Bridge.report_metric("level_complete", {
			"seconds": (Time.get_ticks_msec() - int(lvl.level_start_ms)) / 1000})
	ScreenShake.zoom_to(1.0, 0.6)
	AudioManager.play_voice("victory")
	ScreenShake.heavy()
	GameManager.save_session()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 1.0)
	tween.parallel().tween_property(self, "rotation", PI * 4, 1.0)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 1.0)
	await tween.finished
	var cutscene := preload("res://src/level/stage1_boss_defeat_cutscene.gd").new()
	get_tree().current_scene.add_child(cutscene)
	cutscene.play()
	await cutscene.finished
	var victory := preload("res://src/ui/victory_screen.tscn").instantiate()
	victory.setup(GameManager.total_score, 1)
	get_tree().current_scene.add_child(victory)
	queue_free()
```

Key existing facts: `current_state = State.DEFEATED` and
`StateMachine.change_state(LEVEL_COMPLETE)` both happen at the very top,
BEFORE any of this runs. `player.gd`'s `_physics_process` returns immediately
unless `StateMachine.is_playing()`, so player input has been frozen since the
top of `die()` — the cutscene doesn't need to freeze anything itself, it's
already inside a frozen window that the original code already relied on for
its own 1-second tween.

### The new file, `src/level/stage1_boss_defeat_cutscene.gd` (complete)

@include src/level/stage1_boss_defeat_cutscene.gd

### The gate that exercises it, `tests/stage1_defeat_cutscene_test.gd` (complete)

@include tests/stage1_defeat_cutscene_test.gd

## Engine facts you must not "correct"

- Godot 4.3. `get_tree().create_timer(t, true, false, true)` is this
  project's own hardened idiom (process_always, ignore-physics-only,
  ignore-time-scale) — already used in `player.gd`, `distributor.gd`,
  `auditor.gd` elsewhere. Not a bug if you see it; it's the fix for a
  documented prior bug class.
- `CanvasLayer` children that are `Control`/`Node2D`/`Sprite2D` all render in
  that layer's own screen-space transform (identity by default) — this
  cutscene is deliberately screen-space only and never touches the live
  player's world position/camera.
- `AudioManager.play_voice(id)` is an existing autoload method (not shown —
  trust it exists and is safe to call with an arbitrary id; it no-ops if the
  file is missing).
- `Player.Outfit.MINER` and `player.set_outfit()` are pre-existing, already
  used identically by `level_02_crystal_caverns.gd`.

## The actual question

1. Does `_run()` have any path where `finished` is never emitted and the
   hard-deadline timer also fails to save it? (E.g., does connecting
   `get_tree().create_timer(...).timeout.connect(_finish)` at the top of
   `play()`, before `_run()` is even called, actually survive if `_run()`
   throws partway through? Trace it.)
2. Is there a double-`queue_free()` / double-`finished.emit()` risk anywhere
   given `_finish()`'s `_done` guard — specifically: can the hard-deadline
   timer and the normal end-of-`_run()` path both fire in the same frame in a
   way that races past the guard?
3. `_shaft.pivot_offset = Vector2(60, 0)` is set on a `ColorRect` whose `size`
   starts at `Vector2.ZERO` and is only ever tweened via `size`, never
   `scale`/`rotation` — is `pivot_offset` doing anything here, and is it
   capable of causing a visual or layout bug (not just "unnecessary")?
4. `get_tree().get_first_node_in_group("player")` is called mid-sequence
   (beat 3). If the scene were ever reloaded or the player removed between
   `play()` being called and that line executing, what actually happens —
   confirm the `is_instance_valid` + `has_method` guard is sufficient, or
   name the gap if not.
5. Any GDScript 4.3 API misuse: invalid property-subpath strings
   (`"color:a"`), tween chaining (`.set_trans().set_ease()` on
   `tween_property()`'s return value), or a variable used before assignment
   on an interrupted path (e.g. `_pickaxe`/`_miner_portrait`/`_shaft` read in
   a later beat when an earlier beat's `ResourceLoader.exists()` check
   returned false and skipped creating it).

## Hard constraints

- Do not propose changing `auditor.gd`'s existing tween, VO, telemetry, or
  `victory_screen` hand-off — only the two new lines that insert the cutscene
  between them are in scope.
- Do not propose new external assets or a rendered video — this is
  intentionally an in-engine sequence (Godot 4.3 HTML5 export only plays
  Ogg Theora, and this project's one existing video use ships muted for that
  reason — a movie file is not a safe way to ship this dialogue).

## Output format

A numbered list of real defects only (skip anything not concretely
demonstrable from the code shown). For each: exact line/construct, the
failure scenario (what input/timing triggers it), and severity
(CRITICAL/HIGH/MEDIUM/LOW using this project's own bug-pattern-scan.sh
scale). If you find nothing in a question above, say so explicitly rather
than inventing a finding — a clean audit is a valid result.
