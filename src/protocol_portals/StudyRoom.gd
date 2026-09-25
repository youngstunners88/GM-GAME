extends Node2D
## Protocol Portals step 3 — the study room underneath a glowing ladder.
##
## One screen, no platforming: LEFT is the whitepaper plate, RIGHT is the video
## shrine, and the examiner stands between them at floor level. Everything is
## built in code so the three protocol skins are one-line .tscn instances that
## only override `protocol` and `stage_id`.
##
## The room owns the PortalSession loop for the STUDY_CHOICE half of the run:
##   STUDY_CHOICE -> WHITEPAPER | VIDEO        (overlay, back to STUDY_CHOICE)
##   STUDY_CHOICE -> EXAMINER_INTRO -> QUIZ -> RESULT
##   RESULT -> QUIZ (retry) | ASCENT (leave at any time)
##
## It never mints, never networks and never talks to ICP. Completion only writes
## a local record through ScorecardGrant and hands the player back to the level
## through PortalTravel.ascend().

const SignalsScript := preload("res://src/protocol_portals/PortalSignals.gd")
const PortalSessionScript := preload("res://src/protocol_portals/PortalSession.gd")
const QuizBankScript := preload("res://src/protocol_portals/QuizBank.gd")
const Travel := preload("res://src/protocol_portals/PortalTravel.gd")
const Grant := preload("res://src/protocol_portals/ScorecardGrant.gd")
const SmokePlateScript := preload("res://src/protocol_portals/SmokePlate.gd")
const WhitepaperJumpScript := preload("res://src/protocol_portals/WhitepaperJump.gd")
const VideoShrineScript := preload("res://src/protocol_portals/VideoShrine.gd")
const ExaminerScript := preload("res://src/protocol_portals/Examiner.gd")

# ---- Configuration ----------------------------------------------------------

## Which protocol this room belongs to. Overridden by each skin scene.
@export var protocol: String = "smoke"
## Stage identity. Overridden by each skin scene.
@export var stage_id: int = 1

const ROOM_W: float = 1280.0
const ROOM_H: float = 720.0
const FLOOR_Y: float = 620.0
const PLAYER_SCENE: String = "res://src/player/player.tscn"
const COPY_PATH: String = "res://src/protocol_portals/data/portal_copy.json"

## Divider x (the crisp line splitting paper from video).
const DIVIDER_X: float = 640.0
## Diamonds-room player spawn: left of the divider so the Assay Trio
## (x 700..860) never overlaps the player at load.
const DIAMONDS_SPAWN_X: float = 560.0

## Official study links. EXACTLY these, nothing else, ever.
const PAPER_URLS: Dictionary = {
	"smoke": "https://richs-crypto-projects.gitbook.io/smokering",
	"diamonds": "https://richs-crypto-projects.gitbook.io/diamonds",
	"gold": "https://richs-crypto-projects.gitbook.io/goldmine",
}
const VIDEO_URLS: Dictionary = {
	"smoke": "https://x.com/DefiSparco/status/2082090949086519703",
	"diamonds": "https://x.com/richland100/status/2003193678790283561",
	"gold": "https://x.com/richland100/status/2070925446124839334",
}

# ---- State ------------------------------------------------------------------

var session: PortalSessionScript = null
var bank: QuizBankScript = null

var _copy: Dictionary = {}
var _data: Dictionary = {}
var _glow: Color = Color(0.35, 1.0, 0.45)

var _ui_layer: CanvasLayer = null
var _overlay_root: Control = null
var _overlay_panel: Panel = null
var _overlay_box: VBoxContainer = null
var _overlay_open: bool = false
var _watch_timer: Timer = null
var _done_button: Button = null
var _primary_action: Callable = Callable()
var _quiz_active: bool = false
var _player_in_ascent: bool = false
var _intro_index: int = 0
var _q_index: int = 0
var _grant_recorded: bool = false


func _ready() -> void:
	# StudyRoom keeps receiving input while the tree is paused for an overlay,
	# so it processes always; the player is explicitly re-marked PAUSABLE right
	# after it is instanced, so a paused overlay really does freeze the room.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_glow = _glow_color()
	_copy = _load_copy()
	var raw: Variant = _copy.get(protocol, {})
	if typeof(raw) == TYPE_DICTIONARY:
		_data = raw

	_build_backdrop()
	_build_floor_and_walls()
	_build_divider()
	_build_ascent_shaft()
	_build_whitepaper_plate()
	_build_video_shrine()
	_build_examiner()
	_build_player()
	_build_ui()
	_start_session()


# ---- Copy -------------------------------------------------------------------

func _load_copy() -> Dictionary:
	if not FileAccess.file_exists(COPY_PATH):
		push_error("StudyRoom: copy file missing: %s" % COPY_PATH)
		return {}
	var file: FileAccess = FileAccess.open(COPY_PATH, FileAccess.READ)
	if file == null:
		push_error("StudyRoom: could not open %s (err %d)"
			% [COPY_PATH, FileAccess.get_open_error()])
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("StudyRoom: %s is not a JSON object" % COPY_PATH)
		return {}
	return parsed


func _s(key: String, fallback: String = "") -> String:
	var value: Variant = _data.get(key, fallback)
	if value == null:
		return fallback
	return String(value)


func _s2(source: Dictionary, key: String, fallback: String = "") -> String:
	var value: Variant = source.get(key, fallback)
	if value == null:
		return fallback
	return String(value)


func _plate() -> Dictionary:
	var value: Variant = _data.get("plate", {})
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {}


# ---- Session ----------------------------------------------------------------

## Reuses the session PortalTravel opened for this protocol (the normal path
## when the player came down the ladder), otherwise opens one here so the room
## also works when loaded directly. Either way the session sits in STUDY_CHOICE
## once _ready is done.
func _start_session() -> void:
	var reuse: bool = false
	if Travel.session != null:
		reuse = String(Travel.session.get("protocol")) == protocol
	if reuse:
		session = Travel.session
	else:
		session = PortalSessionScript.begin(stage_id, protocol)
		Travel.session = session
	if session == null:
		push_error("StudyRoom: could not start a PortalSession for %s" % protocol)
		return
	if session.state == SignalsScript.State.WORLD:
		session.transition(SignalsScript.State.DESCENT)
	if session.state == SignalsScript.State.DESCENT:
		session.transition(SignalsScript.State.STUDY_CHOICE)


## Headless test hook: drives the session through the exam without any UI.
## Returns session.to_dict() so a test can assert on score / pass / completion.
func test_run(choices: Array[int]) -> Dictionary:
	if session == null:
		return {"error": "no session"}
	if bank == null:
		bank = QuizBankScript.load_bank(protocol)
	if bank == null:
		return {"error": "no quiz bank for %s" % protocol}
	if session.state == SignalsScript.State.STUDY_CHOICE:
		session.transition(SignalsScript.State.EXAMINER_INTRO)
	if session.state == SignalsScript.State.EXAMINER_INTRO:
		session.transition(SignalsScript.State.QUIZ)
	if session.state != SignalsScript.State.QUIZ:
		return {"error": "session not in QUIZ (state %d)" % session.state}
	for i in range(SignalsScript.QUESTION_COUNT):
		var choice: int = choices[i] if i < choices.size() else -1
		if choice < 0:
			continue
		session.answer(i, choice)
	session.grade(bank.answer_key())
	if session.state == SignalsScript.State.QUIZ:
		session.transition(SignalsScript.State.RESULT)
	return session.to_dict()


## True while any overlay is open (the tree is paused). Used by the interaction
## zones so a second overlay can never stack.
func is_overlay_open() -> bool:
	return _overlay_open


# ---- Backdrop ---------------------------------------------------------------

func _glow_color() -> Color:
	match protocol:
		"diamonds":
			return Color(0.35, 0.95, 1.0)
		"gold":
			return Color(1.0, 0.9, 0.45)
		_:
			return Color(0.35, 1.0, 0.45)


func _top_color() -> Color:
	match protocol:
		"diamonds":
			return Color(0.03, 0.07, 0.17)
		"gold":
			return Color(0.14, 0.09, 0.05)
		_:
			return Color(0.05, 0.13, 0.09)


