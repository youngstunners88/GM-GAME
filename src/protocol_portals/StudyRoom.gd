extends Node2D
## Protocol Portals tour strip (founder tour rebuild, 2026-09-25).
##
## A walkable strip, several screens wide, one screen tall. Far left: the
## arrival shaft; the player is shown climbing down its last rungs, and
## climbing UP it (same enter/exit_ladder_zone handshake as the level ladder)
## to the top trigger calls PortalTravel.ascend(). Along the floor: named
## stops (TourStop) from portal_copy.json, then the whitepaper plate (jump on
## it), the video shrine, and the examiner's desk LAST, where the quiz starts.
## The companion (leader still) follows the player and speaks at each stop.
##
## Session loop is unchanged:
##   STUDY_CHOICE -> WHITEPAPER | VIDEO -> STUDY_CHOICE
##   STUDY_CHOICE -> EXAMINER_INTRO -> QUIZ -> RESULT -> QUIZ | ASCENT
## Never mints, never networks.

const SignalsScript := preload("res://src/protocol_portals/PortalSignals.gd")
const PortalSessionScript := preload("res://src/protocol_portals/PortalSession.gd")
const QuizBankScript := preload("res://src/protocol_portals/QuizBank.gd")
const Travel := preload("res://src/protocol_portals/PortalTravel.gd")
const Grant := preload("res://src/protocol_portals/ScorecardGrant.gd")
const SmokePlateScript := preload("res://src/protocol_portals/SmokePlate.gd")
const WhitepaperJumpScript := preload("res://src/protocol_portals/WhitepaperJump.gd")
const VideoShrineScript := preload("res://src/protocol_portals/VideoShrine.gd")
const ExaminerScript := preload("res://src/protocol_portals/Examiner.gd")
const TourStopScript := preload("res://src/protocol_portals/TourStop.gd")
const CompanionScript := preload("res://src/protocol_portals/Companion.gd")

@export var protocol: String = "smoke"
@export var stage_id: int = 1

const ROOM_H: float = 720.0
const FLOOR_Y: float = 620.0
const PLAYER_SCENE: String = "res://src/player/player.tscn"
const COPY_PATH: String = "res://src/protocol_portals/data/portal_copy.json"

## Arrival / ascent shaft.
const SHAFT_X: float = 160.0
const SHAFT_TOP_Y: float = 90.0
const SHAFT_WIDTH: float = 64.0
const RUNG_SPACING: float = 20.0
const TOP_REACH: float = 40.0
const ARRIVAL_DROP: float = 200.0
const ARRIVAL_TIME: float = 0.9
const PLAYER_BOX: float = 32.0

## Stops.
const FIRST_STOP_X: float = 620.0
const STOP_SPACING: float = 560.0
const END_PAD: float = 480.0
const MIN_STRIP_W: float = 2560.0

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
const LEADER_TEXTURES: Dictionary = {
	"smoke": "res://src/assets/portals/companions/pauly_the_smokest.png",
	"diamonds": "res://src/assets/portals/companions/kane_the_blaze_mechanic.png",
	"gold": "res://src/assets/portals/companions/rich_the_claim_recorder.png",
}

# ---- State ------------------------------------------------------------------

var session: PortalSessionScript = null
var bank: QuizBankScript = null
## Width of the walkable strip in px (always >= MIN_STRIP_W).
var strip_width: float = MIN_STRIP_W

var _copy: Dictionary = {}
var _data: Dictionary = {}
var _glow: Color = Color(0.35, 1.0, 0.45)
var _stop_plan: Array[Dictionary] = []
var _stop_lines: Dictionary = {}

var _player: Node2D = null
var _companion: Node2D = null
var _shaft: TourShaft = null
var _player_in_shaft: bool = false
var _arriving: bool = false
var _ascending: bool = false

var _ui_layer: CanvasLayer = null
var _overlay_root: Control = null
var _overlay_panel: Panel = null
var _overlay_box: VBoxContainer = null
var _overlay_open: bool = false
var _watch_timer: Timer = null
var _done_button: Button = null
var _primary_action: Callable = Callable()
var _quiz_active: bool = false
var _intro_index: int = 0
var _q_index: int = 0
var _grant_recorded: bool = false


