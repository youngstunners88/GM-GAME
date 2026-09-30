extends Node2D
## Painted protocol maps. Props, approach zones and movement share authored
## ground coordinates; learning, study and quiz progression remain room-owned.

const SignalsScript := preload("res://src/protocol_portals/PortalSignals.gd")
const PortalSessionScript := preload("res://src/protocol_portals/PortalSession.gd")
const QuizBankScript := preload("res://src/protocol_portals/QuizBank.gd")
const Travel := preload("res://src/protocol_portals/PortalTravel.gd")
const Grant := preload("res://src/protocol_portals/ScorecardGrant.gd")
const TourStopScript := preload("res://src/protocol_portals/TourStop.gd")
const CompanionScript := preload("res://src/protocol_portals/Companion.gd")
const Layout := preload("res://src/protocol_portals/RoomLayout.gd")
const FixtureScript := preload("res://src/protocol_portals/RoomFixture.gd")

@export var protocol: String = "smoke"
@export var stage_id: int = 1

const ROOM_H: float = 1100.0
const FLOOR_Y: float = 900.0
const PLAYER_SCENE: String = "res://src/protocol_portals/PortalExplorer.tscn"
const COPY_PATH: String = "res://src/protocol_portals/data/portal_copy.json"

const ARRIVAL_TIME: float = 0.5

## Stops.
const FIRST_STOP_X: float = 620.0
const STOP_SPACING: float = 360.0
const END_PAD: float = 480.0
const MIN_STRIP_W: float = 2800.0

const MAP_POSITIONS: Dictionary = Layout.STOPS

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
## Several aspects per stop so a returning player hears something new, not a repeat.
var _stop_aspects: Dictionary = {}
var _stop_visits: Dictionary = {}
var _stop_current: Dictionary = {}
var _visited_learning_stops: Dictionary = {}
var _required_learning_stops: Array[String] = []
var _objective_label: Label = null

var _player: Node2D = null
var _companion: Node2D = null
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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_glow = _glow_color()
	_copy = _load_copy()
	var raw: Variant = _copy.get(protocol, {})
	if typeof(raw) == TYPE_DICTIONARY:
		_data = raw
	_plan_stops()
	_build_backdrop()
	_add_painted_map()
	_build_atmosphere()
	_build_floor_and_walls()
	_build_return_waystone()
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
			return Color(0.12, 0.18, 0.28)
		"gold":
			return Color(0.27, 0.21, 0.14)
		_:
			return Color(0.16, 0.22, 0.19)


func _bottom_color() -> Color:
	match protocol:
		"diamonds":
			return Color(0.07, 0.10, 0.16)
		"gold":
			return Color(0.14, 0.10, 0.07)
		_:
			return Color(0.08, 0.12, 0.10)


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
		if id != "paper" and id != "video":
			_required_learning_stops.append(id)
		if id == "paper":
			has_paper = true
		elif id == "video":
			has_video = true
		_stop_plan.append(d)
	if not has_paper:
		_stop_plan.append({"id": "paper", "name": _s("paper_label", "Read the whitepaper"),
			"line": "The official whitepaper. Approach the lectern and press E."})
	if not has_video:
		_stop_plan.append({"id": "video", "name": _s("video_label", "Watch the video"),
			"line": "The official X video. Stand at the shrine, press E."})
	if exam.is_empty():
		exam = {"id": "exam", "name": _s("examiner_name", "Examiner"),
			"line": _s("quiz_intro")}
	_stop_plan.append(exam)
	strip_width = MIN_STRIP_W


# ---- Backdrop ---------------------------------------------------------------

## Founder 2026-09-28: "expansive like Warcraft, walking on a mapped-out section".
## A painted overhead map (MuAPI Flux, Jev-picked, scripts/gen_portal_maps.py) is
## laid over the procedural backdrop inside the Backdrop layer, so stops, props,
## the companion and the player all still draw on top of it.
const PAINTED_MAPS: Dictionary = {
	"smoke": "res://src/assets/portals/maps/map_smoke.jpg",
	"diamonds": "res://src/assets/portals/maps/map_diamonds_courtyard.png",
	"gold": "res://src/assets/portals/maps/map_gold_square.png",
}