func _bottom_color() -> Color:
	match protocol:
		"diamonds":
			return Color(0.01, 0.02, 0.06)
		"gold":
			return Color(0.05, 0.03, 0.02)
		_:
			return Color(0.02, 0.05, 0.04)


func _slab_color() -> Color:
	match protocol:
		"diamonds":
			return Color(0.02, 0.04, 0.09)
		"gold":
			return Color(0.09, 0.06, 0.035)
		_:
			return Color(0.03, 0.06, 0.045)


## Vertical gradient + vignette + slow drifting motes. All CPUParticles2D (never
## GPU): the HTML5 non-threaded target has no reliable GPU particles.
func _build_backdrop() -> void:
	var layer := Node2D.new()
	layer.name = "Backdrop"
	layer.z_index = -100
	add_child(layer)

	var grad := Gradient.new()
	grad.set_color(0, _top_color())
	grad.set_color(1, _bottom_color())
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_LINEAR
	grad_tex.fill_from = Vector2(0.0, 0.0)
	grad_tex.fill_to = Vector2(0.0, 1.0)
	grad_tex.width = 8
	grad_tex.height = 256
	var bg := TextureRect.new()
	bg.name = "Gradient"
	bg.texture = grad_tex
	bg.position = Vector2.ZERO
	bg.size = Vector2(ROOM_W, ROOM_H)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	layer.add_child(bg)

	var vig_grad := Gradient.new()
	vig_grad.set_color(0, Color(0.0, 0.0, 0.0, 0.0))
	vig_grad.set_color(1, Color(0.0, 0.0, 0.0, 0.6))
	var vig_tex := GradientTexture2D.new()
	vig_tex.gradient = vig_grad
	vig_tex.fill = GradientTexture2D.FILL_RADIAL
	vig_tex.fill_from = Vector2(0.5, 0.5)
	vig_tex.fill_to = Vector2(0.5, 0.0)
	vig_tex.width = int(ROOM_W)
	vig_tex.height = int(ROOM_H)
	var vignette := TextureRect.new()
	vignette.name = "Vignette"
	vignette.texture = vig_tex
	vignette.position = Vector2.ZERO
	vignette.size = Vector2(ROOM_W, ROOM_H)
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	layer.add_child(vignette)

	var motes := CPUParticles2D.new()
	motes.name = "Motes"
	motes.texture = _make_square_texture(2)
	motes.amount = 26
	motes.lifetime = 9.0
	motes.local_coords = false
	motes.position = Vector2(ROOM_W * 0.5, ROOM_H * 0.5)
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(ROOM_W * 0.5, ROOM_H * 0.4)
	motes.direction = Vector2(0.0, -1.0)
	motes.spread = 40.0
	motes.gravity = Vector2.ZERO
	motes.initial_velocity_min = 5.0
	motes.initial_velocity_max = 18.0
	motes.scale_amount_min = 2.0
	motes.scale_amount_max = 4.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(_glow.r, _glow.g, _glow.b, 0.0))
	ramp.set_color(1, Color(_glow.r, _glow.g, _glow.b, 0.35))
	motes.color_ramp = ramp
	layer.add_child(motes)


func _make_square_texture(side: int) -> ImageTexture:
	var img: Image = Image.create(side, side, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 1.0, 1.0, 1.0))
	return ImageTexture.create_from_image(img)


# ---- Floor ------------------------------------------------------------------

## Solid floor across the room (top surface exactly at FLOOR_Y) plus two off
## screen side walls, so the player can never run out of the pocket.
func _build_floor_and_walls() -> void:
	var slab := ColorRect.new()
	slab.name = "FloorSlab"
	slab.position = Vector2(0.0, FLOOR_Y)
	slab.size = Vector2(ROOM_W, ROOM_H - FLOOR_Y)
	slab.color = _slab_color()
	slab.z_index = -50
	add_child(slab)

	var trim := ColorRect.new()
	trim.name = "FloorTrim"
	trim.position = Vector2(0.0, FLOOR_Y - 3.0)
	trim.size = Vector2(ROOM_W, 3.0)
	trim.color = Color(_glow.r, _glow.g, _glow.b, 0.55)
	trim.z_index = -49
	add_child(trim)

	var floor_body := StaticBody2D.new()
	floor_body.name = "Floor"
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	floor_body.position = Vector2(ROOM_W * 0.5, FLOOR_Y + 20.0)
	var floor_shape := CollisionShape2D.new()
	floor_shape.name = "CollisionShape2D"
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(ROOM_W, 40.0)
	floor_shape.shape = floor_rect
	floor_body.add_child(floor_shape)
	add_child(floor_body)

	var walls := StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = 1
	walls.collision_mask = 0
	var wall_xs: Array[float] = [-20.0, ROOM_W + 20.0]
	for i in range(wall_xs.size()):
		var wall_shape := CollisionShape2D.new()
		wall_shape.name = "WallShape%d" % i
		var wall_rect := RectangleShape2D.new()
		wall_rect.size = Vector2(40.0, ROOM_H + 200.0)
		wall_shape.shape = wall_rect
		wall_shape.position = Vector2(wall_xs[i], ROOM_H * 0.5)
		walls.add_child(wall_shape)
	add_child(walls)


# ---- Divider ----------------------------------------------------------------

## One crisp 3px line splitting LEFT (paper) from RIGHT (video). Deliberately a
## single Line2D with two points: no second edge, no seam, no taper.
func _build_divider() -> void:
	# Faint wide glow copy underneath — sits below the crisp line so no doubled
	# hard edge shows.
	var glow_line := Line2D.new()
	glow_line.name = "DividerGlow"
	glow_line.width = 12.0
	glow_line.default_color = Color(_glow.r, _glow.g, _glow.b, 0.18)
	glow_line.joint_mode = Line2D.LINE_JOINT_SHARP
	glow_line.points = PackedVector2Array([Vector2(640.0, 372.0), Vector2(640.0, FLOOR_Y)])
	glow_line.z_index = -41
	add_child(glow_line)

	# Dark backing stroke: gold-on-dark-brown read as "barely visible" in the
	# Jev round-3 capture, so the crisp line now sits on a near-black band.
	var backing := Line2D.new()
	backing.name = "DividerBacking"
	backing.width = 8.0
	backing.default_color = Color(0.02, 0.02, 0.03, 0.9)
	backing.points = PackedVector2Array([Vector2(640.0, 372.0), Vector2(640.0, FLOOR_Y)])
	backing.z_index = -41
	add_child(backing)

	var line := Line2D.new()
	line.name = "Divider"
	line.width = 4.0
	line.default_color = _glow.lerp(Color.WHITE, 0.35)
	line.joint_mode = Line2D.LINE_JOINT_SHARP
	line.points = PackedVector2Array([Vector2(640.0, 372.0), Vector2(640.0, FLOOR_Y)])
	line.z_index = -40
	add_child(line)


# ---- Ascent shaft -----------------------------------------------------------

