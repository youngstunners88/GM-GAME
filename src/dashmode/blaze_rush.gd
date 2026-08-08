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
## Blaze-exclusive BGM. Released on EVERY exit path (finish, Q/ESC/EXIT,
## watchdog) via _release_music(), so the track can never leak into a level.
const BLAZE_MUSIC := "res://src/assets/music/blaze_rush_theme.mp3"
var _music_token: int = -1

func _release_music() -> void:
	if _music_token != -1:
		# discard_music_override(), NOT release_music_override(): the
		# destination scene's own _ready() calls play_playlist() a moment
		# after this, so resuming the paused base track first only creates a
		# ~0.8s window where it overlaps the fresh track fading in (the
		# founder's reported "faint second song").
		AudioManager.discard_music_override(_music_token)
		_music_token = -1

## Belt and braces: if this node is freed by ANY route the override is dropped.
func _exit_tree() -> void:
	_release_music()

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
	# After obstacles: the landmarks are decorative and must not influence or
	# be influenced by hazard placement.
	_build_protocol_landmarks()
	_build_finish()
	_build_player()
	_build_camera()
	_build_speed_atmosphere()
	_build_hud()
	StateMachine.change_state(StateMachine.State.PLAYING)
	AudioManager.play_sfx("powerup")
	# Blaze Rush has its own track (founder-supplied NewLB2.mp3). push/pop
	# override pauses and later RESUMES the level's music at its saved
	# position, so returning to the stage does not restart its song.
	_music_token = AudioManager.push_music_override(BLAZE_MUSIC)

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

	_build_stage_theme_layer(pbg)

## STAGE-THEMED BACKDROP.
##
## Founder: "return the trees in the background of the Blaze Rush like before
## for stage one as it had the theme of the 1st stage, and the theme of the
## 2nd Blaze Rush background should align with the 2nd stage and same with
## the 3rd."
##
## Blaze Rush was drawing one hardcoded purple void for all three levels, so
## every run looked identical and belonged to no stage. This pulls the SOURCE
## LEVEL's own painted backdrop (the Smoke Realm forest, the Crystal Caverns,
## the Gold Rush canyon) and darkens/tints it into the Electric Haze palette —
## the run still reads as the fast secret mode, but it is unmistakably that
## stage's version of it.
##
## Silent no-op if the level resource or its art is missing, matching the
## missing-asset convention used everywhere else in this project.
func _build_stage_theme_layer(pbg: ParallaxBackground) -> void:
	var data_path := "res://src/resources/level_%02d_data.tres" % _level_index
	if not ResourceLoader.exists(data_path):
		return
	var data: Resource = load(data_path)
	if data == null or not ("background_path" in data):
		return
	var art_path: String = str(data.background_path)
	if art_path == "" or not ResourceLoader.exists(art_path):
		return
	var tex: Texture2D = load(art_path)
	if tex == null:
		return
	var view_h: float = get_viewport_rect().size.y
	var fill: float = maxf(1.0, view_h / float(tex.get_height()))
	var layer := ParallaxLayer.new()
	# Slower than the haze so it sits clearly further back; y locked so it can
	# never slide off and expose the void (same rule as level_base).
	layer.motion_scale = Vector2(0.08, 0.0)
	layer.motion_mirroring = Vector2(tex.get_width() * fill, 0.0)
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.scale = Vector2(fill, fill)
	# Pushed dark and toward the mode's magenta so the neon foreground still
	# pops against it — the stage reads, but the run keeps its own identity.
	spr.modulate = Color(0.42, 0.28, 0.55, 1.0)
	layer.add_child(spr)
	pbg.add_child(layer)

## Protocol key art embedded along the course, as the founder mocked up
## ("here's another design of how we can embed art from the artworks
## throughout the Blaze Rush"). Purely decorative, placed BEHIND gameplay and
## well clear of the run line so it can never be mistaken for a platform.
## Where the embedded key art sits inside the purple ground band, and how big.
## The band is 220px tall from GROUND_Y; 150px of art centred at +122 sits in
## its lower half with clearance top and bottom.
const BAND_ART_Y: float = 122.0
const BAND_ART_SIZE: float = 190.0

