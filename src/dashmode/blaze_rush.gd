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

## "Electric Haze" palette (Grok 4.5 dispatch, docs/model-responses/
## 2026-07-29-grok-blaze-rush.md) — deliberately distinct from every other
## realm: hot/electric rather than the Smoke Realm's forest calm, Crystal
## Caverns' cool cave, or the Smoke Lounge's chill purple-grey. This is the
## secret FAST mode; it's allowed to look different.
const COLOR_VOID := Color(0.04, 0.0, 0.08, 1.0)
const COLOR_HAZE := Color(0.35, 0.05, 0.55, 1.0)
const COLOR_ACCENT_LIME := Color(0.55, 1.0, 0.25, 1.0)
const COLOR_HAZARD := Color(1.0, 0.25, 0.08, 1.0)
const COLOR_SAFE_GROUND := Color(0.45, 0.35, 0.75, 1.0)
const COLOR_SAFE_EDGE := Color(0.3, 1.0, 0.85, 1.0)
const COLOR_COLLECTIBLE := Color(1.0, 0.95, 0.75, 1.0)

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
var _exiting: bool = false
## Snapshot dash_return at _ready so a mid-run reset() can't clear it.
var _return_path: String = ""
var _return_pos: Vector2 = Vector2.ZERO

## Hazard telegraph (Grok's "critical for auto-run" call): one reusable
## warning bar, not one per obstacle — repositions each frame to whichever
## lethal hazard (candle or gap) is next ahead of the player, fading in as
## it approaches. fud_walls aren't tracked here: they're visibly landable,
## not an ambush the way a thin candle or a floor gap is at 320px/s.
var _hazard_x: Array[float] = []
var _telegraph: ColorRect
const TELEGRAPH_LEAD: float = 450.0

@onready var _smoke_label: Label = Label.new()
@onready var _attempt_label: Label = Label.new()
@onready var _progress: ProgressBar = ProgressBar.new()

func _ready() -> void:
	_level_index = int(GameManager.dash_return.get("level_index", 1))
	_return_path = str(GameManager.dash_return.get("scene_path",
		"res://src/level/level_01_smoke_realm.tscn"))
	_return_pos = GameManager.dash_return.get("position", Vector2.ZERO)
	var layout := BlazeRushLayouts.get_layout(_level_index)
	_course_length = layout.get("length", 3400.0)
	_build_background()
	_build_ground(layout)
	_build_obstacles(layout)
	_build_finish()
	_build_player()
	_build_camera()
	_build_speed_atmosphere()
	_build_hud()
	StateMachine.change_state(StateMachine.State.PLAYING)
	AudioManager.play_sfx("powerup")

# --- construction -----------------------------------------------------------

func _build_background() -> void:
	# L0 void — static screen-space base, never scrolls (Grok spec: "0" scroll).
	# Kimi audit: CanvasLayer draw order is lowest-layer-first (higher numbers
	# draw later, in front) — this MUST be more negative than the haze layer
	# below it, or the opaque void fully occludes the haze behind it. An
	# earlier version had this backwards (void -1, haze -2), rendering as a
	# flat two-layer background with the haze invisible.
	var layer := CanvasLayer.new()
	layer.layer = -2
	var bg := ColorRect.new()
	bg.color = COLOR_VOID
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	add_child(layer)

	# L1 far haze — true world-space parallax (~0.15x), same ParallaxBackground/
	# ParallaxLayer + motion_mirroring pattern already used in level_base.gd and
	# secret_realm.gd, so it tiles indefinitely over the run instead of running
	# out partway through a long course. Must draw in FRONT of the void (-2)
	# but behind gameplay (default layer 0), hence -1.
	var pbg := ParallaxBackground.new()
	pbg.layer = -1
	add_child(pbg)
	var haze_layer := ParallaxLayer.new()
	haze_layer.motion_scale = Vector2(0.15, 0.0)
	haze_layer.motion_mirroring = Vector2(900.0, 0.0)
	for i in range(3):
		var blob := Sprite2D.new()
		blob.texture = _make_glow_texture()
		blob.modulate = Color(COLOR_HAZE.r, COLOR_HAZE.g, COLOR_HAZE.b, 0.5)
		blob.scale = Vector2(6.0, 4.0)
		blob.position = Vector2(150.0 + i * 300.0, 250.0 + (i % 2) * 150.0)
		haze_layer.add_child(blob)
	pbg.add_child(haze_layer)