## The tour shaft handed to player.enter_ladder_zone(). Its global_position is
## the shaft top, like PortalLadder; it exposes the three methods player.gd
## calls back into on its active ladder.
class TourShaft extends Node2D:
	var floor_y: float = 620.0

	func top_y() -> float:
		return global_position.y

	func bottom_y() -> float:
		return floor_y

	func top_exit_position() -> Vector2:
		return Vector2(global_position.x - 16.0, global_position.y - 34.0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_glow = _glow_color()
	_copy = _load_copy()
	var raw: Variant = _copy.get(protocol, {})
	if typeof(raw) == TYPE_DICTIONARY:
		_data = raw
	_plan_stops()
	_build_backdrop()
	_build_floor_and_walls()
	_build_shaft()
	_build_stops()
	_build_player()
	_build_companion()
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


func is_overlay_open() -> bool:
	return _overlay_open


func get_strip_width() -> float:
	return strip_width


# ---- Colours ----------------------------------------------------------------

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


func _backing_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(6.0)
	return sb


func _make_square_texture(side: int) -> ImageTexture:
	var img: Image = Image.create(side, side, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 1.0, 1.0, 1.0))
	return ImageTexture.create_from_image(img)


# ---- Stop plan --------------------------------------------------------------

## Reads the "stops" list, guarantees paper + video stops exist and puts the
## examiner ("exam") stop LAST. Also sizes the strip.
func _plan_stops() -> void:
	_stop_plan.clear()
	var list: Array = []
	var raw: Variant = _data.get("stops", [])
	if typeof(raw) == TYPE_ARRAY:
		list = raw
	var exam: Dictionary = {}
	var has_paper: bool = false
	var has_video: bool = false
	for item in list:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = item
		var id: String = _s2(d, "id")
		if id.is_empty():
			continue
		if id == "exam":
			exam = d
			continue
		if id == "paper":
			has_paper = true
		elif id == "video":
			has_video = true
		_stop_plan.append(d)
	if not has_paper:
		_stop_plan.append({"id": "paper", "name": _s("paper_label", "Read the whitepaper"),
			"line": "The official whitepaper. Jump on the plate to read it."})
	if not has_video:
		_stop_plan.append({"id": "video", "name": _s("video_label", "Watch the video"),
			"line": "The official X video. Stand at the shrine, press E."})
	if exam.is_empty():
		exam = {"id": "exam", "name": _s("examiner_name", "Examiner"),
			"line": _s("quiz_intro")}
	_stop_plan.append(exam)
	var last_x: float = FIRST_STOP_X + STOP_SPACING * float(_stop_plan.size() - 1)
	strip_width = maxf(MIN_STRIP_W, last_x + END_PAD)


