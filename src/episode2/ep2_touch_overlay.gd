class_name Ep2TouchOverlay
extends CanvasLayer
## Episode 2's WORDLESS touch overlay: the pause card (a dim, one big round PLAY triangle and a HOME
## house) and the lone HOME icon that stays reachable under the portrait "turn your phone" cue.
## Nothing is written on it (founder 2026-10-13: a phone has no keys, no words).
##
## Why it exists. Escape is Episode 2's only exit and a phone has no Escape. The runner and on-foot
## layouts carry a small PAUSE button that presses the `pause` action; Ep2Entry opens this card for
## it, pauses the sim (StateMachine PAUSED), and returns to the menu through the very path Escape
## uses. `pause_menu.tscn` is NOT reused: its Restart / Quit call GameManager.reset_session().
##
## LAYERING. The card is canvas layer 70, above the touch layer (18, or 60 for the film / end /
## rotate profiles) and the film / weapon-selector layers (40). While the card is up the sim is
## PAUSED, so the runner / foot controls underneath are SUSPENDED (dimmed, nothing injected) and
## every touch lands here.
##
## TOUCH TRAP 11. Godot only turns the FIRST finger down into a mouse click, so a second finger
## would never reach an ordinary Button. Each pad therefore reacts to the raw finger events and
## dedupes against the emulated click arriving in the SAME frame (one activation per frame).
##
## The pad glyphs are real VirtualButtons used as pure drawings (mouse_filter IGNORE, no action):
## the card shares the touch layer's PLAY / HOME vectors instead of copying them.

signal resume_pressed
signal home_pressed

enum Mode { HIDDEN, PAUSE, PORTRAIT }

const LAYER_INDEX: int = 70
const DIM_ALPHA: float = 0.58
## Visible radius (dp) + invisible hit pad (dp) of each pad. Hit diameter = 2 x (radius + pad):
## PLAY 108 dp, HOME 88 dp - both above the 72 dp the brief asks of a pause card.
const PLAY_RADIUS_DP: float = 44.0
const HOME_RADIUS_DP: float = 34.0
const PAD_HIT_DP: float = 10.0
## Centre-to-centre distance of PLAY and HOME (dp) so a thumb aimed at PLAY cannot leave the run.
const PAD_SPACING_DP: float = 150.0
## HOME sits this far (dp) above the bottom of the safe area under the portrait cue.
const PORTRAIT_HOME_LIFT_DP: float = 84.0
const PAD_NONE := &""
const PAD_PLAY := &"play"
const PAD_HOME := &"home"
const BACKING := Color(0.06, 0.03, 0.0, 0.8)
const RING := Color(1.0, 0.9, 0.62, 0.9)

## One round, tappable pad. A tap = down AND up on this pad, finger not cancelled.
class Pad extends Control:
	signal tapped
	var radius_dp: float = 40.0
	var hit_pad_dp: float = 10.0
	var unit: float = 1.0
	var _down: Dictionary = {}
	var _last_activation_frame: int = -1

	func _has_point(point: Vector2) -> bool:
		var half: float = size.x * 0.5
		return point.distance_to(Vector2(half, half)) <= half

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			var touch := event as InputEventScreenTouch
			_pointer("t%d" % touch.index, touch.pressed, touch.canceled, touch.position)
			accept_event()
		elif event is InputEventScreenDrag:
			accept_event()
		elif event is InputEventMouseButton:
			var click := event as InputEventMouseButton
			if click.button_index == MOUSE_BUTTON_LEFT:
				_pointer("m", click.pressed, false, click.position)
			accept_event()

	func _pointer(key: String, pressed: bool, canceled: bool, pos: Vector2) -> void:
		if pressed:
			_down[key] = true
			queue_redraw()
			return
		var started: bool = _down.erase(key)
		queue_redraw()
		if canceled or not started or not _has_point(pos):
			return
		# one activation per engine frame: a first-finger tap arrives as the raw finger event AND the
		# click Godot emulates from it
		var frame: int = Engine.get_process_frames()
		if frame == _last_activation_frame:
			return
		_last_activation_frame = frame
		tapped.emit()

	func is_engaged() -> bool:
		return not _down.is_empty()

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = radius_dp * unit
		var engaged: bool = is_engaged()
		draw_circle(c, r, BACKING)
		var ring_w: float = maxf((3.4 if engaged else 2.4) * unit, 1.5)
		draw_arc(c, r, 0.0, TAU, 56, RING if engaged else Color(RING.r, RING.g, RING.b, 0.6), ring_w, true)

var _dim: ColorRect
var _field: Control
var _play: Pad
var _home: Pad
var _play_vis: VirtualButton
var _home_vis: VirtualButton
var _mode: int = Mode.HIDDEN
var _dp: float = 1.0
var _opened_frame: int = -1

func _init() -> void:
	layer = LAYER_INDEX
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func _ready() -> void:
	name = "Ep2TouchOverlay"
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(0.0, 0.0, 0.0, DIM_ALPHA)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	# The one full-screen STOP Control: while the pause card is up no tap may reach the run.
	_field = Control.new()
	_field.name = "Field"
	_field.mouse_filter = Control.MOUSE_FILTER_STOP
	_field.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_field)
	_play = _make_pad("PlayPad", PLAY_RADIUS_DP, VirtualButton.Glyph.PLAY)
	_home = _make_pad("HomePad", HOME_RADIUS_DP, VirtualButton.Glyph.HOME)
	_play_vis = _play.get_child(0) as VirtualButton
	_home_vis = _home.get_child(0) as VirtualButton
	_play.tapped.connect(func() -> void: resume_pressed.emit())
	_home.tapped.connect(func() -> void: home_pressed.emit())
	_relayout()
	get_tree().root.size_changed.connect(_relayout)