## L2 streak field + L3 dust — camera-attached (not world-parallax): these are
## a constant speed cue near the player throughout the whole run, the same way
## sprint_dust/wall_sparks are children of the PLAYER in the main game rather
## than fixed world props the run would leave behind after one pass.
func _build_speed_atmosphere() -> void:
	var streaks := CPUParticles2D.new()
	streaks.texture = load("res://src/assets/sprites/fx_dot.png")
	streaks.amount = 40
	streaks.lifetime = 0.5
	streaks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	streaks.emission_rect_extents = Vector2(80.0, 300.0)
	streaks.position = Vector2(300.0, 0.0)
	streaks.direction = Vector2(-1, 0)
	streaks.spread = 4.0
	streaks.initial_velocity_min = 500.0
	streaks.initial_velocity_max = 700.0
	streaks.scale_amount_min = 0.3
	streaks.scale_amount_max = 1.2
	streaks.color = Color(COLOR_ACCENT_LIME.r, COLOR_ACCENT_LIME.g, COLOR_ACCENT_LIME.b, 0.35)
	_camera.add_child(streaks)

	var dust := CPUParticles2D.new()
	dust.texture = load("res://src/assets/sprites/fx_dot.png")
	dust.amount = 20
	dust.lifetime = 0.8
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(200.0, 260.0)
	dust.position = Vector2(0.0, 0.0)
	dust.direction = Vector2(-1, 0)
	dust.spread = 15.0
	dust.initial_velocity_min = 120.0
	dust.initial_velocity_max = 220.0
	dust.scale_amount_min = 0.2
	dust.scale_amount_max = 0.5
	dust.color = Color(COLOR_COLLECTIBLE.r, COLOR_COLLECTIBLE.g, COLOR_COLLECTIBLE.b, 0.2)
	_camera.add_child(dust)

	# Hazard telegraph — a thin world-space warning bar, repositioned each
	# physics frame in _physics_process to whichever lethal hazard is next
	# ahead of the player. At RUN_SPEED (320px/s) the player covers ~450px in
	# ~1.4s; leading by TELEGRAPH_LEAD gives a real reaction window instead of
	# an ambush, matching the fairness contract already used for the Tax
	# Collector's ALERT telegraph and the shooter drones' fire warning.
	# Kimi audit: this was hardcoded to world y in [-260, 0], while every other
	# world element (floor, candles, walls, tokens, player) is anchored to
	# GROUND_Y (500.0, from BlazeRushLayouts) — the bar rendered ~500-700px
	# above the actual course, nowhere near the hazards it was meant to warn
	# about. Anchored to GROUND_Y now, spanning from above candle/wall height
	# down through the floor, same vertical footprint the obstacles use.
	_telegraph = ColorRect.new()
	_telegraph.size = Vector2(6, 260)
	_telegraph.position = Vector2(-3, GROUND_Y - 260.0)
	_telegraph.color = Color(COLOR_HAZARD.r, COLOR_HAZARD.g, COLOR_HAZARD.b, 0.0)
	_telegraph.z_index = 5
	add_child(_telegraph)