# ---- Backdrop ---------------------------------------------------------------

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
	bg.size = Vector2(strip_width, ROOM_H)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)

	# Distant pillars so the camera pan reads as movement.
	var x: float = 360.0
	var i: int = 0
	while x < strip_width:
		var pillar := ColorRect.new()
		pillar.name = "Pillar%d" % i
		pillar.position = Vector2(x, 150.0)
		pillar.size = Vector2(44.0, FLOOR_Y - 150.0)
		pillar.color = Color(_slab_color().r, _slab_color().g, _slab_color().b, 0.8).lightened(0.05)
		layer.add_child(pillar)
		var trim := ColorRect.new()
		trim.name = "PillarTrim%d" % i
		trim.position = Vector2(x, 150.0)
		trim.size = Vector2(44.0, 3.0)
		trim.color = Color(_glow.r, _glow.g, _glow.b, 0.25)
		layer.add_child(trim)
		x += 420.0
		i += 1

	var ceiling := ColorRect.new()
	ceiling.name = "Ceiling"
	ceiling.position = Vector2(0.0, 0.0)
	ceiling.size = Vector2(strip_width, 40.0)
	ceiling.color = _slab_color()
	layer.add_child(ceiling)

	var motes := CPUParticles2D.new()
	motes.name = "Motes"
	motes.texture = _make_square_texture(2)
	motes.amount = 60
	motes.lifetime = 9.0
	motes.local_coords = false
	motes.position = Vector2(strip_width * 0.5, ROOM_H * 0.5)
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(strip_width * 0.5, ROOM_H * 0.4)
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

	# Screen-space vignette + room title.
	var vig_layer := CanvasLayer.new()
	vig_layer.name = "VignetteLayer"
	vig_layer.layer = 5
	add_child(vig_layer)
	var vig_grad := Gradient.new()
	vig_grad.set_color(0, Color(0.0, 0.0, 0.0, 0.0))
	vig_grad.set_color(1, Color(0.0, 0.0, 0.0, 0.55))
	var vig_tex := GradientTexture2D.new()
	vig_tex.gradient = vig_grad
	vig_tex.fill = GradientTexture2D.FILL_RADIAL
	vig_tex.fill_from = Vector2(0.5, 0.5)
	vig_tex.fill_to = Vector2(0.5, 0.0)
	vig_tex.width = 256
	vig_tex.height = 144
	var vignette := TextureRect.new()
	vignette.name = "Vignette"
	vignette.texture = vig_tex
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vig_layer.add_child(vignette)

	var title := Label.new()
	title.name = "RoomTitle"
	title.text = _s("room_title", "Study")
	title.position = Vector2(440.0, 48.0)
	title.size = Vector2(400.0, 36.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", _glow)
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_stylebox_override("normal", _backing_style())
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vig_layer.add_child(title)


# ---- Floor ------------------------------------------------------------------

func _build_floor_and_walls() -> void:
	var slab := ColorRect.new()
	slab.name = "FloorSlab"
	slab.position = Vector2(0.0, FLOOR_Y)
	slab.size = Vector2(strip_width, ROOM_H - FLOOR_Y)
	slab.color = _slab_color()
	slab.z_index = -50
	add_child(slab)

	var trim := ColorRect.new()
	trim.name = "FloorTrim"
	trim.position = Vector2(0.0, FLOOR_Y - 3.0)
	trim.size = Vector2(strip_width, 3.0)
	trim.color = Color(_glow.r, _glow.g, _glow.b, 0.55)
	trim.z_index = -49
	add_child(trim)

	var floor_body := StaticBody2D.new()
	floor_body.name = "Floor"
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	floor_body.position = Vector2(strip_width * 0.5, FLOOR_Y + 20.0)
	var floor_shape := CollisionShape2D.new()
	floor_shape.name = "CollisionShape2D"
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(strip_width, 40.0)
	floor_shape.shape = floor_rect
	floor_body.add_child(floor_shape)
	add_child(floor_body)

	var walls := StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = 1
	walls.collision_mask = 0
	var wall_xs: Array[float] = [-20.0, strip_width + 20.0]
	for i in range(wall_xs.size()):
		var wall_shape := CollisionShape2D.new()
		wall_shape.name = "WallShape%d" % i
		var wall_rect := RectangleShape2D.new()
		wall_rect.size = Vector2(40.0, ROOM_H + 400.0)
		wall_shape.shape = wall_rect
		wall_shape.position = Vector2(wall_xs[i], ROOM_H * 0.5)
		walls.add_child(wall_shape)
	add_child(walls)


# ---- Arrival / ascent shaft -------------------------------------------------

## Rails from the ceiling to the floor at SHAFT_X. ClimbZone uses the player's
## own climb (move_up / move_down); the TopTrigger near the top calls ascend.
func _build_shaft() -> void:
	_shaft = TourShaft.new()
	_shaft.name = "AscentShaft"
	_shaft.floor_y = FLOOR_Y
	_shaft.position = Vector2(SHAFT_X, SHAFT_TOP_Y)
	_shaft.z_index = -20
	add_child(_shaft)

	var depth: float = FLOOR_Y - SHAFT_TOP_Y
	var top_local: float = -SHAFT_TOP_Y
	var full: float = FLOOR_Y

	var hole := ColorRect.new()
	hole.name = "ShaftHole"
	hole.position = Vector2(-SHAFT_WIDTH * 0.5, top_local)
	hole.size = Vector2(SHAFT_WIDTH, full)
	hole.color = Color(0.02, 0.03, 0.04, 0.9)
	_shaft.add_child(hole)

	var rail_color: Color = Color(_glow.r, _glow.g, _glow.b, 0.9).darkened(0.2)
	var outline_color: Color = Color(0.02, 0.02, 0.03, 0.95)
	var rail_xs: Array[float] = [-24.0, 19.0]
	for i in range(rail_xs.size()):
		var ro := ColorRect.new()
		ro.name = "RailOutline%d" % i
		ro.position = Vector2(rail_xs[i] - 2.0, top_local)
		ro.size = Vector2(9.0, full)
		ro.color = outline_color
		_shaft.add_child(ro)
		var r := ColorRect.new()
		r.name = "Rail%d" % i
		r.position = Vector2(rail_xs[i], top_local)
		r.size = Vector2(5.0, full)
		r.color = rail_color
		_shaft.add_child(r)

	var y: float = top_local + 10.0
	var n: int = 0
	while y < depth - 4.0:
		var rung := ColorRect.new()
		rung.name = "Rung%d" % n
		rung.position = Vector2(-24.0, y)
		rung.size = Vector2(48.0, 4.0)
		rung.color = rail_color
		_shaft.add_child(rung)
		y += RUNG_SPACING
		n += 1

	var label := Label.new()
	label.name = "AscentLabel"
	label.text = "CLIMB UP"
	label.size = Vector2(160.0, 34.0)
	label.position = Vector2(46.0, 60.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", _glow)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_stylebox_override("normal", _backing_style())
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shaft.add_child(label)

	var hint := Label.new()
	hint.name = "AscentHint"
	hint.text = "HOLD UP IN THE SHAFT"
	hint.size = Vector2(220.0, 26.0)
	hint.position = Vector2(46.0, 100.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.9, 0.95, 0.95))
	hint.add_theme_stylebox_override("normal", _backing_style())
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shaft.add_child(hint)

	var zone := Area2D.new()
	zone.name = "ClimbZone"
	zone.collision_layer = 0
	zone.collision_mask = 2
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40.0, depth + 30.0)
	shape.shape = rect
	shape.position = Vector2(0.0, (depth + 30.0) * 0.5 - 20.0)
	zone.add_child(shape)
	zone.body_entered.connect(_on_shaft_body_entered)
	zone.body_exited.connect(_on_shaft_body_exited)
	_shaft.add_child(zone)

	var top := Area2D.new()
	top.name = "TopTrigger"
	top.collision_layer = 0
	top.collision_mask = 2
	var tshape := CollisionShape2D.new()
	tshape.name = "CollisionShape2D"
	var trect := RectangleShape2D.new()
	trect.size = Vector2(SHAFT_WIDTH, 60.0)
	tshape.shape = trect
	tshape.position = Vector2(0.0, 20.0)
	top.add_child(tshape)
	top.body_entered.connect(_on_top_body_entered)
	_shaft.add_child(top)