## The way home: the same glow colour as the ladder down in the level, rails
## climbing up and out of the top of the frame, an always-visible "CLIMB BACK"
## prompt and the AscentShaft area at the base. Leaving is allowed at ANY time.
func _build_ascent_shaft() -> void:
	var rails := Node2D.new()
	rails.name = "AscentRails"
	rails.z_index = -30
	add_child(rails)

	var shaft_color: Color = _glow
	var offsets: Array[float] = [-14.0, 14.0]
	for i in range(offsets.size()):
		var rail := Line2D.new()
		rail.name = "Rail%d" % i
		rail.width = 4.0
		rail.default_color = shaft_color
		# Rails stop at y=360 so the ladder never crosses the Divider below.
		rail.points = PackedVector2Array([
			Vector2(640.0 + offsets[i], -40.0),
			Vector2(640.0 + offsets[i], 360.0),
		])
		rails.add_child(rail)

	var y: float = -30.0
	var rung_index: int = 0
	while y < 352.0:
		var rung := Line2D.new()
		rung.name = "Rung%d" % rung_index
		rung.width = 4.0
		rung.default_color = shaft_color.darkened(0.15)
		rung.points = PackedVector2Array([Vector2(626.0, y), Vector2(654.0, y)])
		rails.add_child(rung)
		rung_index += 1
		y += 26.0

	var label := Label.new()
	label.name = "AscentLabel"
	label.text = "CLIMB BACK  [E]"
	label.size = Vector2(240.0, 38.0)
	# Sits just above the top of the visible rails, centred on the shaft.
	label.position = Vector2(520.0, 91.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", shaft_color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_stylebox_override("normal", _backing_style())
	label.z_index = 5
	add_child(label)

	var area := Area2D.new()
	area.name = "AscentShaft"
	area.collision_layer = 0
	area.collision_mask = 2
	# Anchored at the shaft base (y ~ 350) with the rect stretched down to the
	# floor, so a player standing under the shaft can still interact.
	area.position = Vector2(640.0, 350.0)
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(100.0, 540.0)
	shape.shape = rect
	area.add_child(shape)
	area.body_entered.connect(_on_ascent_body_entered)
	area.body_exited.connect(_on_ascent_body_exited)
	add_child(area)

	var motes := CPUParticles2D.new()
	motes.name = "ShaftMotes"
	motes.texture = _make_square_texture(2)
	motes.amount = 16
	motes.lifetime = 2.0
	motes.local_coords = false
	motes.position = Vector2(640.0, 340.0)
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(28.0, 16.0)
	motes.direction = Vector2(0.0, -1.0)
	motes.spread = 10.0
	motes.gravity = Vector2.ZERO
	motes.initial_velocity_min = 30.0
	motes.initial_velocity_max = 70.0
	motes.scale_amount_min = 2.0
	motes.scale_amount_max = 4.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(_glow.r, _glow.g, _glow.b, 0.9))
	ramp.set_color(1, Color(_glow.r, _glow.g, _glow.b, 0.0))
	motes.color_ramp = ramp
	motes.z_index = -29
	add_child(motes)


func _on_ascent_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_ascent = true


func _on_ascent_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_ascent = false


# ---- Whitepaper plate (LEFT, x ~ 300) ---------------------------------------

