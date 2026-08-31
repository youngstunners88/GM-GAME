extends Node2D
## Session-4 T6 — dying in Stage 3 must respawn Lil Blunt AT / NEAR where he
## died, never at a coordinate belonging to a different level.
##
## Founder (session 4): "when I die in level 3 he appears somewhere else!!!
## He must reappear exactly or close to where he died."
##
## Root cause: `_respawn_or_game_over()` used to fall back to
## `get_checkpoint(1)` (a LEVEL-1 coordinate) whenever the current level had no
## checkpoint yet — dropping the player at a Level-1 spot inside the Level-3
## scene. The fix removes the cross-level fallback and respawns at the last
## safe grounded sample near the death instead.
##
## This gate is written to FAIL on the pre-fix behaviour: it seeds a Level-1
## checkpoint at a coordinate FAR from the Stage-3 death, gives the current
## level (3) NO checkpoint, and asserts the respawn lands near the death, not
## on the Level-1 coordinate.
##
## Run: godot --headless res://tests/s4_respawn_near_death_test.tscn

const PLAYER := preload("res://src/player/player.tscn")

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("SESSION 4 RESPAWN NEAR DEATH:")
	await _test_respawn_lands_near_death_not_other_level()
	print("S4_RESPAWN_NEAR_DEATH: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _test_respawn_lands_near_death_not_other_level() -> void:
	# Arrange a Stage-3 death with no Stage-3 checkpoint and a decoy Level-1
	# checkpoint far away (the source of the old cross-level teleport).
	GameManager.current_level = 3
	GameManager.clear_checkpoint(3)
	var level1_decoy := Vector2(200.0, 520.0)
	GameManager.save_checkpoint(1, 1, level1_decoy)
	GameManager.lives = 5  # plenty, so lose_life() takes the respawn branch
	GameManager.max_health = 3

	var death_pos := Vector2(2500.0, 640.0)  # deep in the Stage-3 arena
	var player: Node = PLAYER.instantiate()
	add_child(player)
	await get_tree().process_frame
	player.global_position = death_pos
	# Seed the safe-position samplers as if he had been walking the Stage-3 floor.
	player.set("_prev_safe_position", death_pos)
	player.set("_last_safe_position", death_pos)

	player.call("_respawn_or_game_over")
	await get_tree().process_frame

	var respawn: Vector2 = player.global_position
	var dist_to_death := respawn.distance_to(death_pos)
	var dist_to_decoy := respawn.distance_to(level1_decoy)

	_check("respawn lands NEAR the Stage-3 death position (<= 60px)",
		dist_to_death <= 60.0,
		"respawned at %s, %dpx from death %s" % [str(respawn), int(dist_to_death), str(death_pos)])
	_check("respawn does NOT teleport to the Level-1 checkpoint (cross-level bug)",
		dist_to_decoy > 400.0,
		"respawned only %dpx from the Level-1 decoy %s — the cross-level fallback returned" % [int(dist_to_decoy), str(level1_decoy)])

	player.queue_free()
	GameManager.clear_checkpoint(1)
	GameManager.clear_checkpoint(3)
	await get_tree().process_frame
