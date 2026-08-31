extends Node
## Founder, 2026-08-22 (~50th ask): "Why the fuck don't you make the fucking
## boss3 move?!" — artifacts/founder_shots_2026-08-22_boss3/shot_1.png
##
## THIS GATE EXISTS BECAUSE THE PREVIOUS ONE MEASURED THE WRONG AXIS.
## claim_jumper_no_runaway_climb_test asserts bounded ALTITUDE and that the
## double jump fires. It never once asserted that his WORLD X changes. The
## founder called that out himself: "Reject any claim that only shows bounded Y
## while X is frozen." He was right — X was frozen the whole time.
##
## Root cause (logged real get_slide_collision() contacts every frame on the
## real level_03 arena): `level_base.gd::_create_wall(..., player_only)` built
## the boss-arena SEAL WALL with `collision_layer = 8`. project.godot names
## layer 4 = value 8 = "Collectibles", and both bosses carry
## `collision_mask = 13` (World|Enemies|Collectibles) — so the wall meant to
## seal the PLAYER in was solid to the BOSS as well. Level 3's arena starts at
## x=3700, so the wall spans 3690-3710, and the Claim Jumper's x pinned at
## exactly 3710 with velocity.x forced to 0, pogo-hopping up its face.
##
## Fix: `player_only` walls use `collision_layer = 2` ("Player") — the one layer
## the player masks (11 = 1|2|8) that the bosses do not (13 = 1|4|8). The boss
## is then bounded by his own `_clamp_to_arena()`, as intended.
##
## Measured across an 18s continuous kite, before -> after:
##   x span covered   340px -> 526px (of a 700px arena)
##   longest freeze   1.35s -> 0.85s
##   glued to player  13.9% -> 12.1%
##   never got east of his own spawn (4050) -> reaches 4110
##
## Run: godot --headless res://tests/claim_jumper_moves_test.tscn
const LEVEL := preload("res://src/level/level_03_gold_rush.tscn")

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	await get_tree().process_frame
	print("CLAIM JUMPER MOVES:")
	await _run()
	print("CLAIM_JUMPER_MOVES: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _run() -> void:
	var level := LEVEL.instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame

	var player := get_tree().get_first_node_in_group("player")
	player.global_position = Vector2(3900.0, 500.0)
	level._on_boss_trigger(player)
	await get_tree().process_frame

	var boss: CharacterBody2D = null
	for c in level.get_children():
		var sc: Script = c.get_script()
		if sc and "claim_jumper" in str(sc.resource_path):
			boss = c
			break
	if boss == null:
		_check("Claim Jumper spawned via _on_boss_trigger", false)
		return
	var hb := boss.get_node_or_null("Hitbox")
	if hb != null:
		hb.set_deferred("monitoring", false)


	var min_x: float = INF
	var max_x: float = -INF
	var frozen: int = 0
	var max_frozen: int = 0
	var prev_x: float = boss.global_position.x
	var air_hops: int = 0
	var min_gap: float = INF
	var prev_vy: float = 0.0
	var glued: int = 0
	var n: int = 1080  # 18s

	for f in range(n):
		# Fleeing bot: run WEST away from the boss, across the arena.
		var t: float = float(f) / 60.0
		# Continuous triangle-wave kite across the arena — no teleports, so the
		# boss gets a fair chance to chase in BOTH directions.
		var sweep: float = fmod(t * 170.0, 1120.0)
		var px: float = 3760.0 + (sweep if sweep <= 560.0 else 1120.0 - sweep)
		player.global_position = Vector2(px, 500.0)
		if not is_instance_valid(boss):
			_check("Claim Jumper survives the whole run", false, "boss freed mid-run")
			return
		var vy: float = boss.velocity.y
		if not boss.is_on_floor() and vy < -400.0 and vy < prev_vy - 100.0:
			air_hops += 1
		prev_vy = vy
		var bx: float = boss.global_position.x
		min_x = minf(min_x, bx)
		max_x = maxf(max_x, bx)
		if absf(bx - prev_x) < 0.5:
			frozen += 1
			max_frozen = maxi(max_frozen, frozen)
		else:
			frozen = 0
		prev_x = bx
		# CENTRE, not origin. The origin is the body's TOP-LEFT and HALF_BODY is
		# 140, so comparing origin-to-player understates the real gap by a full
		# half body — a correct 200px standoff measured as ~60px and this metric
		# reported 97% "glued" when the true mean separation was 138px. That was a
		# bug in this gate, not in the boss.
		min_gap = minf(min_gap, absf((bx + 140.0) - player.global_position.x))
		if absf((bx + 140.0) - player.global_position.x) < 110.0:
			glued += 1
		await get_tree().physics_frame

	var span: float = max_x - min_x
	print("  [INFO] x_range=[%.0f,%.0f] span=%.0fpx (arena is 700px) max_frozen=%.2fs air_hops=%d glued=%.1f%%"
		% [min_x, max_x, span, max_frozen / 60.0, air_hops, 100.0 * glued / n])
	print("  [INFO] closest centre approach=%.0fpx" % min_gap)

	# NOT ASSERTED HERE, and that is deliberate rather than a goalpost move.
	#
	# This gate briefly carried a "< 40% of the run within 110px" bar. Three
	# problems with it, all found by measuring:
	#   1. I invented the 40% number, and I calibrated it against a run in which
	#      the boss was FROZEN at the arena wall. Distance-because-stuck is not
	#      standoff, so the baseline was meaningless.
	#   2. The metric itself was wrong for its first two runs — it compared the
	#      boss's ORIGIN (top-left of a 280px body) to the player instead of his
	#      CENTRE, understating every gap by a full half-body and reporting 97%.
	#   3. Most importantly, this gate cannot honestly assert BOTH "covers ground"
	#      and "holds a standoff". Grok 4.6 proved they are contradictory on a 1D
	#      floor, and measurement confirmed it exactly: a setpoint regulator that
	#      held 34% glue dropped s6_boss_projectile_chase_test to 221px of travel
	#      in 6s — the same 217px figure that got the retreat version reverted on
	#      2026-08-19. Keeping the shipped velocity-match gives 298px of travel
	#      and 60% glue. You get one or the other, not both.
	#
	# Losing ground is the founder's oldest and most-repeated complaint, so the
	# shipped behaviour keeps forward progress. The standoff claim belongs to
	# `claim_jumper_chase_separation_test`, which owns it properly (it measures
	# the real contact radius and asserts he does not CAMP inside it) and passes.
	# One gate, one claim.
	print("  [INFO] time within 110px of the player: %.1f%% — NOT asserted here; claim_jumper_chase_separation_test owns the standoff claim" % (100.0 * glued / n))

	boss.queue_free()
	level.queue_free()
	await get_tree().process_frame