func _add_painted_map() -> void:
	var map := Sprite2D.new()
	map.name = "PaintedMap"
	map.texture = load(String(PAINTED_MAPS[protocol]))
	map.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	map.centered = false
	map.region_enabled = true
	# Explicit crop keeps every authored landmark coordinate stable.
	var source_scale := map.texture.get_size() / Vector2(2800, 1200)
	map.region_rect = Rect2(Vector2(0, 50) * source_scale, Vector2(strip_width, ROOM_H) * source_scale)
	map.scale = Vector2.ONE / source_scale
	get_node("Backdrop").add_child(map)


# ---- Atmosphere -------------------------------------------------------------

const HazeShader := preload("res://src/assets/shaders/portal_haze.gdshader")
static var _puff_tex: GradientTexture2D = null

func _puff_texture() -> GradientTexture2D:
	if _puff_tex == null:
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 0.85))
		grad.set_color(1, Color(1, 1, 1, 0.0))
		_puff_tex = GradientTexture2D.new()
		_puff_tex.gradient = grad
		_puff_tex.fill = GradientTexture2D.FILL_RADIAL
		_puff_tex.fill_from = Vector2(0.5, 0.5)
		_puff_tex.fill_to = Vector2(1.0, 0.5)
		_puff_tex.width = 96
		_puff_tex.height = 96
	return _puff_tex


## Founder 2026-09-29: "haze smoke appearing or blowing in the house or wherever".
## Two drifting haze layers (behind and in front of the props) plus particle wisps.
func _build_atmosphere() -> void:
	var cfg: Dictionary = Layout.ATMOSPHERE.get(protocol, {})
	if cfg.is_empty():
		return
	var tint: Color = cfg["haze"]
	_add_haze_layer("HazeFar", -90, tint, float(cfg["far"]), 3.0, Vector2(0.035, -0.006))
	_add_haze_layer("HazeNear", 3000, tint, float(cfg["near"]), 1.7, Vector2(-0.05, -0.010))
	for src in cfg["sources"]:
		_add_wisps(String(src["kind"]), src["pos"], tint)
	var accents: Array = cfg.get("accents", [])
	for i in accents.size():
		var acc: Dictionary = accents[i]
		match String(acc["kind"]):
			"glow": _add_accent_glow(i, acc)
			_: _add_accent_sparks(i, acc)


## Accents make what the painting ALREADY shows glow (founder on Diamonds: "the gate seems
## redundant as we see the entrance already, so lets just accentuate what's already
## there"): an additive bloom that breathes, sitting over the painting and under the props.
func _add_accent_glow(index: int, acc: Dictionary) -> void:
	var col: Color = acc["color"]
	var strength := float(acc["strength"])
	var glow := Sprite2D.new()
	glow.name = "AccentGlow_%d" % index
	glow.texture = _puff_texture()
	glow.position = acc["pos"]
	glow.scale = Vector2(acc["size"]) / 96.0
	glow.z_index = -80
	glow.modulate = Color(col.r, col.g, col.b, strength)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	add_child(glow)
	var half := float(acc.get("pulse", 3.0))
	var tween := create_tween().set_loops()
	tween.tween_interval(randf() * half)  # desynchronise the glows
	tween.tween_property(glow, "modulate:a", strength * 0.5, half).set_trans(Tween.TRANS_SINE)
	tween.tween_property(glow, "modulate:a", strength, half).set_trans(Tween.TRANS_SINE)