## A lectern holding the plate. Smoke renders the plate in code (SmokePlate);
## diamonds and gold hang the founder JPEG, framed and shadowed.
func _build_whitepaper_plate() -> void:
	var holder := Node2D.new()
	holder.name = "WhitepaperPlate"
	holder.position = Vector2(300.0, FLOOR_Y)
	add_child(holder)

	var lectern := Polygon2D.new()
	lectern.name = "Lectern"
	lectern.polygon = PackedVector2Array([
		Vector2(-90.0, 0.0),
		Vector2(90.0, 0.0),
		Vector2(58.0, -150.0),
		Vector2(-58.0, -150.0),
	])
	lectern.color = _slab_color().lightened(0.08)
	holder.add_child(lectern)

	var lectern_top := Polygon2D.new()
	lectern_top.name = "LecternTop"
	lectern_top.polygon = PackedVector2Array([
		Vector2(-74.0, -150.0),
		Vector2(74.0, -150.0),
		Vector2(66.0, -162.0),
		Vector2(-66.0, -162.0),
	])
	lectern_top.color = _slab_color().lightened(0.18)
	holder.add_child(lectern_top)

	if protocol == "smoke":
		var plate := Node2D.new()
		plate.name = "PlateArt"
		plate.set_script(SmokePlateScript)
		plate.position = Vector2(0.0, -250.0)
		plate.scale = Vector2(0.55, 0.55)
		var spec: Variant = _plate().get("draw_spec", {})
		if typeof(spec) == TYPE_DICTIONARY:
			plate.set("draw_spec", spec)
		holder.add_child(plate)
	else:
		holder.add_child(_build_plate_art(
			"res://src/assets/portals/plate_%s_whitepaper.jpg" % protocol,
			Vector2(0.0, -250.0), 300.0))

	var label := Label.new()
	label.name = "PaperLabel"
	label.text = _s("paper_label", "Read the Whitepaper")
	label.size = Vector2(300.0, 40.0)
	label.position = Vector2(-150.0, -470.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", _glow)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_stylebox_override("normal", _backing_style())
	holder.add_child(label)

	var zone := Area2D.new()
	zone.set_script(WhitepaperJumpScript)
	zone.name = "WhitepaperJumpZone"
	zone.collision_layer = 0
	zone.collision_mask = 2
	zone.position = Vector2(0.0, -160.0)
	zone.set("room", self)
	var zone_shape := CollisionShape2D.new()
	zone_shape.name = "CollisionShape2D"
	var zone_rect := RectangleShape2D.new()
	zone_rect.size = Vector2(280.0, 320.0)
	zone_shape.shape = zone_rect
	zone.add_child(zone_shape)
	holder.add_child(zone)


## Founder art, centred, with a drop shadow behind it and a glow-colour frame
## around it. Falls back to a plain dark card if the texture is missing.
func _build_plate_art(texture_path: String, centre: Vector2, target_width: float) -> Node2D:
	var holder := Node2D.new()
	holder.name = "PlateArt"
	holder.position = centre

	var art_size := Vector2(target_width, 200.0)
	var sprite: Sprite2D = null
	if ResourceLoader.exists(texture_path):
		var tex: Texture2D = load(texture_path)
		if tex != null and tex.get_width() > 0:
			sprite = Sprite2D.new()
			sprite.name = "PlateTexture"
			sprite.texture = tex
			var factor: float = target_width / float(tex.get_width())
			sprite.scale = Vector2(factor, factor)
			art_size = Vector2(float(tex.get_width()) * factor, float(tex.get_height()) * factor)
	else:
		push_warning("StudyRoom: plate texture missing: %s" % texture_path)

	var half := art_size * 0.5

	var shadow := ColorRect.new()
	shadow.name = "PlateShadow"
	shadow.position = Vector2(-half.x + 10.0, -half.y + 12.0)
	shadow.size = art_size
	shadow.color = Color(0.0, 0.0, 0.0, 0.45)
	holder.add_child(shadow)

	if sprite != null:
		holder.add_child(sprite)
	else:
		var card := ColorRect.new()
		card.name = "PlateFallback"
		card.position = -half
		card.size = art_size
		card.color = _slab_color().lightened(0.05)
		holder.add_child(card)

	var frame := Line2D.new()
	frame.name = "PlateFrame"
	frame.width = 3.0
	frame.default_color = Color(_glow.r, _glow.g, _glow.b, 0.85)
	frame.closed = true
	frame.points = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	holder.add_child(frame)
	return holder


# ---- Video shrine (RIGHT, x ~ 980) ------------------------------------------

## A small shrine: stone arch, a screen with a drawn play triangle and the
## video label above it. The triangle is a Polygon2D — the game font has no
## play glyph.
func _build_video_shrine() -> void:
	var holder := Node2D.new()
	holder.name = "VideoShrine"
	holder.position = Vector2(980.0, FLOOR_Y)
	add_child(holder)

	var arch := Polygon2D.new()
	arch.name = "Arch"
	arch.polygon = PackedVector2Array([
		Vector2(-80.0, 0.0),
		Vector2(80.0, 0.0),
		Vector2(80.0, -140.0),
		Vector2(0.0, -200.0),
		Vector2(-80.0, -140.0),
	])
	arch.color = _slab_color().lightened(0.06)
	holder.add_child(arch)

	var screen := Polygon2D.new()
	screen.name = "Screen"
	screen.polygon = PackedVector2Array([
		Vector2(-90.0, -150.0),
		Vector2(90.0, -150.0),
		Vector2(90.0, -30.0),
		Vector2(-90.0, -30.0),
	])
	screen.color = Color(0.02, 0.03, 0.05, 0.95)
	screen.z_index = 1
	holder.add_child(screen)

	var screen_frame := Line2D.new()
	screen_frame.name = "ScreenFrame"
	screen_frame.width = 3.0
	screen_frame.default_color = Color(_glow.r, _glow.g, _glow.b, 0.85)
	screen_frame.closed = true
	screen_frame.points = PackedVector2Array([
		Vector2(-90.0, -150.0),
		Vector2(90.0, -150.0),
		Vector2(90.0, -30.0),
		Vector2(-90.0, -30.0),
	])
	screen_frame.z_index = 2
	holder.add_child(screen_frame)

	var play := Polygon2D.new()
	play.name = "PlayTriangle"
	play.polygon = PackedVector2Array([
		Vector2(-16.0, -26.0),
		Vector2(-16.0, 26.0),
		Vector2(26.0, 0.0),
	])
	play.color = Color(_glow.r, _glow.g, _glow.b, 0.95)
	play.position = Vector2(0.0, -90.0)
	play.z_index = 3
	holder.add_child(play)

	var label := Label.new()
	label.name = "VideoLabel"
	label.text = _s("video_label", "Watch the Video")
	label.size = Vector2(300.0, 40.0)
	label.position = Vector2(-150.0, -300.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", _glow)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_stylebox_override("normal", _backing_style())
	holder.add_child(label)

	var zone := Area2D.new()
	zone.set_script(VideoShrineScript)
	zone.name = "VideoShrineZone"
	zone.collision_layer = 0
	zone.collision_mask = 2
	zone.position = Vector2(0.0, -110.0)
	zone.set("room", self)
	var zone_shape := CollisionShape2D.new()
	zone_shape.name = "CollisionShape2D"
	var zone_rect := RectangleShape2D.new()
	zone_rect.size = Vector2(240.0, 300.0)
	zone_shape.shape = zone_rect
	zone.add_child(zone_shape)
	holder.add_child(zone)


# ---- Examiner (CENTRE-RIGHT, x ~ 760) ---------------------------------------

## A protocol-specific Polygon2D prop plus the examiner's name. Smoke: Ember,
## a robed archivist with a green lamp. Diamonds: the Assay Trio, three crystal
## jurors. Gold: the Claim Recorder at a small desk with a stamp and ledger.
## Purely decorative plus an interaction zone — no minting anywhere near it.
##
## Anchor x is 760. The Assay Trio spans world x 700..860 (local -60..+100),
## so it stays clear of the video shrine screen (left edge 890) and of the
## divider (640). Its label is centred over the trio at world x 780 and its
## left edge sits at 680, 40 px right of the divider.
func _build_examiner() -> void:
	var holder := Node2D.new()
	holder.name = "Examiner"
	holder.position = Vector2(760.0, FLOOR_Y)
	add_child(holder)

	var prop := Node2D.new()
	prop.name = "ExaminerProp"
	holder.add_child(prop)
	match protocol:
		"diamonds":
			_build_assay_trio(prop)
		"gold":
			_build_claim_recorder(prop)
		_:
			_build_ember(prop)

	var label := Label.new()
	label.name = "ExaminerLabel"
	label.text = _s("examiner_name", "Examiner")
	label.size = Vector2(200.0, 34.0)
	if protocol == "diamonds":
		# Centred on the trio (world x 780 = local +20), just above the tallest
		# juror (CUT, top at -136). Left edge local -80 = world 680, i.e. 40 px
		# from the divider; any overflow grows to the right, away from it.
		label.position = Vector2(-80.0, -214.0)
	else:
		label.position = Vector2(-100.0, -262.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", _glow)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_stylebox_override("normal", _backing_style())
	holder.add_child(label)

	var zone := Area2D.new()
	zone.set_script(ExaminerScript)
	zone.name = "ExaminerZone"
	zone.collision_layer = 0
	zone.collision_mask = 2
	zone.position = Vector2(0.0, -110.0)
	zone.set("room", self)
	zone.set("protocol", protocol)
	var zone_shape := CollisionShape2D.new()
	zone_shape.name = "CollisionShape2D"
	var zone_rect := RectangleShape2D.new()
	zone_rect.size = Vector2(160.0, 300.0)
	zone_shape.shape = zone_rect
	zone.add_child(zone_shape)
	holder.add_child(zone)


## Ember: a ~150 px tall hooded archivist standing on the floor, in a warm
## parchment robe with a dark brown outline so the silhouette reads against the
## deep green smoke room. Holds a green lantern aloft in one hand and a closed
## book under the other arm.
func _build_ember(parent: Node2D) -> void:
	var parchment := Color(0.92, 0.86, 0.72)
	var parchment_shade := Color(0.84, 0.77, 0.63)
	var outline_brown := Color(0.34, 0.24, 0.15)
	var face_dark := Color(0.20, 0.14, 0.10)
	var eye_dark := Color(0.08, 0.08, 0.10)
	var brass := Color(0.85, 0.72, 0.35)
	var beard_grey := Color(0.80, 0.80, 0.82)
	var book_brown := Color(0.42, 0.28, 0.16)
	var gold_spine := Color(0.90, 0.74, 0.30)
	var lantern_green := Color(0.35, 1.0, 0.45)
	var lantern_pos := Vector2(48.0, -138.0)

	# --- dark ground shadow ellipse, drawn first so it sits under the figure ---
	var shadow := _add_poly(parent, "GroundShadow", _circle_polygon(34.0, 24),
		Color(0.0, 0.0, 0.0, 0.45), Vector2(0.0, 2.0))
	shadow.scale = Vector2(1.5, 0.34)

	# --- robe body (hem on the floor) and hood ---
	_add_poly(parent, "Robe", PackedVector2Array([
		Vector2(-34.0, 0.0), Vector2(34.0, 0.0),
		Vector2(26.0, -92.0), Vector2(-26.0, -92.0),
	]), parchment)
	_add_poly(parent, "Hood", PackedVector2Array([
		Vector2(-26.0, -86.0), Vector2(26.0, -86.0),
		Vector2(20.0, -140.0), Vector2(0.0, -152.0),
		Vector2(-20.0, -140.0),
	]), parchment_shade)

	# --- darker brown outline around the whole silhouette ---
	var outline := Line2D.new()
	outline.name = "RobeOutline"
	outline.width = 3.0
	outline.default_color = outline_brown
	outline.closed = true
	outline.points = PackedVector2Array([
		Vector2(-34.0, 0.0),
		Vector2(34.0, 0.0),
		Vector2(26.0, -92.0),
		Vector2(20.0, -140.0),
		Vector2(0.0, -152.0),
		Vector2(-20.0, -140.0),
		Vector2(-26.0, -92.0),
	])
	parent.add_child(outline)

	# --- face opening, dot eyes and round spectacles ---
	_add_poly(parent, "FaceOpening", _circle_polygon(13.0, 20), face_dark, Vector2(0.0, -114.0))
	_add_poly(parent, "EyeL", _circle_polygon(2.4, 10), eye_dark, Vector2(-5.0, -117.0))
	_add_poly(parent, "EyeR", _circle_polygon(2.4, 10), eye_dark, Vector2(5.0, -117.0))
	for i in range(2):
		var lens_x: float = -5.0 if i == 0 else 5.0
		var lens := Line2D.new()
		lens.name = "Spectacle%d" % i
		lens.width = 1.5
		lens.default_color = brass
		lens.closed = true
		lens.points = _circle_polygon(5.0, 14)
		lens.position = Vector2(lens_x, -117.0)
		parent.add_child(lens)
	_add_line(parent, "SpectacleBridge", Vector2(-2.0, -117.0), Vector2(2.0, -117.0), brass, 1.5)

	# --- long grey beard hanging over the chest ---
	_add_poly(parent, "Beard", PackedVector2Array([
		Vector2(-9.0, -104.0), Vector2(9.0, -104.0), Vector2(0.0, -62.0),
	]), beard_grey)

	# --- closed book tucked under the left arm, gold spine on the outer edge ---
	_add_poly(parent, "Book", PackedVector2Array([
		Vector2(-50.0, -86.0), Vector2(-24.0, -86.0),
		Vector2(-24.0, -54.0), Vector2(-50.0, -54.0),
	]), book_brown)
	_add_line(parent, "BookSpine", Vector2(-44.0, -86.0), Vector2(-44.0, -54.0), gold_spine, 2.5)
	_add_poly(parent, "ArmL", PackedVector2Array([
		Vector2(-18.0, -94.0), Vector2(-6.0, -98.0),
		Vector2(-30.0, -88.0), Vector2(-44.0, -96.0),
	]), parchment_shade)

	# --- right arm raised, holding the green lantern ---
	_add_poly(parent, "ArmR", PackedVector2Array([
		Vector2(16.0, -94.0), Vector2(28.0, -98.0),
		Vector2(44.0, -118.0), Vector2(32.0, -126.0),
	]), parchment_shade)
	_add_poly(parent, "HandR", _circle_polygon(5.0, 12), parchment, Vector2(40.0, -120.0))
	_add_poly(parent, "LanternCap", PackedVector2Array([
		Vector2(-7.0, -20.0), Vector2(7.0, -20.0),
		Vector2(4.0, -13.0), Vector2(-4.0, -13.0),
	]), outline_brown, lantern_pos)
	_add_poly(parent, "LanternBody", PackedVector2Array([
		Vector2(-10.0, -12.0), Vector2(10.0, -12.0),
		Vector2(12.0, 10.0), Vector2(-12.0, 10.0),
	]), lantern_green, lantern_pos)
	_add_poly(parent, "LanternBase", PackedVector2Array([
		Vector2(-9.0, 10.0), Vector2(9.0, 10.0),
		Vector2(7.0, 16.0), Vector2(-7.0, 16.0),
	]), outline_brown, lantern_pos)

	# --- additive radial glow on the lantern ---
	var glow_grad := Gradient.new()
	glow_grad.set_color(0, Color(lantern_green.r, lantern_green.g, lantern_green.b, 0.85))
	glow_grad.set_color(1, Color(lantern_green.r, lantern_green.g, lantern_green.b, 0.0))
	var glow_tex := GradientTexture2D.new()
	glow_tex.gradient = glow_grad
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.5)
	glow_tex.fill_to = Vector2(0.5, 0.0)
	glow_tex.width = 90
	glow_tex.height = 90
	var glow_mat := CanvasItemMaterial.new()
	glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var glow := Sprite2D.new()
	glow.name = "LanternGlow"
	glow.texture = glow_tex
	glow.material = glow_mat
	glow.position = lantern_pos
	parent.add_child(glow)


## The Assay Trio: three DISTINCT crystal jurors standing in a row on the floor
## between world x 700 and 860 (local -60..+100 around the x=760 anchor):
##   CUT   — tall faceted sapphire blue, holding a chisel   (local -60..-18)
##   WEIGH — wide violet, a small balance scale on its crown (local  -8..+48)
##   STAMP — short pale cyan, holding an assay stamp         (local +56..+100)
## Each has a dark outline, a lighter facet plane and two outlined eyes.
func _build_assay_trio(parent: Node2D) -> void:
	var ink := Color(0.03, 0.04, 0.10)

	# --- CUT: tall faceted blue, chisel in its left hand ---
	var cut_x: float = -36.0
	var cut_body := PackedVector2Array([
		Vector2(-14.0, 0.0), Vector2(14.0, 0.0),
		Vector2(18.0, -70.0), Vector2(10.0, -120.0),
		Vector2(0.0, -136.0), Vector2(-10.0, -120.0),
		Vector2(-18.0, -70.0),
	])
	var cut_facet := PackedVector2Array([
		Vector2(-18.0, -70.0), Vector2(-10.0, -120.0),
		Vector2(0.0, -136.0), Vector2(0.0, -70.0),
	])
	_build_juror(parent, 0, cut_x, cut_body, cut_facet,
		Color(0.22, 0.45, 0.95), -104.0, 18.0, ink)
	_add_line(parent, "CutFacetLine", Vector2(cut_x - 18.0, -70.0), Vector2(cut_x + 18.0, -70.0),
		Color(0.55, 0.75, 1.0, 0.8), 1.5)
	_add_line(parent, "CutFacetLine2", Vector2(cut_x, -70.0), Vector2(cut_x, 0.0),
		Color(0.55, 0.75, 1.0, 0.6), 1.5)
	# Chisel: wooden handle up top, steel blade pointing down.
	_add_poly(parent, "ChiselHandle", PackedVector2Array([
		Vector2(cut_x - 26.0, -78.0), Vector2(cut_x - 18.0, -78.0),
		Vector2(cut_x - 18.0, -56.0), Vector2(cut_x - 26.0, -56.0),
	]), Color(0.50, 0.32, 0.16))
	_add_poly(parent, "ChiselBlade", PackedVector2Array([
		Vector2(cut_x - 25.0, -56.0), Vector2(cut_x - 19.0, -56.0),
		Vector2(cut_x - 19.0, -36.0), Vector2(cut_x - 22.0, -30.0),
		Vector2(cut_x - 25.0, -36.0),
	]), Color(0.80, 0.84, 0.90))
	_add_outline(parent, "ChiselOutline", PackedVector2Array([
		Vector2(cut_x - 26.0, -78.0), Vector2(cut_x - 18.0, -78.0),
		Vector2(cut_x - 18.0, -56.0), Vector2(cut_x - 19.0, -56.0),
		Vector2(cut_x - 19.0, -36.0), Vector2(cut_x - 22.0, -30.0),
		Vector2(cut_x - 25.0, -36.0), Vector2(cut_x - 25.0, -56.0),
		Vector2(cut_x - 26.0, -56.0),
	]), ink, 1.5)
	_add_poly(parent, "CutHand", _circle_polygon(4.0, 10), Color(0.35, 0.58, 1.0), Vector2(cut_x - 17.0, -60.0))

	# --- WEIGH: wide violet, balance scale on its crown ---
	var weigh_x: float = 20.0
	var weigh_body := PackedVector2Array([
		Vector2(-24.0, 0.0), Vector2(24.0, 0.0),
		Vector2(28.0, -40.0), Vector2(14.0, -78.0),
		Vector2(-14.0, -78.0), Vector2(-28.0, -40.0),
	])
	var weigh_facet := PackedVector2Array([
		Vector2(-28.0, -40.0), Vector2(-14.0, -78.0),
		Vector2(14.0, -78.0), Vector2(0.0, -40.0),
	])
	_build_juror(parent, 1, weigh_x, weigh_body, weigh_facet,
		Color(0.55, 0.32, 0.88), -56.0, 26.0, ink)
	_add_line(parent, "WeighFacetLine", Vector2(weigh_x - 28.0, -40.0), Vector2(weigh_x + 28.0, -40.0),
		Color(0.80, 0.65, 1.0, 0.8), 1.5)
	var brass := Color(0.92, 0.80, 0.40)
	_add_line(parent, "ScalePost", Vector2(weigh_x, -78.0), Vector2(weigh_x, -100.0), brass, 2.5)
	_add_line(parent, "ScaleBeam", Vector2(weigh_x - 18.0, -100.0), Vector2(weigh_x + 18.0, -100.0), brass, 2.5)
	_add_line(parent, "ScaleCordL", Vector2(weigh_x - 18.0, -100.0), Vector2(weigh_x - 18.0, -90.0), brass, 1.5)
	_add_line(parent, "ScaleCordR", Vector2(weigh_x + 18.0, -100.0), Vector2(weigh_x + 18.0, -90.0), brass, 1.5)
	for side in range(2):
		var pan_x: float = weigh_x - 18.0 if side == 0 else weigh_x + 18.0
		var pan_pts := PackedVector2Array([
			Vector2(pan_x - 7.0, -90.0), Vector2(pan_x + 7.0, -90.0),
			Vector2(pan_x + 4.0, -85.0), Vector2(pan_x - 4.0, -85.0),
		])
		_add_poly(parent, "ScalePan%d" % side, pan_pts, brass)
		_add_outline(parent, "ScalePanOutline%d" % side, pan_pts, ink, 1.2)
	_add_poly(parent, "ScalePivot", _circle_polygon(2.5, 10), brass, Vector2(weigh_x, -101.0))

	# --- STAMP: short pale cyan, assay stamp in its right hand ---
	var stamp_x: float = 74.0
	var stamp_body := PackedVector2Array([
		Vector2(-15.0, 0.0), Vector2(15.0, 0.0),
		Vector2(18.0, -30.0), Vector2(0.0, -56.0),
		Vector2(-18.0, -30.0),
	])
	var stamp_facet := PackedVector2Array([
		Vector2(-18.0, -30.0), Vector2(0.0, -56.0), Vector2(0.0, -30.0),
	])
	_build_juror(parent, 2, stamp_x, stamp_body, stamp_facet,
		Color(0.66, 0.92, 1.0), -30.0, 18.0, ink)
	_add_line(parent, "StampFacetLine", Vector2(stamp_x - 18.0, -30.0), Vector2(stamp_x + 18.0, -30.0),
		Color(0.95, 1.0, 1.0, 0.8), 1.5)
	_add_poly(parent, "StampKnob", _circle_polygon(4.0, 12), Color(0.30, 0.20, 0.12), Vector2(stamp_x + 21.0, -40.0))
	_add_poly(parent, "StampShaft", PackedVector2Array([
		Vector2(stamp_x + 19.0, -37.0), Vector2(stamp_x + 23.0, -37.0),
		Vector2(stamp_x + 23.0, -26.0), Vector2(stamp_x + 19.0, -26.0),
	]), Color(0.30, 0.20, 0.12))
	var stamp_head := PackedVector2Array([
		Vector2(stamp_x + 14.0, -26.0), Vector2(stamp_x + 26.0, -26.0),
		Vector2(stamp_x + 26.0, -18.0), Vector2(stamp_x + 14.0, -18.0),
	])
	_add_poly(parent, "StampHead", stamp_head, Color(0.80, 0.20, 0.18))
	_add_outline(parent, "StampHeadOutline", stamp_head, ink, 1.5)
	_add_poly(parent, "StampHand", _circle_polygon(3.5, 10), Color(0.80, 0.97, 1.0), Vector2(stamp_x + 16.0, -32.0))


## One juror: ground shadow, crystal body (named Crystal<i>), lighter facet
## plane, dark outline and two outlined eyes at `eye_y`.
func _build_juror(parent: Node2D, index: int, cx: float, body: PackedVector2Array,
		facet: PackedVector2Array, color: Color, eye_y: float, half_w: float, ink: Color) -> void:
	var shadow := _add_poly(parent, "JurorShadow%d" % index, _circle_polygon(half_w + 4.0, 20),
		Color(0.0, 0.0, 0.0, 0.45), Vector2(cx, 2.0))
	shadow.scale = Vector2(1.0, 0.25)
	_add_poly(parent, "Crystal%d" % index, _shift(body, cx), color)
	_add_poly(parent, "Facet%d" % index, _shift(facet, cx), color.lightened(0.35))
	_add_outline(parent, "CrystalOutline%d" % index, _shift(body, cx), ink, 2.5)
	for side in range(2):
		var ex: float = cx - 5.0 if side == 0 else cx + 5.0
		_add_poly(parent, "EyeRim%d_%d" % [index, side], _circle_polygon(4.6, 12), ink, Vector2(ex, eye_y))
		_add_poly(parent, "EyeWhite%d_%d" % [index, side], _circle_polygon(3.4, 12),
			Color(0.97, 0.98, 1.0), Vector2(ex, eye_y))
		_add_poly(parent, "Pupil%d_%d" % [index, side], _circle_polygon(1.7, 8), ink, Vector2(ex + 0.6, eye_y + 0.4))


func _shift(points: PackedVector2Array, dx: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(Vector2(p.x + dx, p.y))
	return out


func _add_outline(parent: Node2D, node_name: String, points: PackedVector2Array, color: Color, width: float = 2.0) -> Line2D:
	var line := Line2D.new()
	line.name = node_name
	line.points = points
	line.closed = true
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.default_color = color
	line.width = width
	parent.add_child(line)
	return line


## The Claim Recorder: a readable clerk (green eyeshade, two dot eyes, sleeves
## with arm garters, a vest pocket-watch chain) behind a desk holding an open
## two-page ledger with ruled lines and a red rubber stamp. Slate-blue uniform
## so the silhouette reads against the brown/gold room. ~140 px tall overall.
func _build_claim_recorder(parent: Node2D) -> void:
	var coat := Color(0.13, 0.17, 0.26)
	var coat_light := Color(0.19, 0.25, 0.36)
	var skin := Color(0.88, 0.74, 0.60)
	var visor := Color(0.18, 0.62, 0.38)
	var wood := Color(0.20, 0.13, 0.07)
	var wood_top := Color(0.32, 0.22, 0.11)
	var paper := Color(0.90, 0.87, 0.74)
	var rule := Color(0.42, 0.46, 0.52)
	var stamp_red := Color(0.76, 0.18, 0.15)
	var watch_gold := Color(0.88, 0.74, 0.32)

	# --- clerk torso, shoulders, neck, head (drawn first, behind the desk) ---
	_add_poly(parent, "ClerkTorso", PackedVector2Array([
		Vector2(-30.0, -28.0), Vector2(30.0, -28.0),
		Vector2(28.0, -110.0), Vector2(-28.0, -110.0),
	]), coat)
	_add_poly(parent, "ClerkCollar", PackedVector2Array([
		Vector2(-28.0, -110.0), Vector2(28.0, -110.0),
		Vector2(19.0, -98.0), Vector2(-19.0, -98.0),
	]), coat_light)
	_add_poly(parent, "ClerkNeck", PackedVector2Array([
		Vector2(-6.0, -108.0), Vector2(6.0, -108.0),
		Vector2(6.0, -118.0), Vector2(-6.0, -118.0),
	]), skin.darkened(0.14))
	_add_poly(parent, "ClerkHead", _circle_polygon(15.0, 20), skin, Vector2(0.0, -124.0))
	# Green eyeshade / visor across the brow.
	_add_poly(parent, "ClerkVisor", PackedVector2Array([
		Vector2(-19.0, -136.0), Vector2(19.0, -136.0),
		Vector2(19.0, -126.0), Vector2(14.0, -122.0),
		Vector2(-14.0, -122.0), Vector2(-19.0, -126.0),
	]), visor)
	# Two dot eyes under the shade.
	_add_poly(parent, "ClerkEyeL", _circle_polygon(2.4, 10), Color(0.08, 0.08, 0.10), Vector2(-5.5, -116.0))
	_add_poly(parent, "ClerkEyeR", _circle_polygon(2.4, 10), Color(0.08, 0.08, 0.10), Vector2(5.5, -116.0))

	# --- desk in front ---
	_add_poly(parent, "DeskFront", PackedVector2Array([
		Vector2(-84.0, 0.0), Vector2(84.0, 0.0),
		Vector2(84.0, -38.0), Vector2(-84.0, -38.0),
	]), wood)
	_add_poly(parent, "DeskTop", PackedVector2Array([
		Vector2(-88.0, -38.0), Vector2(88.0, -38.0),
		Vector2(88.0, -46.0), Vector2(-88.0, -46.0),
	]), wood_top)
	_add_line(parent, "DeskDrawer", Vector2(-80.0, -20.0), Vector2(80.0, -20.0), wood.lightened(0.18), 2.0)

	# --- sleeves reaching to the ledger, with arm garters ---
	_add_poly(parent, "SleeveL", PackedVector2Array([
		Vector2(-16.0, -106.0), Vector2(-30.0, -106.0),
		Vector2(-46.0, -46.0), Vector2(-32.0, -46.0),
	]), coat_light)
	_add_poly(parent, "SleeveR", PackedVector2Array([
		Vector2(16.0, -106.0), Vector2(30.0, -106.0),
		Vector2(46.0, -46.0), Vector2(32.0, -46.0),
	]), coat_light)
	_add_poly(parent, "GarterL", PackedVector2Array([
		Vector2(-35.0, -90.0), Vector2(-22.0, -88.0),
		Vector2(-20.0, -81.0), Vector2(-33.0, -83.0),
	]), visor.darkened(0.12))
	_add_poly(parent, "GarterR", PackedVector2Array([
		Vector2(35.0, -90.0), Vector2(22.0, -88.0),
		Vector2(20.0, -81.0), Vector2(33.0, -83.0),
	]), visor.darkened(0.12))
	_add_poly(parent, "HandL", _circle_polygon(5.0, 12), skin, Vector2(-42.0, -52.0))
	_add_poly(parent, "HandR", _circle_polygon(5.0, 12), skin, Vector2(42.0, -52.0))

	# --- open ledger on the desk, two pages with ruled lines ---
	_add_poly(parent, "LedgerL", PackedVector2Array([
		Vector2(-36.0, -46.0), Vector2(-3.0, -46.0),
		Vector2(-3.0, -76.0), Vector2(-36.0, -76.0),
	]), paper)
	_add_poly(parent, "LedgerR", PackedVector2Array([
		Vector2(3.0, -46.0), Vector2(36.0, -46.0),
		Vector2(36.0, -76.0), Vector2(3.0, -76.0),
	]), paper.darkened(0.08))
	_add_poly(parent, "LedgerSpine", PackedVector2Array([
		Vector2(-3.0, -46.0), Vector2(3.0, -46.0),
		Vector2(3.0, -76.0), Vector2(-3.0, -76.0),
	]), Color(0.30, 0.25, 0.18))
	for i in range(3):
		var ly: float = -54.0 - float(i) * 7.0
		_add_line(parent, "LedgerRuleL%d" % i, Vector2(-30.0, ly), Vector2(-8.0, ly), rule, 2.0)
		_add_line(parent, "LedgerRuleR%d" % i, Vector2(8.0, ly), Vector2(30.0, ly), rule, 2.0)

	# --- red rubber stamp on the desk ---
	_add_poly(parent, "StampBody", PackedVector2Array([
		Vector2(52.0, -46.0), Vector2(68.0, -46.0),
		Vector2(68.0, -58.0), Vector2(52.0, -58.0),
	]), stamp_red)
	_add_poly(parent, "StampHandle", PackedVector2Array([
		Vector2(56.0, -58.0), Vector2(64.0, -58.0),
		Vector2(64.0, -72.0), Vector2(56.0, -72.0),
	]), Color(0.24, 0.16, 0.10))

	# --- vest pocket-watch chain ---
	_add_line(parent, "WatchChain", Vector2(-10.0, -100.0), Vector2(8.0, -92.0), watch_gold, 2.0)
	_add_line(parent, "WatchChainTail", Vector2(8.0, -92.0), Vector2(14.0, -84.0), watch_gold, 2.0)
	_add_poly(parent, "PocketWatch", _circle_polygon(4.5, 12), watch_gold, Vector2(15.0, -80.0))
	_add_poly(parent, "PocketWatchFace", _circle_polygon(2.6, 10), Color(0.95, 0.93, 0.82), Vector2(15.0, -80.0))


func _add_poly(parent: Node2D, node_name: String, points: PackedVector2Array, color: Color, offset: Vector2 = Vector2.ZERO) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.name = node_name
	poly.polygon = points
	poly.color = color
	poly.position = offset
	parent.add_child(poly)
	return poly


func _add_line(parent: Node2D, node_name: String, from: Vector2, to: Vector2, color: Color, width: float = 2.0) -> Line2D:
	var line := Line2D.new()
	line.name = node_name
	line.points = PackedVector2Array([from, to])
	line.default_color = color
	line.width = width
	parent.add_child(line)
	return line


func _circle_polygon(radius: float, segments: int = 20) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle: float = TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


# ---- Player -----------------------------------------------------------------

## The room is one screen wide, so the player's own camera is clamped to the
## room rectangle and left at 1:1 zoom. No extra Camera2D is created here.
func _build_player() -> void:
	if not ResourceLoader.exists(PLAYER_SCENE):
		push_error("StudyRoom: player scene missing: %s" % PLAYER_SCENE)
		return
	var packed: PackedScene = load(PLAYER_SCENE)
	if packed == null:
		push_error("StudyRoom: could not load %s" % PLAYER_SCENE)
		return
	var player: Node2D = packed.instantiate()
	player.name = "Player"
	# Diamonds: spawn left of the divider so the Assay Trio (700..860) is never
	# drawn over the player at load. Other rooms keep the shaft-base spawn.
	var spawn_x: float = DIAMONDS_SPAWN_X if protocol == "diamonds" else DIVIDER_X
	player.position = Vector2(spawn_x, 560.0)
	player.add_to_group("player")
	# Explicitly pausable: StudyRoom itself processes always so it can keep
	# handling overlay input, and PROCESS_MODE_INHERIT would drag the player
	# along with it.
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)

	var camera: Camera2D = _find_camera(player)
	if camera != null:
		camera.limit_left = 0
		camera.limit_top = 0
		camera.limit_right = int(ROOM_W)
		camera.limit_bottom = int(ROOM_H)
		camera.zoom = Vector2.ONE


func _find_camera(root: Node) -> Camera2D:
	if root is Camera2D:
		return root as Camera2D
	for child in root.get_children():
		var found: Camera2D = _find_camera(child)
		if found != null:
			return found
	return null


# ---- UI ---------------------------------------------------------------------

func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UI"
	_ui_layer.layer = 20
	# ALWAYS so an overlay keeps working while get_tree().paused is true.
	_ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui_layer)

	_overlay_root = Control.new()
	_overlay_root.name = "OverlayRoot"
	_overlay_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay_root.visible = false
	_ui_layer.add_child(_overlay_root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	_overlay_root.add_child(dim)

	_overlay_panel = Panel.new()
	_overlay_panel.name = "Panel"
	_overlay_panel.position = Vector2(260.0, 100.0)
	_overlay_panel.size = Vector2(760.0, 520.0)
	_overlay_panel.add_theme_stylebox_override("panel", _panel_style())
	_overlay_root.add_child(_overlay_panel)

	_overlay_box = VBoxContainer.new()
	_overlay_box.name = "Box"
	_overlay_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_box.offset_left = 28.0
	_overlay_box.offset_top = 28.0
	_overlay_box.offset_right = -28.0
	_overlay_box.offset_bottom = -28.0
	_overlay_box.add_theme_constant_override("separation", 14)
	_overlay_panel.add_child(_overlay_box)

	# Counts the minimum watch time with an always-processing timer.
	_watch_timer = Timer.new()
	_watch_timer.name = "VideoWatchTimer"
	_watch_timer.one_shot = true
	_watch_timer.wait_time = SignalsScript.VIDEO_MIN_WATCH_SEC
	_watch_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_watch_timer.timeout.connect(_on_watch_timeout)
	_ui_layer.add_child(_watch_timer)


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.06, 0.96)
	sb.border_color = Color(_glow.r, _glow.g, _glow.b, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(0.0)
	sb.shadow_color = Color(_glow.r, _glow.g, _glow.b, 0.18)
	sb.shadow_size = 10
	return sb


func _button_style(hovered: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(_glow.r, _glow.g, _glow.b, 0.18 if hovered else 0.08)
	sb.border_color = Color(_glow.r, _glow.g, _glow.b, 1.0 if hovered else 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10.0)
	return sb


func _backing_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(6.0)
	return sb


## Opens the shared overlay shell: wipes previous content, shows the panel and
## pauses the tree (the player must stop while reading).
func _open_overlay() -> void:
	_clear_overlay()
	_overlay_open = true
	_overlay_root.visible = true
	get_tree().paused = true


func _clear_overlay() -> void:
	for child in _overlay_box.get_children():
		_overlay_box.remove_child(child)
		child.queue_free()
	_primary_action = Callable()
	_quiz_active = false
	_done_button = null
	if _watch_timer != null:
		_watch_timer.stop()


## Closes the overlay shell and unpauses. The session move back to STUDY_CHOICE
## is done by the callers that changed it.
func _close_overlay_ui() -> void:
	_clear_overlay()
	_overlay_open = false
	_overlay_root.visible = false
	get_tree().paused = false


func _add_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(704.0, 0.0)
	_overlay_box.add_child(label)
	return label


func _add_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0.0, 46.0)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color(0.92, 0.96, 0.96))
	button.add_theme_stylebox_override("normal", _button_style(false))
	button.add_theme_stylebox_override("hover", _button_style(true))
	button.add_theme_stylebox_override("pressed", _button_style(true))
	if action.is_valid():
		button.pressed.connect(action)
	_overlay_box.add_child(button)
	return button


# ---- Overlay: whitepaper ----------------------------------------------------

## LEFT plate overlay. STUDY_CHOICE -> WHITEPAPER, then back on EXIT.
func open_whitepaper() -> void:
	if _overlay_open or session == null:
		return
	if session.state == SignalsScript.State.STUDY_CHOICE:
		session.choose_study("whitepaper")
	_open_overlay()
	var plate: Dictionary = _plate()
	_add_label(_s("paper_label", "Read the Whitepaper"), 26, _glow)
	_add_label(_s2(plate, "title"), 22, Color(0.95, 0.98, 0.98))
	_add_label(_s2(plate, "subtitle"), 20, Color(0.78, 0.84, 0.84))
	_add_label(_s2(plate, "design_notes"), 18, Color(0.66, 0.72, 0.72))
	_add_button("OPEN WHITEPAPER", _on_open_paper)
	_add_button("EXIT", close_overlay)


func _on_open_paper() -> void:
	# Opens a browser tab on web; the URL list is fixed and official.
	OS.shell_open(String(PAPER_URLS.get(protocol, "")))


## Closes any study overlay and walks the session back to STUDY_CHOICE.
func close_overlay() -> void:
	if session != null:
		if session.state == SignalsScript.State.WHITEPAPER or session.state == SignalsScript.State.VIDEO:
			session.transition(SignalsScript.State.STUDY_CHOICE)
	_close_overlay_ui()


# ---- Overlay: video ---------------------------------------------------------

## RIGHT shrine overlay. STUDY_CHOICE -> VIDEO, DONE gated on the minimum watch
## time so a video-only player can never be blocked out of the loop.
func open_video() -> void:
	if _overlay_open or session == null:
		return
	if session.state == SignalsScript.State.STUDY_CHOICE:
		session.choose_study("video")
	_open_overlay()
	_add_label(_s("video_label", "Watch the Video"), 26, _glow)
	_add_label(_s("video_wait_line"), 20, Color(0.85, 0.90, 0.90))
	_add_button("WATCH ON X", _on_open_video)
	_done_button = _add_button("DONE", close_overlay)
	_done_button.disabled = true
	if _watch_timer != null:
		_watch_timer.start(SignalsScript.VIDEO_MIN_WATCH_SEC)


func _on_open_video() -> void:
	OS.shell_open(String(VIDEO_URLS.get(protocol, "")))


func _on_watch_timeout() -> void:
	if _done_button != null and is_instance_valid(_done_button):
		_done_button.disabled = false


# ---- Overlay: examiner, quiz, result ----------------------------------------

## EXAMINER_INTRO: the three intro lines, one at a time, then the quiz intro.
func start_exam() -> void:
	if _overlay_open or session == null:
		return
	if bank == null:
		bank = QuizBankScript.load_bank(protocol)
	if session.state == SignalsScript.State.STUDY_CHOICE:
		session.transition(SignalsScript.State.EXAMINER_INTRO)
	_intro_index = 0
	_show_intro()


func _show_intro() -> void:
	_open_overlay()
	if bank == null:
		bank = QuizBankScript.load_bank(protocol)
	var intro: Array = []
	var raw: Variant = _data.get("examiner_intro", [])
	if typeof(raw) == TYPE_ARRAY:
		intro = raw
	if _intro_index < intro.size():
		_add_label(_s("examiner_name", "Examiner"), 26, _glow)
		_add_label(String(intro[_intro_index]), 22, Color(0.92, 0.95, 0.95))
		_add_label("%d / %d" % [_intro_index + 1, intro.size()], 16, Color(0.62, 0.68, 0.68))
		_primary_action = _on_intro_next
		_add_button("NEXT  [E]", _on_intro_next)
	else:
		_add_label(_s("examiner_name", "Examiner"), 26, _glow)
		_add_label(_s("quiz_intro"), 22, Color(0.92, 0.95, 0.95))
		_primary_action = _begin_quiz
		_add_button("BEGIN QUIZ  [E]", _begin_quiz)


func _on_intro_next() -> void:
	_intro_index += 1
	_show_intro()


func _begin_quiz() -> void:
	if session != null and session.state == SignalsScript.State.EXAMINER_INTRO:
		session.transition(SignalsScript.State.QUIZ)
	_q_index = 0
	_show_question()


func _show_question() -> void:
	_open_overlay()
	if bank == null:
		return
	var question: Dictionary = bank.question(_q_index)
	_add_label("Question %d / %d" % [_q_index + 1, SignalsScript.QUESTION_COUNT],
		18, Color(0.66, 0.74, 0.74))
	_add_label(String(question.get("prompt", "")), 24, Color(0.95, 0.98, 0.98))
	var options: Array = []
	var raw: Variant = question.get("options", [])
	if typeof(raw) == TYPE_ARRAY:
		options = raw
	for i in range(options.size()):
		_add_button("%d) %s" % [i + 1, String(options[i])], _on_option.bind(i))
	# Keys 1/2/3 are handled in _unhandled_input; E is not a valid answer.
	_primary_action = Callable()
	_quiz_active = true


func _on_option(index: int) -> void:
	if session == null:
		return
	_quiz_active = false
	session.answer(_q_index, index)
	_q_index += 1
	if _q_index >= SignalsScript.QUESTION_COUNT:
		_finish_quiz()
	else:
		_show_question()


func _finish_quiz() -> void:
	_quiz_active = false
	if session == null or bank == null:
		return
	session.grade(bank.answer_key())
	if session.state == SignalsScript.State.QUIZ:
		session.transition(SignalsScript.State.RESULT)
	_grant_once()
	_show_result()


## Completion — pass or proceed — earns scorecard eligibility exactly once.
func _grant_once() -> void:
	if _grant_recorded or session == null:
		return
	if not session.eligible_for_scorecard():
		return
	Grant.mark_eligible(session)
	_grant_recorded = true


func _show_result() -> void:
	_open_overlay()
	if session == null:
		return
	_add_label("Score: %d / %d" % [session.score_correct, SignalsScript.QUESTION_COUNT],
		30, _glow)
	_add_label(_s("pass_line" if session.passed else "fail_line"), 22, Color(0.94, 0.96, 0.96))
	if not session.passed and not session.proceeded_without_pass:
		_add_button(_s("retry_label", "Retry the Quiz"), _on_retry)
		_add_button(_s("proceed_label", "Keep Score and Go"), _on_proceed)
	else:
		_add_label(_s("ascent_line"), 20, Color(0.80, 0.88, 0.88))
		_add_button("CLIMB BACK", _on_climb_back)


func _on_retry() -> void:
	if session == null:
		return
	if session.state == SignalsScript.State.RESULT:
		session.transition(SignalsScript.State.QUIZ)
	_q_index = 0
	_show_question()


func _on_proceed() -> void:
	if session == null:
		return
	session.proceed_without_pass()
	_grant_once()
	_show_result()


func _on_climb_back() -> void:
	_close_overlay_ui()
	Travel.ascend()


# ---- Input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _overlay_open:
		_handle_overlay_input(event)
		return
	if not _player_in_ascent:
		return
	if not InputMap.has_action("interact"):
		return
	if event.is_action_pressed("interact"):
		# Leaving is allowed at any point in the loop.
		Travel.ascend()


func _handle_overlay_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _primary_action.is_valid():
		_primary_action.call()
		return
	if _quiz_active and event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		match key.keycode:
			KEY_1:
				_on_option(0)
			KEY_2:
				_on_option(1)
			KEY_3:
				_on_option(2)
