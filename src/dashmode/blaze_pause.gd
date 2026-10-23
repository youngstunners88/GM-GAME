class_name BlazePause
extends CanvasLayer
## Blaze Rush's WORDLESS pause card (touch): a dim, one big round PLAY triangle and a
## smaller EXIT doorway. Nothing is written on it.
##
## Why it exists. The run has one verb (tap anywhere), so the on-screen controls are a
## full-screen tap field plus one small pause button (src/input/mobile). A phone has no
## Esc and no Q: this card is the touch player's way to stop, come back, or leave. It
## also opens by itself when the app loses focus (a call, the notification shade, an app
## switch), so a backgrounded tab never drops the player back into a moving cube.
## `pause_menu.tscn` cannot be reused: its Restart and Quit call GameManager.reset_session().
##
## LAYERING. This card is canvas layer 40; the Blaze touch layer is 60. While the card is
## up the run reports `touch_suspended()`, which makes the layer-60 controls inert
## (MobileLayoutManager LAYERING RULE) so every touch lands here, not on the tap field.
##
## TOUCH TRAP 11. Godot only turns the FIRST finger down into a mouse click, so a second
## finger would never reach an ordinary Button. The card therefore reacts to the raw
## finger events itself and dedupes against the emulated click that arrives in the SAME
## frame (the same one-activation-per-frame rule as PauseMenu._activate).
##
## The two discs are real VirtualButtons used as pure drawings (mouse_filter IGNORE, no
## action): the card shares the touch layer's glyphs instead of copying them.

signal resume_pressed
signal exit_pressed

const LAYER_INDEX: int = 40
const DIM_ALPHA: float = 0.58
## PLAY is 80 dp across (the brief asks for >= 72) with a 12 dp hit pad on top.
const PLAY_RADIUS_DP: float = 40.0
const PLAY_HIT_PAD_DP: float = 12.0
## EXIT is smaller and sits clear of PLAY so a thumb aiming for PLAY cannot leave the run.
const EXIT_RADIUS_DP: float = 26.0
const EXIT_HIT_PAD_DP: float = 12.0
const EXIT_GAP_DP: float = 48.0
const PAD_NONE := &""
const PAD_PLAY := &"play"
const PAD_EXIT := &"exit"

const BACKING := Color(0.06, 0.0, 0.12, 0.78)
const RING := Color(1.0, 0.95, 0.75, 0.9)

var _dim: ColorRect
var _field: Control
var _play_vis: VirtualButton
var _exit_vis: VirtualButton
var _dp: float = 1.0
var _play_c: Vector2 = Vector2.ZERO
var _exit_c: Vector2 = Vector2.ZERO
## pointer key ("t0" a finger, "m" the mouse) -> the pad it went down on.
var _down: Dictionary = {}
var _last_activation_frame: int = -1
var _opened_frame: int = -1

func _init() -> void:
	layer = LAYER_INDEX
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func _ready() -> void:
	name = "BlazePause"
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(0.0, 0.0, 0.0, DIM_ALPHA)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	# The one STOP Control of the card: it covers the screen so no tap can reach the run.
	_field = Control.new()
	_field.name = "BlazePauseField"
	_field.mouse_filter = Control.MOUSE_FILTER_STOP
	_field.set_anchors_preset(Control.PRESET_FULL_RECT)
	_field.gui_input.connect(_on_field_input)
	_field.draw.connect(_draw_backing)
	add_child(_field)

	_play_vis = _make_disc(VirtualButton.Glyph.PLAY, PLAY_RADIUS_DP)
	_exit_vis = _make_disc(VirtualButton.Glyph.EXIT, EXIT_RADIUS_DP)
	_relayout()
	get_tree().root.size_changed.connect(_relayout)

func _exit_tree() -> void:
	var root: Window = get_tree().root if is_inside_tree() else null
	if root != null and root.size_changed.is_connected(_relayout):
		root.size_changed.disconnect(_relayout)

func _make_disc(glyph: VirtualButton.Glyph, radius_dp: float) -> VirtualButton:
	var b := VirtualButton.new()
	b.glyph = glyph
	b.radius_dp = radius_dp
	b.hit_pad_dp = 0.0
	b.role = &"jump"
	# a drawing only: it must never take a touch (the field above decides what was hit)
	b.base_mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.hint_active = true
	add_child(b)
	return b

# --- public ------------------------------------------------------------------

## Show the card (the run freezes itself; this only draws and listens).
func open() -> void:
	_relayout()
	_down.clear()
	_opened_frame = Engine.get_process_frames()
	visible = true
	_field.queue_redraw()

func close() -> void:
	visible = false
	_down.clear()

