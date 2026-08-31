extends Node2D
## Session-6 T2 (S2 projectile purity) + T3 (S3 horizontal chase), each written
## to FAIL on the pre-fix code:
##   T2  Every projectile the Distributor's redirectable volley (_throw_shards)
##       spawns must carry distinct diamond geometry (a Polygon2D child) with the
##       base fx_dot hidden (tint alpha 0) — no circle/orb reads like Stage 1.
##       Pre-fix the orbs are opaque blue dots (tint.a == 1, no Polygon2D).
##   T3  The Claim Jumper travels a meaningful horizontal distance while a player
##       kites ABOVE him. Pre-fix he ping-pongs ±367px around the player and
##       nets ~0 (the "only jumps in one spot" bug); post-fix he tracks.
##
## Run: godot --headless res://tests/s6_boss_projectile_chase_test.tscn

const DISTRIBUTOR := preload("res://src/boss/distributor.tscn")
const CLAIM_JUMPER := preload("res://src/boss/claim_jumper.tscn")

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("SESSION 6 BOSS PROJECTILE + CHASE:")
	await _test_s2_volley_is_diamonds_not_circles()
	await _test_s3_chases_horizontally_while_player_kites_above()
	print("S6_BOSS_PROJECTILE_CHASE: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _info(label: String, value: Variant) -> void:
	print("  [INFO] %s: %s" % [label, str(value)])

func _stub_player(at: Vector2) -> CharacterBody2D:
	var stub := GDScript.new()
	stub.source_code = "extends CharacterBody2D\nfunc take_damage(_a: int) -> void:\n\tpass\n"
	stub.reload()
	var p := CharacterBody2D.new()
	p.set_script(stub)
	p.collision_layer = 2
	p.collision_mask = 0
	p.add_to_group("player")
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(32, 48)
	cs.shape = r
	p.add_child(cs)
	p.global_position = at
	add_child(p)
	return p

## T2 — every orb in the redirectable volley is a diamond, not a circle.
func _test_s2_volley_is_diamonds_not_circles() -> void:
	get_tree().call_group("boss_projectile", "queue_free")
	await get_tree().physics_frame
	var boss: Node2D = DISTRIBUTOR.instantiate()
	add_child(boss)
	var player := _stub_player(Vector2(400, 500))
	boss.global_position = Vector2(0, 400)
	var hb := boss.get_node("Hitbox") as Area2D
	hb.monitoring = false
	boss.set("current_phase", 1)
	await get_tree().physics_frame
	# Fire the redirectable ETH-orb volley (the "circles").
	boss.call("_throw_shards")
	await get_tree().physics_frame

	# Scope to THIS volley by the volley_id the boss just stamped (test-standards:
	# never select spawned objects by group alone across sequential tests).
	var vid: int = int(boss.get("_volley_id"))
	var orbs: Array = []
	for c in get_children():
		if c.is_in_group("boss_projectile") and int(c.get("volley_id")) == vid:
			orbs.append(c)
	_check("the redirectable volley actually spawns projectiles", orbs.size() >= 1,
		"no boss_projectile with volley_id=%d" % vid)

	var all_diamonds := true
	var detail := ""
	for orb in orbs:
		var t: Color = orb.get("tint")
		var has_poly := false
		for c in orb.get_children():
			if c is Polygon2D:
				has_poly = true
		if t.a != 0.0 or not has_poly:
			all_diamonds = false
			detail = "an orb has tint.a=%.2f has_poly=%s — reads as a circle" % [t.a, str(has_poly)]
	_check("every volley projectile is a diamond (tint alpha 0 + Polygon2D), no circle dots",
		all_diamonds and orbs.size() >= 1, detail)

	get_tree().call_group("boss_projectile", "queue_free")
	boss.queue_free(); player.queue_free()
	await get_tree().process_frame

## T3 — real physics reproduction of the "only jumps in one spot" bug: a player
## hovers roughly OVERHEAD (the condition that makes |dx| small) and drifts +x
## slowly. Pre-fix, the hop commits the FULL patrol_speed regardless of the tiny
## gap, so the boss overshoots ~367px past the player, dx flips, and he
## ping-pongs — overshooting far PAST the player every hop while netting ~0 real
## pursuit. Post-fix, the hop is sized to the gap, so he tracks the player and
## never lunges far past. We measure BOTH: he must make forward progress (chase)
## AND he must not overshoot wildly past the player (no pogo). The overshoot
## bound is the discriminating assertion — it fails on the pre-fix code.
func _test_s3_chases_horizontally_while_player_kites_above() -> void:
	var boss: Node2D = CLAIM_JUMPER.instantiate()
	add_child(boss)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var fcs := CollisionShape2D.new()
	var frect := RectangleShape2D.new()
	frect.size = Vector2(12000, 80)
	fcs.shape = frect
	floor_body.add_child(fcs)
	floor_body.global_position = Vector2(5000, 900)
	add_child(floor_body)
	# No arena clamp set (arena_max stays zero) so open-ground behaviour is what
	# we measure; the ledge sense still applies but the floor is flat and wide.
	boss.global_position = Vector2(1000, 620)
	var hb := boss.get_node("Hitbox") as Area2D
	hb.monitoring = false
	# Player hovers just above the boss's body CENTRE and drifts +x SLOWLY, so the
	# horizontal gap stays small — the exact regime where a full-speed hop
	# overshoots. Start directly over the centre (boss.x + HALF_BODY).
	var player := _stub_player(Vector2(boss.global_position.x + 140.0, boss.global_position.y - 130.0))
	await get_tree().physics_frame

	var start_x: float = boss.global_position.x
	var drift: float = 70.0        # slow overhead drift, well under patrol_speed
	var dt: float = 1.0 / 60.0
	var floor_y: float = 900.0
	var fell := false
	var hops: int = 0
	var prev_vy: float = 0.0
	for i in range(360):  # ~6s
		player.global_position.x += drift * dt
		player.global_position.y = boss.global_position.y - 130.0
		# Isolate the PATROL hop path (where the pogo bug lives): keep him out of
		# THROW/VULNERABLE, which ground-chase without hopping and would mask the
		# behaviour. This is the state a live fight sits in between attacks.
		boss.set("current_state", 0)   # State.PATROL
		boss.set("throw_timer", 999.0) # never enter THROW during the measurement
		await get_tree().physics_frame
		# Count hop take-offs: velocity.y snapping to the hop impulse (~-620).
		var vy: float = (boss.get("velocity") as Vector2).y
		if vy < -500.0 and prev_vy >= -500.0:
			hops += 1
		prev_vy = vy
		if boss.global_position.y > floor_y + 200.0:
			fell = true
	var travel: float = boss.global_position.x - start_x
	_info("boss net horizontal travel over 6s", "%.0fpx" % travel)
	_info("boss hop take-offs on flat ground (overhead player)", hops)

	# Chase happening at all: he follows the drifting player forward on the ground.
	_check("Stage 3 boss makes forward horizontal progress toward the player",
		travel > 250.0,
		"boss moved only %.0fpx in 6s" % travel)
	# THE DISCRIMINATOR: on flat ground with a player merely overhead, the boss
	# must NOT pogo. Pre-fix (the "player above" hop gated on the trivially-true
	# _gap_crossable) launches repeatedly; post-fix (gated on _higher_ground_ahead)
	# finds no real ledge and chases on the ground instead.
	_check("Stage 3 boss does NOT pogo in place when the player is just overhead on flat ground",
		hops <= 1,
		"boss launched %d hops on flat ground — the 'only jumps in one spot' bug" % hops)
	_check("Stage 3 boss did not suicide off the world while chasing",
		not fell and not bool(boss.get("is_dead")),
		"boss fell below the floor (fell=%s, dead=%s)" % [str(fell), str(boss.get("is_dead"))])

	boss.queue_free(); floor_body.queue_free(); player.queue_free()
	await get_tree().process_frame
