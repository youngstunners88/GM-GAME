class_name VirtualButton
extends VirtualControl
## A large round thumb button that holds one InputMap action.
##
## HOLD  - the action is held exactly while a finger is on the button. Right for
##         JUMP (variable jump height needs the release), ATK (fire-breath hold)
##         and DASH (just_pressed on touch-down).
## TOGGLE - a tap flips it on or off and it stays on with both thumbs free. Right
##         for RUN: sprinting while still reaching JUMP with the same thumb was
##         the one thing the old held RUN button could not do.
##
## A button with no `action` just emits `activated`.
## Sliding the finger off does NOT release (the Kimi F4 lesson): the press ends
## when the finger lifts, because the GUI keeps delivering that finger's release
## to this control wherever it ends up.
##
## Glyphs are vector drawings (no text, no font, no art file). SKIP also draws a ring
## that fills while the finger is down (`hold_seconds`): the film itself decides when a
## held `jump` skips, the ring only shows how long that takes. `ring_progress` can also
## be driven from outside (a cooldown). `arm_delay_s` makes a button ignore presses for
## a moment after it appears (retry / home on a run-over screen: the thumb that was
## mashing FIRE must not hit them by accident).

signal activated
signal pressed
signal released
signal toggled(is_on: bool)
## Emitted once when a held SKIP-style ring reaches full (`hold_seconds` elapsed).
signal hold_completed

enum Mode { HOLD, TOGGLE }
## Append only: layout scenes store these as integers.
enum Glyph { NONE, JUMP, ATTACK, DASH, RUN, GRAB, PAUSE, SKIP, PICKAXE, CYLINDER, SCOPE, RETRY, HOME, PLAY, EXIT, EYE, CLAIM }

@export var action: StringName = &""
@export var mode: Mode = Mode.HOLD
@export var glyph: Glyph = Glyph.NONE
## > 0: while a finger is down a ring fills over this many seconds (SKIP).
@export var hold_seconds: float = 0.0
## 0..1 ring around the disc. Driven by `hold_seconds` while held, or set from outside.
@export_range(0.0, 1.0, 0.01) var ring_progress: float = 0.0 : set = _set_ring_progress
## Ignore presses for this long after the button appears (0 = always armed).
@export var arm_delay_s: float = 0.0
## True for a button whose action is a touch-only verb with no key binding
## (`ep2_touch_reload`, ...): the action is registered empty in the InputMap on _ready.
@export var touch_only: bool = false

var _finger: int = -1
var _is_on: bool = false
var _press_amount: float = 0.0 : set = _set_press_amount
var _tween: Tween
var _hold_elapsed: float = 0.0
var _hold_done: bool = false
var _arm_until_ms: int = 0

func _ready() -> void:
	super()
	set_process(false)
	if touch_only and action != &"":
		TouchActions.ensure_action(action)
	_start_arming()

func _process(delta: float) -> void:
	if _finger == -1 or hold_seconds <= 0.0:
		set_process(false)
		return
	_hold_elapsed += delta
	ring_progress = clampf(_hold_elapsed / hold_seconds, 0.0, 1.0)
	if ring_progress >= 1.0 and not _hold_done:
		_hold_done = true
		TouchActions.buzz(20)
		hold_completed.emit()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if not is_armed():
				# not armed yet: swallow the touch, own nothing
				accept_event()
				return
			if _finger == -1:
				_finger = touch.index
				_begin_press()
			accept_event()
		elif touch.index == _finger:
			_finger = -1
			_end_press()
			accept_event()
	elif event is InputEventScreenDrag:
		accept_event()

func _begin_press() -> void:
	_animate_press(1.0, 0.05)
	TouchActions.buzz()
	_hold_elapsed = 0.0
	_hold_done = false
	if hold_seconds > 0.0:
		ring_progress = 0.0
		set_process(true)
	match mode:
		Mode.HOLD:
			if action != &"":
				TouchActions.press(action)
		Mode.TOGGLE:
			_is_on = not _is_on
			if action != &"":
				if _is_on:
					TouchActions.press(action)
				else:
					TouchActions.release(action)
			toggled.emit(_is_on)
	pressed.emit()
	activated.emit()
	queue_redraw()