func is_open() -> bool:
	return visible

## Centres and hit radii in canvas units (the tests tap exactly there).
func play_center() -> Vector2:
	return _play_c

func exit_center() -> Vector2:
	return _exit_c

func play_hit_radius() -> float:
	return (PLAY_RADIUS_DP + PLAY_HIT_PAD_DP) * _dp

func exit_hit_radius() -> float:
	return (EXIT_RADIUS_DP + EXIT_HIT_PAD_DP) * _dp

## Which pad is under `pos` (canvas units): PAD_PLAY, PAD_EXIT or PAD_NONE.
func pad_at(pos: Vector2) -> StringName:
	if pos.distance_to(_play_c) <= play_hit_radius():
		return PAD_PLAY
	if pos.distance_to(_exit_c) <= exit_hit_radius():
		return PAD_EXIT
	return PAD_NONE

# --- layout ------------------------------------------------------------------

## Place the pads from the live touch metrics: PLAY at the centre of the safe area, EXIT
## beside it (landscape) or under it (portrait), both sized in dp.
func _relayout() -> void:
	if _field == null:
		return
	var m: TouchMetrics = TouchUi.metrics()
	_dp = maxf(m.dp, 0.1)
	var centre: Vector2 = m.safe_rect.position + m.safe_rect.size * 0.5
	var step: float = (PLAY_RADIUS_DP + EXIT_GAP_DP + EXIT_RADIUS_DP) * _dp
	_play_c = centre
	if m.orientation == TouchMetrics.PORTRAIT:
		_exit_c = centre + Vector2(0.0, step)
	else:
		_exit_c = centre + Vector2(step, 0.0)
	_place(_play_vis, _play_c, PLAY_RADIUS_DP)
	_place(_exit_vis, _exit_c, EXIT_RADIUS_DP)
	_field.queue_redraw()

func _place(disc: VirtualButton, centre: Vector2, radius_dp: float) -> void:
	disc.unit = _dp
	disc.dp = _dp
	disc.size = Vector2.ONE * (radius_dp + 8.0) * 2.0 * _dp
	disc.position = centre - disc.size * 0.5
	disc.queue_redraw()

## A solid dark disc under each glyph so it reads on any stage plate, and a brighter ring
## on the pad a finger is currently on.
func _draw_backing() -> void:
	_draw_pad_backing(_play_c, PLAY_RADIUS_DP, PAD_PLAY)
	_draw_pad_backing(_exit_c, EXIT_RADIUS_DP, PAD_EXIT)

func _draw_pad_backing(centre: Vector2, radius_dp: float, pad: StringName) -> void:
	var r: float = radius_dp * _dp
	var engaged: bool = _down.values().has(pad)
	_field.draw_circle(centre, r, BACKING)
	var ring_w: float = maxf((3.4 if engaged else 2.4) * _dp, 1.5)
	_field.draw_arc(centre, r, 0.0, TAU, 56, RING if engaged else Color(RING.r, RING.g, RING.b, 0.55), ring_w, true)

# --- input -------------------------------------------------------------------

func _on_field_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		_pointer("t%d" % touch.index, touch.pressed, touch.canceled, touch.position)
		_field.accept_event()
	elif event is InputEventScreenDrag:
		_field.accept_event()
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT:
			_pointer("m", click.pressed, false, click.position)
		_field.accept_event()

## A tap = down and up on the SAME pad, finger not cancelled. Activation is deduped per
## engine frame: a first-finger tap arrives as the raw finger event AND the click Godot
## emulates from it; a second finger only as the raw one.
func _pointer(key: String, pressed: bool, canceled: bool, pos: Vector2) -> void:
	var pad: StringName = pad_at(pos)
	if pressed:
		_down[key] = pad
		_field.queue_redraw()
		return
	var started: StringName = _down.get(key, PAD_NONE)
	_down.erase(key)
	_field.queue_redraw()
	if canceled or started == PAD_NONE or started != pad:
		return
	_activate(started)

func _activate(pad: StringName) -> void:
	var frame: int = Engine.get_process_frames()
	if frame == _last_activation_frame:
		return
	_last_activation_frame = frame
	if pad == PAD_PLAY:
		resume_pressed.emit()
	elif pad == PAD_EXIT:
		exit_pressed.emit()

## Gamepad / keyboard: the `pause` action (Start) or accept resumes. Esc is not handled
## here on purpose: the run's own _input turns it into the instant exit it has always been.
func _input(event: InputEvent) -> void:
	if not visible or event.is_echo():
		return
	if Engine.get_process_frames() == _opened_frame:
		return   # the very press that opened the card must not close it again
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		resume_pressed.emit()
