extends Node
## Gate for the TransitionDirector (autoload; skill ep2-seamless-transition).
## Proves: the Episode 2 warm-up completes incrementally within a frame budget (no long freeze), the hand-off goes
## cover -> load -> swap -> reveal -> idle, the global StateMachine follows (TRANSITIONING then PLAYING), nothing is
## left covering the screen, and the boss hand-offs use the director instead of the blue diamond wipe.
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/transition_director_test.tscn

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	print("TRANSITION DIRECTOR:")
	# The test node must survive the scene swap: live under the root, with a dummy "current scene" to be replaced.
	var root: Node = get_tree().root
	reparent.call_deferred(root)
	await get_tree().process_frame
	var dummy := Node.new()
	dummy.name = "DummyCurrentScene"
	root.add_child(dummy)
	get_tree().current_scene = dummy
	var td: Node = root.get_node("TransitionDirector")

	# 1. Warm-up is incremental and completes.
	var ep2: String = "res://src/episode2/ep2_entry.tscn"
	td.prewarm(ep2)
	_check("prewarm starts WARMING", td.state == td.S.WARMING)
	var first_frac: float = td.warm_fraction()
	var worst_ms: float = 0.0
	var frames: int = 0
	var last_t: int = Time.get_ticks_usec()
	# While WARMING (the film is playing) the heavy script/scene items must be held back for the card.
	var held_late: bool = false
	while td.state == td.S.WARMING and frames < 400:
		await get_tree().process_frame
		var now0: int = Time.get_ticks_usec()
		worst_ms = maxf(worst_ms, float(now0 - last_t) / 1000.0)
		last_t = now0
		frames += 1
		if not td._late.is_empty():
			held_late = true
	_check("scripts/scenes are held back for the card, not loaded in front of the player", held_late and td.state == td.S.WARMING)
	_check("...so no single warm frame in front of the player stalled over 250 ms (%.0f ms worst)" % worst_ms, worst_ms < 250.0)
	# Stand-in for the covered phase (the card is up): everything left may load now.
	td.state = td.S.COVERING
	td._pump_warm(1.0e9)
	td._pump_warm(1.0e9)
	td.state = td.S.WARMING
	td._pump_warm(1.0)
	while td.state == td.S.WARMING and frames < 20000:
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		worst_ms = maxf(worst_ms, float(now - last_t) / 1000.0)
		last_t = now
		frames += 1
	_check("the whole Episode 2 warm-up finished (READY) over %d frames" % frames, td.state == td.S.READY, str(td.state))
	_check("it was spread over many frames, not one freeze", frames >= 5, str(frames))
	print("    worst single frame while warming: %.1f ms" % worst_ms)
	for si in td.slow_items:
		print("    slow item %.0f ms  %s" % [si[0], si[1]])
	_check("warm fraction reached 1.0", is_equal_approx(td.warm_fraction(), 1.0))
	_check("prewarm twice for the same path is a no-op", (func(): td.prewarm(ep2); return td.state == td.S.READY).call())

	# 2. Hand-off to a tiny scene: states, StateMachine, card, scene change.
	var states: Array = []
	td.state_changed.connect(func(_f, t): states.append(t))
	var target: String = "res://tests/fixtures/transition_target.tscn"
	var seen: Dictionary = {"transitioning": false}
	StateMachine.state_changed.connect(func(_f, t): if t == "TRANSITIONING": seen["transitioning"] = true)
	td.go(target, "TEST", "CARD")
	_check("go() covers immediately (state COVERING, card visible)", td.state == td.S.COVERING and td._card.visible)
	_check("a second go() while busy is ignored", (func(): td.go(ep2); return td.target_path == target).call())
	await td.finished
	_check("hand-off walked cover -> load -> swap -> reveal -> idle: %s" % str(states),
		states.has("COVERING") and states.has("LOADING") and states.has("SWAPPING") and states.has("REVEALING") and states[-1] == "IDLE")
	_check("the scene actually changed", get_tree().current_scene != null and get_tree().current_scene.name == "TransitionTarget")
	_check("the card is gone (nothing left covering the game)", not td._card.visible and td.state == td.S.IDLE)
	_check("StateMachine went TRANSITIONING then PLAYING", bool(seen["transitioning"]) and StateMachine.get_current_state() == "PLAYING")
	_check("the director can run again", not td.is_busy())

	# 3. Routing: bosses use the director, never the blue diamond wipe, for the Episode 2 hand-off.
	for bp in ["res://src/boss/claim_jumper.gd", "res://src/boss/bandit_boss.gd"]:
		var src: String = FileAccess.get_file_as_string(bp)
		_check("%s prewarms on death and hands off through TransitionDirector.go" % bp.get_file(),
			src.contains("TransitionDirector.prewarm(GameManager.EPISODE2_SCENE)") and src.contains("TransitionDirector.go(GameManager.next_level_scene(3))")
			and not src.contains("next_level_scene(3), SceneRouter.Transition.DIAMOND"))
	var card_bg: Color = td._bg.color
	_check("the loading card is black-violet, not blue (b - r < 0.05: %s)" % str(card_bg), card_bg.b - card_bg.r < 0.05)

	print("TRANSITION_DIRECTOR: %s" % ("ALL PASS" if _fail == 0 else "FAIL (%d)" % _fail))
	get_tree().quit(_fail)
