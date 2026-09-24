extends Node
## FOUNDER, 2026-09-16 (P0, RE-REPORT): "the blue block disappears when one
## jumps on it and then the fucking game freezes!!!"
##
## The "blue block" is `secret_wall.tscn` — the ONLY thing in the game that
## draws `tile_block-chain.png` untinted, so it renders in the texture's own
## CYAN while every platform modulates it to the realm's colour. Stage 3 places
## two of them, at (620, 624) and (1260, 624), and BOTH sit inside pits in the
## ground (segments leave gaps at 560-700 and 1220-1320) — they are the only
## floor across those holes.
##
## This was reported once before (2026-08-26) and three separate hardenings
## landed: the degenerate zero-scale collider (breakable_block/secret_wall),
## the ground-pound watchdog, and `_force_unstick()` clearing `_ground_pounding`.
## The founder says it still happens, so none of those was the live cause.
##
## THE UNFIXED CAUSE THIS GATE PINS DOWN: `player._check_pickaxe_breaks()` runs
## every physics frame and smashes EVERY breakable in a slide collision —
## including the one the player is RESTING ON. Its own doc comment says
## "walking INTO a breakable block smashes it", but `get_slide_collision()`
## reports the FLOOR contact too. So with the pickaxe out (the founder's
## screenshot shows PICKAXE 41%), simply landing on the blue block deletes the
## floor under his feet on the very next frame, drops him in the pit it was
## bridging, and does it again on every frame of contact.
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless \
##        res://tests/blue_block_floor_freeze_test.tscn

const WALL := preload("res://src/level/secret_wall.tscn")
const PLAYER := preload("res://src/player/player.tscn")

