extends Node
## Founder, 2026-08-26 (P0): "When Lil Blunt jumps on the blue block it
## disappears then he freezes and the music continues but the game is frozen!!!"
##
## ROOT CAUSE: breakable_block.break_block() / secret_wall.break_block() tweened
## the StaticBody2D ITSELF to Vector2.ZERO, which scales its CollisionShape2D to
## zero. A zero-scale collider is degenerate (non-invertible transform), so the
## player standing on the block is left in contact with a broken floor — he can't
## depenetrate, is_on_floor() stops resolving, and a Big-Mode ground pound (which
## is what breaks the block) never clears _ground_pounding. Hard freeze, music on.
## The player breaks the very block he stands on, so it fired every time.
##
## This gate drives the REAL block scene under a REAL player and asserts the
## block stops being a floor CLEANLY: collider disabled, body scale never
## degenerate, and the player still moves afterwards.
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/breakable_block_no_freeze_test.tscn

const PLAYER := preload("res://src/player/player.tscn")
const BLOCK := preload("res://src/level/breakable_block.tscn")
const SECRET := preload("res://src/level/secret_wall.tscn")

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	await get_tree().process_frame
	print("BREAKABLE BLOCK NO FREEZE:")
	await _run_block("breakable_block", BLOCK)
	await _run_block("secret_wall", SECRET)
	print("BREAKABLE_BLOCK_NO_FREEZE: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _run_block(label: String, scene: PackedScene) -> void:
	if not StateMachine.is_playing():
		StateMachine.change_state(StateMachine.State.TRANSITIONING)
		StateMachine.change_state(StateMachine.State.PLAYING)

	var block: StaticBody2D = scene.instantiate()
	add_child(block)
	block.global_position = Vector2(0, 64)
	var player: CharacterBody2D = PLAYER.instantiate()
	add_child(player)
	# Player collision is top-left anchored (32x32 at offset 16,16): sit him
	# directly on top of the block so it is his floor.
	player.global_position = Vector2(0, 32)
	# Big Mode is the state the founder was in when this fired.
	GameManager.activate_power_up("big", 10.0)
	await get_tree().physics_frame

	# Settle him onto the block.
	for f in range(20):
		player.velocity.y += 980.0 * (1.0 / 60.0)
		player.move_and_slide()
		await get_tree().physics_frame
	_check("[%s] player is resting ON the block before it breaks" % label,
		player.is_on_floor(), "never landed — geometry doesn't reproduce the case")

	# BREAK IT under his feet — exactly what _resolve_ground_pound does.
	var x0: float = player.global_position.x
	block.break_block()

	# SAMPLE THE WHOLE HAZARD WINDOW, not one frame. The old break tween took
	# 0.25s to reach zero scale, so a 2-frame check misses the trap entirely
	# (measured: it passed on the buggy build). Walk the player the whole time —
	# the freeze is exactly "collider still live while the shape shrinks".
	var violation := ""     # a frame where an ENABLED collider had a shrunken body
	var min_scale := 1.0
	for f in range(30):     # 0.5s — covers the full 0.25s shrink + free
		if is_instance_valid(block):
			var c: CollisionShape2D = block.get_node_or_null("CollisionShape2D")
			var enabled: bool = c != null and not c.disabled
			min_scale = minf(min_scale, block.scale.x)
			if enabled and block.scale.x < 0.9 and violation == "":
				violation = "frame %d: collider ENABLED at body scale %.2f" % [f, block.scale.x]
		player.velocity.x = 200.0
		player.velocity.y += 980.0 * (1.0 / 60.0)
		player.move_and_slide()
		await get_tree().physics_frame

	# THE INVARIANT: a live (enabled) collider must never be scaled toward zero.
	# That degenerate state is what traps the player standing on it.
	_check("[%s] never an ENABLED collider on a shrinking body" % label,
		violation == "",
		"%s — this degenerate collider is the freeze" % violation)

	# The player must keep moving right through the break window.
	_check("[%s] player keeps moving through the break (NOT frozen)" % label,
		absf(player.global_position.x - x0) > 30.0,
		"moved only %.1fpx during the break — this is the freeze"
			% absf(player.global_position.x - x0))

	GameManager.current_power_up = ""
	player.queue_free()
	if is_instance_valid(block):
		block.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
