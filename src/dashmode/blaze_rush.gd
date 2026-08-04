extends Node2D
## Blaze Rush — Geometry-Dash-style auto-runner secret mode.
## Lil Blunt compresses into a SMOKE cube and auto-runs a neon corridor:
## one tap to jump, instant restart on crash, $SMOKE tokens along the path.
## Launched by BlazePortal via GameManager.dash_return; returns to the
## source level on finish or exit.
##
## Run speed ramps from speed_start to speed_end across the course (data
## from BlazeRushLayouts, per level) — same pixel telegraph lead, less real
## reaction time as the run progresses, which combined with the layouts'
## shrinking hazard spacing is what makes a run actually get harder as it
## goes instead of holding one flat difficulty the whole way.

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
var _speed_start: float = 320.0
var _speed_end: float = 320.0
var _current_speed: float = 320.0
var _player: CharacterBody2D
var _player_visual: Node2D
var _camera: Camera2D
var _attempts: int = 1
var _smoke_this_attempt: int = 0
var _smoke_tokens: Array[Area2D] = []
var _finished: bool = false
var _tap_buffered: bool = false

## Hazard telegraph (Grok's "critical for auto-run" call): one reusable
## warning bar, not one per obstacle — repositions each frame to whichever
## lethal hazard (candle or gap) is next ahead of the player, fading in as
## it approaches. fud_walls aren't tracked here: they're visibly landable,
## not an ambush the way a thin candle or a floor gap is at 320px/s.
var _hazard_x: Array[float] = []
var _telegraph: ColorRect
const TELEGRAPH_LEAD: float = 450.0

## Founder defect F — magic marijuana skateboard. One data-driven zone per
## level (BlazeRushLayouts), placed over an existing gap so "steer through
## instead of jumping" is legible at a glance. Grok 4.5 feel brief (docs/
## model-responses dispatch this session) supplied the numbers below.
var _board_zone: Dictionary = {}
var _on_board: bool = false
var _board_steer_vx: float = 0.0
var _board_bob_t: float = 0.0
var _board_visual: Node2D
const BOARD_STEER_MAX: float = 140.0
const BOARD_STEER_ACCEL: float = 900.0
const BOARD_STEER_DECEL: float = 1100.0
const BOARD_BOB_AMP: float = 10.0
const BOARD_BOB_PERIOD: float = 1.8
const BOARD_SPRING: float = 8.0
const BOARD_MAGNET_RADIUS: float = 48.0
const BOARD_MAGNET_PULL: float = 220.0
const BOARD_JUMP_POP: float = -260.0

@onready var _smoke_label: Label = Label.new()
@onready var _attempt_label: Label = Label.new()
@onready var _progress: ProgressBar = ProgressBar.new()

## WHERE ESC GOES BACK TO — captured ONCE, here, at entry.
##
## Founder-reported repeatedly: "the player is unable to exit back to level 3
## by pressing Esc". A previous session (me) "proved" the exit path worked by
## feeding it a synthetic GameManager.dash_return dictionary — a proof that
## could never catch this class of bug, because the failure is about that
## dictionary's LIFETIME, not its contents.
##
## `GameManager.dash_return` is shared mutable autoload state that
## `_exit_to_level()` itself CLEARS, and that `reset_session()` also clears.
## Reading it lazily at exit time means any path that empties it first sends
## the player to the hardcoded `level_01` fallback — which, to a player who
## entered from Level 3, looks exactly like "Esc doesn't take me back".
##
## Snapshotting it into plain members at _ready() makes the return trip
## depend only on how the run STARTED. Nothing that happens during the run —
## a crash, a finish, a double-press, another system touching dash_return —
## can redirect it any more.
var _return_path: String = ""
var _return_pos: Vector2 = Vector2.ZERO
var _exiting: bool = false