func _end_press() -> void:
	_animate_press(0.0, 0.12)
	_reset_hold()
	if mode == Mode.HOLD and action != &"":
		TouchActions.release(action)
	released.emit()
	queue_redraw()

## Is a finger on this button right now?
func is_down() -> bool:
	return _finger != -1

## TOGGLE state (always false for HOLD buttons).
func is_on() -> bool:
	return _is_on

## False during the `arm_delay_s` window after the button appears.
func is_armed() -> bool:
	return Time.get_ticks_msec() >= _arm_until_ms

func release() -> void:
	var was_active: bool = _finger != -1 or _is_on
	_finger = -1
	_is_on = false
	_reset_hold()
	if action != &"":
		TouchActions.release(action)
	# kill a press-in tween still running, or it lands AFTER this and leaves the
	# button drawn pressed with nothing held
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_press_amount = 0.0
	if was_active:
		released.emit()

func _on_visibility_changed() -> void:
	super()
	if is_visible_in_tree():
		_start_arming()

func _start_arming() -> void:
	if arm_delay_s <= 0.0:
		_arm_until_ms = 0
		return
	_arm_until_ms = Time.get_ticks_msec() + int(arm_delay_s * 1000.0)
	if is_inside_tree():
		get_tree().create_timer(arm_delay_s).timeout.connect(queue_redraw)
	queue_redraw()

## A hold ring that belongs to the finger resets with it; an externally driven ring
## (hold_seconds == 0) is left alone.
func _reset_hold() -> void:
	_hold_elapsed = 0.0
	_hold_done = false
	if hold_seconds > 0.0:
		ring_progress = 0.0
	set_process(false)

func _set_ring_progress(v: float) -> void:
	ring_progress = clampf(v, 0.0, 1.0)
	queue_redraw()

