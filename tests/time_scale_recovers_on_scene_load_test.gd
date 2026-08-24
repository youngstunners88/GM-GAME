extends Node
## Founder, 2026-08-23 (2nd occurrence): "After big mode on Stage 3 the game is
## completely frozen while the music continues."
##
## Root cause: player.gd::_hitstop and axe.gd::_boss_hitstop set the GLOBAL
## Engine.time_scale = 0.05 and only restore it on the line AFTER an `await`.
## On Stage 3 a boss touch is boss_contact_restart() -> SceneRouter.load_scene,
## which frees the player/axe mid-await, so the restore never runs and
## time_scale stays pinned at 0.05 ACROSS the reload — physics at 5% (looks
## frozen) while audio (unaffected) plays on ("music continues").
##
## Fix: SceneRouter.load_scene resets Engine.time_scale = 1.0 at the top, so a
## stranded hitstop self-heals on the very next load. This gate reproduces the
## exact stranded state and asserts recovery. Also verifies the value is sane
## after a normal load (not left at some other scale).
##
## Run: godot --headless res://tests/time_scale_recovers_on_scene_load_test.tscn

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	await get_tree().process_frame
	print("TIME SCALE RECOVERS ON SCENE LOAD:")

	# Simulate a hitstop that got stranded (its awaiting node was freed before
	# it could restore) — the exact global state the freeze leaves behind.
	Engine.time_scale = 0.05
	_check("precondition: time_scale is stranded at 0.05", is_equal_approx(Engine.time_scale, 0.05))

	# A boss-contact restart / any transition goes through SceneRouter.load_scene.
	SceneRouter.load_scene("res://src/level/level_01_smoke_realm.tscn", SceneRouter.Transition.FADE)
	# load_scene resets time_scale on its FIRST line, before any await.
	await get_tree().process_frame

	_check("SceneRouter.load_scene restores real time (time_scale == 1.0)",
		is_equal_approx(Engine.time_scale, 1.0),
		"time_scale still %.3f after a scene load — the freeze would persist" % Engine.time_scale)

	print("TIME_SCALE_RECOVERS: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	Engine.time_scale = 1.0
	get_tree().quit(_fail)
