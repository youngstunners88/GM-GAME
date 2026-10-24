class_name VirtualSwipePad
extends VirtualControl
## Finger-movement steering for the Episode 2 mine runner (no buttons, no words).
##
## A real, VISIBLE control (a faint ring with four chevrons under the left thumb, the ring
## jumps under wherever the thumb lands: DYNAMIC origin) with per-finger ownership like the
## stick. It turns finger travel into the runner's ordinary InputMap verbs, so the runner
## reads `move_left` / `move_right` / `jump` / `move_down` exactly as it does from the keyboard:
##
##   * HOP   a sideways swipe of HOP_DP (and clearly more sideways than vertical) pulses
##           move_left / move_right and re-anchors x, so another HOP_DP hops again without
##           lifting the thumb.
##   * JUMP  an upward swipe of JUMP_DP (clearly more vertical than sideways) pulses `jump`,
##           then a JUMP_LOCKOUT_MS lockout, and the finger must come back down JUMP_REARM_DP
##           or lift before the next jump (one long swipe never jumps twice). Coming back down
##           re-anchors y at the finger: the next jump is a fresh JUMP_DP upward from there.
##   * DUCK  a downward swipe of DUCK_DP presses `move_down` and HOLDS it while the finger
##           stays below the anchor + DUCK_RELEASE_DP (hysteresis), for at least
##           DUCK_MIN_HOLD_MS even if the finger lifts early (a flick ducks an arrow volley).
##
## All distances are DP of finger travel (constants below, tune on a real device). The
## decision logic is the pure inner `Classifier` (explicit clock, dp coordinates) so a test
## can feed synthetic point streams; the Control only converts events and applies results.
##
## Suspension (death / pause): `on_suspended` drops a held duck ITSELF (`move_down` is in
## TouchActions.RESUME_ACTIONS, so leaving it wanted would bring it back at respawn) and the
## finger that was down is ignored until it lifts (never adopted). Hide / rotation /
## focus loss: release() drops everything. The pad's left edge stays EDGE_INBOARD_DP in from
## the screen edge so the OS back-swipe gesture is not triggered by a hop.

# --- the numbers (dp of finger travel unless named otherwise) -------------------
const SLOP_DP := 8.0
const HOP_DP := 22.0
const JUMP_DP := 20.0
const DUCK_DP := 24.0
const DUCK_RELEASE_DP := 12.0
const JUMP_REARM_DP := 10.0
## The dominant axis must beat the other by this ratio to count as a swipe.
const AXIS_RATIO := 1.3
const JUMP_LOCKOUT_MS := 120
const DUCK_MIN_HOLD_MS := 150
## Keep the pad's left edge this far in from the screen edge (OS back-swipe strip).
const EDGE_INBOARD_DP := 24.0
const RING_RADIUS_DP := 44.0
const FLASH_SECONDS := 0.28

enum Cmd { HOP_LEFT, HOP_RIGHT, JUMP, DUCK_ON, DUCK_OFF }

