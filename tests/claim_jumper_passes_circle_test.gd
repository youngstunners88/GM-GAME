extends Node
## Founder, 2026-08-22 (~50th ask): "Why the fuck don't you make the fucking
## boss3 move?!" — he circles the MINECART / GOLD band in the east half of the
## Stage 3 arena and says the boss never gets past it.
##
## HIS ACCEPTANCE BAR, ENCODED: boss CENTRE X must cross the circled band. He
## rejects any metric that shows bounded Y while X is frozen, so this gate
## asserts world X and freeze duration only — no altitude, no hop counts.
##
## ROOT CAUSE (measured, real level_03 arena, player parked at x=4390):
## `level_base.gd::arm_boss_arena_seal` builds the EAST wall via
## `_create_wall(end_x, 400, 20, 600)` with NO `player_only` flag, so it kept
## the default collision_layer 1 ("World") — which both bosses mask (13 =
## 1|4|8). The wall built to stop the PLAYER leaving was solid to the BOSS.
## His right edge pinned at exactly 4390 (the wall spans 4390-4410) with
## velocity.x = 0 and he sat FROZEN FOR 13.05s of a 15s run, centre stuck at
## 4250 — 126px short of the 4376 his own `_clamp_to_arena()` allows, and
## squarely inside the circled band.
##
## Kimi K3 confirmed the geometry independently (body span [4236,4516] vs wall
## face 4390 → necessarily overlaps by 126px) and confirmed that raising HOP
## velocity cannot touch it: horizontal problem, vertical constant.
##
## Grok 4.6 rejected the alternative "suppress the hop at the boundary" fix:
## `_clamp_to_arena()` zeroes velocity.x, so removing the hop trades a pogo for
## a permanent freeze. The measurement agreed — he was already frozen, not
## pogoing. So the fix is the wall layer, not boss logic.
##
## Run: godot --headless res://tests/claim_jumper_passes_circle_test.tscn

const LEVEL := preload("res://src/level/level_03_gold_rush.tscn")
## The founder's circled region (minecart / gold), world x.
const CIRCLE_LO := 4150.0
const CIRCLE_HI := 4300.0
const HALF_BODY := 140.0

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("CLAIM JUMPER PASSES CIRCLE:")
	await _run()
	print("CLAIM_JUMPER_PASSES_CIRCLE: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _run() -> void:
	var level := LEVEL.instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame

	var player := get_tree().get_first_node_in_group("player")
	player.global_position = Vector2(4000.0, 500.0)
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

	var max_centre: float = -INF
	var frozen: int = 0
	var max_frozen: int = 0
	var prev: float = boss.global_position.x
	var n: int = 900  # 15s

	for f in range(n):
		# Park the player at the FAR EAST edge — the exact scenario the founder
		# describes. Anything that stops the boss here is terrain, not indecision.
		player.global_position = Vector2(4390.0, 500.0)
		if not is_instance_valid(boss):
			_check("Claim Jumper survives the whole run", false, "boss freed mid-run")
			return
		var centre: float = boss.global_position.x + HALF_BODY
		max_centre = maxf(max_centre, centre)
		if absf(boss.global_position.x - prev) < 0.5:
			frozen += 1
			max_frozen = maxi(max_frozen, frozen)
		else:
			frozen = 0
		prev = boss.global_position.x
		await get_tree().physics_frame

	print("  [INFO] max_centre_x=%.0f (circle band %.0f-%.0f) max_frozen=%.2fs"
		% [max_centre, CIRCLE_LO, CIRCLE_HI, max_frozen / 60.0])

	# THE FOUNDER'S BAR: centre must get PAST the circled band, not merely into it.
	_check("Boss centre X gets past the circled minecart/gold band (> %.0f)" % CIRCLE_HI,
		max_centre > CIRCLE_HI,
		"centre only reached %.0f — still parked on the circle" % max_centre)
	_check("Boss is never frozen in place for long (< 3s)",
		max_frozen < 180,
		"frozen %.2fs — walled again" % (max_frozen / 60.0))

	boss.queue_free()
	level.queue_free()
	await get_tree().process_frame
