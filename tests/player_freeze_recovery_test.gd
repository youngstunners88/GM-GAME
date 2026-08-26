extends Node
## Founder, 2026-08-26 (P0, shots freeze_persist): STILL frozen on the Stage-3
## mushroom/ladder platform after the grow-wedge fix — and shot_1 shows it with
## NO big-mode, so it is not (only) the grow wedge. Two fixes are under test here:
##   1. _force_unstick() (the anti-deadlock heartbeat's action): clears stranded
##      movement-blocking flags (_climbing / _dying) and depenetrates the body
##      out of any solid, so a stuck player is always freed.
##   2. The ladder top-out embed probe now uses recovery_as_collision (via
##      resolve_grow_overlap) — the old probe never detected a resting overlap,
##      so a top-out into geometry left the player embedded and frozen.
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/player_freeze_recovery_test.tscn

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
	print("PLAYER FREEZE RECOVERY:")
	await _run()
	print("PLAYER_FREEZE_RECOVERY: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _wall(left_face_x: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(200, 400)
	col.shape = shape
	body.add_child(col)
	body.global_position = Vector2(left_face_x + 100.0, 0.0)
	return body

func _run() -> void:
	StateMachine.change_state(StateMachine.State.TRANSITIONING)
	StateMachine.change_state(StateMachine.State.PLAYING)
	var player: CharacterBody2D = PLAYER.instantiate()
	add_child(player)
	player.global_position = Vector2.ZERO
	# Wall whose left face is inside the player's body span → embedded.
	var wall := _wall(20.0)
	add_child(wall)
	await get_tree().physics_frame

	var embedded_before: bool = player.move_and_collide(Vector2.ZERO, true, 0.08, true) != null
	_check("player starts embedded in the wall (repro the wedge)", embedded_before,
		"geometry no longer reproduces the wedge")

	# Strand the movement-blocking flags the way a real freeze would.
	player._climbing = true
	player._dying = true

	# Heartbeat action.
	player._force_unstick()
	await get_tree().physics_frame

	var embedded_after: bool = player.move_and_collide(Vector2.ZERO, true, 0.08, true) != null
	_check("after _force_unstick, player is NOT embedded", not embedded_after,
		"still stuck at %s" % str(player.global_position))
	_check("_force_unstick cleared _climbing", not player._climbing)
	_check("_force_unstick cleared stranded _dying", not player._dying)

	# And he can move afterwards (drive away from the wall).
	var x0: float = player.global_position.x
	for f in range(30):
		player.velocity = Vector2(-180.0, 0.0)
		player.move_and_slide()
		await get_tree().physics_frame
	_check("player can move after unstick (not frozen)",
		absf(player.global_position.x - x0) > 20.0,
		"moved only %.1fpx" % absf(player.global_position.x - x0))

	player.queue_free()
	wall.queue_free()
	await get_tree().process_frame