func _on_shaft_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_shaft = true
	if body.has_method("enter_ladder_zone"):
		body.call("enter_ladder_zone", _shaft)


func _on_shaft_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_shaft = false
	if body.has_method("exit_ladder_zone"):
		body.call("exit_ladder_zone", _shaft)


func _on_top_body_entered(body: Node2D) -> void:
	if body == null or body != _player or _arriving:
		return
	if bool(body.get("_climbing")):
		_do_ascend()


func _physics_process(_delta: float) -> void:
	if _ascending or _arriving or _player == null or not is_instance_valid(_player):
		return
	if get_tree().paused or not _player_in_shaft:
		return
	if bool(_player.get("_climbing")) and _player.global_position.y <= SHAFT_TOP_Y + TOP_REACH:
		_do_ascend()


## Top of the shaft reached: freeze the player and go home.
func _do_ascend() -> void:
	if _ascending:
		return
	_ascending = true
	if Travel.return_scene.is_empty():
		push_warning("StudyRoom: no return scene (room loaded directly); staying.")
		_ascending = false
		if _player != null:
			_player.global_position = Vector2(SHAFT_X - PLAYER_BOX * 0.5, FLOOR_Y - PLAYER_BOX - 1.0)
		return
	if _player != null and is_instance_valid(_player):
		if _player is CharacterBody2D:
			(_player as CharacterBody2D).velocity = Vector2.ZERO
		_player.set_physics_process(false)
	Travel.ascend()


