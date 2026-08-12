extends Node2D
## Gate for the Part B downward set-pieces — Diamond Vault (S2) + Fort Knox
## (S3). Proves the founder's three hard rules with real physics + geometry:
## CAN ENTER (drop through the mouth and land in the chamber, not the kill
## zone), CAN EXIT (a reachable ladder whose top-out lands on solid ground east
## of the pit), and NO SOFT-LOCK (the vault ladder cannot be destroyed, and the
## exit is never over air — the exact bug that once blocked Stage 2).
##
## Entry is driven with a REAL 32x32 CharacterBody2D falling under the real
## gravity/fall constants (the same stand-in technique the boss gates use) so
## the collision against the chamber floor and the kill band is genuine, not a
## data check. Exit soundness is asserted from geometry (deterministic, no
## fragile headless Input simulation): ladder span, top-out target, and a real
## downward raycast onto the exit segment.
##
## Run: godot --headless res://tests/protocol_vault_test.tscn

const VAULT := preload("res://src/level/protocol_vault.tscn")
const GRAVITY := 1000.0
const MAX_FALL := 720.0
const KILL_BAND_TOP := 825.0  # _setup_kill_zone: kill_zone_y(850)+175-200

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("PROTOCOL VAULT (Diamond Vault + Fort Knox):")
	_test_vault_geometry("Diamond Vault", "diamonds", 100.0)
	_test_vault_geometry("Fort Knox", "gold", 140.0)
	# Real adjacent ground segments (from level_0N_data.tres): [left, right].
	await _test_dropin_and_exit("Diamond Vault", "diamonds", 100.0, Vector2(2450, 650),
		Rect2(2000, 650, 400, 70), Rect2(2500, 650, 500, 70))
	await _test_dropin_and_exit("Fort Knox", "gold", 140.0, Vector2(2690, 650),
		Rect2(2200, 650, 420, 70), Rect2(2760, 650, 460, 70))
	await _test_real_level_integration()
	print("PROTOCOL_VAULT: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

# --- Structure (deterministic) ---------------------------------------------

func _test_vault_geometry(label: String, protocol: String, mouth_width: float) -> void:
	var vault := VAULT.instantiate()
	vault.protocol = protocol
	vault.mouth_width = mouth_width
	vault.global_position = Vector2(1000, 650)
	add_child(vault)
	var bodies: Array = []
	var ladder: Node = null
	for c in vault.get_children():
		if c is StaticBody2D:
			bodies.append(c)
		elif c.is_in_group("ladder"):
			ladder = c
	_check("%s: builds a solid floor + two walls (3 StaticBodies)" % label,
		bodies.size() == 3, "found %d StaticBody children" % bodies.size())
	_check("%s: has an exit ladder" % label, ladder != null)
	if ladder != null:
		_check("%s: exit ladder is NON-destructible (no soft-lock)" % label,
			not bool(ladder.get("destructible")),
			"destructible=%s — a destroyed vault ladder is unrecoverable" % str(ladder.get("destructible")))
		var off: Vector2 = ladder.get("top_exit_offset")
		_check("%s: ladder top_exit_offset is NOT the default (0,-20)" % label,
			not off.is_equal_approx(Vector2(0, -20)),
			"offset=%s — the default lands the top-out over the pit" % str(off))
		_check("%s: ladder hugs the exit-side wall" % label,
			is_equal_approx(ladder.position.x, mouth_width / 2.0 - 22.0),
			"ladder local x=%.1f" % ladder.position.x)
	vault.queue_free()

# --- Real-physics drop-in + geometric exit proof ---------------------------

func _make_segment(seg: Rect2) -> StaticBody2D:
	# Matches level_base._create_platform: body at top-left (x,y), solid w x h.
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector2(seg.position.x, seg.position.y)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(seg.size.x, seg.size.y)
	cs.shape = rect
	cs.position = Vector2(seg.size.x / 2.0, seg.size.y / 2.0)
	body.add_child(cs)
	add_child(body)
	return body

func _make_killband() -> Array:
	# The real full-width kill Area2D (mask 2 = player) at y 825..1225, with a
	# flag set the instant a player-group body enters it.
	var flag := [false]
	var band := Area2D.new()
	band.collision_layer = 0
	band.collision_mask = 2
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8000, 400)
	cs.shape = rect
	band.add_child(cs)
	band.position = Vector2(2500, KILL_BAND_TOP + 200)  # centre of the 825..1225 band
	band.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("player"):
			flag[0] = true)
	add_child(band)
	return [band, flag]

func _make_player(at: Vector2) -> CharacterBody2D:
	var p := CharacterBody2D.new()
	p.collision_layer = 2
	p.collision_mask = 1  # collide with world geometry only
	p.add_to_group("player")
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(32, 32)  # the real player body size
	cs.shape = rect
	p.add_child(cs)
	p.global_position = at
	add_child(p)
	return p

