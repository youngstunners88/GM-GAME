extends Node
## Runtime behaviour test for The Distributor (Boss 2).
##
## WHY THIS EXISTS: every previous check on this boss was STATIC — reading the
## code, or asking a model to read it. Static review cannot answer the only
## question that matters for a pull mechanic: *does it actually move the
## player?* The first implementation used pull_strength = 520 against the
## player's own ground_decel = 2800 and was therefore pure decoration; that was
## caught by arithmetic, not by measurement. This test measures.
##
## It also catches the failure that static review provably missed: `distributor.gd`
## shipped with a `:=`-from-Variant parse error, so the script did not load AT
## ALL and the boss was inert. A behaviour test fails loudly on that because
## the state machine never advances.
##
## Run: godot --headless res://tests/distributor_behaviour_test.tscn

const DISTRIBUTOR := preload("res://src/boss/distributor.tscn")
const PLAYER := preload("res://src/player/player.tscn")

var _failures: int = 0
var _boss: Node2D
var _player: CharacterBody2D

func _ready() -> void:
	await _run()

func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  [PASS] %s" % label)
	else:
		_failures += 1
		print("  [FAIL] %s %s" % [label, detail])

func _info(label: String, value: Variant) -> void:
	print("  [INFO] %s = %s" % [label, str(value)])

## Minimal arena: a wide solid floor plus walls, mirroring the real boss arena
## (level_02 ground segment 3700..4400 is solid — there are no pits in it).
func _build_arena() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2000, 80)
	cs.shape = rect
	floor_body.add_child(cs)
	floor_body.global_position = Vector2(0, 400)
	add_child(floor_body)

func _run() -> void:
	_build_arena()

	_player = PLAYER.instantiate() as CharacterBody2D
	add_child(_player)
	_player.global_position = Vector2(-200, 300)

	_boss = DISTRIBUTOR.instantiate() as Node2D
	add_child(_boss)
	_boss.global_position = Vector2(0, 280)

	# Let both settle onto the floor.
	for i in 30:
		await get_tree().physics_frame

	print("Distributor behaviour:")
	await _test_script_actually_attached()
	await _test_states_reachable_at_runtime()
	await _test_pull_moves_a_standing_player()
	_test_vulnerable_window_shrinks_per_phase()

	if _failures == 0:
		print("DISTRIBUTOR_BEHAVIOUR: ALL PASS")
		get_tree().quit(0)
	else:
		print("DISTRIBUTOR_BEHAVIOUR: %d FAILURE(S)" % _failures)
		get_tree().quit(1)

## The check that a parse error cannot survive: if the script failed to load,
## the node has no script and none of these members exist.
func _test_script_actually_attached() -> void:
	var scr: Variant = _boss.get_script()
	_check("boss script attached", scr != null, "(parse error would leave this null)")
	_check("boss exposes its state machine", "current_phase_state" in _boss)
	_check("boss health initialised to 7", _boss.health == 7, str(_boss.health))

## Drive the boss through a full cycle and record which states are actually
## entered by REAL physics — not by grepping for assignments.
func _test_states_reachable_at_runtime() -> void:
	var seen := {}
	# The boss alternates pull-cycle / volley-cycle, so run long enough to see
	# both branches (throw_cooldown is 2s; 900 frames ~= 15s at 60Hz).
	for i in 900:
		seen[int(_boss.current_phase_state)] = true
		await get_tree().physics_frame
	# Phase enum: 0 PATROL, 1 GRAVITY_TELL, 2 HOARD_GRAVITY, 3 SHARD_THROW, 4 VULNERABLE
	var names := ["PATROL", "GRAVITY_TELL", "HOARD_GRAVITY", "SHARD_THROW", "VULNERABLE"]
	for i in names.size():
		_check("state %s entered at runtime" % names[i], seen.has(i),
			"(never reached in 15s of real physics)")

## THE measurement. Park the player at a known distance, force the field on,
## apply NO input, and record how far the pull actually drags them.
##
## A standing player decelerates at ground_decel = 2800, so a pull weaker than
## that produces literally zero displacement — which is what shipped first.
func _test_pull_moves_a_standing_player() -> void:
	var centre: Vector2 = _boss.global_position + Vector2(48, 48)
	# Mid-field: far enough that the falloff is doing real work.
	var start := centre + Vector2(-220, 0)
	_player.global_position = start
	_player.velocity = Vector2.ZERO
	for i in 5:
		await get_tree().physics_frame

	var before: float = _player.global_position.x
	_boss.call("_begin_hoard_gravity")
	# The field lasts 1.4s in phase 1; sample 60 frames (~1s) of it.
	for i in 60:
		await get_tree().physics_frame
	var after: float = _player.global_position.x
	var moved := after - before

	_info("player x before pull", before)
	_info("player x after 1s of pull", after)
	_info("displacement toward boss (px)", moved)

	# Direction: the boss is to the RIGHT of the player here, so a working
	# pull produces POSITIVE displacement.
	_check("pull actually moves a standing player", moved > 20.0,
		"moved only %.1f px in 1s — this is the 'cosmetic pull' regression" % moved)
	# Sanity ceiling: a pull that yanks the player hundreds of px in a second
	# is a teleport, not a drag, and would feel like losing control.
	_check("pull is a drag, not a yank", moved < 400.0,
		"moved %.1f px in 1s — too strong to fight" % moved)

## The vulnerable window must SHRINK as phases escalate (the Claim Jumper
## pattern) so there is less free damage time as everything else gets harder.
func _test_vulnerable_window_shrinks_per_phase() -> void:
	var windows: Array[float] = []
	for phase in [1, 2, 3]:
		_boss.set("current_phase", phase)
		_boss.call("_begin_vulnerable")
		windows.append(float(_boss.get("state_timer")))
	_info("vulnerable window p1/p2/p3", windows)
	_check("window shrinks p1 -> p2", windows[1] < windows[0],
		"%.2f -> %.2f" % [windows[0], windows[1]])
	_check("window shrinks p2 -> p3", windows[2] < windows[1],
		"%.2f -> %.2f" % [windows[1], windows[2]])
	_check("window never collapses to nothing", windows[2] >= 0.6,
		"p3 window is %.2fs — too short to react to" % windows[2])
