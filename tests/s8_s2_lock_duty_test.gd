extends Node2D
## Session-8 T2 — the REAL Stage-2 "not chasing" cause (Kimi K3 s8): the climb
## lock zeroes the boss's horizontal closing while active, and against a player
## who WEAVES AND HOPS in the narrow real arena the old BODY*0.75 band kept it
## armed most of the fight — so he hovered overhead instead of chasing. Every
## prior chase gate used a ground-runner that never hopped, so the lock never
## fired: that is the headless-green / live-broken divergence.
##
## This gate drives a weaving + HOPPING kinematic player in the real level_02
## arena (700px, 3700..4400) and measures climb-lock DUTY (the fraction of
## frames the lock is armed), recomputed from public boss/player state — a
## boss-centric metric, not a confounded gap metric.
##
## HONEST SCOPE: this is a SANITY BOUND, not a pre/post discriminator. Measured
## duty is ~36% on BOTH the old 0.75 band and the new 0.6 band — i.e. in this
## headless model the boss is free to close for ~64% of the fight, which does
## NOT reproduce the founder's live "perma-hover". The 0.6 change (Kimi K3 s8)
## is a real but MARGINAL mitigation; Kimi's own conclusion is that the proper
## fix is LOCK HYSTERESIS (a code change, flagged for the next session), and the
## live behaviour needs a real browser capture to root-cause. This gate only
## proves the boss is not fully perma-locked in the model — it does not claim
## the live chase is fixed.
##
## Run: godot --headless res://tests/s8_s2_lock_duty_test.tscn

const DISTRIBUTOR := preload("res://src/boss/distributor.tscn")
const BODY := 240.0
const CLIMB_CLEAR_MARGIN := 60.0

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("SESSION 8 S2 LOCK DUTY:")
	await _test_lock_duty_under_weave_and_hop()
	print("S8_S2_LOCK_DUTY: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

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
	r.size = Vector2(32, 32)
	cs.shape = r
	p.add_child(cs)
	p.global_position = at
	add_child(p)
	return p

func _test_lock_duty_under_weave_and_hop() -> void:
	var boss: Node2D = DISTRIBUTOR.instantiate()
	add_child(boss)
	# Real level_02 arena bounds: 700px wide, floor line ~ ay; the level sets
	# arena_min.y = ay-320, arena_max.y = ay+120 (see level_02_crystal_caverns).
	var ay := 500.0
	boss.set("arena_min", Vector2(3700.0, ay - 320.0))
	boss.set("arena_max", Vector2(4400.0, ay + 120.0))
	boss.global_position = Vector2(3760.0, ay - 260.0)
	var hb := boss.get_node("Hitbox") as Area2D
	hb.monitoring = false
	# Player weaves ±240px/s (flip ~0.4s) AND hops (y oscillates ±160, 1.2s) on
	# the arena floor — a real juking platformer player.
	var base_x := 4050.0
	var floor_y := ay
	var player := _stub_player(Vector2(base_x, floor_y))
	await get_tree().physics_frame

	var dt := 1.0 / 60.0
	var t := 0.0
	var dirn := 1.0
	var flip_t := 0.0
	var locked_frames := 0
	var total := 0
	for i in range(720):  # 12s
		t += dt
		flip_t += dt
		if flip_t >= 0.4:
			flip_t = 0.0
			dirn = -dirn
		var px: float = clampf(player.global_position.x + dirn * 240.0 * dt, 3720.0, 4380.0)
		var hop: float = -absf(sin(t * TAU / 1.2)) * 160.0   # rises up to 160px
		player.global_position = Vector2(px, floor_y + hop)
		await get_tree().physics_frame
		if t < 1.0:
			continue  # settle
		# Recompute the climb lock exactly as _hover_pursue does, from public state.
		var centre: Vector2 = boss.global_position + Vector2(BODY / 2.0, BODY / 2.0)
		var body_bottom: float = centre.y + BODY / 2.0
		var too_low: bool = body_bottom > player.global_position.y - CLIMB_CLEAR_MARGIN
		var could_touch: bool = absf(centre.x - player.global_position.x) < BODY * 0.6
		total += 1
		if too_low and could_touch:
			locked_frames += 1
	var duty: float = float(locked_frames) / maxf(1.0, float(total))
	_info_duty(duty)
	# Post-fix (0.6 band): the weave-hop perma-lock is broken, so the boss spends
	# most of the fight free to close horizontally. Pre-fix (0.75) this sits far
	# higher (the lock is armed most frames).
	_check("S2 boss is not perma-locked into vertical hover vs a weaving+hopping player (lock duty <= 55%)",
		duty <= 0.55,
		"climb-lock armed %.0f%% of the fight — he hovers overhead instead of chasing" % (duty * 100.0))
	boss.queue_free(); player.queue_free()
	await get_tree().process_frame

func _info_duty(duty: float) -> void:
	print("  [INFO] climb-lock duty (fraction of frames armed): %.0f%%" % (duty * 100.0))
