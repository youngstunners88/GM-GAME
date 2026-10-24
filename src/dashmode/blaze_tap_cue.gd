class_name BlazeTapCue
extends Control
## The wordless "tap to go" hand for Blaze Rush's armed start (touch devices only).
##
## The founder's rule (2026-10-13, angry): mobile games do not have words or key names on
## them; a player learns by looking at a picture and moving a finger. Before the first tap
## the cube holds at the start line and this drawn pointing hand taps the air above the
## floor with a ripple at its fingertip. It is shown when the scene is revealed, hides on
## the first tap, and comes back when the player resumes from the pause card.
##
## Everything is `_draw` vectors (no art file, the web pack has no room) in the same
## cream-on-dark-outline style as the rotate cue, so it reads on all three stage plates.
##
## It must NEVER eat a tap: mouse_filter IGNORE (tests/blaze_hud_mouse_filter_test.gd walks
## every Control under the run and fails on a STOP). The real tap is taken by the touch
## layer's tap field above it, or by the run's own fallback when that layer is not up yet.

const CREAM := Color(1.0, 0.95, 0.75, 1.0)
const DARK := Color(0.06, 0.0, 0.12, 0.95)
## One tap cycle: the hand dips and the ripple blooms, then a short rest.
const CYCLE_SECONDS: float = 1.3
const FADE_SECONDS: float = 0.12
## Fingertip position as a share of the viewport (centred, just under the cube's lane).
const TIP_X: float = 0.5
const TIP_Y: float = 0.70

## Canvas units per dp, so the hand is one physical size on every screen.
var unit: float = 1.0

var _shown: bool = false
var _time: float = 0.0
var _fade: Tween

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	modulate.a = 0.0

func _ready() -> void:
	set_process(false)

## Fade the hand in and start tapping.
func show_cue() -> void:
	_shown = true
	_time = 0.0
	visible = true
	set_process(true)
	_fade_to(1.0)

## Fade the hand out (the first tap landed) and stop drawing.
func hide_cue() -> void:
	if not _shown and not visible:
		return
	_shown = false
	_fade_to(0.0)

## True while the hand is up (or fading in).
func is_cue_shown() -> bool:
	return _shown

func _fade_to(target: float) -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if not is_inside_tree():
		modulate.a = target
		visible = target > 0.0
		return
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", target, FADE_SECONDS)
	if target <= 0.0:
		_fade.tween_callback(_finish_hide)

func _finish_hide() -> void:
	if not _shown:
		visible = false
		set_process(false)

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var u: float = maxf(unit, 0.1)
	var phase: float = fmod(_time, CYCLE_SECONDS) / CYCLE_SECONDS
	# The dip: 0 -> 1 over the first 28 %, back over the next 20 %, then rest.
	var dip: float = 0.0
	if phase < 0.28:
		dip = phase / 0.28
	elif phase < 0.48:
		dip = 1.0 - (phase - 0.28) / 0.20
	var tip: Vector2 = Vector2(size.x * TIP_X, size.y * TIP_Y) + Vector2(0.0, 7.0 * u * dip)
	_draw_ripples(Vector2(size.x * TIP_X, size.y * TIP_Y), phase, u)
	_draw_hand(tip, u)

## Two rings that bloom from the fingertip when the hand touches down.
func _draw_ripples(centre: Vector2, phase: float, u: float) -> void:
	for i in range(2):
		var t: float = (phase - 0.24 - 0.12 * float(i)) / 0.55
		if t < 0.0 or t > 1.0:
			continue
		var r: float = lerpf(9.0, 42.0, t) * u
		var a: float = 0.85 * (1.0 - t)
		draw_arc(centre, r, 0.0, TAU, 48, Color(DARK.r, DARK.g, DARK.b, a), 6.5 * u, true)
		draw_arc(centre, r, 0.0, TAU, 48, Color(CREAM.r, CREAM.g, CREAM.b, a), 3.0 * u, true)

## A pointing hand: index finger up, a rounded palm, a thumb. The fingertip is `tip`.
func _draw_hand(tip: Vector2, u: float) -> void:
	var finger_w: float = 11.0 * u
	var finger_top: Vector2 = tip + Vector2(0.0, finger_w * 0.5)
	var finger_bot: Vector2 = tip + Vector2(0.0, 34.0 * u)
	var palm_c: Vector2 = tip + Vector2(3.0 * u, 50.0 * u)
	var palm_r: float = 19.0 * u
	var thumb_a: Vector2 = tip + Vector2(-12.0 * u, 50.0 * u)
	var thumb_b: Vector2 = tip + Vector2(-27.0 * u, 41.0 * u)
	# dark outline first, cream fill on top: the same shapes twice, the first one fatter
	for pass_index in range(2):
		var grow: float = 4.0 * u if pass_index == 0 else 0.0
		var col: Color = DARK if pass_index == 0 else CREAM
		_capsule(finger_top, finger_bot, finger_w + grow, col)
		draw_circle(palm_c, palm_r + grow * 0.5, col)
		_capsule(thumb_a, thumb_b, 9.0 * u + grow, col)
	# two knuckle creases so the shape reads as a hand rather than a blob
	var crease := Color(DARK.r, DARK.g, DARK.b, 0.55)
	draw_line(palm_c + Vector2(-5.0 * u, -6.0 * u), palm_c + Vector2(-5.0 * u, 2.0 * u), crease, 1.8 * u, true)
	draw_line(palm_c + Vector2(5.0 * u, -6.0 * u), palm_c + Vector2(5.0 * u, 2.0 * u), crease, 1.8 * u, true)

## A line with round ends (draw_line has flat caps).
func _capsule(a: Vector2, b: Vector2, width: float, col: Color) -> void:
	draw_line(a, b, col, width, true)
	draw_circle(a, width * 0.5, col)
	draw_circle(b, width * 0.5, col)
