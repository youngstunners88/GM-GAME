extends Node
## T2 REPRODUCTION — "player collects first diamond (often via candle bounce),
## then the game/section resets, but the diamond stays already claimed... I've
## told you about this before!!!"
##
## `tests/blaze_claim_reset_test.gd` already covers this scenario and passes —
## but it does so by calling `run.call("_crash")` and then SYNTHESISING the
## diamond's pickup with `second.body_entered.emit(player)` in the very next
## line. `.emit()` invokes the connected handler synchronously, in the exact
## order the test code calls it in. That proves the guard is CORRECT for the
## one ordering it constructs; it does not prove the guard holds under REAL
## physics, where the candle and diamond are separate Area2D nodes 20px apart
## (x=420, x=440) and the physics server — not the test — decides which
## `body_entered` fires first when the player's real collision shape sweeps
## through both in one `move_and_slide()` step.
##
## This drives the actual player through the actual candle+diamond pair with
## real physics, repeatedly — the founder's "Attempt 17" implies at least 16
## prior crash cycles in the same session before the desync became visible —
## and checks after EVERY cycle whether the counter and the token's visible
## state agree. A single lucky pass proves nothing; this runs enough cycles
## that a race with any real probability of firing would show up.

const BLAZE_RUSH := preload("res://src/dashmode/blaze_rush.tscn")
const CYCLES: int = 30
const MAX_FRAMES_PER_CYCLE: int = 240   # ~4s at 60Hz — generous vs the ~1.4s run to x=440

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("BLAZE DIAMOND BOUNCE REPRO:")
	await _run()
	await _test_legitimate_pickup_still_counts()
	await _test_fast_diagonal_corner_clip_still_counts()
	print("BLAZE_DIAMOND_BOUNCE_REPRO: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

## THE OTHER HALF OF THE PROOF. The stale-pickup fix rejects a claim that
## arrives with the player far from the token — it must NOT also reject a
## real one. Drop the player exactly where a token is (the last one on the
## course, well clear of any candle/fud_wall so a crash can't confound the
## result) and let REAL physics — not `.emit()` — detect the overlap, same
## as every actual pickup in play does.
func _test_legitimate_pickup_still_counts() -> void:
	GameManager.dash_return = {
		"scene_path": "res://src/level/level_01_smoke_realm.tscn",
		"position": Vector2(500, 400),
		"level_index": 1,
	}
	var run: Node2D = BLAZE_RUSH.instantiate()
	add_child(run)
	await get_tree().process_frame
	await get_tree().process_frame

	var tokens: Array = run.get("_smoke_tokens")
	if tokens.is_empty():
		_check("a real, un-crashed pickup still counts", false, "no tokens built")
		run.queue_free()
		return
	var target: Area2D = tokens[tokens.size() - 1]
	var player: CharacterBody2D = run.get("_player")
	player.global_position = target.global_position

	var picked := false
	for f in range(30):
		await get_tree().physics_frame
		if int(run.get("_smoke_this_attempt")) > 0:
			picked = true
			break

	_check("a real, un-crashed pickup still counts",
		picked, "never registered in 30 real-physics frames while standing on the token")
	run.queue_free()
	await get_tree().process_frame

## Review (Fable-5) flagged that STALE_PICKUP_SLACK's original value (24) left
## only ~7px of margin against the worst-case LEGITIMATE first-overlap
## distance for a player striking a token at the CORNER of its collision box
## while falling fast — exactly the situation a token positioned above ground
## level invites. Raised the slack to 60; this proves the raise actually
## covers a real fast-diagonal approach under real physics, not just an
## arithmetic estimate.
func _test_fast_diagonal_corner_clip_still_counts() -> void:
	GameManager.dash_return = {
		"scene_path": "res://src/level/level_01_smoke_realm.tscn",
		"position": Vector2(500, 400),
		"level_index": 1,
	}
	var run: Node2D = BLAZE_RUSH.instantiate()
	add_child(run)
	await get_tree().process_frame
	await get_tree().process_frame

	var tokens: Array = run.get("_smoke_tokens")
	if tokens.is_empty():
		_check("fast diagonal corner-clip pickup still counts", false, "no tokens built")
		run.queue_free()
		return
	# A token mid-course, away from any candle, so a crash can't confound
	# whether the pickup was rejected by the stale-signal guard or just never
	# happened at all.
	var target: Area2D = tokens[min(3, tokens.size() - 1)]
	var player: CharacterBody2D = run.get("_player")
	# Approach from above-left at a steep diagonal, already falling hard (as
	# if mid-arc from a jump) — the corner of the player's 24x24 box is what
	# reaches the token's circle first, which is exactly the geometry that
	# minimises the centre-to-centre distance margin at first contact. Only
	# position + starting velocity are set here; the run's OWN
	# _physics_process drives movement/gravity/collision every frame after
	# this exactly like it does for a real player, so this is real physics,
	# not a hand-rolled substitute that could fight or duplicate it.
	player.global_position = target.global_position + Vector2(-40.0, -60.0)
	# RUN_SPEED (320.0) hardcoded here rather than read off `run` — GDScript
	# constants are NOT reachable via Node.get() (a known trap in this
	# project; it silently returns null rather than erroring).
	player.velocity = Vector2(320.0, 700.0)

	var picked := false
	for f in range(20):
		await get_tree().physics_frame
		if int(run.get("_smoke_this_attempt")) > 0:
			picked = true
			break

	_check("a fast diagonal corner-clip pickup still counts",
		picked, "never registered — the raised STALE_PICKUP_SLACK may still be too tight")

	run.queue_free()
	await get_tree().process_frame

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _run() -> void:
	GameManager.dash_return = {
		"scene_path": "res://src/level/level_01_smoke_realm.tscn",
		"position": Vector2(500, 400),
		"level_index": 1,
	}
	var run: Node2D = BLAZE_RUSH.instantiate()
	add_child(run)
	await get_tree().process_frame
	await get_tree().process_frame

	var desyncs := 0
	var never_crashed := 0

	for cycle in range(CYCLES):
		var attempts_before: int = int(run.get("_attempts"))
		var crashed := false
		for f in range(MAX_FRAMES_PER_CYCLE):
			await get_tree().physics_frame
			if int(run.get("_attempts")) > attempts_before:
				crashed = true
				# Let the deferred _restore_tokens() and any same-frame
				# stragglers settle before reading state.
				await get_tree().process_frame
				await get_tree().physics_frame
				await get_tree().physics_frame
				break

		if not crashed:
			never_crashed += 1
			continue

		var count: int = int(run.get("_smoke_this_attempt"))
		var tokens: Array = run.get("_smoke_tokens")
		var first: Area2D = tokens[0] if tokens.size() > 0 else null
		var first_claimed: bool = first != null and (not first.visible or not first.monitoring)

		# THE FOUNDER'S EXACT BUG SHAPE: the puff counter is non-zero, or the
		# first diamond reads as already claimed, on a cycle where the player
		# has JUST been reset to the start of the course and has not yet
		# touched anything this attempt.
		if count != 0 or first_claimed:
			desyncs += 1
			print("    cycle %d: DESYNC — count=%d first_diamond visible=%s monitoring=%s"
				% [cycle, count, str(first.visible if first else null), str(first.monitoring if first else null)])

	_check("player actually reached the candle/diamond pair every cycle",
		never_crashed == 0,
		"%d of %d cycles never crashed — course/speed assumptions are stale" % [never_crashed, CYCLES])
	_check("puff counter and first-diamond claim state never desync across %d crash cycles" % CYCLES,
		desyncs == 0,
		"%d of %d cycles showed a stale claim after reset" % [desyncs, CYCLES])

	run.queue_free()
	await get_tree().process_frame