## Pure gesture classifier: dp coordinates in, `Cmd` lists out, explicit clock (msec).
class Classifier extends RefCounted:
	var anchor: Vector2 = Vector2.ZERO
	var last: Vector2 = Vector2.ZERO
	var down_now: bool = false
	var duck_on: bool = false
	var duck_since_ms: int = 0
	## When a pending duck release is due (msec), or -1.
	var duck_release_at_ms: int = -1
	var jump_armed: bool = true
	var jump_peak_y: float = 0.0
	var jump_lock_until_ms: int = 0

	## A finger touched down at `p`.
	func down(p: Vector2, _now_ms: int) -> void:
		anchor = p
		last = p
		down_now = true
		jump_armed = true
		jump_peak_y = p.y
		jump_lock_until_ms = 0
		# a duck still being held from a flick keeps its own timer

	## The finger moved to `p`.
	func move(p: Vector2, now_ms: int) -> Array[int]:
		var out: Array[int] = []
		if not down_now:
			return out
		last = p
		# track how far the finger has come back down since the last jump; once it has, the
		# jump re-arms AND y re-anchors at the finger, so a wiggle after a long swipe up
		# can never jump again by itself (it takes a fresh JUMP_DP upward from here)
		if not jump_armed:
			jump_peak_y = minf(jump_peak_y, p.y)
			if p.y - jump_peak_y >= JUMP_REARM_DP:
				jump_armed = true
				anchor.y = p.y
		var d: Vector2 = p - anchor
		if d.length() >= SLOP_DP:
			# HOP: clearly sideways. Re-anchor x so a further HOP_DP hops again.
			if absf(d.x) >= HOP_DP and absf(d.x) >= AXIS_RATIO * absf(d.y):
				out.append(Cmd.HOP_RIGHT if d.x > 0.0 else Cmd.HOP_LEFT)
				anchor.x = p.x
				d = p - anchor
			# JUMP: clearly upward, armed, not locked out. Re-anchor y.
			if jump_armed and now_ms >= jump_lock_until_ms and d.y <= -JUMP_DP \
					and absf(d.y) >= AXIS_RATIO * absf(d.x):
				out.append(Cmd.JUMP)
				jump_armed = false
				jump_lock_until_ms = now_ms + JUMP_LOCKOUT_MS
				jump_peak_y = p.y
				anchor.y = p.y
				d = p - anchor
		# DUCK is independent of x (hops are allowed while ducking)
		if not duck_on:
			if d.y >= DUCK_DP:
				duck_on = true
				duck_since_ms = now_ms
				duck_release_at_ms = -1
				out.append(Cmd.DUCK_ON)
		elif d.y < DUCK_RELEASE_DP:
			if now_ms - duck_since_ms >= DUCK_MIN_HOLD_MS:
				duck_on = false
				duck_release_at_ms = -1
				out.append(Cmd.DUCK_OFF)
			else:
				duck_release_at_ms = duck_since_ms + DUCK_MIN_HOLD_MS
		else:
			duck_release_at_ms = -1
		return out

	## The finger lifted. A duck younger than DUCK_MIN_HOLD_MS is kept until it is due.
	func up(now_ms: int) -> Array[int]:
		var out: Array[int] = []
		down_now = false
		if duck_on:
			if now_ms - duck_since_ms >= DUCK_MIN_HOLD_MS:
				duck_on = false
				duck_release_at_ms = -1
				out.append(Cmd.DUCK_OFF)
			else:
				duck_release_at_ms = duck_since_ms + DUCK_MIN_HOLD_MS
		return out

	## Call every frame while `needs_poll()`: releases a pending duck when it is due.
	func poll(now_ms: int) -> Array[int]:
		var out: Array[int] = []
		if duck_on and duck_release_at_ms >= 0 and now_ms >= duck_release_at_ms:
			duck_on = false
			duck_release_at_ms = -1
			out.append(Cmd.DUCK_OFF)
		return out

	func needs_poll() -> bool:
		return duck_on and duck_release_at_ms >= 0

	## Drop everything now (suspend / hide): releases a held duck at once.
	func cancel() -> Array[int]:
		var out: Array[int] = []
		if duck_on:
			out.append(Cmd.DUCK_OFF)
		duck_on = false
		duck_release_at_ms = -1
		down_now = false
		jump_armed = true
		return out

## Active region as fractions (x, y, w, h) of the safe rectangle.
@export var region: Rect2 = Rect2(0.0, 0.12, 0.44, 0.88)
## Ring centre when idle, in dp inward from the safe rect's bottom-left corner.
@export var rest_offset_dp: Vector2 = Vector2(112, 92)

var _finger: int = -1
## A finger that was down across a suspension (or pressed during one): ignored until it lifts.
var _finger_dead: bool = false
var _rest: Vector2 = Vector2.ZERO          # local coords
var _cls: Classifier = Classifier.new()
var _active_amount: float = 0.0 : set = _set_active_amount
var _flash_dir: Vector2 = Vector2.ZERO
var _flash_age: float = 99.0
var _tween: Tween

func _ready() -> void:
	super()
	set_process(false)

# --- layout ------------------------------------------------------------------

func apply_layout(m: TouchMetrics, unit_scale: float) -> void:
	unit = m.dp * unit_scale
	dp = m.dp
	var rect: Rect2 = m.safe_rect
	var pos: Vector2 = rect.position + rect.size * region.position
	var sz: Vector2 = rect.size * region.size
	# the OS back-swipe strip: keep the left edge inboard of the SCREEN edge
	var min_left: float = EDGE_INBOARD_DP * m.dp
	if pos.x < min_left:
		sz.x = maxf(sz.x - (min_left - pos.x), 1.0)
		pos.x = min_left
	position = pos
	size = sz
	var global_rest := Vector2(rect.position.x + rest_offset_dp.x * unit, rect.end.y - rest_offset_dp.y * unit)
	_rest = _clamp_ring(global_rest - position)
	queue_redraw()