func _exit_tree() -> void:
	var root: Window = get_tree().root if is_inside_tree() else null
	if root != null and root.size_changed.is_connected(_relayout):
		root.size_changed.disconnect(_relayout)

func _make_pad(pad_name: String, radius_dp: float, glyph: VirtualButton.Glyph) -> Pad:
	var pad := Pad.new()
	pad.name = pad_name
	pad.radius_dp = radius_dp
	pad.hit_pad_dp = PAD_HIT_DP
	pad.mouse_filter = Control.MOUSE_FILTER_STOP
	pad.focus_mode = Control.FOCUS_NONE
	var vis := VirtualButton.new()
	vis.glyph = glyph
	vis.radius_dp = radius_dp
	vis.hit_pad_dp = 0.0
	vis.role = &"jump"
	# a drawing only: it must never take a touch (the pad above decides what was hit)
	vis.base_mouse_filter = Control.MOUSE_FILTER_IGNORE
	vis.hint_active = true
	pad.add_child(vis)
	add_child(pad)
	return pad

# --- public ------------------------------------------------------------------

## The pause card: dim + PLAY + HOME. The caller pauses the sim; this only draws and listens.
func show_pause() -> void:
	_mode = Mode.PAUSE
	_open()

## Only the HOME icon, no dim, nothing else swallowing touches (the portrait rotate cue stays
## visible underneath and a locked-portrait phone is never trapped on it).
func show_portrait_exit() -> void:
	_mode = Mode.PORTRAIT
	_open()

func close() -> void:
	_mode = Mode.HIDDEN
	visible = false
	for pad: Pad in [_play, _home]:
		if pad != null:
			pad._down.clear()

func is_open() -> bool:
	return _mode != Mode.HIDDEN

func mode() -> int:
	return _mode

## Centres and hit radii in canvas units (the tests tap exactly there).
func play_center() -> Vector2:
	return _centre_of(_play)

func home_center() -> Vector2:
	return _centre_of(_home)

func play_hit_radius() -> float:
	return (PLAY_RADIUS_DP + PAD_HIT_DP) * _dp

func home_hit_radius() -> float:
	return (HOME_RADIUS_DP + PAD_HIT_DP) * _dp

## True when the PLAY pad takes touches in the current mode.
func play_enabled() -> bool:
	return _mode == Mode.PAUSE

## Which pad is under `pos` (canvas units) in the current mode.
func pad_at(pos: Vector2) -> StringName:
	if _mode == Mode.HIDDEN:
		return PAD_NONE
	if _mode == Mode.PAUSE and pos.distance_to(play_center()) <= play_hit_radius():
		return PAD_PLAY
	if pos.distance_to(home_center()) <= home_hit_radius():
		return PAD_HOME
	return PAD_NONE

func _centre_of(pad: Pad) -> Vector2:
	return pad.position + pad.size * 0.5 if pad != null else Vector2.ZERO

# --- layout ------------------------------------------------------------------

func _open() -> void:
	_opened_frame = Engine.get_process_frames()
	_relayout()
	visible = true

## Place the pads from the live touch metrics, sized in dp.
func _relayout() -> void:
	if _field == null:
		return
	var m: TouchMetrics = TouchUi.metrics()
	_dp = maxf(m.dp, 0.1)
	var centre: Vector2 = m.safe_rect.position + m.safe_rect.size * 0.5
	var pause_mode: bool = _mode == Mode.PAUSE
	_dim.visible = pause_mode
	_field.mouse_filter = Control.MOUSE_FILTER_STOP if pause_mode else Control.MOUSE_FILTER_IGNORE
	_play.visible = pause_mode
	var half: float = PAD_SPACING_DP * 0.5 * _dp
	var play_c: Vector2 = centre - Vector2(half, 0.0)
	var home_c: Vector2 = centre + Vector2(half, 0.0)
	if _mode == Mode.PORTRAIT:
		home_c = Vector2(centre.x, m.safe_rect.end.y - PORTRAIT_HOME_LIFT_DP * _dp)
	_place(_play, play_c, PLAY_RADIUS_DP)
	_place(_home, home_c, HOME_RADIUS_DP)

func _place(pad: Pad, centre: Vector2, radius_dp: float) -> void:
	pad.unit = _dp
	pad.size = Vector2.ONE * (radius_dp + PAD_HIT_DP) * 2.0 * _dp
	pad.position = centre - pad.size * 0.5
	var vis: VirtualButton = pad.get_child(0) as VirtualButton
	vis.unit = _dp
	vis.dp = _dp
	vis.radius_dp = radius_dp
	vis.size = pad.size
	vis.position = Vector2.ZERO
	vis.queue_redraw()
	pad.queue_redraw()

# --- keyboard / gamepad -------------------------------------------------------

## The `pause` action (gamepad Start) or accept resumes; Escape leaves for the menu, exactly what
## it does when the card is not up (the run itself is paused, so its own handler cannot hear it).
func _input(event: InputEvent) -> void:
	if _mode != Mode.PAUSE or event.is_echo():
		return
	if Engine.get_process_frames() == _opened_frame:
		return   # the very press that opened the card must not close it again
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		resume_pressed.emit()
	elif event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		home_pressed.emit()
