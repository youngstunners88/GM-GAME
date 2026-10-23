extends Node
## Blaze Rush on a PHONE: the touch layer is wired into the run, and a real finger drives it.
##
## Blaze Rush has one verb (tap anywhere = jump), so on a phone it is a full-screen tap field
## plus one pause button (src/input/mobile, profile `blaze`), a wordless pause card
## (src/dashmode/blaze_pause.gd) and an ARMED start with a tap-hand cue
## (src/dashmode/blaze_tap_cue.gd). This gate drives the REAL scene with REAL injected
## fingers through the REAL touch layer (Input.parse_input_event -> GUI -> VirtualTapField
## -> TouchActions -> the `jump` action -> blaze_rush.gd), at the three shapes the founder's
## devices make, on all three stages:
##
##   phone landscape  844x390 dp   (a 1688x780 @2x phone: same canvas, same dp; the headless
##   phone portrait   390x844 dp    display reports density 1, so the dp window is used and the
##   tablet           1024x768 dp   phone CLASS - and so the layout key - is the real one)
##
## What it pins (each section is mutation-checked, see the report):
##   * the profile / layout key / layer, the layout's controls, and that nothing is written;
##   * the armed start: the cube holds at x=0 until the reveal AND the first tap, the first
##     tap is not a jump, a tap before the reveal is ignored, the 1.0 s safety timeout, and a
##     REAL SceneRouter load enters PLAYING only at the reveal;
##   * one tap = exactly one jump anywhere on the screen, a resting thumb never swallows the
##     next finger, a lazily detected touch device loses no first tap;
##   * the pause card: Pause does not jump and opens it, a finger down on it is not adopted by
##     the tap field, PLAY resumes with cleared buffers and a beat, EXIT is the SAME exit as
##     Esc (side_return, music resume, controls released, profile gone), focus-out opens it;
##   * the HUD: no written exit on a phone, inside the safe area, clear of the Pause button,
##     and it follows a lazily flipped touch device / a key press / a rotation;
##   * lifecycle on all three stages: finish / exit -> exactly one stage track, no override.
##
## Needs a FRESH user dir (the shared dev save is polluted by other runs):
##   XDG_DATA_HOME=$(mktemp -d) godot --headless --path . res://tests/blaze_rush_touch_test.tscn
## Verdict: BLAZE_RUSH_TOUCH: ALL PASS | N FAILURE(S)

const BLAZE_RUSH := preload("res://src/dashmode/blaze_rush.tscn")
const PORTAL_SCENE := preload("res://src/dashmode/blaze_portal.tscn")
const BLAZE_TRACK := "res://src/assets/music/blaze_rush_theme.mp3"
const BLAZE_SCENE := "res://src/dashmode/blaze_rush.tscn"
const LEVELS := {
	1: "res://src/level/level_01_smoke_realm.tscn",
	2: "res://src/level/level_02_crystal_caverns.tscn",
	3: "res://src/level/level_03_gold_rush.tscn",
}
const SCREENS := [
	{"name": "phone landscape", "win": Vector2i(844, 390), "key": &"blaze_phone_landscape", "level": 1},
	{"name": "phone portrait", "win": Vector2i(390, 844), "key": &"blaze_phone_portrait", "level": 2},
	{"name": "tablet landscape", "win": Vector2i(1024, 768), "key": &"blaze_tablet_landscape", "level": 3},
]
## Any visible text in the run must be one of these (the founder-restored stat labels and the
## in-world FUD tag). Everything else - "TAP OUT (Q)", a key name, an instruction - fails.
## The strip (dp, in from the safe-area corner) the layout's Pause button owns: 62 x 96 dp.
const PAUSE_ZONE_W_DP: float = 62.0
const ALLOWED_TEXT := "^(BLAZE DIAMONDS \\d+|ATTEMPT \\d+ ?|FUD)$"
## Words and key names that must never appear on a touch device (also applied to the toast).
const FORBIDDEN_WORDS := "(?i)\\b(tap|press|hold|click|swipe|space|enter|esc|escape|jump|reload|out|exit|quit|pause|play|retry|skip|key|button)\\b|\\([A-Za-z]\\)|\\[[A-Za-z]\\]"

var _fail: int = 0
var _checks: int = 0
var _seen: Array[String] = []
var _was_touch: bool = false
var _was_force: bool = false
var _screen: Vector2i = Vector2i(844, 390)

func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

## The game's own actions as the run sees them (the tap field pushes InputEventAction).
func _input(event: InputEvent) -> void:
	if event is InputEventAction:
		var a := event as InputEventAction
		_seen.append("%s:%s" % [a.action, "down" if a.pressed else "up"])

func _count(name: String) -> int:
	return _seen.count(name)

