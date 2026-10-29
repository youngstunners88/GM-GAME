class_name LogansLakeChamber
extends Ep2Interlude
## Founder lock 2026-10-18: investigate / stage depth, never fishing or a protocol dashboard.
## The surface route continues here after Rich & Utah's gear. No currency writes or rewards.
enum Beat { ARRIVE, INVESTIGATE, STAGE, HANDOFF, OVERLOOK }
const LOGAN := "res://src/episode2/extras/lake/logan.glb"
const DOCK := "res://src/episode2/assets/lake/staging_dock.glb"
const SPAWN := Vector3(-8, 0, -13)
const LOGAN_MARK := Vector3(-3.4, 0, 8)
const STAGING_MARK := Vector3(-4.5, 0, 17)
const OVERLOOK := Vector3(-8, 6, 61)
const LINES := [
	"LOGAN: This depth stays deep. We stage what comes in before anything goes downstream.",
	"LIL BLUNT: So the lake holds the depth, and the river carries what is ready?",
	"LOGAN: Exactly. Check the cargo at that staging marker. Keep the bank secure; don't empty the lake.",
]
var _logan: Ep2TownFolk
var _marker: Node3D
var _cargo: Node3D
var _line: int = 0
var _talk_t: float = 0.0
var _gesture_t: float = 0.0
var _staged: bool = false
var _dialogue: Label
var _dialogue_panel: PanelContainer
var _marker_label: Label3D
var _stage_calls: int = 0
var _landscape := Ep2LakeLandscape.new()
var _skiff: Ep2LoganSkiff
var _cabin := Ep2LoganCabin.new()

func _init() -> void:
	title_card = "LOGAN'S LAKE"
	viewmodel_exposure = 0.82
	camera_min = Vector3(-150, -3, -150)
	camera_max = Vector3(200, 120, 200)

func _chamber_id() -> String: return "logans_lake"
func _beat_label(b: int) -> String: return Beat.keys()[clampi(b, 0, Beat.size() - 1)]
func _build_steps() -> Array: return [_light, _land, _water, _shore, _vegetation, _people, _build_skiff, _build_cabin]

func _light() -> void:
	var env := Environment.new()
	_env_node.environment = env
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.48, 0.58)
	sky_mat.sky_horizon_color = Color(0.71, 0.77, 0.76)
	sky_mat.ground_horizon_color = Color(0.42, 0.48, 0.39)
	sky_mat.ground_bottom_color = Color(0.10, 0.14, 0.09)
	sky_mat.sun_angle_max = 4.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.53, 0.65, 0.63)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.60, 0.69, 0.65)
	env.fog_density = 0.0015
	_sun.rotation_degrees = Vector3(-31, -34, 0)
	_sun.light_color = Color(1.0, 0.88, 0.70)
	_sun.light_energy = 1.25
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 90.0

static func path_height(z: float) -> float:
	return Ep2LakeLandform.path_height(z)

static func terrain_height(x: float, z: float) -> float:
	return Ep2LakeLandform.terrain_height(x, z)

func _land() -> void:
	_landscape.build_ground(_visuals)

func _water() -> void:
	_landscape.build_water(_sun)

func _sign(words: String, p: Vector3, width: float = 2.6) -> Label3D:
	var wood: Material = _tex(TIMBER_TEX, Color(0.50, 0.33, 0.18), 0.5)
	_box(Vector3(0.15, 2.3, 0.15), p + Vector3(0, 0.6, 0), wood)
	_box(Vector3(width, 0.7, 0.13), p + Vector3(0, 1.5, 0), wood)
	var label := Label3D.new()
	label.text = words
	label.position = p + Vector3(0, 1.5, -0.075)
	label.rotation.y = PI
	label.font_size = 40
	label.pixel_size = 0.009
	label.modulate = Color(0.96, 0.82, 0.55)
	label.outline_size = 3
	_visuals.add_child(label)
	return label

func _shore() -> void:
	var dock: Node3D = (load(DOCK) as PackedScene).instantiate()
	dock.name = "StagingDock"
	dock.position = Vector3(0, 0, 10)
	_visuals.add_child(dock)
	_landscape.register_dock(dock)
	_sign("LOGAN'S LAKE", Vector3(-4.1, 0, -7), 3.2)
	_sign("RIVER OVERLOOK  >", Vector3(-4, path_height(34), 34), 3.3)
	_marker = Node3D.new()
	_marker.name = "StagingMarker"
	_marker.position = STAGING_MARK
	_visuals.add_child(_marker)
	var wood: Material = _tex(TIMBER_TEX, Color(0.65, 0.46, 0.27), 0.7)
	_box(Vector3(1.4, 0.95, 1.0), Vector3(0, 0.48, 0), wood, _marker)
	for x in [-0.53, 0.53]:
		_box(Vector3(0.09, 1.0, 1.06), Vector3(x, 0.49, 0), _plain(Color(0.19, 0.17, 0.12)), _marker)
	_marker_label = _sign("STAGED CARGO", STAGING_MARK + Vector3(1.1, 0, 0.5), 3.4)
	# Cargo waiting at the narrow water, below the player's later overlook.
	_cargo = Node3D.new()
	_cargo.name = "StagedShipment"
	_cargo.position = Vector3(24, -0.08, 49)
	_visuals.add_child(_cargo)
	_box(Vector3(3.0, 0.25, 5.5), Vector3.ZERO, wood, _cargo)
	for x in [-1.35, 1.35]:
		_box(Vector3(0.18, 0.65, 5.3), Vector3(x, 0.26, 0), wood, _cargo)
	for z in [-1.4, 0, 1.4]:
		_box(Vector3(1.6, 0.9, 1.1), Vector3(0, 0.55, z), wood, _cargo)
	_sign("DAY-88 RIVER", Vector3(-4.5, path_height(56), 56), 2.9)