## Tiny additive motes: "rise" = embers lifting off a doorway/brazier, otherwise glints
## twinkling in place (sun catching a coin heap).
func _add_accent_sparks(index: int, acc: Dictionary) -> void:
	var col: Color = acc["color"]
	var p := CPUParticles2D.new()
	p.name = "AccentSparks_%d" % index
	p.position = acc["pos"]
	p.z_index = 1500
	p.texture = _puff_texture()
	p.local_coords = true  # the node never moves; global coords stray when the room opens
	p.amount = int(acc.get("amount", 10))
	p.randomness = 0.8
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = acc["extent"]
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(col.r, col.g, col.b, 0.0), Color(col.r, col.g, col.b, 0.9), Color(col.r, col.g, col.b, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	p.color_ramp = ramp
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	if String(acc["kind"]) == "rise":
		p.gravity = Vector2(4, -6)  # CPUParticles2D defaults to 98 px/s^2 of gravity: motes would fall
		p.lifetime = 3.2
		p.direction = Vector2(0.1, -1.0)
		p.spread = 22.0
		p.initial_velocity_min = 14.0
		p.initial_velocity_max = 34.0
		p.scale_amount_min = 0.05
		p.scale_amount_max = 0.11
	else:
		p.gravity = Vector2.ZERO
		p.lifetime = 1.8
		p.direction = Vector2(0, -1)
		p.spread = 180.0
		p.initial_velocity_min = 0.0
		p.initial_velocity_max = 3.0
		p.scale_amount_min = 0.07
		p.scale_amount_max = 0.16
	p.preprocess = p.lifetime
	p.emitting = true
	add_child(p)


func _add_haze_layer(node_name: String, z: int, tint: Color, density: float, scale_k: float, drift: Vector2) -> void:
	var rect := ColorRect.new()
	rect.name = node_name
	rect.position = Vector2.ZERO
	rect.size = Vector2(strip_width, ROOM_H)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.z_index = z
	var mat := ShaderMaterial.new()
	mat.shader = HazeShader
	mat.set_shader_parameter("haze_color", tint)
	mat.set_shader_parameter("density", density)
	mat.set_shader_parameter("scale", scale_k)
	mat.set_shader_parameter("aspect", strip_width / ROOM_H)
	mat.set_shader_parameter("drift", drift)
	rect.material = mat
	add_child(rect)


func _add_wisps(kind: String, pos: Vector2, tint: Color) -> void:
	var p := CPUParticles2D.new()
	p.name = "Wisps_%s" % kind
	p.position = pos
	p.z_index = 2000
	p.texture = _puff_texture()
	p.local_coords = false
	p.lifetime = 5.5
	p.preprocess = 5.5  # already drifting when the room opens
	p.randomness = 0.6
	p.angular_velocity_min = -12.0
	p.angular_velocity_max = 12.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(tint.r, tint.g, tint.b, 0.0), Color(tint.r, tint.g, tint.b, 0.30), Color(tint.r, tint.g, tint.b, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	p.color_ramp = ramp
	match kind:
		"door":  # the open lounge doorway breathing smoke out onto the plaza
			p.amount = 14
			p.emission_rect_extents = Vector2(120, 8)
			p.direction = Vector2(0.15, 1.0)
			p.spread = 32.0
			p.initial_velocity_min = 22.0
			p.initial_velocity_max = 44.0
			p.gravity = Vector2(14, 0)
			p.scale_amount_min = 1.6
			p.scale_amount_max = 3.2
			p.lifetime = 7.0
			p.preprocess = 7.0
		"rise":  # a slow curling column
			p.amount = 10
			p.emission_rect_extents = Vector2(24, 6)
			p.direction = Vector2(0, -1)
			p.spread = 24.0
			p.initial_velocity_min = 16.0
			p.initial_velocity_max = 34.0
			p.gravity = Vector2(10, -6)
			p.scale_amount_min = 0.8
			p.scale_amount_max = 2.0
		_:  # "drift": a wide horizontal breeze
			p.amount = 8
			p.emission_rect_extents = Vector2(900, 200)
			p.direction = Vector2(1, -0.1)
			p.spread = 20.0
			p.initial_velocity_min = 10.0
			p.initial_velocity_max = 24.0
			p.gravity = Vector2(6, 0)
			p.scale_amount_min = 2.4
			p.scale_amount_max = 4.6
			p.lifetime = 9.0
			p.preprocess = 9.0
	p.emitting = true
	add_child(p)


func _build_backdrop() -> void:
	var layer := Node2D.new()
	layer.name = "Backdrop"
	layer.z_index = -100
	add_child(layer)

	# Screen-space vignette + room title.
	var vig_layer := CanvasLayer.new()
	vig_layer.name = "VignetteLayer"
	vig_layer.layer = 5
	add_child(vig_layer)
	var vig_grad := Gradient.new()
	vig_grad.set_color(0, Color(0.0, 0.0, 0.0, 0.0))
	vig_grad.set_color(1, Color(0.0, 0.0, 0.0, 0.22))
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

	# No room title: it sat over the stop labels (founder 2026-09-30).


## Movement uses the same ground map as the stop placement.
func constrain_to_ground(point: Vector2) -> Vector2:
	return Layout.constrain(protocol, point)


# ---- Floor ------------------------------------------------------------------

func _build_floor_and_walls() -> void:
	var slab := ColorRect.new()
	slab.name = "FloorSlab"
	slab.position = Vector2.ZERO
	slab.size = Vector2(strip_width, ROOM_H)
	slab.color = _slab_color()
	# This is the map's base, not a foreground overlay. Backdrop is at -100.
	slab.z_index = -110
	add_child(slab)

	var floor_body := StaticBody2D.new()
	floor_body.name = "Floor"
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	floor_body.position = Vector2(strip_width * 0.5, ROOM_H + 20.0)
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
	var wall_specs: Array[Dictionary] = [
		{"position": Vector2(-20.0, ROOM_H * 0.5), "size": Vector2(40.0, ROOM_H)},
		{"position": Vector2(strip_width + 20.0, ROOM_H * 0.5), "size": Vector2(40.0, ROOM_H)},
		{"position": Vector2(strip_width * 0.5, -20.0), "size": Vector2(strip_width, 40.0)},
		{"position": Vector2(strip_width * 0.5, ROOM_H + 20.0), "size": Vector2(strip_width, 40.0)},
	]
	for i in range(wall_specs.size()):
		var wall_shape := CollisionShape2D.new()
		wall_shape.name = "WallShape%d" % i
		var wall_rect := RectangleShape2D.new()
		wall_rect.size = wall_specs[i]["size"]
		wall_shape.shape = wall_rect
		wall_shape.position = wall_specs[i]["position"]
		walls.add_child(wall_shape)
	add_child(walls)


# ---- Return to the campaign -------------------------------------------------

func _build_return_waystone() -> void:
	_build_stop({"id": "exit", "name": "Return waystone", "line": "Return to the adventure."}, Layout.WAYSTONES[protocol])

func _do_ascend() -> void:
	if _ascending or _arriving:
		return
	if Travel.return_scene.is_empty():
		if _companion != null:
			_companion.call("say", "Enter this room from the adventure to return through the waystone.")
		return
	_ascending = true
	# The governor says goodbye and Lil Blunt answers before he climbs out (founder 2026-09-30).
	if _player != null and is_instance_valid(_player):
		_player.set_physics_process(false)
	await _converse("farewell")
	Travel.ascend()


# ---- Stops ------------------------------------------------------------------

func _build_stops() -> void:
	for i in range(_stop_plan.size()):
		var entry: Dictionary = _stop_plan[i]
		_build_stop(entry, _map_position(String(entry.get("id", "")), i))


func _map_position(stop_id: String, fallback_index: int) -> Vector2:
	var raw_layout: Variant = MAP_POSITIONS.get(protocol, {})
	if typeof(raw_layout) == TYPE_DICTIONARY:
		var layout: Dictionary = raw_layout
		if layout.has(stop_id):
			return layout[stop_id]
	return Vector2(FIRST_STOP_X + STOP_SPACING * float(fallback_index), FLOOR_Y - 80.0)


func _build_stop(entry: Dictionary, map_position: Vector2) -> void:
	var id: String = _s2(entry, "id")
	var line: String = _s2(entry, "line")
	_stop_lines[id] = line
	var aspects: Variant = entry.get("aspects", [])
	if typeof(aspects) == TYPE_ARRAY and not (aspects as Array).is_empty():
		_stop_aspects[id] = aspects
	var stop := TourStopScript.new()
	stop.name = "Stop_%s" % id
	stop.position = map_position
	stop.z_index = int(map_position.y)
	stop.setup(id, _s2(entry, "name", id), line, _glow, false, 150.0)
	add_child(stop)
	stop.reached.connect(_on_stop_reached)
	stop.activated.connect(_activate_stop)
	# The painted entrance is the mint gate; do not block it with another prop.
	if protocol == "diamonds" and id == "blaze_gate":
		stop.label_height = 90.0
		return
	var fixture := FixtureScript.new()
	fixture.name = "Fixture"
	fixture.kind = id
	fixture.protocol = protocol
	fixture.target_width = Layout.prop_width(protocol, id) if Layout.PROP_WIDTH.has(protocol) \
			else (145.0 if id in ["arb_well", "exam", "vault_crush"] else 125.0)
	stop.add_child(fixture)


func _activate_stop(id: String) -> void:
	match id:
		"paper": open_whitepaper()
		"video": open_video()
		"exam": start_exam()
		"exit": _do_ascend()
		_:
			_on_stop_reached(id)
			_open_overlay()
			var stop := get_node("Stop_" + id)
			_add_label(String(stop.stop_name), 26, _glow)
			_add_label(_current_aspect(id), 21, Color("eee1c3"))
			_add_button("CONTINUE EXPLORING", _close_overlay_ui)


func _on_stop_reached(stop_id: String) -> void:
	if stop_id in _required_learning_stops:
		_visited_learning_stops[stop_id] = true
		_update_objective()
	if _companion == null or _overlay_open:
		return
	var idx := _next_aspect(stop_id)
	var text := _current_aspect(stop_id)
	_companion.call("say", text, clampf(3.0 + float(text.length()) / 14.0, 5.0, 14.0))
	# ElevenLabs read of the same aspect (Pauly / Kane / Rich); silent if no clip exists.
	_companion.call("play_voice", "res://src/assets/portals/vo/%s_%s_%d.mp3" % [protocol, stop_id, idx])


## Advance to the next aspect of this stop (wraps), so revisits bring a new angle.
func _next_aspect(stop_id: String) -> int:
	var aspects: Array = _stop_aspects.get(stop_id, [])
	if aspects.is_empty():
		return 0
	var visits: int = int(_stop_visits.get(stop_id, 0))
	_stop_visits[stop_id] = visits + 1
	_stop_current[stop_id] = visits % aspects.size()
	return int(_stop_current[stop_id])


func _current_aspect(stop_id: String) -> String:
	var aspects: Array = _stop_aspects.get(stop_id, [])
	if aspects.is_empty():
		return String(_stop_lines.get(stop_id, ""))
	return String(aspects[int(_stop_current.get(stop_id, 0)) % aspects.size()])


# ---- Player + companion -----------------------------------------------------

## Arrive along the painted entrance path, beside the return waystone.
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
	var entrance: Vector2 = Layout.ENTRANCES[protocol]
	player.position = entrance + Vector2(0, 35)
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
	tween.tween_property(player, "position", entrance, ARRIVAL_TIME)
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
		_converse("welcome")


## Greeting / goodbye exchange: the governor speaks, then Lil Blunt answers, each with voice.
func _converse(phase: String) -> void:
	var lines: Variant = _data.get(phase, {})
	if _companion == null or typeof(lines) != TYPE_DICTIONARY or (lines as Dictionary).is_empty():
		return
	var dict: Dictionary = lines
	var base := "res://src/assets/portals/vo/%s_%s_" % [protocol, phase]
	var wait: float = float(_companion.call("speak", String(dict.get("gov", "")), base + "gov.mp3", String(_companion.get("display_name"))))
	if not is_inside_tree():
		return
	await get_tree().create_timer(wait).timeout
	if not is_inside_tree() or _companion == null:
		return
	wait = float(_companion.call("speak", String(dict.get("lb", "")), base + "lb.mp3", "Lil Blunt"))
	await get_tree().create_timer(wait).timeout


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
	comp.position = Layout.constrain(protocol, Layout.ENTRANCES[protocol] + Vector2(-40, 20))
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

	_objective_label = Label.new()
	_objective_label.name = "KnowledgeQuest"
	_objective_label.position = Vector2(28.0, 28.0)
	_objective_label.size = Vector2(430.0, 96.0)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.add_theme_font_size_override("font_size", 18)
	_objective_label.add_theme_color_override("font_color", _glow)
	_objective_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_objective_label.add_theme_constant_override("outline_size", 6)
	_objective_label.add_theme_stylebox_override("normal", _backing_style())
	_objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(_objective_label)
	_update_objective()

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
	_add_label("FIELD GUIDE", 18, _glow)
	for stop_id in _required_learning_stops:
		_add_label("• %s" % String(_stop_lines.get(stop_id, "")), 17, Color(0.84, 0.9, 0.88))
	_add_button("OPEN WHITEPAPER", _on_open_paper)
	_add_button("EXIT", close_overlay)
	_update_objective()


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
	_open_overlay()
	_add_label(_s("video_label", "Watch the Video"), 26, _glow)
	_add_label(_s("video_wait_line"), 20, Color(0.85, 0.90, 0.90))
	_add_button("WATCH ON X", _on_open_video)
	_done_button = _add_button("DONE", close_overlay)
	_done_button.disabled = true


func _on_open_video() -> void:
	OS.shell_open(String(VIDEO_URLS.get(protocol, "")))
	if session != null and session.state == SignalsScript.State.STUDY_CHOICE:
		session.choose_study("video")
	if _watch_timer != null:
		_watch_timer.start(SignalsScript.VIDEO_MIN_WATCH_SEC)
	_update_objective()


func _on_watch_timeout() -> void:
	if _done_button != null and is_instance_valid(_done_button):
		_done_button.disabled = false


# ---- Overlay: examiner, quiz, result ----------------------------------------

func start_exam() -> void:
	if _overlay_open or session == null:
		return
	if _visited_learning_stops.size() < _required_learning_stops.size() or session.study_path.is_empty():
		_show_exam_locked()
		return
	if bank == null:
		bank = QuizBankScript.load_bank(protocol)
	if session.state == SignalsScript.State.STUDY_CHOICE:
		session.transition(SignalsScript.State.EXAMINER_INTRO)
	_intro_index = 0
	_show_intro()


func _show_exam_locked() -> void:
	_open_overlay()
	_add_label("KNOWLEDGE GATE", 28, _glow)
	_add_label("Explore every protocol mechanism, then study either the field guide or official video before taking the exam.", 21, Color(0.92, 0.95, 0.95))
	_add_label("Mechanisms: %d / %d   Study source: %s" % [_visited_learning_stops.size(), _required_learning_stops.size(), "complete" if session != null and not session.study_path.is_empty() else "needed"], 19, Color(0.75, 0.84, 0.84))
	_add_button("RETURN TO THE MAP", _close_overlay_ui)


func _update_objective() -> void:
	if _objective_label == null:
		return
	var studied: bool = session != null and not session.study_path.is_empty()
	_objective_label.text = "PROTOCOL QUEST\nDiscover mechanisms  %d/%d   |   Study source  %s\nWASD / arrows to walk · E to interact" % [_visited_learning_stops.size(), _required_learning_stops.size(), "DONE" if studied else "0/1"]


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
		_add_button("RETURN TO ADVENTURE", _on_climb_back)
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

## One dispatcher chooses the nearest prop, so one press opens one interaction.
func _unhandled_input(event: InputEvent) -> void:
	if _overlay_open:
		_handle_overlay_input(event)
		return
	if _arriving or not event.is_action_pressed("interact"):
		return
	var nearest: Node2D = null
	var distance := TourStopScript.INTERACT_RADIUS
	for stop in get_tree().get_nodes_in_group("portal_stop"):
		if not is_ancestor_of(stop):
			continue
		var d: float = _player.global_position.distance_to(stop.global_position + TourStopScript.APPROACH)
		if d < distance:
			distance = d
			nearest = stop
	if nearest != null:
		get_viewport().set_input_as_handled()
		nearest.activate()


func _handle_overlay_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close_overlay()
		get_viewport().set_input_as_handled()
		return
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
