extends Node
## THE GATE THAT WOULD HAVE CAUGHT "the 2nd boss is not present at all".
##
## Founder, 2026-08-20: "Now the 2nd boss is not present at all!!! You IDIOT!!!
## I cant even progress to the next stage!!!"
##
## Cause (self-inflicted, previous commit): the boss-fight teardown that ends a
## fight when the player leaves the arena was made UNCONDITIONAL on the player's
## x. level_02's BossTrigger is a 200x800 box centred at x=3700, i.e. spanning
## 3600..3800, while `_seal_x` is that level's arena start_x = 3700 — so the
## teardown line (3660) sits INSIDE the trigger. Walking in from the west fired
## the trigger at x=3600, the boss spawned, and one frame later the same
## _process saw 3600 < 3660 and freed him. `body_entered` only fires on ENTRY,
## and the player was already inside the trigger volume, so no second event ever
## arrived: the arena stayed permanently empty and the stage was uncompletable.
##
## WHY EVERY EXISTING BOSS TEST MISSED IT: they all call `_on_boss_trigger()`
## directly with the player teleported to `start_x + 120` — already well inside
## the arena, past the teardown line. None of them reproduced a player WALKING
## IN THROUGH the trigger from the west, which is the only way a real player
## ever starts these fights.
##
## Run: godot --headless res://tests/boss_spawn_survives_walk_in_test.tscn

const LEVELS := [
	{"name": "Stage 2 — Crystal Caverns", "scene": "res://src/level/level_02_crystal_caverns.tscn"},
	{"name": "Stage 3 — Gold Rush", "scene": "res://src/level/level_03_gold_rush.tscn"},
	{"name": "Stage 1 — Smoke Realm", "scene": "res://src/level/level_01_smoke_realm.tscn"},
]

## Player top speed, so the walk-in happens at a realistic pace.
const WALK_SPEED := 240.0

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("BOSS SPAWN SURVIVES WALK-IN:")
	for cfg in LEVELS:
		await _probe(cfg)
	print("BOSS_SPAWN_SURVIVES_WALK_IN: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _probe(cfg: Dictionary) -> void:
	var level: Node = load(cfg["scene"]).instantiate()
	add_child(level)
	for _i in range(10):
		await get_tree().process_frame

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		_check("%s: player spawned" % cfg["name"], false)
		level.queue_free()
		await get_tree().process_frame
		return

	var arena: Dictionary = level.level_data.boss_arena
	var start_x: float = float(arena.get("start_x", 0.0))

	# Start WEST of the trigger volume and walk east through it, exactly as a
	# real player arrives. 260px back clears level_02's 200-wide trigger box.
	player.set_physics_process(false)
	player.global_position = Vector2(start_x - 260.0, player.global_position.y)
	for _i in range(4):
		await get_tree().process_frame

	# Walk in. The boss should spawn partway through this.
	#
	# The instant he appears, silence his contact hitbox: boss contact calls
	# GameManager.boss_contact_restart(), which swaps the whole scene out from
	# under this test via SceneRouter and leaves the await hanging forever. We
	# are gating SPAWN SURVIVAL here, not contact (boss_stakes_test covers that).
	var t := 0.0
	while t < 2.5:
		player.global_position.x += WALK_SPEED * (1.0 / 60.0)
		_silence_contact()
		t += 1.0 / 60.0
		await get_tree().physics_frame

	var boss_after_walk := get_tree().get_first_node_in_group("boss")
	_check("%s: boss EXISTS after walking in through the trigger" % cfg["name"],
		boss_after_walk != null and is_instance_valid(boss_after_walk),
		"no boss in the 'boss' group — the arena is empty and the stage cannot be completed")

	# ...and is still there a few seconds later, standing well inside the arena.
	# A boss that spawns and is torn down a frame later would pass a naive
	# "did it spawn" check but fail this one.
	var t2 := 0.0
	while t2 < 3.0:
		player.global_position.x = start_x + 200.0
		_silence_contact()
		t2 += 1.0 / 60.0
		await get_tree().physics_frame

	var boss_later := get_tree().get_first_node_in_group("boss")
	_check("%s: boss STILL present 3s into the fight" % cfg["name"],
		boss_later != null and is_instance_valid(boss_later),
		"boss vanished after spawning — teardown fired on a player who never left")

	level.queue_free()
	for _i in range(2):
		await get_tree().process_frame


## Turn off every live boss's contact Area2D. Idempotent and cheap; called each
## frame because the boss can spawn at any point during the walk-in.
func _silence_contact() -> void:
	for b in get_tree().get_nodes_in_group("boss"):
		if not is_instance_valid(b):
			continue
		var hb := b.get_node_or_null("Hitbox")
		if hb != null and hb.get("monitoring") == true:
			hb.set_deferred("monitoring", false)
