extends Node
## Founder, 2026-08-20 (shot_1): "He is now stuck here as he tries jumping up and
## down and hitting his head on the platform!!!! Give him more intelligence to
## use the block to launch himself over the platform or to double jump!"
##
## The failure is a LOOP, not a single bad jump: the Auditor only ever leapt from
## the floor (~196px of clearance), so a terrace taller than that made his
## "player is above me" rule re-fire every 0.9s forever, driving his head into
## the same platform underside from the same x every time.
##
## This gate reproduces exactly that trap — a boss penned under a solid ceiling
## with the player above him — and asserts he does not stay in one column
## head-banging. It deliberately does NOT assert "he reaches the player": the
## honest fix is that he SEARCHES (sidesteps toward a gap) and can double-jump
## once he finds one, not that he teleports up.
##
## Run: godot --headless res://tests/auditor_platform_intelligence_test.tscn

const AUDITOR := preload("res://src/boss/auditor.tscn")

const FLOOR_Y := 700.0
const BOSS_X := 1000.0
## Ceiling sits 150px above his head — INSIDE a single leap's 196px reach, so a
## naive boss bonks it; the gap is off to the east so a searching boss escapes.
const CEILING_Y := 380.0
const CEILING_X0 := 700.0
const CEILING_X1 := 1240.0

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("AUDITOR PLATFORM INTELLIGENCE:")
	await _run()
	print("AUDITOR_PLATFORM_INTELLIGENCE: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

## Solid static geometry on the World layer (what the boss's mask 13 reads).
func _slab(x0: float, x1: float, y: float, h: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(x1 - x0, h)
	cs.shape = r
	body.add_child(cs)
	body.position = Vector2((x0 + x1) * 0.5, y + h * 0.5)
	add_child(body)
	return body

func _run() -> void:
	_slab(200.0, 2000.0, FLOOR_Y, 80.0)          # ground
	_slab(CEILING_X0, CEILING_X1, CEILING_Y, 60.0)  # the platform he bonks

	var boss: Node2D = AUDITOR.instantiate()
	add_child(boss)
	boss.global_position = Vector2(BOSS_X, FLOOR_Y - 220.0)

	# Player parked ABOVE the ceiling — the exact condition that arms his
	# "leap toward a player above" rule.
	var stub := GDScript.new()
	stub.source_code = "extends CharacterBody2D\nfunc take_damage(_a: int) -> void:\n\tpass\n"
	stub.reload()
	var player := CharacterBody2D.new()
	player.set_script(stub)
	player.collision_layer = 2
	player.collision_mask = 0
	player.add_to_group("player")
	var pcs := CollisionShape2D.new()
	var pr := RectangleShape2D.new()
	pr.size = Vector2(32, 32)
	pcs.shape = pr
	player.add_child(pcs)
	add_child(player)
	player.global_position = Vector2(BOSS_X + 60.0, CEILING_Y - 140.0)

	# Contact would restart the run and tear this scene down mid-test.
	var hb := boss.get_node_or_null("Hitbox")
	if hb != null:
		hb.set_deferred("monitoring", false)

	var min_x: float = INF
	var max_x: float = -INF
	var ceiling_hits: int = 0
	var was_ceiling := false
	for _f in range(420):   # 7s
		if not is_instance_valid(boss):
			break
		player.global_position = Vector2(BOSS_X + 60.0, CEILING_Y - 140.0)
		var cx: float = boss.global_position.x
		min_x = minf(min_x, cx)
		max_x = maxf(max_x, cx)
		var on_ceil: bool = boss.is_on_ceiling()
		if on_ceil and not was_ceiling:
			ceiling_hits += 1
		was_ceiling = on_ceil
		await get_tree().physics_frame

	var span: float = max_x - min_x
	print("  [INFO] boss x-span under the ceiling: %.0f px (ceiling hits: %d)" % [span, ceiling_hits])

	# THE ACTUAL DEFECT: staying in one column, re-bonking the same spot. A boss
	# that searches sideways for the platform edge covers real ground. 150px is
	# well under the 540px-wide ceiling but far more than the few px of jitter a
	# stuck boss produces.
	_check("Auditor does not stay pinned in one column head-banging (span %.0f >= 150px)" % span,
		span >= 150.0,
		"span=%.0f px — he is still jumping into the same spot" % span)

	# And he must not be welded to the ceiling for the whole run.
	_check("Auditor is not permanently jammed against the ceiling (hits=%d)" % ceiling_hits,
		ceiling_hits < 30,
		"ceiling_hits=%d — repeated head-banging" % ceiling_hits)

	boss.queue_free()
	player.queue_free()
	await get_tree().process_frame