func _ready() -> void:
	_level_index = int(GameManager.dash_return.get("level_index", 1))
	_return_path = str(GameManager.dash_return.get("scene_path", ""))
	_return_pos = GameManager.dash_return.get("position", Vector2.ZERO)
	if _return_path == "":
		# No launch record (e.g. scene run directly). Fall back to the level
		# matching the index we were given rather than blindly to level 1.
		_return_path = GameManager.level_scene(_level_index)
	var layout := BlazeRushLayouts.get_layout(_level_index)
	_course_length = layout.get("length", 3400.0)
	_speed_start = layout.get("speed_start", 320.0)
	_speed_end = layout.get("speed_end", _speed_start)
	_current_speed = _speed_start
	_board_zone = layout.get("board_zone", {})
	layout = _clear_board_landing_runway(layout)
	_build_background()
	_build_ground(layout)
	_build_obstacles(layout)
	_build_protocol_landmarks()
	_build_finish()
	_build_player()
	_build_camera()
	_build_speed_atmosphere()
	_build_hud()
	StateMachine.change_state(StateMachine.State.PLAYING)
	AudioManager.play_sfx("powerup")

## How much clear, hazard-free floor must exist where the board sets you down.
##
## Founder: "the rocket at the Blaze Rush is a nice idea but it causes the
## player to crash into the red candles" / "when the player lands he
## immediately dies as it crashes into the FUD box". His screenshot read
## ATTEMPT 81 — he died eighty times to this.
##
## There is no literal rocket in the code: what he is describing is the
## board/hover section, which flies him along a raised path and then, at
## zone_end, hands control straight back to normal gravity. Whatever the
## hand-authored layout happened to place next — a candle, a FUD wall, or a
## GAP in the floor — he fell directly into it with no reaction time. The
## board's landing spot was never part of the layout design.
##
## Rather than hand-editing coordinates per level (and re-breaking it the
## next time a layout is tuned), the landing window is cleared from the DATA
## before anything is built, so the guarantee holds for every level and any
## future layout edit. 320px is comfortably over half a second of runway even
## at Level 3's top speed of 460px/s.
const BOARD_LANDING_RUNWAY: float = 320.0

## Strip every lethal obstacle out of the board's landing window.
##
## Returns a COPY — BlazeRushLayouts hands back freshly-built dictionaries,
## but treating layout data as immutable keeps this safe if that ever changes
## to return shared/static data.
##
## Note this must run BEFORE _build_ground(), not just before
## _build_obstacles(): "gap" entries are what carve holes in the floor, so
## filtering them only at obstacle-build time would still leave the player
## landing in a pit.
func _clear_board_landing_runway(layout: Dictionary) -> Dictionary:
	if _board_zone.is_empty():
		return layout
	var zone_end: float = float(_board_zone.get("end", 0.0))
	# Start the window slightly BEFORE the zone ends: the player is still
	# descending as they cross the boundary, so a hazard sitting right on it
	# is just as lethal as one just after it.
	var win_start := zone_end - 40.0
	var win_end := zone_end + BOARD_LANDING_RUNWAY
	var safe: Array = []
	var dropped := 0
	for ob in layout.get("obstacles", []):
		var t: String = ob.get("type", "")
		if t == "candle" or t == "fud_wall" or t == "gap":
			# A gap occupies a span, not a point — reject on overlap.
			var ob_start: float = float(ob.x)
			var ob_end: float = ob_start + float(ob.get("w", 0.0))
			if ob_end >= win_start and ob_start <= win_end:
				dropped += 1
				continue
		safe.append(ob)
	if dropped > 0:
		print("[BlazeRush] L%d: cleared %d hazard(s) from the board landing runway (x %.0f..%.0f)"
			% [_level_index, dropped, win_start, win_end])
	var out := layout.duplicate(true)
	out["obstacles"] = safe
	return out