func _vegetation() -> void:
	_landscape.build_vegetation(_visuals)

func _people() -> void:
	# Keep the supplied skin intact in the existing streamed pack. A slow download
	# leaves the shore playable and offers retry; never substitute a generic person.
	if _logan != null or not Ep2Extras.has(LOGAN): return
	_logan = Ep2TownFolk.new()
	_logan.name = "Logan"
	_visuals.add_child(_logan)
	_logan.setup(LOGAN, 1.82)
	_logan.clip_blend = 0.18
	_logan.position = LOGAN_MARK
	_logan.face_yaw(PI)
	var ap: AnimationPlayer = _logan.anim_player()
	if ap != null:
		for name in ap.get_animation_list():
			if str(name).to_lower().contains("idle"):
				ap.get_animation(name).loop_mode = Animation.LOOP_LINEAR

func _build_skiff() -> void:
	if _skiff == null and _logan != null and Ep2Extras.has(Ep2LoganSkiff.MODEL):
		_skiff = Ep2LoganSkiff.new()
		_skiff.build(_visuals, _logan, _landscape.water_material)
		_skiff.reset_routine()

func _build_cabin() -> void:
	_cabin.build(_visuals)

func _on_setup() -> void:
	print("[EP2] Logan lake started")
	_player_pos = SPAWN
	_look_yaw = 0.1
	_look_pitch = 0.02
	_set_ground(0)
	_line = 0
	_talk_t = 0
	_staged = false
	_stage_calls = 0
	_gesture_t = 0
	_marker_label.text = "STAGED CARGO"
	_cargo.position = Vector3(24, -0.08, 49)
	if _logan != null: _logan.hold_clip("Idle")
	if _skiff != null: _skiff.reset_routine()
	Ep2Extras.start(self)
	_vm.set_world_shadows(false)
	_vm.set_own_light(0.65, _sun)
	if not _hud.search_requested.is_connected(start_rig):
		_hud.search_requested.connect(start_rig)
	_build_dialogue()
	_advance_to(Beat.ARRIVE)

func _build_dialogue() -> void:
	if _dialogue_panel != null: return
	_dialogue_panel = PanelContainer.new()
	_dialogue_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dialogue_panel.offset_left = -330
	_dialogue_panel.offset_right = 330
	_dialogue_panel.offset_top = -175
	_dialogue_panel.offset_bottom = -78
	_dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.065, 0.035, 0.94)
	style.border_color = Color(0.63, 0.46, 0.23)
	style.set_border_width_all(1)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_dialogue_panel.add_theme_stylebox_override("panel", style)
	_hud_layer.add_child(_dialogue_panel)
	_dialogue = Label.new()
	_dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue.add_theme_font_size_override("font_size", 21)
	_dialogue.add_theme_color_override("font_color", Color(1, 0.9, 0.7))
	_dialogue_panel.add_child(_dialogue)
	_dialogue_panel.hide()

func _say(text: String, seconds: float) -> void:
	_dialogue.text = text
	_dialogue_panel.show()
	_talk_t = seconds

func _gesture(name: String, seconds: float) -> void:
	_logan.hold_clip(name)
	_gesture_t = seconds

func _on_beat_entered(b: int) -> void:
	match b:
		Beat.ARRIVE: _hud.objective = "Logan's Lake · Meet Logan at the shore."
		Beat.INVESTIGATE:
			_hud.objective = "Investigate the depth. Listen to Logan."
			_say(LINES[0], 6.5)
			_gesture("Greet", 2.5)
		Beat.STAGE: _hud.objective = "Check the staged cargo beside Logan [E]." if TouchUi.keys_shown() else "Check the staged cargo beside Logan."
		Beat.HANDOFF:
			_hud.objective = "Follow the shore trail to the river overlook."
			_say("LOGAN: Cargo checked. The depth holds. Follow the outflow to the high ground—the day-88 shipment leaves from here.", 8.5)
			_gesture("Point", 3.0)
		Beat.OVERLOOK:
			_hud.objective = "Day-88 river · Follow the outflow. This lake visit ends at the overlook."
			_say("The still-water narrows into the river. Rich and Utah's gear is ready for the run downstream.", 8.0)