## The real Stage 3 placement: wall body origin is top-left, its 32x32 shape is
## re-centred to (16,16) in _ready(), so it occupies x 620..652 / y 624..656.
const WALL_POS := Vector2(620, 624)

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	await get_tree().process_frame
	print("BLUE BLOCK FLOOR FREEZE:")
	await _run_stand_on_wall()
	await _run_side_smash_still_works()
	await _run_timed_gate_never_degenerate()
	print("BLUE_BLOCK_FLOOR_FREEZE: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

## Silence every Area2D so collectibles/hazards can't fire on a teleported
## test player — this gate is purely about StaticBody2D floor contact.
func _disable_all_areas(n: Node) -> void:
	if n is Area2D:
		(n as Area2D).set_deferred("monitoring", false)
	for child in n.get_children():
		_disable_all_areas(child)

func _make_player(host: Node, at: Vector2) -> CharacterBody2D:
	# player.gd::_physics_process early-returns unless the run is PLAYING, so
	# without this the body never falls and every assertion below is vacuous.
	if not StateMachine.is_playing():
		StateMachine.change_state(StateMachine.State.TRANSITIONING)
		StateMachine.change_state(StateMachine.State.PLAYING)
	var p: CharacterBody2D = PLAYER.instantiate()
	host.add_child(p)
	p.global_position = at
	_disable_all_areas(p)
	return p

## THE FOUNDER'S CASE: pickaxe out, land on the blue block, keep standing.
## The block must survive — it is the floor. Smashing your own floor is the
## bug, and the pit underneath is why it reads as the game dying.
func _run_stand_on_wall() -> void:
	var host := Node2D.new()
	add_child(host)

	var wall: StaticBody2D = WALL.instantiate()
	host.add_child(wall)
	wall.global_position = WALL_POS
	_disable_all_areas(wall)
	await get_tree().process_frame

	# Drop him from just above the deck, horizontally centred on the block.
	var player := _make_player(host, WALL_POS + Vector2(16, -40))
	GameManager.activate_power_up("pickaxe", 60.0)
	await get_tree().process_frame

	# Fall, land, then hold still ON the block for a full second of real
	# physics. No input — he is just standing there.
	var landed := false
	var wall_alive_after_landing := true
	for i in range(90):
		await get_tree().physics_frame
		if not landed and player.is_on_floor():
			landed = true
		if landed and not is_instance_valid(wall):
			wall_alive_after_landing = false
			break

	_check("player actually landed on the blue block", landed,
		"(never reached is_on_floor — the drop missed the block, test setup is wrong)")
	_check("STANDING on the blue block with the pickaxe does NOT smash it",
		wall_alive_after_landing,
		"the block the player is resting on was destroyed under his own feet — " +
		"_check_pickaxe_breaks smashed a FLOOR contact, which is the founder's " +
		"'jumps on it and it disappears'")
	_check("player is still supported (not dumped into the pit it bridges)",
		is_instance_valid(player) and player.is_on_floor(),
		"(on_floor=%s, y=%.1f)" % [
			str(is_instance_valid(player) and player.is_on_floor()),
			player.global_position.y if is_instance_valid(player) else NAN])

	GameManager.deactivate_power_up()
	host.queue_free()
	await get_tree().process_frame

## The pickaxe smash must still WORK the way it is designed to: walking
## sideways INTO a block breaks it. Fixing the floor case must not disarm the
## feature — Level 1's overhead walls/blocks are smashed exactly this way.
func _run_side_smash_still_works() -> void:
	var host := Node2D.new()
	add_child(host)

	# Floor to stand on, so he can walk rather than fall.
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var fshape := CollisionShape2D.new()
	var frect := RectangleShape2D.new()
	frect.size = Vector2(400, 40)
	fshape.shape = frect
	floor_body.add_child(fshape)
	host.add_child(floor_body)
	floor_body.global_position = Vector2(700, 700)

	# Block sitting ON that floor, to his right.
	var wall: StaticBody2D = WALL.instantiate()
	host.add_child(wall)
	wall.global_position = Vector2(760, 648)
	_disable_all_areas(wall)
	await get_tree().process_frame

	var player := _make_player(host, Vector2(700, 650))
	GameManager.activate_power_up("pickaxe", 60.0)
	await get_tree().process_frame

	# Drive him rightward INTO the block with real synthetic input — writing
	# player.velocity directly would just be overwritten by his own
	# _physics_process, which recomputes velocity from the input axis.
	Input.action_press("move_right")
	var smashed := false
	for i in range(120):
		if not is_instance_valid(player):
			break
		await get_tree().physics_frame
		if not is_instance_valid(wall):
			smashed = true
			break
	Input.action_release("move_right")

	_check("walking sideways INTO the blue block still smashes it", smashed,
		"the pickaxe's actual designed use (Level 1's overhead walls) must keep working")

	GameManager.deactivate_power_up()
	host.queue_free()
	await get_tree().process_frame

## Stage 3's OTHER standable vanishing block: the Gold Rush timed gate at
## (1520,530), a 60x120 pillar whose top is a ledge. `open()` used to tween the
## StaticBody2D's OWN scale to Vector2.ZERO — the exact degenerate-collider
## freeze that was root-caused and fixed in breakable_block/secret_wall on
## 2026-08-26 but never applied here, leaving the last live instance of it in
## the game. A zero-scale collider is non-invertible, so a player standing on
## the gate when it opens cannot depenetrate: is_on_floor() stops resolving and
## the run hard-freezes with the music still playing.
func _run_timed_gate_never_degenerate() -> void:
	var host := Node2D.new()
	add_child(host)

	var gate: StaticBody2D = preload("res://src/level/timed_door.tscn").instantiate()
	host.add_child(gate)
	gate.global_position = Vector2(0, 600)   # 60x120 -> top ledge at y=540
	gate.open_duration = 0.4
	_disable_all_areas(gate)
	await get_tree().process_frame

	# Settle him onto the gate's roof.
	var player := _make_player(host, Vector2(0, 470))
	for i in range(90):
		await get_tree().physics_frame
		if player.is_on_floor():
			break
	_check("[timed gate] player is standing on the gate before it opens",
		player.is_on_floor(), "(y=%.1f)" % player.global_position.y)

	# Open it under him and watch the WHOLE animation window, not one frame.
	gate.open()
	var min_body_scale := 1.0
	var collider_live_while_shrunk := false
	for i in range(45):
		await get_tree().physics_frame
		if not is_instance_valid(gate):
			break
		min_body_scale = minf(min_body_scale, gate.scale.x)
		var c: CollisionShape2D = null
		for child in gate.get_children():
			if child is CollisionShape2D:
				c = child
		if c != null and not c.disabled and gate.scale.x < 0.9:
			collider_live_while_shrunk = true

	_check("[timed gate] the BODY's scale is never collapsed (no degenerate collider)",
		min_body_scale > 0.9,
		"body scale reached %.3f — scaling the StaticBody2D scales its collider to a non-invertible transform" % min_body_scale)
	_check("[timed gate] no frame has a live collider on a shrunken body",
		not collider_live_while_shrunk,
		"the trap window the founder falls into")
	_check("[timed gate] player is not stranded on the vanished gate",
		is_instance_valid(player) and not player.is_on_floor(),
		"he should simply FALL once the gate stops being a floor")

	host.queue_free()
	await get_tree().process_frame
