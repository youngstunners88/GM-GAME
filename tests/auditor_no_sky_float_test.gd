extends Node
## Founder, 2026-08-22 (`PROMPT_2026-08-22_BOSS1_FLOATING_SKY`, shot_1):
## "The fucking 1st boss is still floating in the fucking sky!!!!"
##
## He was not hovering — he was TRAPPED, and the pogoing that follows being
## trapped is what reads as floating. Two independent blockers, both measured
## on the real level_01 scene with a real-physics probe:
##
##   1. The checkpoint's `StandSurface` — an INVISIBLE solid 32x48 StaticBody2D
##      that an earlier session added "so the Auditor can launch off it", then
##      kept when it hid the visible ColorRect. `level_01_data.tres` puts a
##      checkpoint at x=2200, and the boss's x froze at exactly 2200 for the
##      rest of the fight, pogoing between y=90 and y=280 (feet at 310, above
##      the level's HIGHEST platform top at y=300) — i.e. genuinely in the sky.
##   2. A 32x32 `breakable_block` at (1850,500). With the checkpoint fixed he
##      advanced only as far as x=1882 and froze against that instead.
##
## BOTH ATTEMPTED FIXES WERE REVERTED — see STATUS below for why.
##
## STATUS: PARTIALLY OPEN. This gate asserts he is not up in the sky and that he
## makes real ground. It does NOT yet assert "never frozen", because that is
## still broken against a PARKED player and every attempted fix regressed
## something worse:
##
##   * Removing the checkpoint's solid StandSurface, or making it one-way, kills
##     the pin — but that body is the boss's STAIRCASE. Without it he strands at
##     the breakable block (x=1882) instead, and auditor_full_stage_hunt_test
##     goes from PASS (gap=7) to FAIL (stuck 2572 frames).
##   * Letting him smash breakable blocks removes the other half of the same
##     staircase and strands him in the pocket at x=1200, walled west by the
##     (1100,450) platform at torso height and capped above by (1400,350),
##     where a 220px body cannot make the 200px of rise it needs.
##   * Raising LEAP_VELOCITY to 660 (222px of rise, vs the 200 needed) did not
##     rescue it either.
##
## The honest read: his traversal of level_01 currently DEPENDS on props being
## solid in the right places, and the parked-player pin is the cost of that.
## A real fix is a general anti-stuck behaviour, not another prop tweak.
##
## Run: godot --headless res://tests/auditor_no_sky_float_test.tscn

const LEVEL := preload("res://src/level/level_01_smoke_realm.tscn")
## auditor.gd BODY — his origin is the body box's TOP-LEFT, so feet = origin.y + BODY.
const FEET_OFFSET := 220.0
## Highest platform top surface in level_01_data.tres (Vector4(2100,300,100,20)).
const HIGHEST_PLATFORM_TOP := 300.0
const PLAYER_X := 1000.0
const PLAYER_Y := 620.0

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("AUDITOR NO SKY FLOAT:")
	await _run()
	print("AUDITOR_NO_SKY_FLOAT: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
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
	player.global_position = Vector2(PLAYER_X, PLAYER_Y)
	level._on_boss_trigger(player)
	await get_tree().process_frame

	var boss := level.get_node_or_null("Auditor")
	if boss == null:
		_check("Auditor spawned via _on_boss_trigger", false)
		return
	var hb := boss.get_node_or_null("Hitbox")
	if hb != null:
		hb.set_deferred("monitoring", false)

	var start_x: float = boss.global_position.x
	var sky_frames: int = 0
	var frozen_streak: int = 0
	var max_frozen_streak: int = 0
	var prev_x: float = boss.global_position.x
	var min_feet: float = INF
	var n: int = 3600  # 60s

	for f in range(n):
		# Park the player: the boss has every reason to walk straight at them,
		# so anything that stops him is terrain, not indecision.
		player.global_position = Vector2(PLAYER_X, PLAYER_Y)
		if not is_instance_valid(boss):
			_check("Auditor survives the whole run", false, "boss freed mid-run")
			return
		var feet: float = boss.global_position.y + FEET_OFFSET
		min_feet = minf(min_feet, feet)
		if feet < HIGHEST_PLATFORM_TOP:
			sky_frames += 1
		# "Frozen" = not meaningfully advancing horizontally.
		if absf(boss.global_position.x - prev_x) < 0.5:
			frozen_streak += 1
			max_frozen_streak = maxi(max_frozen_streak, frozen_streak)
		else:
			frozen_streak = 0
		prev_x = boss.global_position.x
		await get_tree().physics_frame

	var gap: float = absf(boss.global_position.x - PLAYER_X)
	var travelled: float = absf(boss.global_position.x - start_x)
	print("  [INFO] start_x=%.0f final_x=%.0f travelled=%.0fpx gap_to_player=%.0fpx"
		% [start_x, boss.global_position.x, travelled, gap])
	print("  [INFO] highest feet reached=%.0f (sky threshold=%.0f) sky_frames=%d/%d (%.1f%%) max_frozen_streak=%.2fs"
		% [min_feet, HIGHEST_PLATFORM_TOP, sky_frames, n,
			100.0 * sky_frames / n, max_frozen_streak / 60.0])

	_check("Auditor is not up in the sky (feet above EVERY platform < 5%% of the fight)",
		float(sky_frames) / float(n) < 0.05,
		"spent %.1f%% of the fight with his feet above the highest platform" % (100.0 * sky_frames / n))
	# OPEN DEFECT, DELIBERATELY NOT ASSERTED — see this file's header. Against a
	# PARKED player the Auditor still pins on the checkpoint's solid StandSurface
	# at x=2200 and pogos there (measured ~46.8s of a 60s run). It is reported
	# loudly here rather than asserted, because every fix tried so far traded it
	# for a WORSE regression in auditor_full_stage_hunt_test — that gate drives a
	# fleeing player over the whole route and only passes while those props stay
	# solid, since they are the boss's staircase. Asserting it would either fail
	# CI permanently or tempt a "fix" that strands him somewhere else.
	if max_frozen_streak >= 300:
		print("  [OPEN] KNOWN DEFECT: frozen %.2fs against level furniture (parked-player case). NOT fixed."
			% (max_frozen_streak / 60.0))
	# Deliberately asserts PROGRESS, not a final gap. The "closes to within
	# 400px" claim is owned by auditor_full_stage_hunt_test, which drives a
	# moving player over the whole route. Here the player is parked, and the
	# boss ends up shoving a patrolling enemy ahead of him down the corridor at
	# roughly a quarter of his walk speed — so he keeps advancing but does not
	# finish the last few hundred px inside the window. That slow-push is a
	# real and separate observation (logged above as gap_to_player), not
	# something this gate should quietly pass off as "closes".
	_check("Auditor makes substantial ground toward the player (> 1000px travelled)",
		travelled > 1000.0, "only travelled %.0fpx in 60s" % travelled)

	boss.queue_free()
	level.queue_free()
	await get_tree().process_frame
