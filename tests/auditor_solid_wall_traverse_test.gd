extends Node
## Founder, 2026-08-24 (P0, screen recording + "boss walks through the blocks,
## nothing to leverage for distance, fight impossible"):
##
## The two things this gate locks in are in TENSION, which is the whole reason
## the fix was hard and the reason a single-sided gate keeps getting gamed:
##
##   1. The spacing platforms must BLOCK the boss (so Lil Blunt can put geometry
##      between them and gain distance — the founder's "leverage"). A collision
##      exception / one-way that lets the boss walk straight through fails this.
##   2. The boss must STILL CLOSE the full stage (no 42s pin behind a fled
##      player). Plain-solid platforms with no traverse fail this — measured, he
##      stranded at x=1882 for 2532 frames.
##
## Grok 4.6's ship rule (artifacts/dispatch_2026-08-24_boss1_walkthrough): "you
## cannot have solid torso-height slabs vs a 220 one-shot body without either a
## pin or a traverse." The shipped answer is a telegraphed, phasing WALL-VAULT
## (auditor.gd): the platforms are fully SOLID (player lands, boss is blocked),
## he PLANTS at each wall (leverage) then vaults it, phasing the platforms only
## for the brief arc so his 220px body clears the dense pocket geometry.
##
## This gate reproduces the founder's exact scenario — player fled to the far
## west — and asserts ALL of:
##   A. He CLOSES to striking distance (chase works over solid walls).
##   B. He is never permanently walled (no pin).
##   C. He never floats (peak feet stay below the highest platform — anti-fly,
##      the half PR #52-era gates never measured).
##   D. The walls genuinely IMPEDE him: there are real "planted at a wall" beats.
##      A boss that phased the platforms freely (the rejected exception fix)
##      would score ZERO here — this is the "leverage is not zero" proof, and it
##      is measured from OBSERVABLE physics (grounded + stalled + a soft platform
##      right ahead), never from a boss-internal flag that could be faked.
##
## Run: godot --headless res://tests/auditor_solid_wall_traverse_test.tscn

const LEVEL := preload("res://src/level/level_01_smoke_realm.tscn")
const FEET_OFFSET := 220.0
## Highest platform top in level_01_data.tres (Vector4(2100,300,100,20)).
const HIGHEST_PLATFORM_TOP := 300.0

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	await get_tree().process_frame
	print("AUDITOR SOLID-WALL TRAVERSE:")
	await _run()
	print("AUDITOR_SOLID_WALL_TRAVERSE: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

## Is there a soft (vaultable) platform within `reach` px ahead of the boss, at
## any height across his body? Pure observable physics — no boss internals.
func _soft_ahead(boss: Node2D, reach: float) -> bool:
	var space := boss.get_world_2d().direct_space_state
	var dir: float = signf(boss.patrol_direction) if not is_zero_approx(boss.patrol_direction) else -1.0
	var lead_x: float = boss.global_position.x + (220.0 if dir > 0.0 else 0.0)
	var feet_y: float = boss.global_position.y + FEET_OFFSET
	for step: int in range(0, 22):
		var y: float = feet_y - 4.0 - float(step) * 10.0
		var frm := Vector2(lead_x - dir * 6.0, y)
		var pr := PhysicsRayQueryParameters2D.create(frm, frm + Vector2(dir * reach, 0.0))
		pr.collision_mask = 1
		pr.exclude = [boss.get_rid()]
		var h: Dictionary = space.intersect_ray(pr)
		if not h.is_empty():
			var c: Object = h.get("collider")
			if c is Node and (c as Node).is_in_group("boss_soft_platform"):
				return true
	return false

func _run() -> void:
	var level := LEVEL.instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame

	var player := get_tree().get_first_node_in_group("player")
	# Fight starts from the east; player has fled to the far west edge.
	player.global_position = Vector2(2920.0, 500.0)
	level._on_boss_trigger(player)
	await get_tree().process_frame

	var boss := level.get_node_or_null("Auditor") as Node2D
	if boss == null:
		_check("Auditor spawned", false)
		return
	var hb := boss.get_node_or_null("Hitbox")
	if hb != null:
		hb.set_deferred("monitoring", false)

	var last_x: float = boss.global_position.x
	var stuck: int = 0
	var max_stuck: int = 0
	var min_feet: float = INF
	var planted_frames: int = 0   # grounded + stalled + a soft wall right ahead
	# Player walks the rest of the way to the western edge and waits there.
	for f in range(3000):
		var t: float = float(f) / 60.0
		player.global_position = Vector2(maxf(150.0, 2920.0 - t * 90.0), 500.0)
		if not is_instance_valid(boss):
			_check("Auditor survives the pursuit", false, "freed mid-run")
			return
		var feet: float = boss.global_position.y + FEET_OFFSET
		min_feet = minf(min_feet, feet)
		if absf(boss.global_position.x - last_x) < 2.0:
			stuck += 1
			max_stuck = maxi(max_stuck, stuck)
		else:
			stuck = 0
		last_x = boss.global_position.x
		var grounded: bool = bool(boss.call("is_on_floor"))
		if grounded and absf(boss.velocity.x) < 40.0 and _soft_ahead(boss, 26.0):
			planted_frames += 1
		await get_tree().physics_frame

	var gap: float = absf(boss.global_position.x - player.global_position.x)
	print("  [INFO] final boss_x=%.0f player_x=%.0f gap=%.0f max_stuck=%d highest_feet=%.0f planted=%d frames"
		% [boss.global_position.x, player.global_position.x, gap, max_stuck, min_feet, planted_frames])

	_check("A. Closes to striking distance of a fully-fled player (gap < 350px)",
		gap < 350.0, "gap=%.0f" % gap)
	_check("B. Never permanently walled anywhere on the route (< 5s stuck)",
		max_stuck < 300, "stuck %d frames straight" % max_stuck)
	_check("C. Never floats — peak feet stay below the highest platform top",
		min_feet >= HIGHEST_PLATFORM_TOP, "reached feet y=%.0f (above %.0f)" % [min_feet, HIGHEST_PLATFORM_TOP])
	_check("D. The walls genuinely impede him (planted-at-a-wall beats exist)",
		planted_frames >= 20, "only %d planted frames — platforms not blocking (exception/one-way regression?)" % planted_frames)

	boss.queue_free()
	level.queue_free()
	await get_tree().process_frame
