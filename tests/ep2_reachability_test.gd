extends Node
## REACHABILITY gate for Episode 2.
##
## This exists because of a real failure: the Episode 2 runner↔chamber loop was
## built and eight headless gates covering it were green — 2000-cycle soak,
## 4000-operation economy fuzz, every rail-#5 guard individually asserted — while
## the feature was **completely unplayable**. The founder could not test it at
## all.
##
## Three things were missing, and no existing gate could have caught any of them:
##   1. NO ROUTE. LEVEL_SEQUENCE had three entries and next_level_scene() returned
##      MENU_SCENE after the last one. Nothing in the entire codebase referenced
##      the Episode 2 scenes outside src/episode2/ itself.
##   2. NO INPUT. Not one script under src/episode2/ read an input action. The
##      verbs were callable only from code.
##   3. NO LIGHTS. Neither 3D scene had a light or an environment, so both would
##      render unlit.
##
## The root cause of the blind spot: every other gate INSTANTIATES the scenes
## directly and drives them with step(delta). That proves the logic and can never
## prove that a player can get there. This gate asserts the path a human takes.
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless \
##        res://tests/ep2_reachability_test.tscn

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	await get_tree().process_frame
	print("EP2 REACHABILITY:")

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm == null:
		print("  [FAIL] GameManager autoload missing")
		get_tree().quit(1)
		return

	# 1. Clearing the LAST Episode 1 level must route into Episode 2, not the menu.
	#    This is the assertion that was false before the fix.
	var last: int = int(gm.LEVEL_SEQUENCE.size())
	var next_scene: String = gm.next_level_scene(last)
	_check("clearing the final Episode 1 level routes to Episode 2 (got %s)" % next_scene,
		next_scene == gm.EPISODE2_SCENE,
		"returned the menu — Episode 2 would be unreachable from play")
	_check("the Episode 2 entry scene actually exists on disk (%s)" % gm.EPISODE2_SCENE,
		ResourceLoader.exists(gm.EPISODE2_SCENE))

	# 2. Clearing an EARLIER level must still route to the next level, not skip
	#    the rest of Episode 1.
	var mid: String = gm.next_level_scene(1)
	_check("clearing level 1 still routes to level 2 (got %s)" % mid,
		mid == gm.LEVEL_SEQUENCE[1], "the Episode 2 hand-off must not swallow mid-campaign routing")

	# 3. The entry scene must stand up on its own and reach a PLAYABLE mode —
	#    not merely load. A scene that loads and then sits in IDLE is still
	#    untestable by a human.
	var entry: Node = load(gm.EPISODE2_SCENE).instantiate()
	add_child(entry)
	await get_tree().process_frame
	await get_tree().process_frame

	var root: Node = null
	for c in entry.get_children():
		if c is Ep2SessionRoot:
			root = c
			break
	_check("the entry scene hosts a session root", root != null)
	if root:
		_check("the session root reaches RUNNER mode without a test harness driving it (mode=%d)"
				% root.get_mode(),
			root.get_mode() == Ep2SessionRoot.Mode.RUNNER,
			"a scene that loads but never starts is still unplayable")
		_check("a runner scene is live under the root", root.get_active() is RunnerGraybox)

		# 4. INPUT. The session root must actually handle input events — the gap
		#    that made every verb code-only. Assert the handler exists and that a
		#    synthesised action reaches the runner.
		_check("the session root implements an input handler",
			root.has_method("_unhandled_input"),
			"without this, no key press can reach any Episode 2 verb")

		var r: Node = root.get_active()
		var lane_before: int = r.get_lane()
		var ev := InputEventAction.new()
		ev.action = "move_right"
		ev.pressed = true
		root._unhandled_input(ev)
		_check("a move_right action actually switches rail (%d -> %d)" % [lane_before, r.get_lane()],
			r.get_lane() != lane_before,
			"input is wired to nothing")

		var y_before: float = r.get_cart_y()
		var jump_ev := InputEventAction.new()
		jump_ev.action = "jump"
		jump_ev.pressed = true
		root._unhandled_input(jump_ev)
		r.step(1.0 / 60.0)
		_check("a jump action actually lifts the cart (%.3f -> %.3f)" % [y_before, r.get_cart_y()],
			r.get_cart_y() > y_before, "input is wired to nothing")

	entry.queue_free()
	await get_tree().process_frame

	# 5. LIGHTING. A 3D scene with no light and no environment renders unlit —
	#    it "works" in every headless test and looks broken to a human.
	for path in ["res://src/episode2/runner/runner_graybox.tscn",
			"res://src/episode2/chamber/miner_shaft.tscn"]:
		var scene: Node = load(path).instantiate()
		var has_light := false
		var has_env := false
		for c in scene.get_children():
			if c is DirectionalLight3D or c is OmniLight3D or c is SpotLight3D:
				has_light = true
			if c is WorldEnvironment:
				has_env = true
		_check("%s has a light" % path.get_file(), has_light, "would render unlit")
		_check("%s has a WorldEnvironment" % path.get_file(), has_env, "would render unlit")
		scene.queue_free()

	await get_tree().process_frame
	print("EP2_REACHABILITY: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)
