extends Node
## S-DUAL — REAL-LEVEL boss-chase reproduction.
##
## Every prior boss-chase gate spawned the boss in a SYNTHETIC arena with
## hand-picked bounds. The founder keeps reporting "doesn't move / doesn't
## chase" LIVE anyway. This test closes that gap: it loads the ACTUAL
## level_02 / level_03 scenes, fires the REAL `_on_boss_trigger` path (the same
## one the ?boss=N warp and a walked-in player use — real arena bounds from the
## level's own boss_arena, set on the boss before add_child), then teleports the
## player to one wall, holds, teleports to the other wall, and logs the boss's
## x each step. If the boss tracks the player across the arena, the chase works
## in the real context; if its x barely changes, we have finally reproduced the
## live "frozen" report in a headless gate.
##
## Run: godot --headless res://tests/dual_real_level_boss_chase_test.tscn

const LEVELS := {
	"level_02": "res://src/level/level_02_crystal_caverns.tscn",
	"level_03": "res://src/level/level_03_gold_rush.tscn",
}

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	for key: String in LEVELS:
		await _probe(key, LEVELS[key])
	print("DUAL_REAL_LEVEL_BOSS_CHASE: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _probe(label: String, scene_path: String) -> void:
	print("\n=== %s (%s) ===" % [label, scene_path])
	if not ResourceLoader.exists(scene_path):
		_fail += 1
		print("  [FAIL] scene missing: %s" % scene_path)
		return
	var level: Node = load(scene_path).instantiate()
	add_child(level)
	# Let the level build its geometry, player, and boss trigger.
	for _i in range(8):
		await get_tree().process_frame

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		_fail += 1
		print("  [FAIL] no player spawned")
		level.queue_free()
		await get_tree().process_frame
		return

	# Read the level's own arena bounds and fire the real trigger path.
	var arena: Dictionary = level.level_data.boss_arena
	var start_x: float = float(arena.get("start_x", 0.0))
	var end_x: float = float(arena.get("end_x", 0.0))
	print("  arena: start_x=%.0f end_x=%.0f width=%.0f" % [start_x, end_x, end_x - start_x])
	# Place player just inside the arena (as the warp does) and trigger.
	player.global_position = Vector2(start_x + 120.0, player.global_position.y)
	if not level.has_method("_on_boss_trigger"):
		_fail += 1
		print("  [FAIL] level has no _on_boss_trigger")
		level.queue_free()
		await get_tree().process_frame
		return
	level._on_boss_trigger(player)
	for _i in range(4):
		await get_tree().process_frame

	var boss := get_tree().get_first_node_in_group("boss") as Node2D
	if boss == null:
		_fail += 1
		print("  [FAIL] no boss spawned after trigger")
		level.queue_free()
		await get_tree().process_frame
		return
	print("  boss=%s  arena_min=%s arena_max=%s" % [boss.name, str(boss.get("arena_min")), str(boss.get("arena_max"))])

	# MEASUREMENT ONLY: silence the contact hitbox so the boss reaching the
	# player never fires boss_contact_restart (which reloads the level and would
	# invalidate our refs mid-run). We are gating the CHASE, not contact.
	var hb := boss.get_node_or_null("Hitbox")
	if hb != null:
		hb.set_deferred("monitoring", false)

	# Drive the player wall-to-wall and sample the boss x after each dwell.
	# West wall, hold ~1.5s; east wall, hold ~1.5s; west again.
	var west_x: float = start_x + 140.0
	var east_x: float = end_x - 140.0
	var samples: Array = []
	for target_x: float in [west_x, east_x, west_x]:
		# Pin the player at the target so the boss has a clear, static goal.
		for _f in range(150):  # ~2.5s at 60fps — room to cross the arena
			if is_instance_valid(player):
				player.global_position.x = target_x
			await get_tree().physics_frame
		if not is_instance_valid(boss):
			break
		var bx: float = boss.global_position.x + 140.0  # approx body centre
		samples.append({"player_x": target_x, "boss_cx": bx})
		print("    player pinned x=%.0f -> boss centre x=%.0f (dx=%.0f)" % [target_x, bx, target_x - bx])

	# The boss must MOVE meaningfully between the west dwell and the east dwell.
	# A boss that "doesn't chase" would show near-identical boss_cx at both.
	if samples.size() >= 2:
		var travel: float = absf(samples[1]["boss_cx"] - samples[0]["boss_cx"])
		# Reachable centre band is arena_width - BODY (~420-460px). Require the
		# boss to cross at least a third of it when the player jumps wall-to-wall.
		var pass_bar: float = 120.0
		if travel >= pass_bar:
			print("  [PASS] boss tracked the player across the arena (travel=%.0fpx >= %.0f)" % [travel, pass_bar])
		else:
			_fail += 1
			print("  [FAIL] boss barely moved (travel=%.0fpx < %.0f) — reproduces 'doesn't chase'" % [travel, pass_bar])

	level.queue_free()
	await get_tree().process_frame