# ---- Stops ------------------------------------------------------------------

func _build_stops() -> void:
	for i in range(_stop_plan.size()):
		var entry: Dictionary = _stop_plan[i]
		var x: float = FIRST_STOP_X + STOP_SPACING * float(i)
		_build_stop(entry, x)


func _build_stop(entry: Dictionary, x: float) -> void:
	var id: String = _s2(entry, "id")
	var line: String = _s2(entry, "line")
	_stop_lines[id] = line
	var label_y: float = 220.0
	var pedestal: bool = true
	match id:
		"paper":
			label_y = 380.0
			pedestal = false
		"video":
			label_y = 280.0
			pedestal = false
	var stop: Node2D = TourStopScript.new()
	stop.name = "Stop_%s" % id
	stop.position = Vector2(x, FLOOR_Y)
	stop.call("setup", id, _s2(entry, "name", id), line, _glow, pedestal, label_y)
	add_child(stop)
	stop.connect("reached", _on_stop_reached)
	match id:
		"paper":
			_dress_paper(stop)
		"video":
			_dress_video(stop)
		"exam":
			_dress_exam(stop)


func _on_stop_reached(stop_id: String) -> void:
	if _companion == null or _overlay_open:
		return
	var line: String = String(_stop_lines.get(stop_id, ""))
	_companion.call("say", line)


## Jump-on plate: a low solid slab with the WhitepaperJump zone on top of it.
func _dress_paper(stop: Node2D) -> void:
	var slab_w: float = 150.0
	var slab_h: float = 30.0
	var vis := ColorRect.new()
	vis.name = "PlateSlab"
	vis.position = Vector2(-slab_w * 0.5, -slab_h)
	vis.size = Vector2(slab_w, slab_h)
	vis.color = _slab_color().lightened(0.12)
	stop.add_child(vis)
	var trim := ColorRect.new()
	trim.name = "PlateSlabTrim"
	trim.position = Vector2(-slab_w * 0.5, -slab_h)
	trim.size = Vector2(slab_w, 3.0)
	trim.color = Color(_glow.r, _glow.g, _glow.b, 0.9)
	stop.add_child(trim)

	var body := StaticBody2D.new()
	body.name = "PlateStep"
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector2(0.0, -slab_h * 0.5)
	var bshape := CollisionShape2D.new()
	bshape.name = "CollisionShape2D"
	var brect := RectangleShape2D.new()
	brect.size = Vector2(slab_w, slab_h)
	bshape.shape = brect
	body.add_child(bshape)
	stop.add_child(body)

	if protocol == "smoke":
		var plate := Node2D.new()
		plate.name = "PlateArt"
		plate.set_script(SmokePlateScript)
		plate.position = Vector2(0.0, -220.0)
		plate.scale = Vector2(0.4, 0.4)
		var spec: Variant = _plate().get("draw_spec", {})
		if typeof(spec) == TYPE_DICTIONARY:
			plate.set("draw_spec", spec)
		stop.add_child(plate)
	else:
		stop.add_child(_build_plate_art(
			"res://src/assets/portals/plate_%s_whitepaper.jpg" % protocol,
			Vector2(0.0, -220.0), 240.0))

	var zone := Area2D.new()
	zone.set_script(WhitepaperJumpScript)
	zone.name = "WhitepaperJumpZone"
	zone.collision_layer = 0
	zone.collision_mask = 2
	zone.position = Vector2(0.0, -slab_h - 25.0)
	zone.set("room", self)
	var zshape := CollisionShape2D.new()
	zshape.name = "CollisionShape2D"
	var zrect := RectangleShape2D.new()
	zrect.size = Vector2(slab_w, 50.0)
	zshape.shape = zrect
	zone.add_child(zshape)
	stop.add_child(zone)


