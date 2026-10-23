extends Node
## Gate: NO TOUCH INPUT SURVIVES A SCENE SWAP (mobile transitions, DECISIONS sections 5 + 6).
##
## A thumb that was down when the scene changed must never leave Lil Blunt running in the next one: no action held by
## the touch layer (TouchActions.held_count() == 0) and no InputMap action still pressed on Input, at EVERY moment of
## the hand-off and after it. Three swap paths are driven end to end, each with four fingers down (right, jump, attack,
## duck) when the swap begins:
##   A. boss kill -> film -> TransitionDirector.go(cover) -> reveal   (the Episode 1 -> Episode 2 hand-off)
##   B. the swap FAILS (an empty PackedScene) -> recover -> menu route (the abort path)
##   C. menu -> Episode 2 through SceneRouter.load_scene's divert to the director, into the REAL Episode 2 scene
## A finger that lands DURING the hand-off (the touch layer is hidden, the card swallows touches) must press nothing.
## Preconditions are asserted too (the fingers really were down through the film; the controls really were shown),
## so a pass can never be a test that held nothing.
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/touch_scene_swap_cleanup_test.tscn

const EP2 := "res://src/episode2/ep2_entry.tscn"
const TARGET := "res://tests/fixtures/transition_target.tscn"
const HOME_FIXTURE := "res://tests/router_reveal_target.tscn"
const FINGERS: Array[StringName] = [&"move_right", &"jump", &"attack", &"move_down"]

var _fail: int = 0
var _td: Node = null
var _mlm: Node = null
## Violations seen while a path was running (any frame where something was still held / pressed).
var _leaks: Array = []


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])