func _has_point(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(point)

## Keep the whole ring inside the region (and so on screen).
func _clamp_ring(p: Vector2) -> Vector2:
	var r: float = RING_RADIUS_DP * unit
	var lo := Vector2(r, r)
	var hi := Vector2(maxf(size.x - r, r), maxf(size.y - r, r))
	return p.clamp(lo, hi)

# --- input -------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _finger == -1:
				_finger = touch.index
				_finger_dead = TouchActions.is_suspended()
				if not _finger_dead:
					_cls.down(touch.position / maxf(dp, 0.001), Time.get_ticks_msec())
					_animate_active(1.0)
			accept_event()
		elif touch.index == _finger:
			_finger = -1
			if not _finger_dead:
				_run(_cls.up(Time.get_ticks_msec()))
			_finger_dead = false
			_animate_active(0.0)
			accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _finger and not _finger_dead and not TouchActions.is_suspended():
			_run(_cls.move(drag.position / maxf(dp, 0.001), Time.get_ticks_msec()))
			queue_redraw()
		accept_event()

## Apply classifier output to the InputMap through TouchActions.
func _run(cmds: Array[int]) -> void:
	for c in cmds:
		match c:
			Cmd.HOP_LEFT:
				TouchActions.pulse(&"move_left")
				_flash(Vector2.LEFT)
			Cmd.HOP_RIGHT:
				TouchActions.pulse(&"move_right")
				_flash(Vector2.RIGHT)
			Cmd.JUMP:
				TouchActions.pulse(&"jump")
				_flash(Vector2.UP)
			Cmd.DUCK_ON:
				TouchActions.press(&"move_down")
				_flash(Vector2.DOWN)
			Cmd.DUCK_OFF:
				TouchActions.release(&"move_down")
	if not cmds.is_empty() and (cmds.has(Cmd.HOP_LEFT) or cmds.has(Cmd.HOP_RIGHT) or cmds.has(Cmd.JUMP) or cmds.has(Cmd.DUCK_ON)):
		TouchActions.buzz(6)
	set_process(_cls.needs_poll() or _flash_age < FLASH_SECONDS)
	queue_redraw()

func _flash(dir: Vector2) -> void:
	_flash_dir = dir
	_flash_age = 0.0
	set_process(true)

func _process(delta: float) -> void:
	if _cls.needs_poll():
		_run(_cls.poll(Time.get_ticks_msec()))
	if _flash_age < FLASH_SECONDS:
		_flash_age += delta
		queue_redraw()
	if not _cls.needs_poll() and _flash_age >= FLASH_SECONDS:
		set_process(false)

## Is a finger steering with this pad right now?
func is_active() -> bool:
	return _finger != -1 and not _finger_dead

## True while the pad holds `move_down` (a duck).
func is_ducking() -> bool:
	return _cls.duck_on

## Injection stopped (death / pause): drop a held duck ourselves, ignore the finger until it lifts.
func on_suspended(on: bool) -> void:
	if on:
		_run(_cls.cancel())
		_finger_dead = _finger != -1
		_animate_active(0.0)

## Let go of everything from OUTSIDE (hide, rotation, focus loss). The finger is NOT
## remembered for adoption: a pad never takes over a finger it no longer owns.
func release() -> void:
	_finger = -1
	_finger_dead = false
	_run(_cls.cancel())
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_active_amount = 0.0

func _animate_active(target: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not is_inside_tree():
		_active_amount = target
		return
	_tween = create_tween()
	_tween.tween_property(self, "_active_amount", target, 0.10)

func _set_active_amount(v: float) -> void:
	_active_amount = v
	queue_redraw()

# --- drawing -----------------------------------------------------------------

## The ring sits under the thumb while a finger is down, at its rest spot otherwise.
func _ring_centre() -> Vector2:
	if _finger != -1 and not _finger_dead:
		return _clamp_ring(_cls.anchor * dp)
	return _rest

func _draw() -> void:
	var col: Color = tint()
	var idle: float = hint_alpha() if hint_active else idle_alpha()
	var alpha: float = lerpf(idle * 0.62, pressed_alpha() * 0.62, _active_amount)
	var r: float = RING_RADIUS_DP * unit
	var ring_w: float = maxf((touch_theme.ring_width_dp if touch_theme != null else 2.5) * unit, 1.5)
	var c: Vector2 = _ring_centre()
	draw_circle(c, r, Color(col.r, col.g, col.b, alpha * 0.22))
	draw_arc(c, r, 0.0, TAU, 56, Color(col.r, col.g, col.b, alpha), ring_w, true)
	# four chevrons pointing outward: up / down / left / right
	var flash: float = clampf(1.0 - _flash_age / FLASH_SECONDS, 0.0, 1.0)
	for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var lit: float = flash if d == _flash_dir else 0.0
		var a: float = clampf(alpha * 0.95 + lit * 0.7, 0.0, 1.0)
		_draw_chevron(c + d * r * 0.62, d, r * 0.17, Color(1, 1, 1, a), ring_w * (1.0 + lit * 0.5))
	# the thumb: a small dot at the finger's position while steering
	if _finger != -1 and not _finger_dead:
		var finger_pos: Vector2 = _cls.last * dp
		var off: Vector2 = (finger_pos - c).limit_length(r * 1.1)
		draw_circle(c + off, 11.0 * unit, Color(col.r, col.g, col.b, clampf(alpha * 1.1, 0.0, 1.0)))
		draw_arc(c + off, 11.0 * unit, 0.0, TAU, 24, Color(1, 1, 1, clampf(alpha + 0.1, 0.0, 1.0)), ring_w, true)

func _draw_chevron(at: Vector2, dir: Vector2, s: float, col: Color, w: float) -> void:
	var side: Vector2 = Vector2(-dir.y, dir.x)
	draw_polyline(PackedVector2Array([at - dir * s * 0.6 + side * s, at + dir * s * 0.6, at - dir * s * 0.6 - side * s]), col, w, true)