## Founder defect A4: L2 (and L3) Blaze Rush read as an identical reskin of
## L1 — same void/haze tint regardless of _level_index. Ties each run's
## palette to that level's own campaign identity (Smoke Realm violet /
## Crystal Caverns cyan / Gold Rush amber) instead of one flat "Electric
## Haze" default for every level. Ground/hazard/collectible colors are left
## alone — those are tuned for hazard-vs-safe readability and apply equally
## well regardless of level.
func _level_haze_tint() -> Color:
	match _level_index:
		2:
			return Color(0.1, 0.35, 0.55, 1.0)   # Crystal Caverns — cool cyan-blue
		3:
			return Color(0.55, 0.35, 0.05, 1.0)  # Gold Rush — warm amber
		_:
			return COLOR_HAZE                     # Smoke Realm — violet (unchanged)

func _level_backdrop_modulate() -> Color:
	match _level_index:
		2:
			return Color(0.75, 0.92, 1.0, 0.9)   # cyan-leaning
		3:
			return Color(1.0, 0.9, 0.7, 0.9)     # gold-leaning
		_:
			return Color(0.85, 0.8, 1.0, 0.9)     # violet (unchanged L1 default)

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
	# Void base colour still fills first (covers any letterboxing on odd aspect
	# ratios), with the R5 branded crystal-cavern backdrop on top of it.
	var bg := ColorRect.new()
	bg.color = COLOR_VOID
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	# R5 (2026-08-08): replace the bland flat void with a generated branded
	# backdrop (OpenRouter openai/gpt-5-image, per the Grok beat sheet: deep
	# teal crystal-cavern void, calm central band so foreground stays readable,
	# faint rings). Screen-space, stretched to fill, dimmed so it reads as
	# depth behind the parallax haze/treeline in front, not a focal plate.
	var cavern_path := "res://src/assets/backgrounds/bg_blaze_rush_cavern.png"
	if ResourceLoader.exists(cavern_path):
		var art := TextureRect.new()
		art.texture = load(cavern_path)
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_SCALE
		art.modulate = _level_backdrop_modulate()
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(art)
	add_child(layer)

	# L1 far haze — true world-space parallax (~0.15x), same ParallaxBackground/
	# ParallaxLayer + motion_mirroring pattern already used in level_base.gd and
	# secret_realm.gd, so it tiles indefinitely over the run instead of running
	# out partway through a long course. Must draw in FRONT of the void (-2)
	# but behind gameplay (default layer 0), hence -1.
	var pbg := ParallaxBackground.new()
	pbg.layer = -1
	add_child(pbg)

	# L1a treeline — Grok 4.5 art-direction brief (2026-08-01,
	# docs/model-responses/2026-08-02-grok-blaze-rush-branding.md), vertical
	# slice #1: "the fastest proof this is Lil Blunt's world" was a distant
	# Smoke Realm forest silhouette sitting BEHIND the run, same biome as
	# every campaign level, without touching any gameplay-critical hazard
	# silhouette. Muapi-generated (assets/art-manifest.json id
	# "bg_blaze_rush_treeline"), added as its own ParallaxLayer so it can
	# scroll slower than the haze blobs (more distant = less motion) and
	# tiles infinitely via motion_mirroring, same technique as the haze layer
	# right below it. Added BEFORE the haze layer so haze draws in front.
	var treeline_layer := ParallaxLayer.new()
	treeline_layer.motion_scale = Vector2(0.08, 0.0)
	var treeline_tex: Texture2D = load("res://src/assets/backgrounds/bg_blaze_rush_treeline.jpg")
	treeline_layer.motion_mirroring = Vector2(float(treeline_tex.get_width()), 0.0)
	var treeline := Sprite2D.new()
	treeline.texture = treeline_tex
	treeline.centered = false
	treeline.position = Vector2(0.0, GROUND_Y - float(treeline_tex.get_height()))
	# Per-level tint (A4) — was a flat cool-purple regardless of level, which
	# is exactly why L1/L2/L3 read as reskins of each other. Still keeps it
	# from fighting the haze for saturation; just ties the hue to the level.
	treeline.modulate = _level_backdrop_modulate()
	treeline_layer.add_child(treeline)
	pbg.add_child(treeline_layer)

	var haze_layer := ParallaxLayer.new()
	haze_layer.motion_scale = Vector2(0.15, 0.0)
	haze_layer.motion_mirroring = Vector2(900.0, 0.0)
	var haze_tint := _level_haze_tint()
	for i in range(3):
		var blob := Sprite2D.new()
		blob.texture = _make_glow_texture()
		blob.modulate = Color(haze_tint.r, haze_tint.g, haze_tint.b, 0.5)
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
	# ahead of the player. Run speed ramps from speed_start to speed_end
	# across the course, so the same TELEGRAPH_LEAD pixel distance buys
	# steadily less real reaction time as the run progresses (e.g. at 320px/s
	# it's ~1.4s of warning; by 460px/s late in level 3 that's down to ~1.0s)
	# — this is the deliberate escalation, not an ambush, matching the
	# fairness contract already used for the Tax Collector's ALERT telegraph
	# and the shooter drones' fire warning.
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

