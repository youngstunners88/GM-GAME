extends Node2D
## Blaze Rush — Geometry-Dash-style auto-runner secret mode.
## Lil Blunt compresses into a SMOKE cube and auto-runs a neon corridor:
## one tap to jump, instant restart on crash, $SMOKE tokens along the path.
## Launched by BlazePortal via GameManager.dash_return; returns to the
## source level on finish or exit.

const RUN_SPEED: float = 320.0
const GRAVITY: float = 2200.0
const JUMP_VELOCITY: float = -700.0
const GROUND_Y: float = BlazeRushLayouts.GROUND_Y
const CRASH_Y: float = 700.0
const PLAYER_SIZE: float = 28.0
const COMPLETION_GOLD: int = 5
const FLAWLESS_DIAMONDS: int = 5
const SCORE_PER_SMOKE: int = 10

var _level_index: int = 1
var _course_length: float = 3400.0
var _player: CharacterBody2D
var _player_visual: Node2D
var _camera: Camera2D
var _attempts: int = 1
var _smoke_this_attempt: int = 0
var _smoke_tokens: Array[Area2D] = []
var _finished: bool = false
var _tap_buffered: bool = false

@onready var _smoke_label: Label = Label.new()
@onready var _attempt_label: Label = Label.new()
@onready var _progress: ProgressBar = ProgressBar.new()

func _ready() -> void:
	_level_index = int(GameManager.dash_return.get("level_index", 1))
	var layout := BlazeRushLayouts.get_layout(_level_index)
	_course_length = layout.get("length", 3400.0)
	_build_background()
	_build_ground(layout)
	_build_obstacles(layout)
	_build_finish()
	_build_player()
	_build_camera()
	_build_hud()
	StateMachine.change_state(StateMachine.State.PLAYING)
	AudioManager.play_sfx("powerup")

# --- construction -----------------------------------------------------------

func _build_background() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.01, 0.12, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	add_child(layer)

func _build_ground(layout: Dictionary) -> void:
	# Walkable floor split around "gap" obstacles.
	var gaps: Array = []
	for ob in layout.get("obstacles", []):
		if ob.get("type", "") == "gap":
			gaps.append(Vector2(ob.x, ob.x + ob.get("w", 140.0)))
	gaps.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)

	var cursor: float = -200.0
	for gap in gaps:
		_make_floor_segment(cursor, gap.x)
		cursor = gap.y
	_make_floor_segment(cursor, _course_length + 600.0)

func _make_floor_segment(from_x: float, to_x: float) -> void:
	var w := to_x - from_x
	if w <= 0.0:
		return
	var body := StaticBody2D.new()
	body.position = Vector2(from_x, GROUND_Y)
	var visual := ColorRect.new()
	visual.color = Color(0.25, 0.1, 0.45, 1.0)
	visual.size = Vector2(w, 220.0)
	body.add_child(visual)
	var edge := ColorRect.new()
	edge.color = Color(0.6, 0.95, 0.8, 1.0)
	edge.size = Vector2(w, 4.0)
	body.add_child(edge)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, 220.0)
	col.shape = shape
	col.position = Vector2(w / 2.0, 110.0)
	body.add_child(col)
	add_child(body)

func _build_obstacles(layout: Dictionary) -> void:
	for ob in layout.get("obstacles", []):
		match ob.get("type", ""):
			"candle":
				_make_candle(ob.x)
			"fud_wall":
				_make_fud_wall(ob.x)
			"smoke":
				_make_smoke_token(ob.x, ob.get("y", 60.0))
			"gap":
				pass  # handled by _build_ground

func _make_candle(x: float) -> void:
	# Red market-dip candle: thin wick + body, kills on touch.
	var area := Area2D.new()
	area.position = Vector2(x, GROUND_Y)
	area.collision_mask = 2  # player runs on layer 2
	area.set_meta("hazard", true)
	var body := ColorRect.new()
	body.color = Color(0.9, 0.15, 0.2, 1.0)
	body.size = Vector2(18, 34)
	body.position = Vector2(-9, -34)
	area.add_child(body)
	var wick := ColorRect.new()
	wick.color = Color(0.9, 0.15, 0.2, 0.8)
	wick.size = Vector2(4, 14)
	wick.position = Vector2(-2, -48)
	area.add_child(wick)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14, 30)
	col.shape = shape
	col.position = Vector2(0, -17)
	area.add_child(col)
	area.body_entered.connect(func(b: Node2D) -> void:
		if b == _player:
			_crash()
	)
	add_child(area)

