extends Area2D
## Blaze Portal — hidden Geometry-Dash-style secret entrance.
## Locked until the player's accumulated score crosses `unlock_threshold`;
## then it brightens, pulses, and entering launches the Blaze Rush run
## for `level_index`. Shows a ✓ ring once that run has been completed.

@export var unlock_threshold: int = 1500
@export var level_index: int = 1

## Hint label font on a mouse-and-keyboard machine (unchanged).
const HINT_FONT_PX: int = 12
## Touch: the hint is this tall in dp, clamped to a sane canvas-unit range.
const TOUCH_HINT_DP: float = 11.0
const TOUCH_HINT_MIN_PX: int = 14
const TOUCH_HINT_MAX_PX: int = 44
const TOUCH_HINT_WIDTH: float = 240.0

## Hint font size in canvas units for a screen where one dp is `dp_units` canvas
## units. Pure, so a test can pose as a 2x phone (1.85 u/dp) or a 3x portrait one.
static func touch_hint_font_px(dp_units: float) -> int:
	return clampi(int(round(TOUCH_HINT_DP * maxf(dp_units, 0.1))), TOUCH_HINT_MIN_PX, TOUCH_HINT_MAX_PX)

var _unlocked: bool = false
var _ring: Node2D
var _hint: Label
var _pulse_tween: Tween

func _ready() -> void:
	# One Blaze Rush run per stage — same rule the founder gave for the Smoke
	# Lounge diamond. The portal is removed, not merely disabled, so it cannot
	# be re-entered by accident mid-chase.
	if GameManager.is_side_entrance_used("blaze", level_index):
		queue_free()
		return
	body_entered.connect(_on_body_entered)
	GameManager.score_changed.connect(_on_any_score_changed)
	ComboSystem.score_changed.connect(_on_any_score_changed)
	_setup_visual()
	_refresh_state()

func _setup_visual() -> void:
	# Smoke-ring torus: two concentric rounded rects reading as a glowing ring.
	_ring = Node2D.new()
	add_child(_ring)

	var outer := ColorRect.new()
	outer.color = Color(0.55, 0.95, 0.75, 0.9)
	outer.size = Vector2(56, 72)
	outer.position = Vector2(-28, -36)
	_ring.add_child(outer)

	var inner := ColorRect.new()
	inner.color = Color(0.06, 0.02, 0.12, 1.0)
	inner.size = Vector2(36, 52)
	inner.position = Vector2(-18, -26)
	_ring.add_child(inner)

	var core := ColorRect.new()
	core.name = "Core"
	core.color = Color(0.9, 0.55, 1.0, 0.35)
	core.size = Vector2(28, 44)
	core.position = Vector2(-14, -22)
	_ring.add_child(core)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position = Vector2(-52, -78)
	_hint.custom_minimum_size = Vector2(104, 0)
	_hint.add_theme_font_size_override("font_size", HINT_FONT_PX)
	if TouchUi.is_touch():
		# 12 px is 6.5 dp tall on a phone: unreadable. Size the hint in dp (the
		# camera of a platformer stage is unzoomed, so canvas units are world
		# units), and widen + raise the label so the bigger text stays centred
		# over the ring instead of growing off to the right.
		var px: int = touch_hint_font_px(TouchUi.metrics().dp)
		_hint.add_theme_font_size_override("font_size", px)
		_hint.custom_minimum_size = Vector2(TOUCH_HINT_WIDTH, 0)
		_hint.position = Vector2(-TOUCH_HINT_WIDTH * 0.5, -44.0 - float(px) * 1.5)
	add_child(_hint)

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(56, 72)
	col.shape = shape
	add_child(col)

func _current_total_score() -> int:
	return GameManager.total_score + ComboSystem.current_score

func _on_any_score_changed(_v: int) -> void:
	if not _unlocked:
		_refresh_state()

func _refresh_state() -> void:
	if GameManager.blaze_rush_completed.get(level_index, false):
		_unlocked = true
		_ring.modulate = Color(1.0, 0.9, 0.4, 1.0)
		_hint.text = "BLAZE RUSH ✓"
		return
	if _current_total_score() >= unlock_threshold:
		if not _unlocked:
			_unlocked = true
			_on_unlocked()
	else:
		_ring.modulate = Color(1.0, 1.0, 1.0, 0.25)
		_hint.text = "??? %d PTS" % unlock_threshold

func _on_unlocked() -> void:
	_ring.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_hint.text = "BLAZE RUSH!"
	AudioManager.play_sfx("powerup")
	ScreenShake.shake(0.2, 5.0)
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_ring, "scale", Vector2(1.12, 1.12), 0.5)
	_pulse_tween.tween_property(_ring, "scale", Vector2(1.0, 1.0), 0.5)

func _on_body_entered(body: Node2D) -> void:
	if not _unlocked or not body.is_in_group("player"):
		return
	GameManager.mark_side_entrance_used("blaze", level_index)
	# Remember where to come back to before leaving the level.
	GameManager.dash_return = {
		"scene_path": get_tree().current_scene.scene_file_path,
		"position": global_position,
		"level_index": level_index,
	}
	# The level's on-screen controls dissolve with the dive wipe instead of snapping off:
	# load_scene() moves the StateMachine to TRANSITIONING, which hides the touch layer, and
	# this asks the manager to fade THAT one hide (0.12 s, controls inert meanwhile). Only
	# when the controls are actually up - on a desktop nothing is shown and nothing is armed.
	if MobileLayoutManager.controls_visible:
		MobileLayoutManager.request_fade_hide()
	# Match the wipe to THIS realm's palette, not a blanket green/purple smoke
	# cloud — see SceneRouter.blaze_transition_for_level for why.
	SceneRouter.load_scene("res://src/dashmode/blaze_rush.tscn",
		SceneRouter.blaze_transition_for_level(level_index),
		SceneRouter.blaze_wipe_seconds())