func _build_plate_art(texture_path: String, centre: Vector2, target_width: float) -> Node2D:
	var holder := Node2D.new()
	holder.name = "PlateArt"
	holder.position = centre
	var art_size := Vector2(target_width, 160.0)
	var sprite: Sprite2D = null
	if ResourceLoader.exists(texture_path):
		var tex: Texture2D = load(texture_path)
		if tex != null and tex.get_width() > 0:
			sprite = Sprite2D.new()
			sprite.name = "PlateTexture"
			sprite.texture = tex
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])
	holder.add_child(frame)
	return holder


## Video shrine: arch, screen, drawn play triangle, VideoShrine zone.
func _dress_video(stop: Node2D) -> void:
	var arch := Polygon2D.new()
	arch.name = "Arch"
	arch.polygon = PackedVector2Array([
		Vector2(-80.0, 0.0), Vector2(80.0, 0.0), Vector2(80.0, -140.0),
		Vector2(0.0, -200.0), Vector2(-80.0, -140.0),
	])
	arch.color = _slab_color().lightened(0.06)
	stop.add_child(arch)
	var screen_pts := PackedVector2Array([
		Vector2(-90.0, -150.0), Vector2(90.0, -150.0),
		Vector2(90.0, -30.0), Vector2(-90.0, -30.0),
	])
	var screen := Polygon2D.new()
	screen.name = "Screen"
	screen.polygon = screen_pts
	screen.color = Color(0.02, 0.03, 0.05, 0.95)
	stop.add_child(screen)
	var frame := Line2D.new()
	frame.name = "ScreenFrame"
	frame.width = 3.0
	frame.default_color = Color(_glow.r, _glow.g, _glow.b, 0.85)
	frame.closed = true
	frame.points = screen_pts
	stop.add_child(frame)
	var play := Polygon2D.new()
	play.name = "PlayTriangle"
	play.polygon = PackedVector2Array([
		Vector2(-16.0, -26.0), Vector2(-16.0, 26.0), Vector2(26.0, 0.0),
	])
	play.color = Color(_glow.r, _glow.g, _glow.b, 0.95)
	play.position = Vector2(0.0, -90.0)
	stop.add_child(play)

	var zone := Area2D.new()
	zone.set_script(VideoShrineScript)
	zone.name = "VideoShrineZone"
	zone.collision_layer = 0
	zone.collision_mask = 2
	zone.position = Vector2(0.0, -100.0)
	zone.set("room", self)
	var zshape := CollisionShape2D.new()
	zshape.name = "CollisionShape2D"
	var zrect := RectangleShape2D.new()
	zrect.size = Vector2(200.0, 200.0)
	zshape.shape = zrect
	zone.add_child(zshape)
	stop.add_child(zone)


## Examiner's desk / bench: the last stop, where the quiz starts.
func _dress_exam(stop: Node2D) -> void:
	var ledger := ColorRect.new()
	ledger.name = "Ledger"
	ledger.position = Vector2(-30.0, -108.0)
	ledger.size = Vector2(60.0, 10.0)
	ledger.color = Color(0.9, 0.87, 0.74)
	stop.add_child(ledger)

	var zone := Area2D.new()
	zone.set_script(ExaminerScript)
	zone.name = "ExaminerZone"
	zone.collision_layer = 0
	zone.collision_mask = 2
	zone.position = Vector2(0.0, -100.0)
	zone.set("room", self)
	zone.set("protocol", protocol)
	var zshape := CollisionShape2D.new()
	zshape.name = "CollisionShape2D"
	var zrect := RectangleShape2D.new()
	zrect.size = Vector2(180.0, 200.0)
	zshape.shape = zrect
	zone.add_child(zshape)
	stop.add_child(zone)


# ---- Player + companion -----------------------------------------------------