func _make_fud_wall(x: float) -> void:
	# Solid block: landing on top is safe, slamming the side is a crash
	# (checked via collision normal in _physics_process).
	var body := StaticBody2D.new()
	body.position = Vector2(x, GROUND_Y - 52.0)
	body.set_meta("fud_wall", true)
	var visual := ColorRect.new()
	visual.color = Color(0.5, 0.2, 0.6, 1.0)
	visual.size = Vector2(46, 52)
	visual.position = Vector2(-23, 0)
	body.add_child(visual)
	var tag := Label.new()
	tag.text = "FUD"
	tag.position = Vector2(-16, 14)
	tag.add_theme_font_size_override("font_size", 14)
	body.add_child(tag)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(46, 52)
	col.shape = shape
	col.position = Vector2(0, 26)
	body.add_child(col)
	add_child(body)

func _make_smoke_token(x: float, height: float) -> void:
	var area := Area2D.new()
	area.position = Vector2(x, GROUND_Y - height)
	area.collision_mask = 2
	var puff := ColorRect.new()
	puff.color = Color(0.75, 0.9, 0.85, 0.95)
	puff.size = Vector2(16, 16)
	puff.position = Vector2(-8, -8)
	area.add_child(puff)
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 14.0
	col.shape = shape
	area.add_child(col)
	area.body_entered.connect(func(b: Node2D) -> void:
		if b == _player and area.visible:
			area.visible = false
			area.set_deferred("monitoring", false)
			_smoke_this_attempt += 1
			_update_hud()
			AudioManager.play_sfx("coin")
	)
	add_child(area)
	_smoke_tokens.append(area)

func _build_finish() -> void:
	var area := Area2D.new()
	area.position = Vector2(_course_length + 120.0, GROUND_Y - 60.0)
	area.collision_mask = 2
	var ring := ColorRect.new()
	ring.color = Color(1.0, 0.85, 0.2, 1.0)
	ring.size = Vector2(20, 120)
	ring.position = Vector2(-10, -60)
	area.add_child(ring)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 300)
	col.shape = shape
	area.add_child(col)
	area.body_entered.connect(func(b: Node2D) -> void:
		if b == _player:
			_finish_run()
	)
	add_child(area)

func _build_player() -> void:
	_player = CharacterBody2D.new()
	_player.collision_layer = 2
	_player.collision_mask = 1
	_player_visual = Node2D.new()
	var cube := ColorRect.new()
	cube.color = Color(0.35, 0.85, 0.45, 1.0)
	cube.size = Vector2(PLAYER_SIZE, PLAYER_SIZE)
	cube.position = Vector2(-PLAYER_SIZE / 2.0, -PLAYER_SIZE / 2.0)
	_player_visual.add_child(cube)
	for eye_x in [-6.0, 4.0]:
		var eye := ColorRect.new()
		eye.color = Color(0.05, 0.05, 0.1, 1.0)
		eye.size = Vector2(4, 7)
		eye.position = Vector2(eye_x, -6)
		_player_visual.add_child(eye)
	_player.add_child(_player_visual)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(PLAYER_SIZE - 4.0, PLAYER_SIZE - 4.0)
	col.shape = shape
	_player.add_child(col)
	add_child(_player)
	_reset_player()

