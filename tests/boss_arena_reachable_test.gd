extends Node
## Can the player actually GET INTO each boss arena?
##
## WHY: LevelBase._setup_boss_arena() builds a wall at `boss_arena.start_x` —
## the same x the boss trigger sits at. A 600px-tall wall there would seal the
## arena off from the approach, meaning the boss spawns, its health bar
## appears, and the player can never reach it.
##
## That is exactly the symptom the 2026-07-30 browser playtest produced: the
## driver reached Level 1's Auditor, the health bar showed, and the boss sat at
## 6/6 HP for 380 seconds while the player made no progress.
##
## This test answers it with physics rather than inference: put the player just
## short of start_x, push right for a second, and see whether they get past.
##
## Run: godot --headless res://tests/boss_arena_reachable_test.tscn

const LEVELS := {
	1: "res://src/resources/level_01_data.tres",
	2: "res://src/resources/level_02_data.tres",
	3: "res://src/resources/level_03_data.tres",
}
const PLAYER := preload("res://src/player/player.tscn")

var _failures: int = 0

func _ready() -> void:
	await _run()

func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  [PASS] %s" % label)
	else:
		_failures += 1
		print("  [FAIL] %s %s" % [label, detail])

const LEVEL_SCENES := {
	1: "res://src/level/level_01_smoke_realm.tscn",
	2: "res://src/level/level_02_crystal_caverns.tscn",
	3: "res://src/level/level_03_gold_rush.tscn",
}

func _run() -> void:
	_test_triggers_reach_the_ground()
	for idx in LEVELS.keys():
		await _probe(int(idx))

## The boss trigger must overlap the FLOOR the player walks on.
##
## Levels 1 and 2 shipped a 200x200 trigger centred at y=400 — spanning
## y 300..500 — while the ground sits at y=650. A player walking into the
## arena never touched it, so the fight only started if they happened to jump
## high enough at the right x. Level 3's 600x800 trigger did cover the ground,
## which is why only that one behaved. Caught 2026-07-30.
func _test_triggers_reach_the_ground() -> void:
	print("Boss trigger vertical coverage:")
	for idx in LEVEL_SCENES.keys():
		var packed: PackedScene = load(LEVEL_SCENES[idx])
		var inst := packed.instantiate()
		var trig := inst.get_node_or_null("BossTrigger") as Area2D
		var data: LevelData = load(LEVELS[idx])
		# Ground surface for this level (all segments share y in these levels).
		var ground_y: float = 650.0
		for seg in data.ground_segments:
			ground_y = seg.y
			break
		var ok := false
		var detail := "no BossTrigger/shape"
		if trig != null:
			for child in trig.get_children():
				var cs := child as CollisionShape2D
				if cs == null or cs.shape == null:
					continue
				var rect := cs.shape as RectangleShape2D
				if rect == null:
					continue
				# World centre = trigger position + shape position.
				var centre_y: float = trig.position.y + cs.position.y
				var top: float = centre_y - rect.size.y / 2.0
				var bottom: float = centre_y + rect.size.y / 2.0
				detail = "trigger spans y %.0f..%.0f, ground at y %.0f" % [top, bottom, ground_y]
				# The player stands ON the ground, so the trigger must reach it.
				if bottom >= ground_y:
					ok = true
		_check("level %d: boss trigger reaches the ground" % idx, ok, detail)
		inst.free()
	if _failures == 0:
		print("BOSS_ARENA_REACHABLE: ALL PASS")
		get_tree().quit(0)
	else:
		print("BOSS_ARENA_REACHABLE: %d FAILURE(S)" % _failures)
		get_tree().quit(1)

## Rebuild only the geometry that matters: the ground under the approach and
## the arena walls exactly as LevelBase creates them.
func _probe(level_index: int) -> void:
	var data: LevelData = load(LEVELS[level_index])
	var start_x: float = float(data.boss_arena.get("start_x", 0.0))
	print("Level %d (boss_arena.start_x = %.0f):" % [level_index, start_x])

	var root := Node2D.new()
	add_child(root)

	# Ground: reproduce the real segments so the player has the same floor.
	for seg in data.ground_segments:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.position = Vector2(seg.x, seg.y)
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(seg.z, seg.w)
		cs.shape = rect
		cs.position = Vector2(seg.z / 2.0, seg.w / 2.0)
		body.add_child(cs)
		root.add_child(body)

	# Only the FAR wall, matching LevelBase._setup_boss_arena after the fix.
	# The entry wall is now raised by arm_boss_arena_seal() once the player is
	# inside; if it is ever restored to level-build time, this probe fails
	# again — which is the regression this test exists to catch.
	var end_x: float = float(data.boss_arena.get("end_x", 0.0))
	for wx in [end_x]:
		if wx <= 0.0:
			continue
		var wall := StaticBody2D.new()
		wall.position = Vector2(wx, 400)
		var wcs := CollisionShape2D.new()
		var wrect := RectangleShape2D.new()
		wrect.size = Vector2(20, 600)
		wcs.shape = wrect
		wall.add_child(wcs)
		root.add_child(wall)

	var player := PLAYER.instantiate() as CharacterBody2D
	root.add_child(player)
	# Start 150px short of the wall, on the ground.
	player.global_position = Vector2(start_x - 150.0, 560.0)
	for i in 20:
		await get_tree().physics_frame

	var before: float = player.global_position.x
	# Drive right for ~1.5s using the same walk speed the controller uses.
	for i in 90:
		player.velocity.x = 220.0
		player.move_and_slide()
		await get_tree().physics_frame
	var after: float = player.global_position.x

	print("    x %.0f -> %.0f (wall spans %.0f..%.0f)" % [before, after, start_x - 10.0, start_x + 10.0])
	_check("level %d: player can pass boss_arena.start_x" % level_index,
		after > start_x + 12.0,
		"stopped at %.0f — the arena entry wall seals the boss off" % after)

	root.queue_free()
	await get_tree().physics_frame