func _ready() -> void:
	print("TOUCH SCENE SWAP CLEANUP:")
	var root: Node = get_tree().root
	reparent.call_deferred(root)
	await get_tree().process_frame
	_td = root.get_node("TransitionDirector")
	_mlm = root.get_node("MobileLayoutManager")
	var win0: Vector2i = root.size
	var touch0: bool = bool(_mlm.is_touch_device)
	var unlocked0: bool = GameManager.ep2_story_unlocked
	_mlm.is_touch_device = true                      # a phone
	root.size = Vector2i(844, 390)
	await get_tree().process_frame
	await get_tree().process_frame
	_install_level(root)
	StateMachine.change_state(StateMachine.State.TRANSITIONING)
	StateMachine.change_state(StateMachine.State.PLAYING)

	await _path_a_boss_film_go_reveal(root)
	await _path_b_failed_swap(root)
	await _path_c_menu_divert(root)

	_td.home_scene_path = ""
	root.size = win0
	_mlm.is_touch_device = touch0
	GameManager.ep2_story_unlocked = unlocked0
	TouchActions.release_all()
	print("TOUCH_SCENE_SWAP_CLEANUP: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)


# --- the three paths -----------------------------------------------------------------------------------------------

func _path_a_boss_film_go_reveal(root: Node) -> void:
	print(" A. boss kill -> film -> go -> reveal")
	var level: Node = _fresh_level(root)
	await _show_controls_with_fingers_down("A")
	# the kill: LEVEL_COMPLETE. The level's own opt-in goes with the Player; ONLY the film keeps the controls up.
	StateMachine.change_state(StateMachine.State.LEVEL_COMPLETE)
	_level_opt_in(level, false)
	var film: Stage3BossDefeatCutscene = Stage3BossDefeatCutscene.new()
	film.keep_cover = true
	level.add_child(film)
	film.play()
	_mlm.refresh()
	await get_tree().process_frame
	_check("A: through the film the controls stay up (hold-jump skips it) and the thumbs are still down",
		bool(_mlm.controls_visible) and TouchActions.held_count() == FINGERS.size(), "held %d" % TouchActions.held_count())
	film._finish()
	var cover: Control = film.make_cover()
	film.queue_free()
	_leaks.clear()
	_td.go(TARGET, "", "", cover)
	_check("A: the instant go() starts, the layer is hidden and every finger is released (held %d)" % TouchActions.held_count(),
		not bool(_mlm.controls_visible) and TouchActions.held_count() == 0 and _pressed().is_empty(), str(_pressed()))
	await _watch_until_idle("A")
	await _frames(5)
	_check("A: nothing was held or pressed at ANY frame of the hand-off (%d leaks)" % _leaks.size(), _leaks.is_empty(), str(_leaks.slice(0, 3)))
	_check("A: after the reveal the new scene starts clean (held %d, pressed %s)" % [TouchActions.held_count(), str(_pressed())],
		TouchActions.held_count() == 0 and _pressed().is_empty())
	_check("A: the hand-off really swapped the scene", get_tree().current_scene != null and get_tree().current_scene.name == "TransitionTarget")


func _path_b_failed_swap(root: Node) -> void:
	print(" B. a failed swap -> recover -> menu route")
	_fresh_level(root)
	_td.home_scene_path = HOME_FIXTURE
	await _show_controls_with_fingers_down("B")
	_leaks.clear()
	var got: Dictionary = {"aborted": false}
	var on_abort := func(_p: String) -> void:
		got["aborted"] = true
		# the state machine is back where it was: the stand-in level is on stage again and opted in, so the layer is SHOWN
		# again - with NOTHING held (the fingers were released at the cover and nobody has touched since)
		if TouchActions.held_count() != 0 or not _pressed().is_empty():
			_leaks.append("at abort: held %d pressed %s" % [TouchActions.held_count(), str(_pressed())])
	_td.aborted.connect(on_abort)
	var hook := func(_f: String, to: String) -> void:
		if to == "SWAPPING":
			_td._packed = PackedScene.new()             # instantiate() -> null: change_scene_to_packed fails
	_td.state_changed.connect(hook)
	var cover := ColorRect.new()
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	_td.go(TARGET, "", "", cover)
	_check("B: go() released every finger at the cover (held %d)" % TouchActions.held_count(),
		not bool(_mlm.controls_visible) and TouchActions.held_count() == 0 and _pressed().is_empty())
	var guard: int = 0
	while (not bool(got["aborted"]) or not _scene_is(HOME_FIXTURE) or not SceneRouter.is_revealed()) and guard < 3000:
		await get_tree().process_frame
		guard += 1
		_sample("B")
	_td.aborted.disconnect(on_abort)
	_td.state_changed.disconnect(hook)
	await _frames(5)
	_check("B: the swap failed, the director recovered and the player went home", bool(got["aborted"]) and _scene_is(HOME_FIXTURE))
	_check("B: nothing was held or pressed at ANY frame of the failed hand-off (%d leaks)" % _leaks.size(), _leaks.is_empty(), str(_leaks.slice(0, 3)))
	_check("B: afterwards nothing is held (held %d)" % TouchActions.held_count(), TouchActions.held_count() == 0 and _pressed().is_empty())
	_td.home_scene_path = ""


func _path_c_menu_divert(root: Node) -> void:
	print(" C. menu -> Episode 2 (router divert -> director -> the real scene)")
	_fresh_level(root)
	GameManager.ep2_story_unlocked = true
	await _show_controls_with_fingers_down("C")
	TouchActions.pulse(&"move_left")                      # a swipe in flight at the very moment of the tap
	_leaks.clear()
	SceneRouter.load_scene(EP2, SceneRouter.Transition.FADE)
	_check("C: the router diverted EPISODE 2 to the director (covering at once)", _td.state == _td.S.COVERING and _td.target_path == EP2, str(_td.state))
	_check("C: the instant the tap is accepted, every finger is released (held %d)" % TouchActions.held_count(),
		not bool(_mlm.controls_visible) and TouchActions.held_count() == 0 and _pressed().is_empty(), str(_pressed()))
	# a NEW finger lands on the screen while the card is up: the touch layer is hidden and the card eats it
	await get_tree().process_frame
	var tap := InputEventScreenTouch.new()
	tap.index = 0
	tap.position = Vector2(760.0, 330.0)               # where an attack/jump button would be on a phone
	tap.pressed = true
	Input.parse_input_event(tap)
	await get_tree().process_frame
	_check("C: a finger that lands during the hand-off presses nothing (held %d)" % TouchActions.held_count(),
		TouchActions.held_count() == 0 and _pressed().is_empty(), str(_pressed()))
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = tap.position
	up.pressed = false
	Input.parse_input_event(up)
	await _watch_until_idle("C")
	await _frames(8)
	_check("C: nothing was held or pressed at ANY frame of the menu route (%d leaks)" % _leaks.size(), _leaks.is_empty(), str(_leaks.slice(0, 3)))
	_check("C: the real Episode 2 scene is up and starts clean (held %d, pressed %s)" % [TouchActions.held_count(), str(_pressed())],
		get_tree().current_scene != null and get_tree().current_scene.scene_file_path == EP2 and TouchActions.held_count() == 0 and _pressed().is_empty())
	var cs: Node = get_tree().current_scene
	if cs != null and cs.scene_file_path == EP2:
		cs.queue_free()
	AudioManager.fade_out_music(0.01)
	_install_level(root)


# --- helpers -------------------------------------------------------------------------------------------------------

## A stand-in for a level scene: a current scene with a child opted into touch_controls_wanted (the platformer
## layout, like a level with a Player on stage).
func _install_level(root: Node) -> Node:
	var level := Node.new()
	level.name = "StandInLevel"
	var optin := Node.new()
	optin.name = "OptIn"
	level.add_child(optin)
	root.add_child(level)
	get_tree().current_scene = level
	optin.add_to_group("touch_controls_wanted")
	return level


## Replace the current scene by a fresh stand-in level and put the state machine in PLAYING.
func _fresh_level(root: Node) -> Node:
	var cs: Node = get_tree().current_scene
	if cs != null and is_instance_valid(cs):
		cs.queue_free()
	var level: Node = _install_level(root)
	if StateMachine.get_current_state() == "TRANSITIONING":
		StateMachine.change_state(StateMachine.State.PLAYING)
	elif StateMachine.get_current_state() == "LEVEL_COMPLETE":
		StateMachine.change_state(StateMachine.State.TRANSITIONING)
		StateMachine.change_state(StateMachine.State.PLAYING)
	return level


func _level_opt_in(level: Node, on: bool) -> void:
	var optin: Node = level.get_node_or_null("OptIn")
	if optin == null:
		return
	if on:
		optin.add_to_group("touch_controls_wanted")
	else:
		optin.remove_from_group("touch_controls_wanted")


## Controls up, four thumbs down. Asserts the precondition so the rest of a path can never pass vacuously.
func _show_controls_with_fingers_down(tag: String) -> void:
	TouchActions.release_all()
	_mlm.refresh()
	await get_tree().process_frame
	for a in FINGERS:
		TouchActions.press(a)
	_check("%s: precondition - the touch layer is up and four fingers are down (held %d)" % [tag, TouchActions.held_count()],
		bool(_mlm.controls_visible) and TouchActions.held_count() == FINGERS.size() and Input.is_action_pressed(&"move_right"))


## Every frame until the director is idle again: record any frame where something is still held / pressed.
func _watch_until_idle(tag: String) -> void:
	var guard: int = 0
	while (_td._going or _td.state != _td.S.IDLE) and guard < 6000:
		await get_tree().process_frame
		guard += 1
		_sample(tag)


func _sample(tag: String) -> void:
	if TouchActions.held_count() != 0 or not _pressed().is_empty():
		_leaks.append("%s frame: director %s held %d pressed %s" % [tag, str(_td.state), TouchActions.held_count(), str(_pressed())])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
		_sample("after")


func _scene_is(path: String) -> bool:
	var cs: Node = get_tree().current_scene
	return cs != null and is_instance_valid(cs) and cs.scene_file_path == path


## Every InputMap action that is pressed on Input right now.
func _pressed() -> Array:
	var out: Array = []
	for a in InputMap.get_actions():
		if Input.is_action_pressed(a):
			out.append(a)
	return out
