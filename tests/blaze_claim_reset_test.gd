extends Node
## B4 — "player collects first diamond (often via candle bounce), then the
## game/section resets, but the diamond stays already claimed."
##
## Measured rather than reasoned about: build the REAL Blaze Rush, claim a
## token through its own body_entered handler, then trigger the REAL crash path
## and assert every token is collectable again. A code read of _crash() looks
## like it already resets them, which is exactly why this needs a test — the
## founder is reporting the opposite of what the code appears to say.

const BLAZE_RUSH := preload("res://src/dashmode/blaze_rush.tscn")

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("BLAZE CLAIM RESET (B4):")
	await _run()
	_test_side_entrance_reopens_on_a_fresh_attempt()
	print("BLAZE_CLAIM_RESET: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _tokens(run: Node) -> Array:
	return run.get("_smoke_tokens")

func _claimed_count(run: Node) -> int:
	var n := 0
	for t in _tokens(run):
		if is_instance_valid(t) and not t.visible:
			n += 1
	return n

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

	var tokens: Array = _tokens(run)
	_check("the run built its diamond tokens", tokens.size() > 0,
		"found %d" % tokens.size())
	if tokens.is_empty():
		return

	# Claim through the token's OWN handler, driven with the real player node,
	# so this exercises the shipped pickup path rather than a hand-set flag.
	#
	# The player must actually BE where the token is before this fires: the
	# pickup handler now validates the player's real distance to the token
	# (blaze_diamond_bounce_repro_test.gd), which rejects an emit() fired
	# from the player's default spawn position 400+px away exactly as it
	# should — that gap is what a STALE signal looks like, and this test
	# is not trying to reproduce that case here.
	var player: CharacterBody2D = run.get("_player")
	var first: Area2D = tokens[0]
	player.global_position = first.global_position
	first.body_entered.emit(player)
	await get_tree().process_frame
	_check("claiming a diamond hides it", not first.visible)
	_check("claim registered on the run's counter",
		int(run.get("_smoke_this_attempt")) >= 1,
		"counter = %s" % str(run.get("_smoke_this_attempt")))

	# THE REPORTED SEQUENCE: crash (a candle bounce lands here) -> section resets.
	run.call("_crash")
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	_check("after the reset, the run's puff counter is back to zero",
		int(run.get("_smoke_this_attempt")) == 0,
		"counter = %s" % str(run.get("_smoke_this_attempt")))
	_check("after the reset, NO diamond is still claimed",
		_claimed_count(run) == 0,
		"%d of %d diamond(s) stayed claimed through the restart"
			% [_claimed_count(run), tokens.size()])

	# Re-collectable, not merely re-drawn: a token that is visible again but
	# still has monitoring off looks reset and cannot actually be picked up,
	# which would read to a player as exactly the same bug.
	var dead := 0
	for t in tokens:
		if is_instance_valid(t) and not t.monitoring:
			dead += 1
	_check("every reset diamond can actually be collected again", dead == 0,
		"%d token(s) are visible but not monitoring" % dead)

	# THE RACE THE FOUNDER IS DESCRIBING — "often via candle bounce".
	#
	# A candle and a diamond can be touched on the SAME physics frame. The
	# pickup sets `area.visible = false` immediately, and _crash() sets
	# `token.visible = true` immediately. So whichever Area2D the physics
	# server reports SECOND wins, and when the candle reports first the reset
	# is undone by the pickup that follows it — the diamond stays claimed
	# through the restart. Emitted here in the adverse order on one frame.
	var second: Area2D = tokens[0]
	second.set_deferred("monitoring", true)
	second.visible = true
	await get_tree().physics_frame
	run.call("_crash")            # candle reports first...
	second.body_entered.emit(player)   # ...diamond second, same frame
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check("a diamond touched on the SAME frame as a candle still resets",
		second.visible and second.monitoring,
		"visible=%s monitoring=%s — claimed state survived the restart"
			% [second.visible, second.monitoring])

	run.queue_free()
	await get_tree().process_frame

## The OTHER half of B4, and the one that outlives a single run: the Blaze
## portal — the glowing diamond entrance on the stage — was marked used and
## then cleared NOWHERE in the codebase. Not on death, not on a full wipe, not
## in reset_progress(). So the first Blaze run on a level consumed the entrance
## permanently: every later restart rebuilt the portal, saw the flag still set,
## and freed it immediately. To the player that is "the diamond stays already
## claimed", and no amount of in-run token resetting could fix it.
func _test_side_entrance_reopens_on_a_fresh_attempt() -> void:
	GameManager.current_level = 1
	GameManager.mark_side_entrance_used("blaze", 1)
	GameManager.mark_side_entrance_used("secret", 1)
	_check("entering marks the Blaze entrance used within the attempt",
		GameManager.is_side_entrance_used("blaze", 1))

	# A death / full wipe is a NEW attempt at the level.
	GameManager.reopen_side_entrances(1)
	_check("a fresh attempt reopens the Blaze entrance",
		not GameManager.is_side_entrance_used("blaze", 1),
		"still marked used after the restart")
	_check("a fresh attempt reopens the secret door",
		not GameManager.is_side_entrance_used("secret", 1))

	# ...but only for the level being restarted.
	GameManager.mark_side_entrance_used("blaze", 2)
	GameManager.reopen_side_entrances(1)
	_check("reopening level 1 does NOT reopen level 2's entrance",
		GameManager.is_side_entrance_used("blaze", 2),
		"clearing one level's flag wiped another's")

	# A new session clears everything.
	GameManager.reset_session()
	_check("reset_session clears every side-entrance flag",
		not GameManager.is_side_entrance_used("blaze", 2))
