class_name PlayerCamera
extends Camera2D

## Leads the view in the direction of travel and peeks down during fast falls,
## so the screen shows where Lil Blunt is going instead of where he's been.
## The lookahead is applied through `position` (the smoothed follow target),
## leaving `offset` untouched — ScreenShake owns `offset` and would otherwise
## zero our lookahead every time a shake ends.

## Max horizontal lead in px; reached at full sprint speed.
const LOOKAHEAD_MAX: float = 56.0
## px of lead per px/s of horizontal velocity.
const LOOKAHEAD_PER_SPEED: float = 0.28
## Exponential smoothing rate (1/s) — higher snaps faster.
const LOOKAHEAD_RESPONSE: float = 3.5
## Downward peek while falling fast, so landings aren't blind.
const FALL_PEEK: float = 34.0
const FALL_PEEK_MIN_SPEED: float = 330.0

var _base_position: Vector2
var _look: Vector2 = Vector2.ZERO
var _player: CharacterBody2D

func _ready() -> void:
	_base_position = position
	_player = get_parent() as CharacterBody2D

func _process(delta: float) -> void:
	if _player == null:
		return
	var target := Vector2.ZERO
	target.x = clampf(_player.velocity.x * LOOKAHEAD_PER_SPEED, -LOOKAHEAD_MAX, LOOKAHEAD_MAX)
	if _player.velocity.y > FALL_PEEK_MIN_SPEED:
		target.y = FALL_PEEK
	# Frame-rate-independent exponential smoothing on top of the camera's own
	# position smoothing — the lead drifts in, it never jerks.
	_look = _look.lerp(target, 1.0 - exp(-LOOKAHEAD_RESPONSE * delta))
	position = _base_position + _look