## Spawns the player on the last rungs of the shaft and slides him down to
## the floor, so the arrival reads as the end of the climb down.
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
	var land_y: float = FLOOR_Y - PLAYER_BOX - 1.0
	player.position = Vector2(SHAFT_X - PLAYER_BOX * 0.5, land_y - ARRIVAL_DROP)
	player.add_to_group("player")
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	_player = player

	var camera: Camera2D = _find_camera(player)
	if camera != null:
		camera.limit_left = 0
		camera.limit_top = 0
		camera.limit_right = int(strip_width)
		camera.limit_bottom = int(ROOM_H)
		camera.zoom = Vector2.ONE

	_arriving = true
	player.set_physics_process(false)
	var tween: Tween = create_tween()
	tween.tween_property(player, "position:y", land_y, ARRIVAL_TIME)
	tween.finished.connect(_on_arrival_done)


func _on_arrival_done() -> void:
	_arriving = false
	# FREEZE FIX (founder playtest 2026-09-25): player.gd returns early from
	# _physics_process unless StateMachine.is_playing(). LevelBase sets PLAYING on
	# load; this room is not a LevelBase, so the player never moved. Looked up at
	# runtime so the headless tests (no autoloads) still compile.
	var sm: Node = get_tree().root.get_node_or_null("StateMachine")
	if sm != null and not sm.call("is_playing"):
		sm.call("change_state", 1)  # StateMachine.State.PLAYING
	if _player != null and is_instance_valid(_player):
		if _player is CharacterBody2D:
			(_player as CharacterBody2D).velocity = Vector2.ZERO
		_player.set_physics_process(true)
	if _companion != null:
		var intro: Array = []
		var raw: Variant = _data.get("examiner_intro", [])
		if typeof(raw) == TYPE_ARRAY:
			intro = raw
		if intro.size() > 0:
			_companion.call("say", String(intro[0]))


func _find_camera(root: Node) -> Camera2D:
	if root is Camera2D:
		return root as Camera2D
	for child in root.get_children():
		var found: Camera2D = _find_camera(child)
		if found != null:
			return found
	return null


func _build_companion() -> void:
	var comp: Node2D = CompanionScript.new()
	comp.name = "Companion"
	comp.position = Vector2(SHAFT_X + 90.0, FLOOR_Y)
	comp.z_index = -1
	var tex_path: String = String(LEADER_TEXTURES.get(protocol, LEADER_TEXTURES["smoke"]))
	comp.call("setup", tex_path, _s("examiner_name", "Guide"), _glow, false)  # founder: Kane is ONE figure, no escorts
	comp.set("target", _player)
	comp.set("min_x", 60.0)
	comp.set("max_x", strip_width - 60.0)
	add_child(comp)
	_companion = comp


# ---- UI ---------------------------------------------------------------------

func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UI"
	_ui_layer.layer = 20
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
	_add_button("OPEN WHITEPAPER", _on_open_paper)
	_add_button("EXIT", close_overlay)


func _on_open_paper() -> void:
	OS.shell_open(String(PAPER_URLS.get(protocol, "")))


func close_overlay() -> void:
	if session != null:
		if session.state == SignalsScript.State.WHITEPAPER or session.state == SignalsScript.State.VIDEO:
			session.transition(SignalsScript.State.STUDY_CHOICE)
	_close_overlay_ui()


# ---- Overlay: video ---------------------------------------------------------

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
	_add_label(_s("examiner_name", "Examiner"), 26, _glow)
	if _intro_index < intro.size():
		_add_label(String(intro[_intro_index]), 22, Color(0.92, 0.95, 0.95))
		_add_label("%d / %d" % [_intro_index + 1, intro.size()], 16, Color(0.62, 0.68, 0.68))
		_primary_action = _on_intro_next
		_add_button("NEXT  [E]", _on_intro_next)
	else:
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
		_add_button("KEEP EXPLORING", _close_overlay_ui)


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

## Only overlay input lives here. Leaving the tour is the shaft climb.
func _unhandled_input(event: InputEvent) -> void:
	if _overlay_open:
		_handle_overlay_input(event)


func _handle_overlay_input(event: InputEvent) -> void:
	if InputMap.has_action("interact") and event.is_action_pressed("interact") and _primary_action.is_valid():
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