## SOLID CIRCULAR badges, not the raw square-cornered artwork.
##
## Founder, three separate times: "I don't want the logos to be transparent!!!
## They need to be circular!!!!" The raw PNGs carry a square field around the
## disc, which rendered as a dark plate behind each logo in the purple band —
## his "what the fuck is this" screenshot. These are pre-composited opaque
## circular badges (src/assets/art/badge_*.png).
## Founder: "you need to feature all of the protocol logos in the Blaze
## Rush... none of the logos must ever be pixelated." Every circular badge
## the game has (all rebuilt clean, no added outline, correct green-ring
## DIAMONDS and the founder's own real GoldMine mark), plus two additional
## wide-format artworks alongside them.
const BR_ART := [
	"res://src/assets/art/badge_lilblunt.png",
	"res://src/assets/art/badge_diamonds.png",
	"res://src/assets/art/badge_goldmine.png",
	"res://src/assets/art/badge_smokering.png",
	"res://src/assets/art/badge_hood.png",
]
## Wide-format artworks — NOT forced into circular badges, kept at their own
## aspect ratio. Placed the same as BR_ART (band-anchored, gap-aware).
const BR_ART_WIDE := [
	"res://src/assets/art/br_smoke_lounge_car.png",
	"res://src/assets/art/br_diamond_certificate.png",
]

## X ranges with no floor under them. Logos must never be placed here: with
## the band absent the art hangs in the void, which is exactly what the
## founder circled.
var _gap_spans: Array[Vector2] = []

func _x_over_gap(x: float, half_width: float = BAND_ART_SIZE * 0.5) -> bool:
	for g: Vector2 in _gap_spans:
		# half_width of clearance either side, so a badge (or a wide banner —
		# some founder artworks are up to 3x wider than tall) never even
		# overhangs the lip of a gap.
		if x > g.x - half_width and x < g.y + half_width:
			return true
	return false

func _build_protocol_landmarks() -> void:
	# (path, is_wide) — square badges fit BAND_ART_SIZE both dimensions;
	# wide artworks are scaled by HEIGHT ONLY so they keep their native aspect
	# ratio instead of being squashed into a square.
	var available: Array[Array] = []
	for p: String in BR_ART:
		if ResourceLoader.exists(p):
			available.append([p, false])
	for p: String in BR_ART_WIDE:
		if ResourceLoader.exists(p):
			available.append([p, true])
	if available.is_empty():
		return
	# Founder: "feature ALL of the protocol logos in the Blaze Rush." One slot
	# per available artwork (not a modulo subset), so every piece appears
	# exactly once per run rather than some being skipped.
	var count: int = available.size()
	for i in range(count):
		var entry: Array = available[i]
		var tex: Texture2D = load(entry[0])
		if tex == null:
			continue
		var is_wide: bool = entry[1]
		var art := Sprite2D.new()
		art.texture = tex
		# Normalise wildly different source sizes to a consistent on-screen
		# scale rather than trusting each PNG's native dimensions.
		var target: float = BAND_ART_SIZE
		if is_wide:
			var s: float = target / float(tex.get_height())
			art.scale = Vector2(s, s)  # uniform scale preserves aspect ratio
		else:
			art.scale = Vector2(target / float(tex.get_width()), target / float(tex.get_height()))
		# Founder A5: "the artworks need to be at the BOTTOM by the purple
		# block." They were at GROUND_Y - 300 — up in the sky, nowhere near it.
		# The purple ground band runs GROUND_Y .. GROUND_Y+220 (see
		# _make_floor_segment), so seating the art low inside that band puts it
		# in the empty real estate he is pointing at. z_index 1 draws it ON the
		# band (the band itself is a plain ColorRect at default z), while the
		# run line stays well above at GROUND_Y and up.
		var half_w: float = art.scale.x * float(tex.get_width()) / 2.0
		var ax: float = 700.0 + (_course_length - 900.0) * (float(i) / float(count))
		# Nudge along the run until the slot is genuinely over purple band.
		var tries := 0
		while _x_over_gap(ax, half_w) and tries < 24:
			ax += half_w * 1.2
			tries += 1
		if _x_over_gap(ax, half_w):
			continue  # no clear band left for this one; drop it rather than float it
		art.position = Vector2(ax, GROUND_Y + BAND_ART_Y)
		# Fully opaque: "solid", per the founder. No alpha wash.
		art.modulate = Color(1.0, 1.0, 1.0, 1.0)
		# Smooth downscale for photographic brand art (see note above).
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		art.z_index = 1
		add_child(art)

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
	# Kept for _build_protocol_landmarks(): logos only over real band.
	_gap_spans.clear()
	for g: Vector2 in gaps:
		_gap_spans.append(g)

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
	# RED CANDLE — restored. "Bring back the red candles and replace these
	# squares with the flaming diamonds." The diamonds belong on the floating
	# SMOKE TOKENS (see _make_smoke_token), not on this hazard.
	var body := ColorRect.new()
	body.color = COLOR_HAZARD
	body.size = Vector2(18, 34)
	body.position = Vector2(-9, -34)
	area.add_child(body)
	var wick := ColorRect.new()
	wick.color = Color(1.0, 0.55, 0.15, 0.9)
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
	# THE ORIGINAL FUD BOX, restored as it was.
	#
	# Founder: "I told you to bring back the FUD box back! Not this shit!!!
	# You're confusing the task!" — ref_fud_reject.png. Two separate props were
	# conflated: the FUD wall is a LANDABLE block, and the flaming diamond
	# belongs on the CANDLES (see _make_candle). Putting a gem on the FUD wall
	# made both unreadable. This is the plain solid block again.
	var visual := ColorRect.new()
	visual.color = Color(0.3, 0.2, 0.55, 1.0)
	visual.size = Vector2(46, 52)
	visual.position = Vector2(-23, 0)
	body.add_child(visual)
	var tag := Label.new()
	tag.text = "FUD"
	tag.position = Vector2(-17, 15)
	tag.add_theme_font_size_override("font_size", 16)
	tag.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	tag.add_theme_constant_override("outline_size", 4)
	body.add_child(tag)
	var top_lip := ColorRect.new()
	top_lip.color = COLOR_SAFE_EDGE  # thick cyan-mint top lip: the glance-test "landable" signal
	top_lip.size = Vector2(46, 4)
	top_lip.position = Vector2(-23, 0)
	body.add_child(top_lip)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(46, 52)
	col.shape = shape
	col.position = Vector2(0, 26)
	body.add_child(col)
	add_child(body)