func _build_default_token_visual() -> Control:
	var puff := ColorRect.new()
	puff.color = COLOR_COLLECTIBLE
	puff.size = Vector2(16, 16)
	puff.position = Vector2(-8, -8)
	return puff

## Founder defect A5 — approximates Solana's stacked-diagonal-bar mark with
## primitives (no new art dependency, same convention as every other FX in
## this file): three parallel angled bars in a purple -> teal gradient,
## matching Solana's real brand colors (#9945FF -> #14F195) closely enough to
## read as "SOL" at a glance without needing an image asset.
func _build_sol_token_visual() -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sol_purple := Color(0.6, 0.27, 1.0, 1.0)
	var sol_teal := Color(0.078, 0.945, 0.584, 1.0)
	for i in range(3):
		var bar := ColorRect.new()
		bar.size = Vector2(20, 4)
		bar.position = Vector2(-10, -9 + i * 7)
		bar.pivot_offset = Vector2(10, 2)
		bar.rotation = deg_to_rad(-18.0)
		bar.color = sol_purple.lerp(sol_teal, float(i) / 2.0)
		root.add_child(bar)
	return root

func _make_smoke_token(x: float, height: float) -> void:
	var area := Area2D.new()
	area.position = Vector2(x, GROUND_Y - height)
	area.collision_mask = 2
	# Founder defect A5: L2 tokens should read as Solana-style, not the same
	# plain cream puff every level uses. Visual-only branch — collision,
	# pickup logic, and scoring are identical across all three levels.
	var puff: Control = _build_sol_token_visual() if _level_index == 2 else _build_default_token_visual()
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

## Founder defect A3 (stated 4+ times): Blaze Rush must show protocol
## branding as landmarks along the run, not read as a barren void. Same
## drop-in-art convention as secret_realm.gd's protocol plinth: shows the
## real logo the instant a PNG lands at the documented path; a styled
## placeholder panel until then — "not a barren void" is satisfied either
## way, no code change needed once real art arrives.
const PROTOCOL_LANDMARKS := [
	{"file": "smokering", "label": "FOMO"},
	{"file": "goldmine", "label": "GOLD MINE"},
	{"file": "diamonds", "label": "DIAMONDS"},
]

func _build_protocol_landmarks() -> void:
	var fractions := [0.22, 0.5, 0.78]
	for i in range(PROTOCOL_LANDMARKS.size()):
		_build_one_landmark(_course_length * fractions[i], PROTOCOL_LANDMARKS[i])

func _build_one_landmark(x: float, data: Dictionary) -> void:
	var panel := Panel.new()
	panel.position = Vector2(x - 55.0, GROUND_Y - 340.0)
	panel.size = Vector2(110, 90)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = -1  # backdrop scenery — never occludes hazards/tokens
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.02, 0.14, 0.55)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = COLOR_ACCENT_LIME
	sb.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var logo_path := "res://src/assets/logos/%s.png" % data.file
	if ResourceLoader.exists(logo_path):
		var art := TextureRect.new()
		art.texture = load(logo_path)
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(art)
	else:
		var label := Label.new()
		label.text = data.label
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", COLOR_ACCENT_LIME)
		panel.add_child(label)

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

	_build_board_visual()
	_reset_player()

