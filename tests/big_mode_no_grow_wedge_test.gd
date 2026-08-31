extends Node
## Founder, 2026-08-25 (P0, shot_2): Stage-3 canyon, a magic mushroom on screen,
## "the game is now frozen even though the music is still playing." Root cause
## (measured here, and reached independently by DeepSeek's freeze trace): the
## Magic Mushroom grows Lil Blunt by scaling the player node 1.5x
## (power_up_handler._update_scale), which scales his CollisionShape2D from
## 32x32 to 48x48. If he grows under an overhead platform / low ceiling / canyon
## constriction, the enlarged body is left EMBEDDED in solid geometry, and a
## grounded CharacterBody2D cannot depenetrate — he is WEDGED and unmovable
## while music and enemies keep running. To the founder that is a frozen game.
## This is NOT a tree pause and NOT a stranded time_scale (both already hardened).
##
## This gate builds a tall, narrow overhead block, proves the hazard is real
## (a raw 1.5x scale leaves the body embedded), then proves the shipped fix
## (power_up_handler grow path -> player.resolve_grow_overlap) frees him.
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/big_mode_no_grow_wedge_test.tscn

const PLAYER := preload("res://src/player/player.tscn")

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	await get_tree().process_frame
	print("BIG-MODE NO GROW WEDGE:")
	await _run()
	print("BIG_MODE_NO_GROW_WEDGE: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _make_wall(left_face_x: float) -> StaticBody2D:
	# A World-layer wall whose LEFT face sits at x=left_face_x. The player's
	# 32x32 collision is top-left anchored (offset (16,16)), so scaling the node
	# 1.5x grows the body DOWN and RIGHT — the right edge goes from origin+32 to
	# origin+48. A wall placed just past the 1.0x right edge is clear when small
	# and embedded when big, reproducing the grow-into-solid wedge deterministically.
	var body := StaticBody2D.new()
	body.collision_layer = 1  # World
	body.collision_mask = 0
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(200, 400)
	col.shape = shape
	body.add_child(col)
	body.global_position = Vector2(left_face_x + 100.0, 0.0)  # left face at left_face_x
	return body

func _run() -> void:
	StateMachine.change_state(StateMachine.State.TRANSITIONING)
	StateMachine.change_state(StateMachine.State.PLAYING)

	var player: CharacterBody2D = PLAYER.instantiate()
	add_child(player)
	player.global_position = Vector2.ZERO
	# Small right edge = 32, big right edge = 48. Wall left face at 40 → clear
	# small, 8px embed big.
	var wall := _make_wall(40.0)
	add_child(wall)
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Baseline: small (1.0x) body beside this wall is CLEAR.
	GameManager.current_power_up = ""
	player.scale = Vector2.ONE
	player.global_position = Vector2.ZERO
	await get_tree().physics_frame
	var small_embedded: bool = player.move_and_collide(Vector2.ZERO, true, 0.08, true) != null
	_check("small (1.0x) body is not embedded beside the wall", not small_embedded)

	# HAZARD PROOF: a raw 1.5x scale with NO resolve leaves the body embedded.
	player.global_position = Vector2.ZERO
	player.scale = Vector2(1.5, 1.5)
	await get_tree().physics_frame
	var raw_embedded: bool = player.move_and_collide(Vector2.ZERO, true, 0.08, true) != null
	_check("raw 1.5x grow (no resolve) DOES embed — the wedge hazard is real",
		raw_embedded, "if this is false the geometry no longer reproduces the wedge")

	# THE FIX: reset, then go through the real grow path (activate 'big' ->
	# power_up_handler._update_scale -> resolve_grow_overlap).
	player.scale = Vector2.ONE
	player.power_up_handler.current_scale = Vector2.ONE
	player.global_position = Vector2.ZERO
	await get_tree().physics_frame
	GameManager.activate_power_up("big", 10.0)
	player.power_up_handler._update_scale()
	await get_tree().physics_frame
	var after_embedded: bool = player.move_and_collide(Vector2.ZERO, true, 0.08, true) != null
	_check("after real grow path, body is NOT embedded (wedge resolved)",
		not after_embedded,
		"still embedded at %s — resolve_grow_overlap failed" % str(player.global_position))
	_check("grow actually applied 1.5x scale", is_equal_approx(player.scale.x, 1.5),
		"scale=%s" % str(player.scale))

	# And he can actually MOVE afterwards (not pinned): drive him and confirm x moves.
	var x0: float = player.global_position.x
	for f in range(30):
		player.velocity = Vector2(-180.0, 0.0)  # away from the wall (which is to the right)
		player.move_and_slide()
		await get_tree().physics_frame
	_check("grown player can move horizontally afterwards (not frozen)",
		absf(player.global_position.x - x0) > 20.0,
		"moved only %.1fpx" % absf(player.global_position.x - x0))

	player.queue_free()
	wall.queue_free()
	await get_tree().process_frame
