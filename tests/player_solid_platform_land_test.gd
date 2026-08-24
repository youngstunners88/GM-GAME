extends Node
## Founder, 2026-08-24 (P0, GAUNTLET): "Lil Blunt can't land on the thicker
## solid platforms and falls through them!!!" Regression from PR #52, which made
## Level 1's floating platforms one-way so the 220px Auditor could pass — that
## one-way also broke the PLAYER landing on them (a one-way whose blocked
## direction is wrong, or margin tunneling on a fast fall, drops the player
## straight through the deck).
##
## This gate drops the player from above each real Level 1 floating platform and
## asserts he COMES TO REST ON TOP (is_on_floor, feet at the deck), never
## falling through. Runs the real level so it exercises the actual platform
## builder + collision layers, not a synthetic block.
##
## Run: godot --headless res://tests/player_solid_platform_land_test.tscn

const LEVEL := preload("res://src/level/level_01_smoke_realm.tscn")
## Level 1 floating platforms (x, y, w, h) from level_01_data.tres.
const PLATFORMS := [
	Vector2(300, 500), Vector2(500, 400), Vector2(750, 350), Vector2(1100, 450),
	Vector2(1400, 350), Vector2(1700, 400), Vector2(2100, 300), Vector2(2600, 350),
]
const PLAT_W := [100.0, 100.0, 120.0, 100.0, 100.0, 150.0, 100.0, 100.0]

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	await get_tree().process_frame
	print("PLAYER SOLID PLATFORM LAND:")
	await _run()
	print("PLAYER_SOLID_PLATFORM_LAND: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

## Recursively turn off monitoring on every Area2D so no trigger fires during
## the teleport-and-drop probing.
func _disable_all_areas(n: Node) -> void:
	if n is Area2D:
		(n as Area2D).set_deferred("monitoring", false)
	for child in n.get_children():
		_disable_all_areas(child)

func _run() -> void:
	var level := LEVEL.instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame
	# Neutralise EVERY Area2D trigger before the drops. This gate only tests
	# static-platform LANDING (StaticBody2D collision); the level's Area2D
	# triggers — the boss trigger, collectibles, and especially the Blaze Portal
	# at (1450,250), which sits right where the player is dropped onto platform
	# (1400,350) — would otherwise fire on a teleported test player and warp the
	# whole SceneTree to blaze_rush.tscn mid-run (measured: the gate died after
	# 4 platforms). Disabling monitoring leaves the platforms fully solid.
	_disable_all_areas(level)
	await get_tree().process_frame

	var player: CharacterBody2D = get_tree().get_first_node_in_group("player")
	var landed := 0
	for i in range(PLATFORMS.size()):
		var top: Vector2 = PLATFORMS[i]
		var cx: float = top.x + PLAT_W[i] * 0.5
		# Drop from ~90px above the deck, centred on the platform.
		player.velocity = Vector2.ZERO
		player.global_position = Vector2(cx, top.y - 90.0)
		var rested := false
		var rest_y: float = INF
		for f in range(150):  # up to 2.5s to settle + confirm it holds
			player.velocity.x = 0.0
			player.velocity.y += 980.0 * (1.0 / 60.0)
			player.move_and_slide()
			if player.is_on_floor() and player.global_position.y <= top.y + 4.0:
				rested = true
				rest_y = player.global_position.y
			await get_tree().physics_frame
		var ok: bool = rested and player.is_on_floor() and player.global_position.y < top.y + 40.0
		if ok:
			landed += 1
		_check("lands & stays on platform (%d,%d)" % [int(top.x), int(top.y)],
			ok, "final y=%.0f (deck top %.0f) on_floor=%s — fell through" %
			[player.global_position.y, top.y, player.is_on_floor()])

	_check("player lands on ALL %d floating platforms" % PLATFORMS.size(),
		landed == PLATFORMS.size(), "only %d/%d held" % [landed, PLATFORMS.size()])

	player = null
	level.queue_free()
	await get_tree().process_frame