func _build_camera() -> void:
	_camera = Camera2D.new()
	_camera.position = Vector2(0, 360)
	add_child(_camera)
	_camera.make_current()

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	layer.add_child(margin)

	var row := HBoxContainer.new()
	margin.add_child(row)

	_smoke_label.add_theme_font_size_override("font_size", 22)
	row.add_child(_smoke_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_attempt_label.add_theme_font_size_override("font_size", 22)
	row.add_child(_attempt_label)

	var exit_btn := Button.new()
	exit_btn.text = "  ✕  "
	exit_btn.focus_mode = Control.FOCUS_NONE
	exit_btn.pressed.connect(_exit_to_level)
	row.add_child(exit_btn)

	_progress.max_value = 100.0
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(0, 6)
	_progress.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_progress.offset_top = -8.0
	layer.add_child(_progress)

	_update_hud()

# --- run loop ----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# Whole-screen tap/click = jump (mobile-first, Geometry Dash convention).
	if event is InputEventScreenTouch and event.pressed:
		_tap_buffered = true
	elif event is InputEventMouseButton and event.pressed:
		_tap_buffered = true
	elif event.is_action_pressed("jump"):
		_tap_buffered = true

func _physics_process(delta: float) -> void:
	if _finished or _player == null:
		return

	_player.velocity.x = RUN_SPEED
	_player.velocity.y += GRAVITY * delta

	if _tap_buffered and _player.is_on_floor():
		_player.velocity.y = JUMP_VELOCITY
		_spin_cube()
	_tap_buffered = false

	_player.move_and_slide()

	# Side-slamming a FUD wall is a crash; landing on top is safe.
	for i in range(_player.get_slide_collision_count()):
		var collision := _player.get_slide_collision(i)
		var collider := collision.get_collider()
		if collider and collider.has_meta("fud_wall") and absf(collision.get_normal().x) > 0.5:
			_crash()
			return

	if _player.position.y > CRASH_Y:
		_crash()
		return

	_camera.position.x = _player.position.x + 240.0
	_progress.value = clampf(_player.position.x / _course_length * 100.0, 0.0, 100.0)

func _spin_cube() -> void:
	var tween := create_tween()
	tween.tween_property(_player_visual, "rotation", _player_visual.rotation + PI, 0.35)

func _crash() -> void:
	if _finished:
		return
	_attempts += 1
	_smoke_this_attempt = 0
	ScreenShake.shake(0.2, 6.0)
	AudioManager.play_sfx("hit")
	_reset_player()
	for token in _smoke_tokens:
		token.visible = true
		token.set_deferred("monitoring", true)
	_update_hud()

func _reset_player() -> void:
	_player.position = Vector2(0.0, GROUND_Y - PLAYER_SIZE)
	_player.velocity = Vector2.ZERO
	_player_visual.rotation = 0.0

func _update_hud() -> void:
	_smoke_label.text = "💨 %d" % _smoke_this_attempt
	_attempt_label.text = "ATTEMPT %d " % _attempts

# --- finish / exit -----------------------------------------------------------

func _finish_run() -> void:
	if _finished:
		return
	_finished = true

	# Bank the run: SMOKE persists, score pays out (no combo interference).
	GameManager.add_smoke(_smoke_this_attempt)
	ComboSystem.add_score_no_combo(_smoke_this_attempt * SCORE_PER_SMOKE)

	var first_clear: bool = not GameManager.blaze_rush_completed.get(_level_index, false)
	var toast_lines: Array[String] = ["BLAZE RUSH CLEAR!", "💨 +%d SMOKE" % _smoke_this_attempt]
	if first_clear:
		GoldMineSystem.mine_gold(COMPLETION_GOLD)
		toast_lines.append("+%d GOLD" % COMPLETION_GOLD)
		if _attempts == 1:
			var kept := GoldMineSystem.collect_diamonds(FLAWLESS_DIAMONDS)
			toast_lines.append("FLAWLESS! +%d 💎 (1 burned)" % kept)
		GameManager.blaze_rush_completed[_level_index] = true

	AudioManager.play_sfx("powerup")
	_show_toast("\n".join(toast_lines))
	await get_tree().create_timer(1.8).timeout
	_exit_to_level()

func _show_toast(text: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.add_theme_font_size_override("font_size", 34)
	label.modulate = Color(1.0, 0.85, 0.3, 1.0)
	layer.add_child(label)

func _exit_to_level() -> void:
	var return_path: String = GameManager.dash_return.get(
		"scene_path", "res://src/level/level_01_smoke_realm.tscn"
	)
	var portal_pos: Vector2 = GameManager.dash_return.get("position", Vector2.ZERO)
	if portal_pos != Vector2.ZERO:
		# LevelBase spawns from checkpoint slot 1 — drop the player back at the portal.
		GameManager.save_checkpoint(1, 990 + _level_index, portal_pos)
	GameManager.dash_return = {}
	SceneRouter.load_scene(return_path)