## Radial-falloff dot, generated once and cached — the same "no art dependency
## for a one-off cosmetic effect" technique used throughout this codebase
## (lil_blunt_visual.gd, boss_health_bar.gd, secret_realm.gd).
var _glow_tex: ImageTexture
func _make_glow_texture() -> ImageTexture:
	if _glow_tex:
		return _glow_tex
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	for x in range(size):
		for y in range(size):
			var d := Vector2(x, y).distance_to(center) / (size / 2.0)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	_glow_tex = ImageTexture.create_from_image(img)
	return _glow_tex

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
	visual.color = COLOR_SAFE_GROUND
	visual.size = Vector2(w, 220.0)
	body.add_child(visual)
	var edge := ColorRect.new()
	edge.color = COLOR_SAFE_EDGE
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
				_hazard_x.append(ob.x)
			"fud_wall":
				_make_fud_wall(ob.x)
			"smoke":
				_make_smoke_token(ob.x, ob.get("y", 60.0))
			"gap":
				_hazard_x.append(ob.x)  # lethal if mistimed; telegraph it too
	_hazard_x.sort()

func _make_candle(x: float) -> void:
	# Red market-dip candle: thin wick + body, kills on touch.
	var area := Area2D.new()
	area.position = Vector2(x, GROUND_Y)
	area.collision_mask = 2  # player runs on layer 2
	area.set_meta("hazard", true)
	var body := ColorRect.new()
	body.color = COLOR_HAZARD
	body.size = Vector2(18, 34)
	body.position = Vector2(-9, -34)
	area.add_child(body)
	var wick := ColorRect.new()
	wick.color = Color(1.0, 0.55, 0.15, 0.9)  # hotter yellow-orange top cap
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
	# Sparse ember particle at the wick tip — "hot/danger," not decoration
	# spam (Grok: one 1-point emitter per candle, not a permanent effect stack).
	var ember := CPUParticles2D.new()
	ember.texture = load("res://src/assets/sprites/fx_dot.png")
	ember.amount = 3
	ember.lifetime = 0.6
	ember.position = Vector2(0, -50)
	ember.direction = Vector2(0, -1)
	ember.spread = 15.0
	ember.initial_velocity_min = 15.0
	ember.initial_velocity_max = 30.0
	ember.scale_amount_min = 0.1
	ember.scale_amount_max = 0.2
	ember.color = Color(1.0, 0.6, 0.2, 0.7)
	area.add_child(ember)
	# Kimi audit: every candle in the course was simulating its ember emitter
	# continuously from scene start regardless of the player's position — a
	# 9-candle level (the real per-level max, from BlazeRushLayouts) means 27
	# always-on particles against a ~120 budget already at ~85 steady-state
	# from the background/trail alone. Gate on screen visibility instead —
	# only the 1-2 candles actually on screen ever emit.
	var notifier := VisibleOnScreenNotifier2D.new()
	ember.emitting = false
	notifier.screen_entered.connect(func() -> void: ember.emitting = true)
	notifier.screen_exited.connect(func() -> void: ember.emitting = false)
	area.add_child(notifier)
	add_child(area)

func _make_fud_wall(x: float) -> void:
	# Solid block: landing on top is safe, slamming the side is a crash
	# (checked via collision normal in _physics_process).
	var body := StaticBody2D.new()
	body.position = Vector2(x, GROUND_Y - 52.0)
	body.set_meta("fud_wall", true)
	var visual := ColorRect.new()
	visual.color = Color(0.3, 0.2, 0.55, 1.0)  # darker violet sides, same family as floor
	visual.size = Vector2(46, 52)
	visual.position = Vector2(-23, 0)
	body.add_child(visual)
	var top_lip := ColorRect.new()
	top_lip.color = COLOR_SAFE_EDGE  # thick cyan-mint top lip: the glance-test "landable" signal
	top_lip.size = Vector2(46, 4)
	top_lip.position = Vector2(-23, 0)
	body.add_child(top_lip)
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
	puff.color = COLOR_COLLECTIBLE
	puff.size = Vector2(16, 16)
	puff.position = Vector2(-8, -8)
	area.add_child(puff)
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 14.0
	col.shape = shape
	area.add_child(col)
	# Gentle idle pulse (1.0 -> 1.12) so it reads as "alive/grabbable" at speed.
	var pulse := puff.create_tween().set_loops()
	pulse.tween_property(puff, "scale", Vector2(1.12, 1.12), 0.5).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(puff, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE)
	area.body_entered.connect(func(b: Node2D) -> void:
		if b == _player and area.visible:
			area.visible = false
			area.set_deferred("monitoring", false)
			_smoke_this_attempt += 1
			_update_hud()
			AudioManager.play_sfx("coin")
			_spawn_pickup_burst(area.global_position)
	)
	add_child(area)
	_smoke_tokens.append(area)

