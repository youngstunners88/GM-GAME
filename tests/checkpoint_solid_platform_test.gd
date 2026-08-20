extends Node
## Founder, 2026-08-20 (shot_1): "The 1st boss need to be able to jump on the
## block that i have circled so that he can launch himself onto the
## platform. Why did you make the block something that he can just walk
## through!!!!"
##
## Root cause: checkpoint.tscn's only body was the trigger Area2D itself —
## Area2D nodes never produce a physical collision response, so both the
## player and the Auditor fell straight through the "green block" the
## founder circled. Fix adds a StaticBody2D sibling on the World layer (1)
## matching the block's visible 32x48 footprint, leaving the Area2D trigger
## (checkpoint save logic) untouched.
##
## This reproduces the real failure path: drop a body from above the block
## and assert it comes to rest ON TOP of it rather than passing through to
## the floor below.
##
## Run: godot --headless res://tests/checkpoint_solid_platform_test.tscn

const CHECKPOINT := preload("res://src/level/checkpoint.tscn")

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("CHECKPOINT SOLID PLATFORM:")
	await _run()
	print("CHECKPOINT_SOLID_PLATFORM: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _run() -> void:
	var cp: Node2D = CHECKPOINT.instantiate()
	add_child(cp)
	cp.global_position = Vector2(500.0, 600.0)

	var stand := cp.get_node_or_null("StandSurface")
	_check("checkpoint has a StandSurface StaticBody2D", stand != null and stand is StaticBody2D)
	if stand:
		_check("StandSurface is on the World layer (bit 1)", (stand.collision_layer & 1) == 1,
			"collision_layer=%d" % stand.collision_layer)

	# A generic World-layer body dropped from above the block should land ON
	# it (near global_position.y + 24, the block's vertical center), not fall
	# through to a floor placed far below.
	var body := CharacterBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 13  # matches the Auditor's own mask (World + others)
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 28)
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	body.global_position = Vector2(500.0, 500.0)  # well above the block

	for _f in range(180):  # 3s
		body.velocity.y += 980.0 * (1.0 / 60.0)
		body.move_and_slide()
		await get_tree().physics_frame

	var landed_on_block: bool = body.global_position.y < 610.0
	_check("a boss-mask body dropped above the block rests on it, not through it",
		landed_on_block,
		"final y=%.1f (expected well under 610, i.e. resting on the block, not the far floor)"
			% body.global_position.y)

	body.queue_free()
	cp.queue_free()
	await get_tree().process_frame