func _ready() -> void:
	await get_tree().process_frame
	print("BLAZE RUSH TOUCH:")
	_was_touch = MobileLayoutManager.is_touch_device
	_was_force = MobileLayoutManager.force_touch_ui
	_isolate_game_state()
	_force_touch(true)
	for sc: Dictionary in SCREENS:
		await _screen_battery(sc)
	await _pause_card_flows()
	await _focus_out()
	await _wordless_scan()
	await _hud_follows_the_manager()
	await _rotation()
	await _armed_start_real_router()
	await _reveal_timeout()
	await _desktop_is_unchanged()
	await _lifecycle()
	_force_touch(false)
	MobileLayoutManager.is_touch_device = _was_touch
	MobileLayoutManager.force_touch_ui = _was_force
	if _checks < 200:
		_fail += 1
		print("  [FAIL] only %d checks ran - a false green" % _checks)
	print("BLAZE_RUSH_TOUCH: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

# ---- helpers -------------------------------------------------------------------------------

## The persisted dev save is shared by every test run on this machine and can hold a
## checkpoint AT the Blaze portal; pin the in-memory state instead (never save_session here
## except the portal step, which is why a fresh XDG_DATA_HOME is required).
func _isolate_game_state() -> void:
	GameManager.level_checkpoints.clear()
	GameManager.blaze_rush_completed.clear()
	GameManager.dash_return = {}
	GameManager.side_return = {}
	for lvl in [1, 2, 3]:
		GameManager.blaze_portal_used[lvl] = true

## `on` = a phone: touch forced (a key press must not flip the manager to keyboard mode).
func _force_touch(on: bool) -> void:
	MobileLayoutManager.force_touch_ui = on
	MobileLayoutManager.is_touch_device = on
	MobileLayoutManager.refresh()

func _frames(n: int = 2) -> void:
	for i in n:
		await get_tree().process_frame

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _to_window(canvas_pos: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * canvas_pos

func _touch(index: int, pressed: bool, canvas_pos: Vector2) -> void:
	var t := InputEventScreenTouch.new()
	t.index = index
	t.pressed = pressed
	t.position = _to_window(canvas_pos)
	Input.parse_input_event(t)

func _centre(c: Control) -> Vector2:
	return c.global_position + c.size * 0.5

func _set_screen(size: Vector2i) -> void:
	_screen = size
	get_window().size = size
	await _frames(3)

func _view() -> Vector2:
	return get_viewport().get_visible_rect().size

func _to_transitioning() -> void:
	if StateMachine.get_state_enum() != StateMachine.State.TRANSITIONING:
		StateMachine.change_state(StateMachine.State.TRANSITIONING)

## A fresh Blaze run, entered the way SceneRouter enters it: TRANSITIONING, then the scene.
func _boot(level: int, as_scene: bool = false) -> Node2D:
	GameManager.dash_return = {
		"scene_path": str(LEVELS[level]),
		"position": Vector2(1450.0, 250.0),
		"level_index": level,
	}
	_to_transitioning()
	var run: Node2D = BLAZE_RUSH.instantiate()
	if as_scene:
		# the way SceneRouter holds it: the CURRENT scene, so the router frees it on the way out
		get_tree().root.add_child(run)
		get_tree().current_scene = run
	else:
		add_child(run)
	await _frames(4)
	MobileLayoutManager.refresh()
	await _frames(2)
	return run

func _free(run: Node) -> void:
	if is_instance_valid(run):
		run.queue_free()
	await _frames(2)
	_to_transitioning()
	TouchActions.release_all()
	MobileLayoutManager.refresh()
	await _frames(2)

func _layout() -> TouchLayout:
	return MobileLayoutManager.layout()

func _field() -> VirtualTapField:
	for c in _layout().controls():
		if c is VirtualTapField:
			return c as VirtualTapField
	return null

func _pause_button() -> VirtualButton:
	return _layout().find_button(&"pause")

func _layer_value() -> int:
	return (MobileLayoutManager.get_node("TouchLayer") as CanvasLayer).layer

func _player(run: Node) -> CharacterBody2D:
	return run.get("_player") as CharacterBody2D

func _armed(run: Node) -> bool:
	return bool(run.get("_armed"))

## Stand the cube on the floor at the start line with every buffer clear.
func _park(run: Node) -> void:
	run.call("_reset_player")
	run.set("_jump_buffer", 0.0)
	await _ticks(3)

## TAKEOFF TRACKER. A takeoff is velocity.y crossing -600 (JUMP_VELOCITY is -700) between two
## physics ticks. It is armed BEFORE the finger goes down and read after, so a jump that
## fires in the very next tick cannot be missed. While `pin` the cube is held at x=0 so it can
## never reach a hazard while it is watched.
var _trk_run: Node = null
var _trk_prev: float = 0.0
var _trk_n: int = 0
var _trk_pin: bool = true

func _watch(run: Node, pin: bool = true) -> void:
	_trk_run = run
	_trk_n = 0
	_trk_pin = pin
	_trk_prev = _player(run).velocity.y
	if not get_tree().physics_frame.is_connected(_on_trk_tick):
		get_tree().physics_frame.connect(_on_trk_tick)

func _on_trk_tick() -> void:
	if not is_instance_valid(_trk_run):
		return
	var player: CharacterBody2D = _player(_trk_run)
	if player == null:
		return
	if player.velocity.y <= -600.0 and _trk_prev > -600.0:
		_trk_n += 1
	_trk_prev = player.velocity.y
	if _trk_pin and absf(player.position.x) > 1.0:
		player.position.x = 0.0

func _unwatch() -> int:
	if get_tree().physics_frame.is_connected(_on_trk_tick):
		get_tree().physics_frame.disconnect(_on_trk_tick)
	return _trk_n

## Start the run with one tap (a fresh finger index) and let it go.
func _arm_with_a_tap(run: Node, canvas_pos: Vector2, finger: int = 0) -> void:
	_touch(finger, true, canvas_pos)
	await _frames(2)
	_touch(finger, false, canvas_pos)
	await _frames(2)

func _stat_rects(run: Node) -> Dictionary:
	var out: Dictionary = {}
	out["smoke"] = (run.get("_smoke_label") as Label).get_global_rect()
	out["attempt"] = (run.get("_attempt_label") as Label).get_global_rect()
	var face: Control = run.find_child("TapOutFace", true, false) as Control
	out["face"] = face.get_global_rect() if face != null else Rect2()
	return out

# ================================================================================================
#  one screen shape, one stage
# ================================================================================================

func _screen_battery(sc: Dictionary) -> void:
	var tag: String = str(sc["name"])
	var level: int = int(sc["level"])
	print(" %s, stage %d:" % [tag, level])
	await _set_screen(sc["win"])
	var run: Node2D = await _boot(level)

	# ---- the profile, the layout, the layer ----
	_check("%s: the run is PLAYING once revealed (TRANSITIONING -> PLAYING)" % tag, StateMachine.is_playing())
	_check("%s: the touch profile is blaze" % tag, MobileLayoutManager.current_profile() == &"blaze",
		str(MobileLayoutManager.current_profile()))
	_check("%s: layout key %s" % [tag, sc["key"]], MobileLayoutManager.current_layout_key() == sc["key"],
		str(MobileLayoutManager.current_layout_key()))
	_check("%s: the controls are shown on layer 60 (above the pause card at 40)" % tag,
		MobileLayoutManager.controls_visible and _layer_value() == MobileLayoutManager.LAYER_OVER_FILMS)
	var lay: TouchLayout = _layout()
	var field: VirtualTapField = _field()
	var pause: VirtualButton = _pause_button()
	_check("%s: the tap field is the layout's FIRST control and covers the viewport" % tag,
		field != null and lay.controls()[0] == field and field.size.is_equal_approx(_view()))
	_check("%s: exactly two controls: the tap field and Pause (no exit, no words)" % tag,
		lay.controls().size() == 2 and pause != null)

	# ---- the armed start ----
	var player: CharacterBody2D = _player(run)
	await _ticks(20)
	_check("%s: ARMED - the cube holds at x=0 before the first tap (20 ticks later)" % tag,
		not _armed(run) and player.position.x == 0.0, "armed=%s x=%.1f" % [_armed(run), player.position.x])
	var cue: BlazeTapCue = run.get("_cue") as BlazeTapCue
	_check("%s: the tap-hand cue is showing" % tag, cue != null and cue.is_cue_shown() and cue.visible)

	# ---- the HUD ----
	await _check_hud(run, tag)

	# ---- pause-card geometry (dp) ----
	var card: BlazePause = run.get("_card") as BlazePause
	var m: TouchMetrics = MobileLayoutManager.metrics()
	card.open()
	var play_dp: float = card.play_hit_radius() * 2.0 / m.dp
	var exit_dp: float = card.exit_hit_radius() * 2.0 / m.dp
	_check("%s: PLAY is >= 72 dp across (%.0f dp) with its hit pad (%.0f dp)" % [tag, BlazePause.PLAY_RADIUS_DP * 2.0, play_dp],
		BlazePause.PLAY_RADIUS_DP * 2.0 >= 72.0 and play_dp >= 96.0)
	_check("%s: EXIT is >= 44 dp to hit (%.0f dp)" % [tag, exit_dp], exit_dp >= 44.0)
	var v: Vector2 = _view()
	var r_play: float = card.play_hit_radius()
	var r_exit: float = card.exit_hit_radius()
	_check("%s: both pads sit fully inside the screen" % tag,
		Rect2(Vector2.ZERO, v).encloses(Rect2(card.play_center() - Vector2.ONE * r_play, Vector2.ONE * r_play * 2.0))
		and Rect2(Vector2.ZERO, v).encloses(Rect2(card.exit_center() - Vector2.ONE * r_exit, Vector2.ONE * r_exit * 2.0)))
	_check("%s: the pads do not overlap (a thumb on PLAY cannot leave the run)" % tag,
		card.play_center().distance_to(card.exit_center()) > r_play + r_exit)
	card.close()

	# ---- the first tap STARTS the run and is not a jump ----
	_seen.clear()
	_watch(run, false)
	await _arm_with_a_tap(run, Vector2(v.x * 0.5, v.y * 0.30))
	_check("%s: the first tap arms the run" % tag, _armed(run))
	_check("%s: ...and hides the cue" % tag, not cue.is_cue_shown())
	var x_after: float = player.position.x
	await _ticks(10)
	var starter_jumps: int = _unwatch()
	_check("%s: ...the cube runs (x %.0f -> %.0f)" % [tag, x_after, player.position.x], player.position.x > x_after + 20.0)
	_check("%s: ...and that first tap was not a jump (no takeoff in the next 10 ticks)" % tag, starter_jumps == 0 and player.is_on_floor(),
		"takeoffs=%d" % starter_jumps)

	# ---- one tap anywhere = exactly one jump ----
	var spots: Array = [
		["the sky", Vector2(v.x * 0.5, v.y * 0.28)],
		["the floor", Vector2(v.x * 0.5, v.y * 0.86)],
		["the HUD strip", Vector2(v.x * 0.5, v.y * 0.05)],
		["the top-left corner", Vector2(8.0, 8.0)],
		["the bottom-right corner", Vector2(v.x - 8.0, v.y - 8.0)],
		["the left third", Vector2(v.x / 6.0, v.y * 0.45)],
		["the right third", Vector2(v.x * 5.0 / 6.0, v.y * 0.45)],
	]
	for spot: Array in spots:
		await _park(run)
		_seen.clear()
		_watch(run)
		_touch(0, true, spot[1])
		await _ticks(40)
		var n: int = _unwatch()
		_touch(0, false, spot[1])
		await _frames(2)
		_check("%s: a tap on %s = exactly ONE jump" % [tag, spot[0]], n == 1 and _count("jump:down") == 1,
			"takeoffs=%d jump:down=%d" % [n, _count("jump:down")])
		_check("%s: ...and lifting the finger let `jump` go" % tag, not Input.is_action_pressed(&"jump"))

	# ---- a resting finger never swallows the next ----
	await _park(run)
	_seen.clear()
	var p: Vector2 = Vector2(v.x * 0.30, v.y * 0.40)
	var q: Vector2 = Vector2(v.x * 0.70, v.y * 0.40)
	_watch(run)
	_touch(0, true, p)
	await _ticks(46)
	var first: int = _trk_n
	_touch(1, true, q)
	await _ticks(46)
	var second: int = _unwatch() - first
	_touch(1, false, q)
	_touch(0, false, p)
	await _frames(2)
	_check("%s: a resting finger + a second finger = a second jump (%d then %d)" % [tag, first, second],
		first == 1 and second == 1 and _count("jump:down") == 2, "jump:down=%d %s" % [_count("jump:down"), _seen])

	# ---- Pause: no jump, opens the card ----
	await _park(run)
	_seen.clear()
	var pc: Vector2 = _centre(pause)
	_touch(2, true, pc)
	await _frames(2)
	_check("%s: a tap on Pause opens the card" % tag, bool(run.call("is_pause_card_open")) and card.is_open())
	_check("%s: ...and does not jump" % tag, _count("jump:down") == 0 and float(run.get("_jump_buffer")) == 0.0, str(_seen))
	_check("%s: ...the run is frozen" % tag, bool(run.call("is_run_paused")) and not run.is_physics_processing())
	_check("%s: ...the controls are suspended and inert, nothing is held" % tag,
		MobileLayoutManager.controls_suspended and TouchActions.held_count() == 0 and _all_ignore(lay))
	_touch(2, false, pc)
	await _frames(2)

	# ---- a finger down while the card is up is not adopted by the tap field ----
	_seen.clear()
	var sky: Vector2 = Vector2(v.x * 0.5, v.y * 0.20)
	_touch(3, true, sky)
	await _frames(2)
	_check("%s: a finger on the card is NOT adopted by the tap field (no jump, nothing held)" % tag,
		_count("jump:down") == 0 and field.finger_count() == 0 and TouchActions.held_count() == 0 and not Input.is_action_pressed(&"jump"), str(_seen))
	_touch(3, false, sky)
	await _frames(2)
	_check("%s: a tap on the dim does nothing (the card stays up)" % tag, card.is_open() and bool(run.call("is_run_paused")))

	# ---- PLAY: resumes, buffers cleared, holds for the next tap ----
	run.set("_jump_buffer", 0.1)   # a tap that was queued at the pause edge
	run.set("_coyote", 0.06)
	var pp: Vector2 = card.play_center()
	_touch(0, true, pp)
	await _frames(2)
	_touch(0, false, pp)
	await _frames(3)
	_check("%s: PLAY closes the card and resumes the run" % tag, not card.is_open() and not bool(run.call("is_run_paused")) and run.is_physics_processing())
	_check("%s: ...with the jump buffer and coyote CLEARED (a queued tap cannot fire now)" % tag,
		float(run.get("_jump_buffer")) == 0.0 and float(run.get("_coyote")) == 0.0, "buffer=%f coyote=%f" % [float(run.get("_jump_buffer")), float(run.get("_coyote"))])
	_check("%s: ...the controls listen again and nothing is stuck held" % tag,
		not MobileLayoutManager.controls_suspended and TouchActions.held_count() == 0 and not _all_ignore(lay))
	_check("%s: ...the cube HOLDS for the next tap, cue back" % tag, not _armed(run) and cue.is_cue_shown())
	var held_x: float = player.position.x
	await _ticks(10)
	_check("%s: ...and really stands still" % tag, is_equal_approx(player.position.x, held_x))
	_seen.clear()
	_watch(run, false)
	await _arm_with_a_tap(run, sky)
	await _ticks(8)
	var fresh: int = _unwatch()
	_check("%s: the next tap continues the run and is not a jump (no takeoff)" % tag, _armed(run) and _count("jump:down") == 1 and fresh == 0,
		"armed=%s jump:down=%d takeoffs=%d" % [_armed(run), _count("jump:down"), fresh])
	_park_noawait(run)
	await _free(run)

## Reset without awaiting (used right before freeing).
func _park_noawait(run: Node) -> void:
	run.call("_reset_player")

func _all_ignore(lay: TouchLayout) -> bool:
	for c in lay.controls():
		if c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return false
	return true

# ---- the HUD ---------------------------------------------------------------------------------

func _check_hud(run: Node, tag: String) -> void:
	await _frames(2)
	var btn: Button = run.get("_tapout_button") as Button
	_check("%s: the written exit (TAP OUT (Q)) is NOT shown on a phone" % tag, btn != null and not btn.is_visible_in_tree())
	var face: Control = run.find_child("TapOutFace", true, false) as Control
	_check("%s: the Lil Blunt face stays" % tag, face != null and face.is_visible_in_tree())
	var rects: Dictionary = _stat_rects(run)
	var m: TouchMetrics = MobileLayoutManager.metrics()
	var safe: Rect2 = m.safe_rect
	var zone := Rect2(Vector2(safe.end.x - PAUSE_ZONE_W_DP * m.dp, safe.position.y),
			Vector2(PAUSE_ZONE_W_DP * m.dp, 96.0 * m.dp))
	var pause_rect: Rect2 = _pause_button().get_global_rect()
	for key: String in ["smoke", "attempt", "face"]:
		var r: Rect2 = rects[key]
		_check("%s: HUD %s is inside the safe area" % [tag, key], r.size.x > 1.0 and r.position.x >= safe.position.x - 0.5 and r.position.y >= safe.position.y - 0.5
			and r.end.x <= safe.end.x + 0.5, "%s vs safe %s" % [r, safe])
		_check("%s: HUD %s keeps clear of the top-right Pause zone (62 x 96 dp)" % [tag, key], not r.intersects(zone), "%s vs zone %s" % [r, zone])
		_check("%s: HUD %s does not overlap the real Pause button" % [tag, key], not r.intersects(pause_rect), "%s vs %s" % [r, pause_rect])
	_check("%s: the HUD labels are shown" % tag, (run.get("_smoke_label") as Label).is_visible_in_tree() and (run.get("_attempt_label") as Label).is_visible_in_tree())

# ================================================================================================
#  the pause card, in detail (phone landscape, stage 1)
# ================================================================================================

func _pause_card_flows() -> void:
	print(" pause card:")
	await _set_screen(Vector2i(844, 390))
	var run: Node2D = await _boot(1)
	var card: BlazePause = run.get("_card") as BlazePause
	await _arm_with_a_tap(run, Vector2(400.0, 200.0))
	await _park(run)

	# a resting finger + Pause: the resting finger's later lift must not leave a stale field
	var field: VirtualTapField = _field()
	var rest: Vector2 = Vector2(300.0, 300.0)
	_touch(0, true, rest)
	await _frames(2)
	_check("(setup) a finger rests on the tap field", field.finger_count() == 1 and Input.is_action_pressed(&"jump"))
	var pc: Vector2 = _centre(_pause_button())
	_touch(1, true, pc)
	await _frames(2)
	_check("a SECOND finger on Pause opens the card while the first rests", card.is_open())
	_check("...and the resting finger's `jump` was released by the suspension", not Input.is_action_pressed(&"jump") and TouchActions.held_count() == 0)
	_touch(1, false, pc)
	_touch(0, false, rest)
	await _frames(2)
	_seen.clear()
	_touch(0, true, card.play_center())
	await _frames(2)
	_touch(0, false, card.play_center())
	await _frames(3)
	_check("PLAY with the old resting finger already lifted: card closed", not card.is_open())
	_check("...the tap field holds no stale finger (a fresh tap will count)", field.finger_count() == 0 and TouchActions.held_count() == 0)
	await _arm_with_a_tap(run, Vector2(400.0, 120.0))   # the continuing tap
	await _park(run)
	_seen.clear()
	_watch(run)
	_touch(0, true, Vector2(400.0, 120.0))
	await _ticks(40)
	var n: int = _unwatch()
	_touch(0, false, Vector2(400.0, 120.0))
	await _frames(2)
	_check("after that whole dance a fresh tap is exactly one jump", n == 1 and _count("jump:down") == 1, "takeoffs=%d %s" % [n, _seen])

	# the `pause` action itself (a gamepad's Start) opens it, Start again resumes
	var ev := InputEventAction.new()
	ev.action = &"pause"
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(2)
	_check("the `pause` action opens the card", card.is_open())
	await _frames(2)
	var ev2 := InputEventAction.new()
	ev2.action = &"pause"
	ev2.pressed = true
	Input.parse_input_event(ev2)
	await _frames(2)
	_check("the `pause` action again resumes (a gamepad can leave the card without a screen)", not card.is_open() and not bool(run.call("is_run_paused")))

	# a mouse click works too (a touch laptop / the emulated first finger already proved the touch path)
	run.call("_open_pause_card")
	await _frames(2)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = _to_window(card.play_center())
	Input.parse_input_event(click)
	await _frames(1)
	click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = false
	click.position = _to_window(card.play_center())
	Input.parse_input_event(click)
	await _frames(3)
	_check("a real mouse click on PLAY resumes", not card.is_open())

	# a tap that misses both pads is not an activation; press on EXIT, release on PLAY is nothing
	run.call("_open_pause_card")
	await _frames(2)
	_touch(0, true, card.exit_center())
	await _frames(2)
	_touch(0, false, card.play_center())
	await _frames(3)
	_check("pressing EXIT but lifting on PLAY activates nothing (a tap = down and up on the SAME pad)",
		card.is_open() and not bool(run.get("_exiting")))
	_touch(0, true, Vector2(5.0, 5.0))
	await _frames(2)
	_touch(0, false, Vector2(5.0, 5.0))
	await _frames(3)
	_check("a tap on the bare dim activates nothing", card.is_open() and not bool(run.get("_exiting")))

	# a first-finger tap = the raw touch AND the emulated click in one frame: ONE activation
	var resumes: Array[int] = [0]
	var counter := func() -> void: resumes[0] += 1
	card.resume_pressed.connect(counter)
	_touch(0, true, card.play_center())
	await _frames(2)
	_touch(0, false, card.play_center())
	await _frames(3)
	card.resume_pressed.disconnect(counter)
	_check("one finger tap on PLAY = ONE resume (the emulated click is deduped in the same frame)", resumes[0] == 1, "resumes=%d" % resumes[0])
	await _free(run)

# ================================================================================================
#  focus loss
# ================================================================================================

func _focus_out() -> void:
	print(" focus loss:")
	await _set_screen(Vector2i(844, 390))
	for what: int in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		var label: String = "APPLICATION_FOCUS_OUT" if what == NOTIFICATION_APPLICATION_FOCUS_OUT else "WM_WINDOW_FOCUS_OUT"
		var run: Node2D = await _boot(2)
		var card: BlazePause = run.get("_card") as BlazePause
		await _arm_with_a_tap(run, Vector2(400.0, 200.0))
		_touch(0, true, Vector2(600.0, 300.0))   # a thumb is down when the app is backgrounded
		await _frames(2)
		run.notification(what)
		await _frames(2)
		_check("%s opens the pause card on a touch device" % label, card.is_open() and bool(run.call("is_run_paused")))
		_check("%s releases everything the thumb held" % label, TouchActions.held_count() == 0 and not Input.is_action_pressed(&"jump"))
		_touch(0, false, Vector2(600.0, 300.0))
		await _frames(2)
		await _free(run)
	# desktop keeps carrying on
	_force_touch(false)
	var d: Node2D = await _boot(1)
	d.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames(2)
	_check("desktop: losing focus does NOT open the card (behaviour unchanged)", not bool(d.call("is_pause_card_open")) and not bool(d.call("is_run_paused")))
	await _free(d)
	_force_touch(true)

# ================================================================================================
#  nothing is written on a phone
# ================================================================================================

func _text_nodes(n: Node, out: Array[Control]) -> void:
	if n is Label or n is BaseButton or n is RichTextLabel:
		out.append(n as Control)
	for c in n.get_children():
		_text_nodes(c, out)

func _text_of(c: Control) -> String:
	if c is Label:
		return (c as Label).text
	if c is BaseButton:
		return (c as Button).text if c is Button else ""
	if c is RichTextLabel:
		return (c as RichTextLabel).text
	return ""

func _wordless_scan() -> void:
	print(" wordless:")
	await _set_screen(Vector2i(844, 390))
	var run: Node2D = await _boot(3)
	await _arm_with_a_tap(run, Vector2(400.0, 200.0))
	var texts: Array[Control] = []
	_text_nodes(run, texts)
	_text_nodes(MobileLayoutManager.get_node("TouchLayer"), texts)
	var allow := RegEx.create_from_string(ALLOWED_TEXT)
	var stray: Array[String] = []
	var visible_n: int = 0
	for c: Control in texts:
		if not c.is_visible_in_tree():
			continue
		visible_n += 1
		var t: String = _text_of(c)
		if t.strip_edges().is_empty():
			continue
		if allow.search(t.strip_edges()) == null:
			stray.append("%s='%s'" % [c.name, t])
	_check("the run + the touch layer show only the stat labels (and FUD) as text: %d visible text nodes" % visible_n, stray.is_empty() and visible_n >= 2, ", ".join(stray))
	var layer_texts: Array[Control] = []
	_text_nodes(MobileLayoutManager.get_node("TouchLayer"), layer_texts)
	_check("the touch layer holds no Label / Button at all", layer_texts.is_empty())
	var forbid := RegEx.create_from_string(FORBIDDEN_WORDS)
	var card_texts: Array[Control] = []
	_text_nodes(run.get("_card"), card_texts)
	_check("the pause card holds no text at all", card_texts.is_empty())
	_check("the written exit exists in the tree (desktop needs it) but is hidden here",
		(run.get("_tapout_button") as Button).text.contains("TAP OUT") and not (run.get("_tapout_button") as Button).is_visible_in_tree())
	# the finish toast is the last words a player sees
	run.call("_show_toast", "BLAZE RUSH CLEAR!\n+7 BLAZE DIAMONDS\n+5 GOLD\nFLAWLESS! +5 DIAMONDS (1 burned)")
	var toast_texts: Array[Control] = []
	_text_nodes(run, toast_texts)
	var bad_toast: Array[String] = []
	for c: Control in toast_texts:
		if c.is_visible_in_tree() and forbid.search(_text_of(c)) != null and c != run.get("_tapout_button"):
			bad_toast.append("%s='%s'" % [c.name, _text_of(c)])
	_check("the finish toast names no key and gives no instruction", bad_toast.is_empty(), ", ".join(bad_toast))
	# the detector itself: the desktop exit text IS caught by the forbidden-word rule
	_check("(control) the scan's rule does catch 'TAP OUT (Q)'", forbid.search("  TAP OUT (Q)  ") != null and allow.search("TAP OUT (Q)") == null)
	await _free(run)

# ================================================================================================
#  the HUD follows the manager (lazy touch detection, a key press)
# ================================================================================================

func _hud_follows_the_manager() -> void:
	print(" hud follows touch detection:")
	await _set_screen(Vector2i(844, 390))
	# a laptop that is not (yet) known to be touch: keys shown, desktop run
	MobileLayoutManager.force_touch_ui = false
	MobileLayoutManager.is_touch_device = false
	MobileLayoutManager._keyboard_mode = false
	MobileLayoutManager.refresh()
	var run: Node2D = await _boot(1)
	var btn: Button = run.get("_tapout_button") as Button
	var margin: MarginContainer = run.get("_hud_margin") as MarginContainer
	_check("before any finger: the written exit shows and the HUD margins are the authored 16/12/16",
		btn.is_visible_in_tree() and margin.get_theme_constant("margin_left") == 16 and margin.get_theme_constant("margin_top") == 12
		and margin.get_theme_constant("margin_right") == 16)
	_check("before any finger: the run auto-runs (desktop path) and no touch layer is up",
		bool(run.get("_armed")) and not MobileLayoutManager.controls_visible)
	# the FIRST real finger flips the manager to touch lazily; its tap must not be lost
	var player: CharacterBody2D = _player(run)
	await _park(run)
	_seen.clear()
	_watch(run)
	_touch(0, true, Vector2(500.0, 200.0))
	await _ticks(40)
	var n: int = _unwatch()
	_touch(0, false, Vector2(500.0, 200.0))
	await _frames(2)
	_check("the first tap of a lazily detected touch device is NOT lost (fallback path): one jump", n == 1, "takeoffs=%d" % n)
	await _wait(0.45)
	MobileLayoutManager.refresh()
	await _frames(2)
	_check("the manager now knows it is a touch device and shows the blaze layer", MobileLayoutManager.is_touch_device and MobileLayoutManager.controls_visible
		and MobileLayoutManager.current_profile() == &"blaze")
	_check("the written exit disappears (the HUD followed controls_visibility_changed, not a build-time decision)", not btn.is_visible_in_tree())
	_check("the HUD margins moved to the safe area + Pause zone", margin.get_theme_constant("margin_right") > 60)
	# a real key press hands the screen back to the keyboard
	var key := InputEventKey.new()
	key.keycode = KEY_SHIFT
	key.physical_keycode = KEY_SHIFT
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(3)
	MobileLayoutManager.refresh()
	await _frames(2)
	_check("a key press: the layer hides and the written exit returns", not MobileLayoutManager.controls_visible and btn.is_visible_in_tree())
	_check("...and the authored margins return", margin.get_theme_constant("margin_right") == 16 and margin.get_theme_constant("margin_left") == 16)
	var key_up := InputEventKey.new()
	key_up.keycode = KEY_SHIFT
	key_up.physical_keycode = KEY_SHIFT
	key_up.pressed = false
	Input.parse_input_event(key_up)
	await _frames(2)
	MobileLayoutManager._keyboard_mode = false
	await _free(run)
	_force_touch(true)

# ================================================================================================
#  rotation mid-run
# ================================================================================================

func _rotation() -> void:
	print(" rotation:")
	await _set_screen(Vector2i(844, 390))
	var run: Node2D = await _boot(1)
	await _check_hud(run, "landscape")
	await _set_screen(Vector2i(390, 844))
	MobileLayoutManager.refresh()
	await _frames(3)
	_check("rotated: the portrait blaze layout is built", MobileLayoutManager.current_layout_key() == &"blaze_phone_portrait")
	await _check_hud(run, "portrait (rotated mid-run)")
	_check("rotated: the run is alive and still HOLDING (no reload, no restart)", is_instance_valid(run) and not bool(run.get("_armed")) and _player(run).position.x == 0.0)
	await _set_screen(Vector2i(844, 390))
	MobileLayoutManager.refresh()
	await _frames(3)
	await _check_hud(run, "landscape again")
	await _free(run)

# ================================================================================================
#  armed start through a REAL SceneRouter load, entered from the REAL portal
# ================================================================================================

func _allow_live_save() -> bool:
	# The portal marks its entrance used and calls GameManager.save_session(): only do that
	# against a throw-away user dir (fresh XDG_DATA_HOME) or CI, never a developer's save.
	return OS.get_environment("XDG_DATA_HOME") != "" or OS.get_environment("CI") != ""

func _armed_start_real_router() -> void:
	print(" armed start through the real router and portal:")
	await _set_screen(Vector2i(844, 390))
	var src: String = FileAccess.get_file_as_string("res://src/dashmode/blaze_portal.gd")
	var fade_at: int = src.find("request_fade_hide()")
	var load_at: int = src.find("SceneRouter.load_scene(")
	_check("blaze_portal.gd asks the manager to fade the controls BEFORE SceneRouter.load_scene", fade_at != -1 and load_at != -1 and fade_at < load_at)
	if not _allow_live_save():
		print("  [NOTE] XDG_DATA_HOME/CI not set: the live portal step is skipped so the dev save is not overwritten")
		return
	# the level's own controls are up (an opted-in node WITHOUT touch_profile() = platformer)
	var stand_in := Node.new()
	stand_in.add_to_group(MobileLayoutManager.GROUP_WANTED)
	add_child(stand_in)
	GameManager.blaze_portal_used[1] = false
	_to_transitioning()
	StateMachine.change_state(StateMachine.State.PLAYING)
	MobileLayoutManager.refresh()
	await _frames(4)
	_check("(setup) the level's platformer controls are up", MobileLayoutManager.controls_visible and MobileLayoutManager.current_profile() == &"platformer")
	var portal: Area2D = PORTAL_SCENE.instantiate()
	portal.set("level_index", 1)
	add_child(portal)
	await _frames(2)
	portal.set("_unlocked", true)
	var body := Node2D.new()
	body.add_to_group(&"player")
	add_child(body)
	get_tree().current_scene = null
	var observed: Dictionary = {}
	var on_loaded: Callable = func(_p: String) -> void:
		var run_now: Node = get_tree().current_scene
		observed["scene"] = run_now.scene_file_path if run_now != null else ""
		observed["state"] = StateMachine.get_current_state()
		observed["armed"] = bool(run_now.get("_armed")) if run_now != null else true
		observed["reveal_ready"] = bool(run_now.get("_reveal_ready")) if run_now != null else true
		observed["x"] = (run_now.get("_player") as CharacterBody2D).position.x if run_now != null else -1.0
		observed["visible"] = MobileLayoutManager.controls_visible
	SceneRouter.load_finished.connect(on_loaded, CONNECT_ONE_SHOT)
	var revealed_state: Array[String] = []
	var on_revealed: Callable = func() -> void: revealed_state.append(StateMachine.get_current_state())
	SceneRouter.revealed.connect(on_revealed, CONNECT_ONE_SHOT)
	portal.call("_on_body_entered", body)
	_check("the portal's entry fades the controls out (inert fade, not a snap): fading=%s" % MobileLayoutManager.is_hide_fading(),
		MobileLayoutManager.is_hide_fading() and not MobileLayoutManager.controls_visible)
	_check("...and nothing is held after the entry", TouchActions.held_count() == 0)
	var landed: bool = false
	for i in range(600):
		await get_tree().process_frame
		if observed.has("scene"):
			landed = true
			break
	_check("the router lands blaze_rush.tscn", landed and observed.get("scene", "") == BLAZE_SCENE, str(observed))
	_check("at the moment the scene is built the state is still TRANSITIONING (not PLAYING under the dissolve)", observed.get("state", "") == "TRANSITIONING", str(observed.get("state", "")))
	_check("...the run is HOLDING (armed=false, reveal not ready, cube at x=0) and the touch layer is not up yet",
		observed.get("armed", true) == false and observed.get("reveal_ready", true) == false and observed.get("x", -1.0) == 0.0 and observed.get("visible", true) == false, str(observed))
	var run: Node2D = get_tree().current_scene as Node2D
	# a tap during the dissolve (before the reveal) is ignored: it must not start the run
	_touch(0, true, Vector2(400.0, 200.0))
	await _frames(1)
	_touch(0, false, Vector2(400.0, 200.0))
	_check("a tap BEFORE the reveal does not start the run", not bool(run.get("_armed")))
	var waited: int = 0
	while revealed_state.is_empty() and waited < 240:
		await get_tree().process_frame
		waited += 1
	_check("the router revealed the scene", not revealed_state.is_empty())
	_check("PLAYING is entered at the reveal (the state when `revealed` fired: %s)" % [revealed_state], StateMachine.is_playing())
	await _frames(3)
	MobileLayoutManager.refresh()
	await _frames(2)
	_check("after the reveal the blaze touch layer is up", MobileLayoutManager.controls_visible and MobileLayoutManager.current_profile() == &"blaze")
	var cue: BlazeTapCue = run.get("_cue") as BlazeTapCue
	_check("...the tap-hand cue is showing", cue.is_cue_shown())
	await _wait(0.5)
	_check("...and the cube STILL holds at x=0 half a second after the reveal", _player(run).position.x == 0.0 and not bool(run.get("_armed")))
	_check("the written exit is not on screen", not (run.get("_tapout_button") as Button).is_visible_in_tree())
	await _arm_with_a_tap(run, Vector2(500.0, 200.0))
	await _ticks(15)
	_check("the first tap after the reveal starts the run (x=%.0f)" % _player(run).position.x, bool(run.get("_armed")) and _player(run).position.x > 40.0)
	# leave: the profile goes with the node
	run.queue_free()
	get_tree().current_scene = self
	await _frames(3)
	stand_in.queue_free()
	body.queue_free()
	portal.queue_free()
	GameManager.blaze_portal_used[1] = true
	_to_transitioning()
	TouchActions.release_all()
	MobileLayoutManager.refresh()
	await _frames(3)
	_check("after the run is gone the manager no longer asks for blaze", MobileLayoutManager.current_profile() != &"blaze")

## SceneRouter never emits `revealed` on the watchdog path: the 1.0 s safety timeout must
## still let the run begin.
func _reveal_timeout() -> void:
	print(" reveal safety timeout:")
	SceneRouter._revealed = false
	_to_transitioning()
	GameManager.dash_return = {"scene_path": str(LEVELS[1]), "position": Vector2(1450.0, 250.0), "level_index": 1}
	var run: Node2D = BLAZE_RUSH.instantiate()
	add_child(run)
	await _frames(3)
	_check("never revealed, 0.05 s in: still TRANSITIONING and holding", not StateMachine.is_playing() and not bool(run.get("_armed")))
	await _wait(0.6)
	_check("never revealed, 0.65 s in: still waiting (the timeout is 1.0 s)", not StateMachine.is_playing())
	await _wait(0.6)
	_check("never revealed, 1.25 s in: the safety timeout made it PLAYING", StateMachine.is_playing())
	_check("...and the cue is up, the cube still holds for the first tap", (run.get("_cue") as BlazeTapCue).is_cue_shown() and _player(run).position.x == 0.0)
	SceneRouter._revealed = true
	await _free(run)

# ================================================================================================
#  desktop is unchanged
# ================================================================================================

func _desktop_is_unchanged() -> void:
	print(" desktop:")
	_force_touch(false)
	await _set_screen(Vector2i(1280, 720))
	var run: Node2D = await _boot(1)
	_check("desktop: PLAYING at once, the cube auto-runs, no tap needed", StateMachine.is_playing() and bool(run.get("_armed")))
	await _ticks(20)
	_check("desktop: the cube moved on its own (x=%.0f)" % _player(run).position.x, _player(run).position.x > 60.0)
	_check("desktop: no tap-hand cue and no touch layer", not (run.get("_cue") as BlazeTapCue).is_cue_shown() and not MobileLayoutManager.controls_visible)
	_check("desktop: the written exit is shown", (run.get("_tapout_button") as Button).is_visible_in_tree())
	_check("desktop: the touch profile is still declared (inert without a touch device)", run.call("touch_profile") == &"blaze" and not bool(run.call("touch_suspended")))
	# Esc / Q / Backspace stay an instant exit
	await _free(run)
	for keycode: Key in [KEY_ESCAPE, KEY_Q, KEY_BACKSPACE]:
		var r: Node2D = await _boot(1)
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = true
		Input.parse_input_event(ev)
		await _frames(2)
		_check("desktop: key %s is still an instant exit (_exiting)" % OS.get_keycode_string(keycode), bool(r.get("_exiting")))
		r.set("_exiting", false)   # the router is not asked to move in this section
		SceneRouter._loading_path = ""
		await _free(r)
	_force_touch(true)

# ================================================================================================
#  lifecycle: the card's EXIT and the finish line, on all three stages
# ================================================================================================

func _audible() -> Dictionary:
	var blaze: Array[AudioStreamPlayer] = []
	var stage: Array[AudioStreamPlayer] = []
	for c in AudioManager.get_children():
		if c is AudioStreamPlayer and (c as AudioStreamPlayer).bus == &"Music":
			var p: AudioStreamPlayer = c
			if p.playing and not p.stream_paused and p.volume_db > -20.0 and not p.is_queued_for_deletion():
				if p.stream != null and p.stream.resource_path == BLAZE_TRACK:
					blaze.append(p)
				else:
					stage.append(p)
	return {"blaze": blaze, "stage": stage}

func _lifecycle() -> void:
	print(" lifecycle (real exits, real level scenes):")
	await _set_screen(Vector2i(844, 390))
	await _lifecycle_one(1, "card_exit")
	await _lifecycle_one(2, "finish")
	await _lifecycle_one(3, "finish")
	await _lifecycle_one(3, "card_exit")

func _lifecycle_one(level: int, route: String) -> void:
	var tag: String = "L%d %s" % [level, route]
	AudioManager.fade_out_music(0.01)
	GameManager.side_return = {}
	await _wait(0.1)
	# the stage song is playing (the level's own _ready starts it), then we leave for Blaze
	var level_node: Node = (load(str(LEVELS[level])) as PackedScene).instantiate()
	add_child(level_node)
	await _frames(2)
	await _wait(0.4)
	var stage_player: AudioStreamPlayer = AudioManager.current_music_player
	level_node.queue_free()
	await _frames(2)
	var run: Node2D = await _boot(level, true)
	_check("%s: Blaze paused the stage track and is the audible one" % tag, stage_player != null and stage_player.stream_paused and (_audible()["blaze"] as Array).size() == 1)
	await _arm_with_a_tap(run, Vector2(400.0, 160.0))
	var voice_before: int = AudioManager._voice_gen
	if route == "card_exit":
		var pause: VirtualButton = _pause_button()
		var pc: Vector2 = _centre(pause)
		_touch(2, true, pc)
		await _frames(2)
		_touch(2, false, pc)
		await _frames(2)
		var card: BlazePause = run.get("_card") as BlazePause
		_check("%s: the card is up" % tag, card.is_open())
		_touch(0, true, card.exit_center())
		await _frames(2)
		_touch(0, false, card.exit_center())
		await _frames(2)
		_check("%s: the card's EXIT ran the real exit (_exiting)" % tag, bool(run.get("_exiting")))
	else:
		# real finish: the cube is carried into the finish line by its own forward motion
		_player(run).global_position = Vector2(float(run.get("_course_length")) + 30.0, _player(run).global_position.y)
		var waited: int = 0
		while not bool(run.get("_exiting")) and waited < 600:
			await get_tree().process_frame
			waited += 1
		_check("%s: crossing the finish line ends in the exit (_exiting)" % tag, bool(run.get("_exiting")))
	_check("%s: side_return = {blaze, %d}" % [tag, level],
		GameManager.side_return.get("kind", "") == "blaze" and int(GameManager.side_return.get("level", -1)) == level, str(GameManager.side_return))
	_check("%s: the music override is released (token cleared)" % tag, int(run.get("_music_token")) == -1)
	_check("%s: the stage track RESUMED at once (the wipe is not silent)" % tag,
		AudioManager.current_music_player == stage_player and not stage_player.stream_paused and stage_player.playing)
	var landed: Node = null
	for i in range(300):
		await get_tree().process_frame
		var cur: Node = get_tree().current_scene
		if cur != null and cur != run and cur.scene_file_path == str(LEVELS[level]):
			landed = cur
			break
	_check("%s: the router lands the level scene" % tag, landed != null)
	await _wait(0.9)
	var a: Dictionary = _audible()
	_check("%s: exactly ONE stage track audible, no Blaze tail" % tag, (a["stage"] as Array).size() == 1 and (a["blaze"] as Array).is_empty(),
		"stage=%d blaze=%d" % [(a["stage"] as Array).size(), (a["blaze"] as Array).size()])
	_check("%s: no override left active, nothing retiring" % tag,
		not AudioManager._override_active and AudioManager._retiring.is_empty() and AudioManager._override_player == null)
	_check("%s: the stage-intro voice line was not replayed" % tag, AudioManager._voice_gen == voice_before)
	_check("%s: the touch layer holds nothing (held_count == 0)" % tag, TouchActions.held_count() == 0 and not Input.is_action_pressed(&"jump"))
	_check("%s: side_return was consumed by the level" % tag, GameManager.side_return.is_empty())
	await _frames(3)
	MobileLayoutManager.refresh()
	await _frames(2)
	_check("%s: the manager is back on the platformer profile (blaze is gone)" % tag, MobileLayoutManager.current_profile() == &"platformer",
		str(MobileLayoutManager.current_profile()))
	if landed != null:
		landed.queue_free()
	if is_instance_valid(run):
		run.queue_free()
	await _wait(0.4)
	GameManager.level_checkpoints.erase(level)
	get_tree().current_scene = self
	_to_transitioning()
	TouchActions.release_all()
	await _frames(2)