func _animate_press(target: float, seconds: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not is_inside_tree():
		_press_amount = target
		return
	_tween = create_tween()
	_tween.tween_property(self, "_press_amount", target, seconds)

func _set_press_amount(v: float) -> void:
	_press_amount = v
	queue_redraw()

# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	var th: TouchTheme = touch_theme
	var base_alpha: float = hint_alpha() if (hint_active or cue_active) else idle_alpha()
	var engaged: float = maxf(_press_amount, 1.0 if _is_on else 0.0)
	var alpha: float = lerpf(base_alpha, pressed_alpha(), engaged)
	if not is_armed():
		alpha *= 0.45
	var col: Color = tint()
	var c: Vector2 = local_center()
	var r: float = radius_dp * unit * (1.0 + 0.07 * _press_amount)
	var fill: float = th.fill_strength if th != null else 0.4
	var ring_w: float = maxf((th.ring_width_dp if th != null else 2.5) * unit, 1.5)

	# disc + ring
	draw_circle(c, r, Color(col.r, col.g, col.b, alpha * fill))
	draw_arc(c, r, 0.0, TAU, 48, Color(col.r, col.g, col.b, alpha), ring_w, true)
	# a lit TOGGLE gets a second outer ring so "RUN is on" reads at a glance
	if _is_on:
		draw_arc(c, r + ring_w * 1.8, 0.0, TAU, 48, Color(col.r, col.g, col.b, alpha * 0.8), ring_w, true)
	if cue_active:
		# a second, brighter ring: "a verb is available here" without a word (audit 2026-10-29 P2-2)
		draw_arc(c, r + ring_w * 2.1, 0.0, TAU, 48, Color(col.r, col.g, col.b, alpha * 0.9), ring_w * 1.2, true)
	# a hold ring (SKIP): faint track, bright fill clockwise from 12 o'clock
	if hold_seconds > 0.0 or ring_progress > 0.0:
		var rr: float = r + ring_w * 1.9
		draw_arc(c, rr, 0.0, TAU, 48, Color(1, 1, 1, alpha * 0.25), ring_w, true)
		if ring_progress > 0.0:
			draw_arc(c, rr, -PI * 0.5, -PI * 0.5 + TAU * ring_progress, 48, Color(1, 1, 1, clampf(alpha + 0.2, 0.0, 1.0)), ring_w * 1.4, true)

	var white := Color(1, 1, 1, clampf(alpha + 0.12, 0.0, 1.0))
	var stroke: float = maxf((th.glyph_width_dp if th != null else 3.6) * unit, 2.0)
	var g: float = r * 0.5   # glyph half-size
	_draw_glyph(c, g, stroke, white)

func _draw_glyph(c: Vector2, g: float, stroke: float, col: Color) -> void:
	var soft := Color(col.r, col.g, col.b, col.a * 0.7)
	match glyph:
		Glyph.JUMP:
			# two stacked chevrons: "lift" (and a nod to the double jump)
			draw_polyline(PackedVector2Array([c + Vector2(-g, g * 0.15), c + Vector2(0, -g * 0.55), c + Vector2(g, g * 0.15)]), col, stroke, true)
			draw_polyline(PackedVector2Array([c + Vector2(-g, g * 0.85), c + Vector2(0, g * 0.15), c + Vector2(g, g * 0.85)]), soft, stroke, true)
		Glyph.ATTACK:
			# starburst: a puff going off
			for i in 8:
				var a: float = TAU * float(i) / 8.0
				var d := Vector2(cos(a), sin(a))
				draw_line(c + d * g * 0.38, c + d * g * (1.0 if i % 2 == 0 else 0.72), col, stroke, true)
			draw_circle(c, g * 0.2, col)
		Glyph.DASH:
			draw_polyline(PackedVector2Array([c + Vector2(-g, -g * 0.7), c + Vector2(-g * 0.1, 0), c + Vector2(-g, g * 0.7)]), soft, stroke, true)
			draw_polyline(PackedVector2Array([c + Vector2(0, -g * 0.7), c + Vector2(g * 0.9, 0), c + Vector2(0, g * 0.7)]), col, stroke, true)
		Glyph.RUN:
			# lightning bolt
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(g * 0.2, -g), c + Vector2(-g * 0.6, g * 0.15), c + Vector2(-g * 0.05, g * 0.15),
				c + Vector2(-g * 0.25, g), c + Vector2(g * 0.6, -g * 0.2), c + Vector2(g * 0.05, -g * 0.2)]), col)
		Glyph.GRAB:
			# diamond: the DIAMONDS shard doubles as "interact"
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -g * 0.95), c + Vector2(g * 0.68, 0), c + Vector2(0, g * 0.95), c + Vector2(-g * 0.68, 0)]),
				Color(col.r, col.g, col.b, col.a * 0.9))
		Glyph.PAUSE:
			# two bars: the universal pause mark (no word needed)
			for side in [-1.0, 1.0]:
				var x: float = side * g * 0.34
				draw_line(c + Vector2(x, -g * 0.62), c + Vector2(x, g * 0.62), col, stroke * 1.2, true)
		Glyph.SKIP:
			# double chevron pointing right: "skip ahead"
			for o in [-g * 0.3, g * 0.5]:
				draw_polyline(PackedVector2Array([c + Vector2(-g * 0.5 + o, -g * 0.8), c + Vector2(g * 0.2 + o, 0), c + Vector2(-g * 0.5 + o, g * 0.8)]), col, stroke, true)
		Glyph.PICKAXE:
			# a handle running up and right, a curved head across its top end
			var h: Vector2 = Vector2(1, -1).normalized()
			var p: Vector2 = Vector2(1, 1).normalized()
			var tip: Vector2 = c + h * g * 0.6
			draw_line(c - h * g * 1.0, tip, col, stroke, true)
			draw_polyline(PackedVector2Array([tip - p * g * 1.0 - h * g * 0.15, tip + h * g * 0.35 - p * g * 0.5, tip + h * g * 0.5,
				tip + h * g * 0.35 + p * g * 0.5, tip + p * g * 1.0 - h * g * 0.15]), col, stroke * 1.1, true)
		Glyph.CYLINDER:
			# a revolver cylinder: six chambers round a hub
			draw_arc(c, g * 1.0, 0.0, TAU, 32, col, stroke * 0.9, true)
			for i in 6:
				var a: float = TAU * float(i) / 6.0 - PI * 0.5
				draw_circle(c + Vector2(cos(a), sin(a)) * g * 0.58, g * 0.2, col)
			draw_circle(c, g * 0.14, col)
		Glyph.SCOPE:
			# a sight: ring, four ticks crossing the ring, a dot
			draw_arc(c, g * 0.78, 0.0, TAU, 32, col, stroke * 0.9, true)
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				draw_line(c + d * g * 0.38, c + d * g * 1.15, col, stroke * 0.8, true)
			draw_circle(c, g * 0.1, col)
		Glyph.RETRY:
			# a circular arrow: try again
			var a0: float = -PI * 0.5 + 0.5
			var a1: float = a0 + TAU * 0.8
			var rad: float = g * 0.85
			draw_arc(c, rad, a0, a1, 32, col, stroke, true)
			var e: Vector2 = c + Vector2(cos(a1), sin(a1)) * rad
			var radial: Vector2 = Vector2(cos(a1), sin(a1))
			var tangent: Vector2 = Vector2(-sin(a1), cos(a1))
			draw_colored_polygon(PackedVector2Array([e + tangent * g * 0.6, e + radial * g * 0.5, e - radial * g * 0.5]), col)
		Glyph.HOME:
			# a house: roof, walls, door
			draw_polyline(PackedVector2Array([c + Vector2(-g, -g * 0.05), c + Vector2(0, -g * 0.95), c + Vector2(g, -g * 0.05)]), col, stroke, true)
			draw_polyline(PackedVector2Array([c + Vector2(-g * 0.72, -g * 0.25), c + Vector2(-g * 0.72, g * 0.9), c + Vector2(g * 0.72, g * 0.9), c + Vector2(g * 0.72, -g * 0.25)]), col, stroke, true)
			draw_polyline(PackedVector2Array([c + Vector2(-g * 0.2, g * 0.9), c + Vector2(-g * 0.2, g * 0.35), c + Vector2(g * 0.2, g * 0.35), c + Vector2(g * 0.2, g * 0.9)]), soft, stroke * 0.8, true)
		Glyph.PLAY:
			# a right-pointing triangle: resume
			draw_colored_polygon(PackedVector2Array([c + Vector2(-g * 0.55, -g * 0.85), c + Vector2(g * 0.85, 0), c + Vector2(-g * 0.55, g * 0.85)]), col)
		Glyph.EXIT:
			# a doorway with an arrow leaving it
			draw_polyline(PackedVector2Array([c + Vector2(0.0, -g), c + Vector2(-g * 0.85, -g), c + Vector2(-g * 0.85, g), c + Vector2(0.0, g)]), col, stroke, true)
			draw_line(c + Vector2(-g * 0.4, 0.0), c + Vector2(g * 0.95, 0.0), col, stroke, true)
			draw_polyline(PackedVector2Array([c + Vector2(g * 0.45, -g * 0.45), c + Vector2(g * 0.95, 0.0), c + Vector2(g * 0.45, g * 0.45)]), col, stroke, true)
		Glyph.EYE:
			# an eye: lens outline and a pupil
			var up := PackedVector2Array()
			var down := PackedVector2Array()
			for i in 13:
				var t: float = float(i) / 12.0
				var x: float = lerpf(-g, g, t)
				var y: float = g * 0.6 * sin(PI * t)
				up.append(c + Vector2(x, -y))
				down.append(c + Vector2(x, y))
			draw_polyline(up, col, stroke, true)
			draw_polyline(down, col, stroke, true)
			draw_circle(c, g * 0.3, col)
		Glyph.CLAIM:
			# a circled check: claim the payout now, before the rest is banked
			draw_arc(c, g * 0.9, 0.0, TAU, 40, col, stroke, true)
			draw_polyline(PackedVector2Array([c + Vector2(-g * 0.48, g * 0.02), c + Vector2(-g * 0.1, g * 0.4), c + Vector2(g * 0.5, -g * 0.42)]), col, stroke * 1.1, true)
		_:
			pass