## Founder defect F visual — flat plank deck + lime top lip + dark trucks +
## a soft under-glow (same visual language as the Distributor's levitating
## disc: a haze shape reading as the lift source), with Lil Blunt's own
## cube-green seated on top so it stays legibly "him," not a foreign prop.
## Hidden until the player enters a board zone.
func _build_board_visual() -> void:
	_board_visual = Node2D.new()
	_board_visual.visible = false
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(0, 10), Vector2(30, 2), Vector2(60, 10), Vector2(30, 18)])
	glow.position = Vector2(-30, 8)
	glow.color = Color(0.45, 1.0, 0.4, 0.3)
	_board_visual.add_child(glow)
	for wx in [-20.0, 16.0]:
		var truck := ColorRect.new()
		truck.size = Vector2(8, 5)
		truck.position = Vector2(wx, 6)
		truck.color = Color(0.1, 0.08, 0.1, 1.0)
		_board_visual.add_child(truck)
	var deck := ColorRect.new()
	deck.size = Vector2(56, 10)
	deck.position = Vector2(-28, -4)
	deck.color = Color(0.25, 0.55, 0.22, 1.0)
	_board_visual.add_child(deck)
	var lip := ColorRect.new()
	lip.size = Vector2(56, 2)
	lip.position = Vector2(-28, -4)
	lip.color = COLOR_ACCENT_LIME
	_board_visual.add_child(lip)
	var rider := ColorRect.new()
	rider.size = Vector2(20, 20)
	rider.position = Vector2(-10, -24)
	rider.color = Color(0.3, 1.0, 0.35, 1.0)
	_board_visual.add_child(rider)
	_player.add_child(_board_visual)

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

## ESC is handled in _input(), NOT _unhandled_input().
##
## Founder-reported repeatedly: Esc does not get him out of Blaze Rush.
## _unhandled_input only runs for events NOTHING else consumed — any focused
## Control, the HUD CanvasLayer, or an autoload that handles input first can
## silently swallow it, and the player is then trapped in a run with no way
## out but to finish or die. Escaping a mode the player wants to leave is not
## something to route through the lowest-priority input phase. _input() sees
## it first, unconditionally.
##
## It also now fires on the raw ESCAPE keycode in addition to the `ui_cancel`
## action: ui_cancel is a Godot built-in that is NOT declared in this
## project's InputMap, so it depends entirely on engine defaults surviving —
## a dependency worth not having for the one control that prevents a
## soft-lock.
func _input(event: InputEvent) -> void:
	var esc := event.is_action_pressed("ui_cancel")
	if not esc and event is InputEventKey:
		var k := event as InputEventKey
		esc = k.pressed and not k.echo and k.keycode == KEY_ESCAPE
	if esc:
		get_viewport().set_input_as_handled()
		# Deliberately NOT gated on `_finished`: after crossing the line the
		# run shows a ~1.8s payout toast, and ESC during that window used to
		# do nothing at all.
		_exit_to_level()

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

	var progress := clampf(_player.position.x / _course_length, 0.0, 1.0)
	_current_speed = lerpf(_speed_start, _speed_end, progress)

	var now_on_board := _is_in_board_zone(_player.position.x)
	if now_on_board != _on_board:
		_set_board_mode(now_on_board)
	if _on_board:
		_physics_board(delta)
	else:
		_physics_cube(delta)

	_player.move_and_slide()

	# The board flies clear over ground-level hazards by design (that's the
	# whole point of a zone placed over a gap) — these checks only apply to
	# normal cube running.
	if not _on_board:
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

func _physics_cube(delta: float) -> void:
	_player.velocity.x = _current_speed
	_player.velocity.y += GRAVITY * delta
	if _tap_buffered and _player.is_on_floor():
		_player.velocity.y = JUMP_VELOCITY
		_spin_cube()
	_tap_buffered = false

