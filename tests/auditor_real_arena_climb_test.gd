extends Node
## Founder, 2026-08-21 residual: "He must stand on it and launch up onto the
## next platform. Make all bosses smarter — not stuck / walk-through."
##
## `auditor_platform_intelligence_test.gd` already proves he doesn't get
## trapped head-banging under a SYNTHETIC ceiling slab. This is the honest
## companion: does he actually climb real, solid `platforms` geometry from
## the shipped `level_01_data.tres` during a real fight, not a hand-built
## test rig? The Auditor's own comment ("even if Lil Blunt runs back to the
## beginning section... chase all the way through the stage") means every
## platform in Level 1 is fair game during a fight, not just ones inside
## boss_arena's own x-range — so this drives the player back and forth
## across the platform-dense stretch (x 2100-2800) and checks whether the
## Auditor is EVER actually resting on a platform surface other than the
## y=650 ground, not just airborne near one.
##
## Run: godot --headless res://tests/auditor_real_arena_climb_test.tscn

const LEVEL := preload("res://src/level/level_01_smoke_realm.tscn")

## Real `platforms` entries near the fight zone (level_01_data.tres). Surface
## y = top of the Vector4(x, y, w, h) rect, i.e. the `y` field itself (platform
## bodies are positioned at their top-left per _create_platform).
const PLATFORM_SURFACES := [300.0, 350.0, 450.0, 350.0]  # y=2100,2400,2600 entries (+750 dupe)
const GROUND_Y := 650.0
const SURFACE_TOLERANCE := 30.0

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("AUDITOR REAL-ARENA CLIMB:")
	await _run()
	print("AUDITOR_REAL_ARENA_CLIMB: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _run() -> void:
	var level := LEVEL.instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		_check("player spawned", false, "no player node found")
		return
	player.global_position = Vector2(2920.0, 500.0)
	level._on_boss_trigger(player)
	await get_tree().process_frame

	var boss := level.get_node_or_null("Auditor")
	if boss == null:
		_check("Auditor spawned via _on_boss_trigger", false)
		return

	# Contact/attack damage would kill the player mid-run and tear this level
	# down via the normal death->respawn->reload path — the exact cause of an
	# earlier hang here. Same fix as auditor_platform_intelligence_test.gd.
	var hb := boss.get_node_or_null("Hitbox")
	if hb != null:
		hb.set_deferred("monitoring", false)

	var min_y: float = INF
	var on_real_platform: bool = false
	var platform_frames: int = 0
	# Oscillate the player across the platform-dense stretch just west of the
	# arena so the boss's "player above me" leap/air-jump logic keeps
	# re-arming against REAL terrain, not a single static target. Kept to
	# 2500-2850 deliberately: level_01_smoke_realm.gd places a hidden secret
	# door at x=2350 — crossing it mid-run fires a scene load into the Smoke
	# Lounge and back, which is a real side-trigger, not a bug in this test.
	for f in range(900):  # 15s of real physics
		var t: float = float(f) / 60.0
		var target_x: float = 2675.0 + sin(t * 0.5) * 175.0
		player.global_position = Vector2(target_x, 300.0)
		if is_instance_valid(boss):
			min_y = minf(min_y, boss.global_position.y)
			if boss.is_on_floor() and boss.global_position.y < GROUND_Y - 60.0:
				platform_frames += 1
				for surf_y in PLATFORM_SURFACES:
					if absf(boss.global_position.y - surf_y) <= SURFACE_TOLERANCE:
						on_real_platform = true
		await get_tree().physics_frame

	print("  [INFO] boss min_y reached: %.0f (ground=%.0f, lower is higher up)" % [min_y, GROUND_Y])
	print("  [INFO] frames resting on any non-ground surface: %d / 900" % platform_frames)
	_check("Auditor reaches meaningfully above ground level (min_y <= %.0f)" % (GROUND_Y - 100.0),
		min_y <= GROUND_Y - 100.0,
		"min_y=%.0f — never got far off the ground" % min_y)
	_check("Auditor is observed RESTING on a real level_01 platform surface (not just airborne near one)",
		on_real_platform,
		"never matched a known platform y within %.0fpx while grounded" % SURFACE_TOLERANCE)

	boss.queue_free() if is_instance_valid(boss) else null
	level.queue_free()
	await get_tree().process_frame