func start_rig(_payment: String = "") -> bool:
	if not has_player_control() or armory_open(): return false
	if _beat == Beat.OVERLOOK and _staged and _talk_t <= 0 and _player_pos.z > 59:
		_resolve({"end_session": true, "lake_complete": true, "river_ready": true, "companion": ""})
		return true
	if _logan == null:
		if Ep2Extras.state() == "failed": Ep2Extras.retry(self)
		return false
	if _beat == Beat.ARRIVE and _player_pos.distance_to(LOGAN_MARK) < 3.2:
		_advance_to(Beat.INVESTIGATE)
		return true
	if _beat == Beat.STAGE and _player_pos.distance_to(STAGING_MARK) < 2.8 and not _staged:
		_staged = true
		_stage_calls += 1
		_marker_label.text = "CARGO CHECKED"
		_hud.toast("STAGING CONFIRMED · DEPTH PROTECTED", 3)
		_advance_to(Beat.HANDOFF)
		return true
	return false

func _tick(delta: float) -> void:
	_landscape.refresh_streamed()
	_build_cabin()
	_cabin.refresh_materials()
	_set_ground(Ep2LoganCabin.walk_height(_player_pos) if _player_pos.x < -11.5 else path_height(_player_pos.z))
	if _logan == null:
		_people()
		if _logan == null:
			_hud.objective = "Logan's Lake · Loading Logan…"
			_hud.set_search_prompt("Loading interrupted. Retry [E]" if Ep2Extras.state() == "failed" else "")
			return
		_hud.objective = "Logan's Lake · Meet Logan at the shore."
	_build_skiff()
	_logan.step(delta)
	if _player_pos.distance_to(LOGAN_MARK) < 7:
		_logan.face_point(_player_pos)
	if _gesture_t > 0:
		_gesture_t -= delta
		if _gesture_t <= 0: _logan.hold_clip("Idle")
	if _talk_t > 0:
		_talk_t -= delta
		if _talk_t <= 0:
			if _beat == Beat.INVESTIGATE:
				_line += 1
				if _line < LINES.size():
					_say(LINES[_line], 6.5)
				else:
					_dialogue_panel.hide()
					_advance_to(Beat.STAGE)
			else: _dialogue_panel.hide()
	var prompt := ""
	if _beat == Beat.ARRIVE and _player_pos.distance_to(LOGAN_MARK) < 3.2:
		prompt = "Meet Logan [E]"
	elif _beat == Beat.STAGE and _player_pos.distance_to(STAGING_MARK) < 2.8:
		prompt = "Check staged cargo [E]"
	elif _beat == Beat.OVERLOOK and _talk_t <= 0 and _player_pos.z > 59:
		prompt = "Finish lake visit [E]"
	_hud.set_search_prompt(prompt)
	if _staged:
		_cargo.position.z = minf(72, _cargo.position.z + delta * 0.35)
		_cargo.position.x = Ep2LakeLandform.flow_center(_cargo.position.z)
		_cargo.rotation.z = sin(_elapsed * 0.8) * 0.012
	if _skiff != null:
		_skiff.advance(delta, _staged and _talk_t <= 0.0)
	if _beat == Beat.HANDOFF and _player_pos.z > 59:
		_advance_to(Beat.OVERLOOK)

func _collide(p: Vector3) -> Vector3:
	if Ep2LoganCabin.YARD.has_point(Vector2(p.x, p.z)) or (_player_pos.x < -11.5 and p.x < -11.5):
		return Ep2LoganCabin.collide(p)
	var q := p
	q.z = clampf(q.z, -16, 64)
	q.x = clampf(q.x, -11.5, -4.1)
	# Walk onto the dock only through its landward end; water stays impassable.
	if p.z > 8.85 and p.z < 11.15:
		q.x = clampf(p.x, -11.5, 3.65)
	if _beat < Beat.HANDOFF and q.z > 27:
		q.z = 27
	return q

func _on_player_shot() -> void:
	if _player_pos.distance_to(LOGAN_MARK) < 35:
		_hud.toast("LOGAN: Easy. Keep the staging bank secure.", 2.5)

func staging_complete() -> bool: return _staged
func staging_count() -> int: return _stage_calls
func river_ready() -> bool: return _beat == Beat.OVERLOOK and _staged

## Read-only release diagnostic: instantiate the shipped skin and verify its clips.
## No scene tree entry, unlock, rewards or progression changes.
static func probe_assets() -> bool:
	if not ResourceLoader.exists(LOGAN) or not ResourceLoader.exists(DOCK): return false
	var packed := load(LOGAN) as PackedScene
	if packed == null: return false
	var model := packed.instantiate()
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	var bones: int = skeletons[0].get_bone_count() if skeletons.size() == 1 else 0
	var clips: String = ""
	if not players.is_empty():
		clips = str(players[0].get_animation_list()).to_lower()
	var ok: bool = bones == 65
	for clip in ["idle", "greet", "point", "approve"]: ok = ok and clips.contains(clip)
	model.free()
	if ok: print("[EP2] Logan lake assets ready (bones=65 clips=Idle,Greet,Point,Approve)")
	return ok