func _test_dropin_and_exit(label: String, protocol: String, mouth_width: float,
		origin: Vector2, left_seg: Rect2, right_seg: Rect2) -> void:
	var seg_l := _make_segment(left_seg)
	var seg_r := _make_segment(right_seg)
	var kb: Array = _make_killband()
	var kill_flag: Array = kb[1]
	var vault := VAULT.instantiate()
	vault.protocol = protocol
	vault.mouth_width = mouth_width
	vault.global_position = origin
	add_child(vault)
	await get_tree().physics_frame
	# Drop the player straight down through the centre of the mouth.
	var player := _make_player(Vector2(origin.x, 560))
	# Fall for ~2s of real physics; drive gravity the way the player does.
	for i in range(120):
		player.velocity.y = minf(player.velocity.y + GRAVITY * (1.0 / 60.0), MAX_FALL)
		player.move_and_slide()
		await get_tree().physics_frame
		if player.get_slide_collision_count() > 0 and absf(player.velocity.y) < 1.0:
			pass  # rested

	var feet: float = player.global_position.y + 16.0
	_check("%s: player DROPS IN and rests on the chamber floor (~800)" % label,
		feet >= 790.0 and feet <= 812.0,
		"feet at %.1f (expected ~800)" % feet)
	_check("%s: player never entered the kill band (drop-in is survivable)" % label,
		not bool(kill_flag[0]),
		"kill band fired — the drop-in fell into the hazard")
	_check("%s: player rests ABOVE the kill band top (%.0f)" % [label, KILL_BAND_TOP],
		feet < KILL_BAND_TOP, "feet %.1f vs band top %.0f" % [feet, KILL_BAND_TOP])

	# --- Exit soundness (geometry) ---
	var ladder: Node = null
	for c in vault.get_children():
		if c.is_in_group("ladder"):
			ladder = c
			break
	_check("%s: exit ladder present after build" % label, ladder != null)
	if ladder != null:
		# Ladder spans from the chamber floor up to the surface, so a player
		# standing on the floor is inside the grab zone.
		_check("%s: ladder grab zone reaches the standing player (climbable)" % label,
			ladder.call("bottom_y") >= feet and ladder.call("top_y") <= 655.0,
			"ladder span [%.0f..%.0f], player feet %.0f" % [ladder.call("top_y"), ladder.call("bottom_y"), feet])
		# Landing is reachable on foot from where the player actually landed.
		var reach: float = absf(player.global_position.x - ladder.global_position.x)
		_check("%s: ladder is reachable on foot from the landing spot" % label,
			reach <= mouth_width, "%.0fpx to the ladder (mouth %.0f)" % [reach, mouth_width])
		# Top-out lands on the EXIT segment, east of the pit, never over air.
		var exit_pt: Vector2 = ladder.call("top_exit_position")
		var mouth_lo: float = origin.x - mouth_width / 2.0
		var mouth_hi: float = origin.x + mouth_width / 2.0
		_check("%s: top-out is NOT over the drop pit" % label,
			exit_pt.x < mouth_lo or exit_pt.x > mouth_hi,
			"exit x=%.0f is inside the mouth [%.0f..%.0f]" % [exit_pt.x, mouth_lo, mouth_hi])
		_check("%s: top-out lands on the exit ground segment" % label,
			exit_pt.x >= right_seg.position.x + 16.0 and exit_pt.x <= right_seg.position.x + right_seg.size.x - 16.0,
			"exit x=%.0f not safely inside seg [%.0f..%.0f]" % [exit_pt.x, right_seg.position.x, right_seg.position.x + right_seg.size.x])
		# A real downward ray from the exit point must hit solid ground close by.
		var space := get_world_2d().direct_space_state
		var q := PhysicsRayQueryParameters2D.create(exit_pt, exit_pt + Vector2(0, 80))
		q.collision_mask = 1
		var hit := space.intersect_ray(q)
		_check("%s: solid ground exists under the top-out point (no soft-lock)" % label,
			not hit.is_empty(),
			"a downward ray from the exit point found no floor")

	player.queue_free(); vault.queue_free(); seg_l.queue_free(); seg_r.queue_free()
	(kb[0] as Node).queue_free()
	await get_tree().physics_frame

# --- Real level integration -------------------------------------------------

func _find_vault(node: Node, protocol: String) -> Node:
	for c in node.get_children():
		if c.get_script() != null and c.get_script().resource_path.ends_with("protocol_vault.gd") \
				and str(c.get("protocol")) == protocol:
			return c
	return null

func _test_real_level_integration() -> void:
	for entry: Array in [["res://src/level/level_02_crystal_caverns.tscn", "diamonds", 100.0],
			["res://src/level/level_03_gold_rush.tscn", "gold", 140.0]]:
		var scene: PackedScene = load(entry[0])
		var lvl := scene.instantiate()
		add_child(lvl)
		# Let _ready()/_setup_depth_routes() build the vault.
		for i in range(4):
			await get_tree().physics_frame
		var vault := _find_vault(lvl, entry[1])
		_check("%s: real level builds its %s vault" % [entry[0].get_file(), entry[1]],
			vault != null)
		if vault != null:
			_check("%s: vault mouth_width matches the level's pit" % entry[0].get_file(),
				is_equal_approx(float(vault.get("mouth_width")), float(entry[2])),
				"mouth_width=%s" % str(vault.get("mouth_width")))
		lvl.queue_free()
		await get_tree().physics_frame