## One-shot cream burst on pickup — proximity feedback, not a continuous effect.
func _spawn_pickup_burst(pos: Vector2) -> void:
	var burst := CPUParticles2D.new()
	burst.texture = load("res://src/assets/sprites/fx_dot.png")
	burst.amount = 10
	burst.lifetime = 0.3
	burst.one_shot = true
	burst.emitting = true
	burst.spread = 180.0
	burst.initial_velocity_min = 40.0
	burst.initial_velocity_max = 90.0
	burst.scale_amount_min = 0.2
	burst.scale_amount_max = 0.4
	burst.color = COLOR_COLLECTIBLE
	burst.global_position = pos
	add_child(burst)
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		if is_instance_valid(burst):
			burst.queue_free())

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
	cube.color = Color(0.3, 1.0, 0.35, 1.0)  # brighter/more saturated neon green
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

	# Speed trail — one emitter, small green squares fading out behind the run
	# direction (Grok: "1 trail emitter only").
	var trail := CPUParticles2D.new()
	trail.texture = load("res://src/assets/sprites/fx_dot.png")
	trail.amount = 25
	trail.lifetime = 0.35
	trail.direction = Vector2(-1, 0)
	trail.spread = 8.0
	trail.initial_velocity_min = 40.0
	trail.initial_velocity_max = 90.0
	trail.scale_amount_min = 0.25
	trail.scale_amount_max = 0.45
	trail.color = Color(0.3, 1.0, 0.35, 0.6)
	_player.add_child(trail)

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
	# ESC exits Blaze Rush cleanly, returning to the correct source level.
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_exit_to_level()
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_exit_to_level()
		return
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
	_update_telegraph()

## Find the next lethal hazard ahead of the player and fade the warning bar
## in as it enters TELEGRAPH_LEAD range; fully transparent otherwise.
func _update_telegraph() -> void:
	if _telegraph == null:
		return
	var px := _player.position.x
	var next_x := -1.0
	for hx in _hazard_x:
		if hx > px:
			next_x = hx
			break
	if next_x < 0.0:
		_telegraph.color.a = 0.0
		return
	var dist := next_x - px
	if dist > TELEGRAPH_LEAD:
		_telegraph.color.a = 0.0
		return
	_telegraph.position.x = next_x - 3.0  # keep the 6px bar centered on the hazard
	_telegraph.color.a = clampf(1.0 - dist / TELEGRAPH_LEAD, 0.0, 1.0) * 0.85

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
	_smoke_label.text = "PUFFS %d" % _smoke_this_attempt
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
	var toast_lines: Array[String] = ["BLAZE RUSH CLEAR!", "+%d SMOKE" % _smoke_this_attempt]
	if first_clear:
		GoldMineSystem.mine_gold(COMPLETION_GOLD)
		toast_lines.append("+%d GOLD" % COMPLETION_GOLD)
		if _attempts == 1:
			var kept := GoldMineSystem.collect_diamonds(FLAWLESS_DIAMONDS)
			toast_lines.append("FLAWLESS! +%d DIAMONDS (1 burned)" % kept)
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
	if _exiting:
		return
	_exiting = true
	# Use snapshots taken at _ready() — dash_return may have been cleared
	# mid-run by a reset_session() or a double-exit call.
	var return_path: String = _return_path
	var portal_pos: Vector2 = _return_pos
	if portal_pos != Vector2.ZERO:
		# LevelBase spawns from checkpoint slot 1 — drop the player back at the portal.
		GameManager.save_checkpoint(1, 990 + _level_index, portal_pos)
	GameManager.dash_return = {}
	SceneRouter.load_scene(return_path, SceneRouter.Transition.SMOKE)