## Peak of a ground jump: v^2 / 2g. Anything above this is unreachable.
const JUMP_PEAK: float = (JUMP_VELOCITY * JUMP_VELOCITY) / (2.0 * GRAVITY)
## Ceiling for a HOVER/jump token: the jump peak plus most of a FUD wall's
## 52px, minus a margin so it is comfortably grabbable, not a pixel-perfect
## apex.
const TOKEN_MAX_HEIGHT: float = JUMP_PEAK + 34.0
## Layout heights AT OR BELOW this are meant to read as "ground level" —
## founder: "the final diamond requires the player to jump if he/she wants to
## claim it even though the diamond is on the ground level. Perhaps it's a
## bug." It was: a token authored at height 60 sits close enough to the
## player's standing collision box that most of the time it grazes, but not
## reliably — a near-miss, not a clean walk-through. Anything authored at or
## below this is forced down into WALK_CLAIM_HEIGHT, which the running
## player's own standing hurtbox always overlaps without a jump.
const GROUND_TOKEN_CUTOFF: float = 70.0
const WALK_CLAIM_HEIGHT: float = 18.0

func _make_smoke_token(x: float, height: float) -> void:
	var actual_height: float = height
	if height <= GROUND_TOKEN_CUTOFF:
		actual_height = WALK_CLAIM_HEIGHT
	else:
		actual_height = minf(height, TOKEN_MAX_HEIGHT)
	var area := Area2D.new()
	area.position = Vector2(x, GROUND_Y - actual_height)
	area.collision_mask = 2
	var puff := Sprite2D.new()
	# Blue gem so the RED flame reads against it (founder T1). Slightly smaller
	# than the 0.34 that shipped.
	puff.texture = preload("res://src/assets/sprites/fx_flame_diamond_blue.png")
	puff.scale = Vector2(0.28, 0.28)
	area.add_child(puff)
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 26.0   # forgiving grab at 320px/s (was 14)
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

	_smoke_label.add_theme_font_size_override("font_size", 52)
	row.add_child(_smoke_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_attempt_label.add_theme_font_size_override("font_size", 52)
	row.add_child(_attempt_label)

	var exit_btn := Button.new()
	exit_btn.text = "  EXIT (Q)  "
	exit_btn.focus_mode = Control.FOCUS_NONE
	exit_btn.custom_minimum_size = Vector2(210, 58)
	exit_btn.add_theme_font_size_override("font_size", 26)
	exit_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	exit_btn.add_theme_constant_override("outline_size", 4)
	var exit_plate := StyleBoxFlat.new()
	exit_plate.bg_color = Color(0.55, 0.09, 0.14, 0.94)
	exit_plate.set_corner_radius_all(8)
	exit_plate.content_margin_left = 14
	exit_plate.content_margin_right = 14
	exit_btn.add_theme_stylebox_override("normal", exit_plate)
	var exit_hover := exit_plate.duplicate()
	exit_hover.bg_color = Color(0.78, 0.16, 0.20, 0.98)
	exit_btn.add_theme_stylebox_override("hover", exit_hover)
	exit_btn.add_theme_stylebox_override("pressed", exit_hover)
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

## WHY ESCAPE ALONE WAS NEVER GOING TO BE ENOUGH.
##
## The founder has reported "can't exit with Esc" across five builds. Each
## time the engine-side fix was real AND the complaint stayed true, because
## the problem is not in this project at all:
##
## The game ships as an HTML5 canvas inside an IFRAME on itch.io. In every
## major browser the Escape key is reserved chrome — it exits fullscreen and
## releases pointer-lock, and the browser consumes it BEFORE the event is
## dispatched to the canvas. A headless Godot probe cannot reproduce that: a
## real InputEventKey injected in-engine reaches _input() perfectly, which is
## exactly why every probe passed while the founder still could not get out.
##
## So Escape is kept (it works in a desktop/standalone build) but is no longer
## the ONLY way out. Q and Backspace are not browser-reserved, and the on-screen
## button is now large enough to hit without hunting for it.
const EXIT_KEYS := [KEY_ESCAPE, KEY_Q, KEY_BACKSPACE]

func _input(event: InputEvent) -> void:
	var wants_exit := event.is_action_pressed("ui_cancel")
	if not wants_exit and event is InputEventKey:
		var k := event as InputEventKey
		wants_exit = k.pressed and not k.echo and k.keycode in EXIT_KEYS
	if wants_exit:
		get_viewport().set_input_as_handled()
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
	# ignore_time_scale = TRUE (4th arg). Engine.time_scale is global and the
	# player's hit-stop drops it to 0.05; if a hit-stop coroutine is orphaned
	# (its node freed mid-await) the scale is never restored, and a 1.8s timer
	# that respects it becomes a 36-SECOND wait. To the founder that is
	# indistinguishable from "the game doesn't return me after I win".
	await get_tree().create_timer(1.2, true, false, true).timeout
	_exit_to_level()

func _show_toast(text: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.add_theme_font_size_override("font_size", 52)
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
		# _level_index, NOT a hardcoded 1. level_checkpoints is keyed BY LEVEL,
		# so writing the return position under key 1 while returning to Level 2
		# or 3 filed the portal drop-point in the wrong level's slot: the target
		# level found no checkpoint of its own and spawned the player at its
		# start, while Level 1 silently inherited a checkpoint from a room the
		# player was never in.
		GameManager.save_checkpoint(_level_index, 990 + _level_index, portal_pos)
	GameManager.dash_return = {}
	_release_music()
	SceneRouter.load_scene(return_path, SceneRouter.Transition.SMOKE)
	_arm_exit_watchdog(return_path)

## LAST-RESORT EXIT. The player must NEVER be stranded in Blaze Rush.
##
## SceneRouter.load_scene() begins with `if _loading_path != "": return` — a
## SILENT no-op guarded only by a push_warning, which is invisible in a browser.
## Any earlier load that failed to clear that field leaves the router
## permanently refusing every future request, and from the founder's seat that
## is precisely "I finished / I pressed the key and nothing happened, forever".
##
## This does not try to diagnose that state; it just verifies the outcome. If
## the scene has NOT changed shortly after we asked, go around SceneRouter
## entirely with the engine's own change_scene_to_file. A slightly abrupt
## transition is an acceptable price for never trapping the player.
func _arm_exit_watchdog(return_path: String) -> void:
	# ignore_time_scale so a stuck Engine.time_scale cannot disarm the net.
	await get_tree().create_timer(2.5, true, false, true).timeout
	if not is_inside_tree():
		return
	var cur := get_tree().current_scene
	if is_instance_valid(cur) and cur.scene_file_path == return_path:
		return  # SceneRouter did its job.
	push_warning("BlazeRush: SceneRouter did not land %s in 2.5s — forcing." % return_path)
	# Lift any wipe/fade overlay the stalled router left on screen, or the
	# forced scene change lands behind an opaque rectangle.
	SceneTransition.fade_in()
	StateMachine.change_state(StateMachine.State.TRANSITIONING)
	var err := get_tree().change_scene_to_file(return_path)
	if err != OK:
		push_error("BlazeRush: forced exit to %s failed (err %d)" % [return_path, err])