func _is_in_board_zone(x: float) -> bool:
	if _board_zone.is_empty():
		return false
	return x >= float(_board_zone.get("start", 0.0)) and x <= float(_board_zone.get("end", 0.0))

func _set_board_mode(active: bool) -> void:
	var was_on_board := _on_board
	_on_board = active
	_board_bob_t = 0.0
	_board_steer_vx = 0.0
	_player_visual.visible = not active
	if _board_visual:
		_board_visual.visible = active
	if active:
		AudioManager.play_sfx("powerup")
	elif was_on_board and _player != null:
		# Dismount softly. The hover spring can be carrying real vertical
		# speed at the moment the zone ends; handing that straight to a
		# GRAVITY of 2200 slammed the player down far faster than they could
		# react. Starting the descent from rest turns the drop into a
		# readable arc onto the cleared runway (see BOARD_LANDING_RUNWAY).
		_player.velocity.y = 0.0

## Founder defect F — steer left/right toward a max +/-140px/s offset from
## the auto-run speed, spring toward a fixed hover band instead of falling,
## and lightly magnet toward nearby smoke tokens so the hand-placed token
## line doesn't need pixel-perfect alignment to feel reliable. Jump still
## works as a short optional pop (Grok: "for optional routes") — the spring
## pulls the player straight back onto the band afterward, so it can never
## be used to skip the whole zone's collectibles.
func _physics_board(delta: float) -> void:
	_board_bob_t += delta
	var steer_input := Input.get_axis("move_left", "move_right")
	var target_steer := steer_input * BOARD_STEER_MAX
	var accel := BOARD_STEER_ACCEL if absf(target_steer) > 0.1 else BOARD_STEER_DECEL
	_board_steer_vx = move_toward(_board_steer_vx, target_steer, accel * delta)
	_player.velocity.x = _current_speed + _board_steer_vx

	var zone_height: float = float(_board_zone.get("path_height", 140.0))
	var target_y := GROUND_Y - zone_height + sin(_board_bob_t * TAU / BOARD_BOB_PERIOD) * BOARD_BOB_AMP
	_player.velocity.y = (target_y - _player.position.y) * BOARD_SPRING

	if _tap_buffered:
		_player.velocity.y = BOARD_JUMP_POP
	_tap_buffered = false

	for token in _smoke_tokens:
		if not is_instance_valid(token) or not token.visible:
			continue
		var to_token: Vector2 = token.global_position - _player.global_position
		var dist := to_token.length()
		if dist > 0.1 and dist < BOARD_MAGNET_RADIUS:
			_player.global_position += to_token.normalized() * BOARD_MAGNET_PULL * delta

	if _board_visual:
		_board_visual.rotation = lerp_angle(_board_visual.rotation, deg_to_rad(-steer_input * 12.0), 0.2)

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
	_set_board_mode(false)

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
	# Re-entrancy guard: ESC pressed twice, or ESC during the finish payout,
	# used to run this twice. The second run read an ALREADY-CLEARED
	# dash_return and fell through to the level-1 fallback — sending a Level 3
	# player to Level 1. Now the snapshot is immutable and this returns early.
	if _exiting:
		return
	_exiting = true
	var return_path: String = _return_path
	var portal_pos: Vector2 = _return_pos
	if portal_pos != Vector2.ZERO:
		# BUG (product-breaking): this hardcoded checkpoint slot 1 regardless of
		# which level launched the run. save_checkpoint()'s first argument is
		# the LEVEL NUMBER — the exact key LevelBase._spawn_player() looks up
		# via get_checkpoint(level_data.level_index). Entering Blaze Rush from
		# Level 2/3 wrote the checkpoint into Level 1's slot, so on return the
		# real level found nothing under its own key and fell through to its
		# default player_spawn — the player resumed at the LEVEL START, which
		# reads exactly like "the game restarted." Use the actual level index.
		GameManager.save_checkpoint(_level_index, 990 + _level_index, portal_pos)
	GameManager.dash_return = {}
	SceneRouter.load_scene(return_path, SceneRouter.Transition.SMOKE)
