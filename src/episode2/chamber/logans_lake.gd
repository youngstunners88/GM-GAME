class_name LogansLakeChamber
extends Ep2Interlude
## Founder lock 2026-10-18: investigate / stage depth, player investigates; Logan may fish as background lake life.
## The surface route continues here after Rich & Utah's gear. No currency writes or rewards.
enum Beat { ARRIVE, INVESTIGATE, STAGE, HANDOFF, OVERLOOK }
const LOGAN := "res://src/episode2/extras/lake/logan.glb"
const DOCK := "res://src/episode2/assets/lake/staging_dock.glb"
const SPAWN := Vector3(-8, 0, -13)
const LOGAN_MARK := Vector3(-3.4, 0, 8)
const ARRIVAL_SIGN := Vector3(-12, 0, -4) # opposite the water; leave the rider-to-Logan sightline open
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
## DUDE'S HORSE AT THE LAKE (founder 2026-11-01: "the horse needs to go to the lake and drink this whole time while Lil Blunt speaks
## with Logan ... Lil Blunt would be able to actually mount back on the horse ... as the horse just disappears at this point").
## The trail room that carried the horse is parked off screen when the lake takes over, so the lake keeps its own horse: it walks from
## where he dismounted to the water's edge, drinks through the whole of Logan's talk and after, and stays a mountable actor (E).
## It is a child of the room, not of `_visuals`, so the trail's horizon preview never shows a second horse while he is still riding.
const HORSE_MODEL := "res://src/episode2/assets/town/horse.glb"
const HORSE_DRINK := Vector3(-0.7, 0, 5.0)        # forefeet on the bank, muzzle over the shallows beside Logan's landing
const HORSE_DRINK_YAW := PI * 0.5                 # facing +X: the water
const LOGAN_DRAW_TIME := 0.55                      # gun up to the shot: too fast to answer, long enough to see the gold
const LOGAN_DOWN_TIME := 1.15
const HORSE_SHOT_LINE := "LOGAN: That horse is shot. It won't drink like that. Dude's the man to see."
const HORSE_GONE_LINE := "LOGAN: You walked in. They shot your horse out from under you, then. Dude can find you another."
var _logan_draw_t: float = -1.0
var _logan_fired: bool = false
var _horse_line_said: bool = false
const WALK_ON_Z := 63.4                            # the top of the overlook path (the bank clamps him at 64)
const HORSE_WALK := 2.2                           # m/s, a brisk walk to the water (about 9 s from the shore end of the trail)
const HORSE_CLIP_SPEED := 1.9                     # ground m/s of horse_walk at speed_scale 1 (same clip as the trail)
const HORSE_REACH := 3.6                          # how close E mounts him (he drinks just past the bank path's edge, x = -4.1)
const MOUNTED_EYE := 2.18
const MOUNTED_SPEED := 6.0
const SADDLE_HEIGHT := 1.28
var _horse: Node3D
var _horse_anim: AnimationPlayer
var _horse_state: String = "drink"                # lead -> drink; ridden; graze (left where he dismounted)
var _horse_clip: String = ""
var _horse_sip_t: float = 2.0
var _riding: bool = false
var _mount_t: float = -1.0
var _mount_from: Vector3 = Vector3.ZERO
var _mount_horse_from: Vector3 = Vector3.ZERO
var _mount_to: Vector3 = Vector3.ZERO
var _foot_speed: float = 3.4

func _init() -> void:
	title_card = "LOGAN'S LAKE"
	viewmodel_exposure = 0.82
	camera_min = Vector3(-150, -3, -150)
	camera_max = Vector3(200, 120, 200)

func _chamber_id() -> String: return "logans_lake"
func _beat_label(b: int) -> String: return Beat.keys()[clampi(b, 0, Beat.size() - 1)]
func _build_steps() -> Array: return [_light, _land, _water, _shore, _vegetation, _people, _build_skiff, _build_cabin, _build_ambience, _build_horse]

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
	_sign("LOGAN'S LAKE", ARRIVAL_SIGN, 3.2)
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
	_build_logan_camp()


## LOGAN'S CAMP, READABLE FROM THE TRAIL (founder 2026-11-01: "we cant anticipate that Logan is in the distance"). A small fire on the
## bank beside his landing, a tall pale smoke column and a lantern post at the dock: all under `_visuals`, so the trail copies them
## onto its horizon while he is still riding and the column says "someone is camped by the water" long before Logan is a figure.
const CAMP := Vector3(-2.3, 0, 13.2)
func _build_logan_camp() -> void:
	var camp := Node3D.new()
	camp.name = "LoganCamp"
	camp.position = CAMP
	_visuals.add_child(camp)
	var stone: Material = _plain(Color(0.36, 0.34, 0.31), 0.95)
	for i in 8:
		var a: float = float(i) / 8.0 * TAU
		_sphere(0.16, Vector3(cos(a) * 0.48, 0.07, sin(a) * 0.48), stone, camp, 0.6)
	var wood: Material = _plain(Color(0.27, 0.17, 0.09), 0.9)
	for i in 3:
		var stick := _cyl(0.05, 0.06, 0.7, Vector3(0, 0.12, 0), wood, camp, 7)
		stick.rotation = Vector3(PI * 0.5 - 0.35, float(i) * TAU / 3.0, 0)
	var embers := _sphere(0.2, Vector3(0, 0.14, 0), _glow(Color(1.0, 0.45, 0.12), 3.0), camp, 0.55)
	embers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fire_light := OmniLight3D.new()
	fire_light.name = "CampFireLight"
	fire_light.light_color = Color(1.0, 0.6, 0.28)
	fire_light.light_energy = 0.9
	fire_light.omni_range = 4.5
	fire_light.position = Vector3(0, 0.5, 0)
	camp.add_child(fire_light)
	var smoke := MeshInstance3D.new()
	smoke.name = "CampSmokeColumn"
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	smoke.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/episode2/art/camp_smoke.gdshader")
	smoke.material_override = mat
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smoke.scale = Vector3(10.0, 34.0, 1.0)            # wide and tall enough to read from 150 m down the trail
	smoke.position = Vector3(0, 17.2, 0)
	camp.add_child(smoke)
	# the landing lantern at the dock's shore end: a warm point where Logan stands
	var post := _box(Vector3(0.1, 2.4, 0.1), Vector3(-0.6, 1.2, 8.4) - CAMP, _plain(Color(0.25, 0.16, 0.08), 0.9), camp)
	post.name = "LandingLanternPost"
	var lamp := _sphere(0.13, Vector3(-0.6, 2.35, 8.4) - CAMP, _glow(Color(1.0, 0.78, 0.42), 4.0), camp)
	lamp.name = "LandingLantern"
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

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

## Hidden rooms do not tick; finish streamed destination art before copying it to the approach.
func prepare_approach() -> void:
	_landscape.refresh_streamed()
	_build_cabin()
	_cabin.refresh_materials()
	_people()
	_build_skiff()

func _on_setup() -> void:
	Ep2DrawMusic.begin_lake(self)
	print("[EP2] Logan lake started")
	_player_pos = handoff.get("lake_player",SPAWN)
	_look_yaw = float(handoff.get("lake_yaw",0.1))
	_look_pitch = float(handoff.get("lake_pitch",0.02))
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
	_foot_speed = walk_speed
	_riding = false
	_mount_t = -1.0
	eye_height = FPS_EYE_HEIGHT
	# Ridden in: he stops where Lil Blunt slid off (the trail's dismount stepped him 1.3 m to the right) and walks to the water.
	# On foot (UNHORSE on the trail): Dude's horse found the water first and is already drinking - never strand him at the lake.
	var slid_off_at: Vector3 = _player_pos - Vector3(1.3, 0, 0)
	_logan_draw_t = -1.0
	if armory.horse_is_down():
		_horse_state = "gone"                       # shot out from under him on the trail: there is no horse at the lake to water or ride
		_horse.visible = false
	elif not armory.horse_is_sound():
		_place_horse(slid_off_at, _look_yaw)        # it carried him here, shot, and stands where he got down: it will not drink, and it cannot be ridden
		_horse_state = "hurt"
		_set_horse_clip("horse_stand", 0.6)
	elif bool(handoff.get("arrived_mounted", false)) and slid_off_at.distance_to(HORSE_DRINK) < 40.0:
		_place_horse(slid_off_at, _look_yaw)
		_horse_state = "lead"
	else:
		_place_horse(HORSE_DRINK, HORSE_DRINK_YAW)
		_horse_state = "drink"
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

## A spoken lake line. With its take it is heard and never boxed on screen, and the next line follows the take by a breath
## (founder 2026-11-01: no subtitles, no awkward delay). Without a take the old dialogue box carries the words for `seconds`.
func _say(text: String, seconds: float) -> void:
	_dialogue.text = text
	var parts: PackedStringArray = text.split(": ",true,1)
	var voiced: bool = false
	if parts.size() == 2:
		var speaker: String = "logan" if parts[0] == "LOGAN" else "lil_blunt"
		var id: String = Ep2TownVoiceBank.id_for(speaker,parts[1])
		var stream: AudioStream = Ep2TownVoiceBank.stream(id)
		if stream != null:
			AudioManager.play_voice(id,stream)
			seconds = stream.get_length()+Ep2Speech.GAP
			voiced = true
	_dialogue_panel.visible = not voiced
	if _hud != null: _hud.speech(text, seconds, true)   # logged for tests; the box above is the only unvoiced caption
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
		Beat.STAGE:
			_hud.objective = "Check the staged cargo beside Logan [E]." if TouchUi.keys_shown() else "Check the staged cargo beside Logan."
			if not armory.horse_is_sound() and not _horse_line_said:
				_horse_line_said = true                    # Logan can see what came up that trail: he says so, and nobody offers it water
				_say(HORSE_GONE_LINE if armory.horse_is_down() else HORSE_SHOT_LINE, 5.0)
		Beat.HANDOFF:
			prebuild_requested.emit("river_cover")          # the ridge builds off screen while he walks the shore trail
			_hud.objective = "Follow the shore trail to the river overlook."
			_say("LOGAN: Cargo checked. The depth holds. Follow the outflow to the high ground—the day-88 shipment leaves from here.", 8.5)
			_gesture("Point", 3.0)
		Beat.OVERLOOK:
			_hud.objective = ("Day-88 river · at the overlook, [E] climb to the ridge." if TouchUi.keys_shown()
				else "Day-88 river · at the overlook, climb to the ridge.")
			_say("The still-water narrows into the river. Rich and Utah's gear is ready for the run downstream.", 8.0)

func start_rig(_payment: String = "") -> bool:
	if not has_player_control() or armory_open(): return false
	if _beat == Beat.OVERLOOK and _staged and _talk_t <= 0 and _player_pos.z > 59:
		# founder lock 2026-11-04: the lake hands on to the day-88 ridge (river_cover.gd); Logan stays here, Rich and Utah never come
		_resolve({"next_chamber": "river_cover", "lake_complete": true, "river_ready": true, "companion": ""})
		return true
	if _riding:
		_dismount()
		return true
	if _logan == null:
		if can_mount_horse():
			_mount()
			return true
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
	if can_mount_horse():
		_mount()
		return true
	return false

func _tick(delta: float) -> void:
	if _logan_draw_t >= 0.0:
		_tick_logan_draw(delta)
		return
	_tick_horse(delta)
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
	elif _riding:
		prompt = "Dismount [E]"
	elif can_mount_horse():
		prompt = "Mount the horse [E]"
	elif _horse_state == "hurt" and Vector2(_player_pos.x - _horse.position.x, _player_pos.z - _horse.position.z).length() < HORSE_REACH:
		prompt = "The horse is shot: it needs Dude, not water"
	if prompt != "" and not TouchUi.keys_shown():
		prompt = prompt.replace(" [E]", "")
	_hud.set_search_prompt(prompt)
	if _staged:
		_cargo.position.z = minf(72, _cargo.position.z + delta * 0.35)
		_cargo.position.x = Ep2LakeLandform.flow_center(_cargo.position.z)
		_cargo.rotation.z = sin(_elapsed * 0.8) * 0.012
	if _skiff != null:
		_skiff.advance(delta, _staged and _talk_t <= 0.0)
	if _beat == Beat.HANDOFF and _player_pos.z > 59:
		_advance_to(Beat.OVERLOOK)
	# walking on up the path is enough: the ridge continues from here, [E] only says so sooner
	if _beat == Beat.OVERLOOK and _staged and _talk_t <= 0 and _player_pos.z >= WALK_ON_Z and not _resolved and has_player_control():
		_resolve({"next_chamber": "river_cover", "lake_complete": true, "river_ready": true, "companion": ""})

func _collide(p: Vector3) -> Vector3:
	if Ep2LoganCabin.YARD.has_point(Vector2(p.x, p.z)) or (_player_pos.x < -11.5 and p.x < -11.5):
		return Ep2LoganCabin.collide(p)
	var q := p
	q.z = clampf(q.z, -16, 64)
	q.x = clampf(q.x, -11.5, -4.1)
	# Walk onto the dock only through its landward end; water stays impassable (and no horse on the planks).
	if p.z > 8.85 and p.z < 11.15 and not _riding:
		q.x = clampf(p.x, -11.5, 3.65)
	if _beat < Beat.HANDOFF and q.z > 27:
		q.z = 27
	return q

func _on_player_shot() -> void:
	if _logan != null and _logan_draw_t < 0.0 and _bullet_hits_logan():
		_logan_draws()
		return
	if _player_pos.distance_to(LOGAN_MARK) < 35:
		_hud.toast("LOGAN: Easy. Keep the staging bank secure.", 2.5)


func _bullet_hits_logan() -> bool:
	var eye: Vector3 = _player_pos + Vector3(0, eye_height, 0)
	var cp: float = cos(_look_pitch)
	var dir := Vector3(sin(_look_yaw) * cp, sin(_look_pitch), cos(_look_yaw) * cp)
	var feet: Vector3 = _logan.global_position
	return WoodsQuadChamber._ray_capsule(eye, dir, feet + Vector3(0, 0.3, 0), feet + Vector3(0, 1.7, 0), 0.42) >= 0.0


## FOUNDER'S RULE 2026-11-04: "if you try to shoot Logan. He pulls out a golden revolver, The same Remington that Lil Blunt has that Rich sells and shoots
## you dead and you start all over from Dude on the horse." No fight and no second chance: the story takes the controls, he turns, the gold gun comes up
## on the Point clip, one shot, and the session goes back to Dude's.
func _logan_draws() -> void:
	_logan_draw_t = 0.0
	_logan_fired = false
	_show_blocks_control = true
	_move_input = Vector2.ZERO
	set_aim(false)
	_logan.face_point(_player_pos)
	_logan.hold_clip("Point")
	var gun: Node3D = (load(Ep2ArmoryShop.REMINGTON_MODEL) as PackedScene).instantiate() as Node3D
	gun.name = "GoldenRemington"
	if not _logan.attach_prop(gun, "RightHand", Vector3(0.0, 0.08, 0.03), Vector3(0.0, 90.0, 0.0)):
		_logan.add_child(gun)
		gun.position = Vector3(-0.22, 1.42, 0.5)
	_hud.speech("LOGAN: Wrong water to start a fight.", 1.6, false)


func _tick_logan_draw(delta: float) -> void:
	_logan_draw_t += delta
	var to_logan: Vector3 = _logan.global_position + Vector3(0, 1.5, 0) - (_player_pos + Vector3(0, eye_height, 0))
	_look_yaw = lerp_angle(_look_yaw, atan2(to_logan.x, to_logan.z), clampf(delta * 5.0, 0.0, 1.0))
	if not _logan_fired and _logan_draw_t >= LOGAN_DRAW_TIME:
		_logan_fired = true
		_sfx("ep2_revolver_blast_1")
		_hud.hurt()
		_hud.fade_to(1.0, 0.5)
		_hud.toast("LOGAN DOES NOT MISS", 1.6)
	if _logan_fired:
		_look_pitch = move_toward(_look_pitch, 0.9, delta * 1.4)     # he goes over backwards, looking at the sky
		eye_height = move_toward(eye_height, 0.35, delta * 2.2)
	if _logan_draw_t >= LOGAN_DRAW_TIME + LOGAN_DOWN_TIME and not _resolved:
		_resolve({"respawn_at_dude": true, "logan_shot": true, "companion": ""})


func logan_is_drawing() -> bool: return _logan_draw_t >= 0.0

## The ridge goes on from exactly here (river_cover.gd adopt_lake): where he stands, the way he looks.
func get_handoff() -> Dictionary:
	var result: Dictionary = super.get_handoff()
	result["ridge_from"] = _player_pos
	return result

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

func _build_ambience() -> void:
	var life := preload("res://src/episode2/art/ep2_lake_ambience.gd").new()
	life.name="LakeAmbience"
	_visuals.add_child(life)


# --- Dude's horse at the water ---------------------------------------------------------------------------------------

func _build_horse() -> void:
	if _horse != null:
		return
	_horse = Node3D.new()
	_horse.name = "LakeHorse"
	add_child(_horse)                     # not under _visuals: the trail preview copies _visuals onto its horizon
	var model: Node3D = null
	if ResourceLoader.exists(HORSE_MODEL):
		model = (load(HORSE_MODEL) as PackedScene).instantiate() as Node3D
	if model != null:
		model.rotation.y = -PI * 0.5      # the supplied horse faces +X; the actor faces local +Z (as on the trail)
		_horse.add_child(model)
		for node in model.find_children("*", "AnimationPlayer", true, false):
			_horse_anim = node as AnimationPlayer
			break
		if _horse_anim != null:
			for clip in _horse_anim.get_animation_list():
				_horse_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	else:
		var coat: StandardMaterial3D = _plain(Color(0.30, 0.16, 0.075), 0.92)
		_box(Vector3(0.76, 0.82, 1.75), Vector3(0.0, 1.02, 0.0), coat, _horse)
		_box(Vector3(0.40, 0.42, 0.70), Vector3(0.0, 1.62, 1.0), coat, _horse)
	# Dude's saddle and stirrups, the same leather as on the trail: it is the same horse.
	var leather: StandardMaterial3D = _plain(Color(0.16, 0.075, 0.035), 0.82)
	_box(Vector3(0.72, 0.13, 0.76), Vector3(0.0, SADDLE_HEIGHT, -0.15), leather, _horse)
	_box(Vector3(0.82, 0.07, 0.12), Vector3(0.0, SADDLE_HEIGHT + 0.11, -0.47), leather, _horse)
	for side in [-1.0, 1.0]:
		_box(Vector3(0.035, 0.52, 0.055), Vector3(side * 0.43, SADDLE_HEIGHT - 0.27, -0.12), leather, _horse)
		_box(Vector3(0.13, 0.035, 0.22), Vector3(side * 0.43, SADDLE_HEIGHT - 0.52, -0.12), leather, _horse)
	_place_horse(HORSE_DRINK, HORSE_DRINK_YAW)
	_set_horse_clip("horse_graze", 0.55)


func _ground_at(p: Vector3) -> float:
	return Ep2LoganCabin.walk_height(p) if p.x < -11.5 else path_height(p.z)


func _place_horse(at: Vector3, yaw: float) -> void:
	if _horse == null:
		return
	_horse.position = Vector3(at.x, _ground_at(at), at.z)
	_horse.rotation = Vector3(0, yaw, 0)


func _set_horse_clip(clip: String, speed_scale: float) -> void:
	_horse_clip = clip
	if _horse_anim == null:
		return
	if (_horse_anim.current_animation != clip or not _horse_anim.is_playing()) and _horse_anim.has_animation(clip):
		_horse_anim.play(clip, 0.25)
	_horse_anim.speed_scale = speed_scale


func _tick_horse(delta: float) -> void:
	if _horse == null:
		return
	match _horse_state:
		"lead":
			var to: Vector3 = HORSE_DRINK - Vector3(_horse.position.x, 0, _horse.position.z)
			to.y = 0.0
			if to.length() < 0.08:
				_horse_state = "drink"
			else:
				var step: Vector3 = to.normalized() * minf(to.length(), HORSE_WALK * delta)
				_place_horse(_horse.position + step, lerp_angle(_horse.rotation.y, atan2(to.x, to.z), clampf(delta * 4.0, 0.0, 1.0)))
				_set_horse_clip("horse_walk", HORSE_WALK / HORSE_CLIP_SPEED)
		"hurt", "gone":
			pass
		"drink":
			_horse.rotation.y = lerp_angle(_horse.rotation.y, HORSE_DRINK_YAW, clampf(delta * 2.5, 0.0, 1.0))
			_set_horse_clip("horse_graze", 0.55)
			_horse_sip_t -= delta
			if _horse_sip_t <= 0.0:
				_horse_sip_t = 6.5
				_sip()
		"ridden":
			if _mount_t >= 0.0:
				# he swings up as the horse steps back from the water onto the bank path: both meet at `_mount_to`
				_mount_t += delta
				var k: float = clampf(_mount_t / 0.6, 0.0, 1.0)
				var e: float = k * k * (3.0 - 2.0 * k)
				_player_pos = Vector3(_mount_from.x, _player_pos.y, _mount_from.z).lerp(Vector3(_mount_to.x, _player_pos.y, _mount_to.z), e)
				_place_horse(_mount_horse_from.lerp(_mount_to, e), _horse.rotation.y)
				_set_horse_clip("horse_walk", 0.6)
				if k >= 1.0:
					_mount_t = -1.0
			else:
				var moved: Vector3 = Vector3(_player_pos.x - _horse.position.x, 0, _player_pos.z - _horse.position.z)
				var yaw: float = _horse.rotation.y
				if moved.length() > 0.002:
					yaw = lerp_angle(yaw, atan2(moved.x, moved.z), clampf(delta * 8.0, 0.0, 1.0))
				_place_horse(_player_pos, yaw)
				var speed: float = moved.length() / maxf(delta, 0.0001)
				if _moving and speed > 0.05:
					_set_horse_clip("horse_walk", clampf(speed / HORSE_CLIP_SPEED, 0.4, 3.8))
				else:
					_set_horse_clip("horse_stand", 1.0)
			eye_height = move_toward(eye_height, MOUNTED_EYE, delta * 2.4)
		_:
			_set_horse_clip("horse_graze", 0.55)
			if not _riding:
				eye_height = move_toward(eye_height, FPS_EYE_HEIGHT, delta * 2.4)


func _sip() -> void:
	var stream: AudioStream = load("res://src/episode2/extras/audio/town/water_trough.ogg") if Ep2Extras.has("res://src/episode2/extras/audio/town/water_trough.ogg") else null
	if stream == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = "SFX"
	player.volume_db = -20.0
	player.unit_size = 3.0
	player.max_distance = 18.0
	add_child(player)
	player.position = _horse.position + _horse.basis * Vector3(0, 0.3, 1.2)
	player.play()
	player.finished.connect(player.queue_free)


## E mounts him whenever Logan is not mid-explanation and the horse is beside Lil Blunt.
func can_mount_horse() -> bool:
	# not while he is still walking himself down to the water, nor while Logan is explaining
	if _horse == null or _riding or _horse_state in ["lead", "hurt", "gone"] or _beat == Beat.INVESTIGATE or not has_player_control():
		return false
	return Vector2(_player_pos.x - _horse.position.x, _player_pos.z - _horse.position.z).length() < HORSE_REACH


func _mount() -> void:
	_riding = true
	_horse_state = "ridden"
	_mount_from = _player_pos
	_mount_horse_from = _horse.position
	_mount_to = _collide(Vector3(_horse.position.x, _player_pos.y, _horse.position.z))
	_mount_t = 0.0
	walk_speed = MOUNTED_SPEED


func _dismount() -> void:
	_riding = false
	_mount_t = -1.0
	_horse_state = "graze"
	walk_speed = _foot_speed
	# He slides off on the left and the horse stays where it stands, grazing, ready to be mounted again.
	var left: Vector3 = _horse.basis * Vector3(-1.2, 0, 0)
	_player_pos = _collide(_player_pos + Vector3(left.x, 0, left.z))


## True while Lil Blunt rides Dude's horse at the lake (the return trail keeps him mounted).
func is_riding_horse() -> bool:
	return _riding


func get_horse_node() -> Node3D:
	return _horse


func get_horse_state() -> String:
	return _horse_state


func get_horse_clip() -> String:
	return _horse_clip


## A later visit from the trail (world routes, no fresh setup): ridden in, he is still in the saddle; on foot, the horse stays
## wherever he left it at the water.
func arrive_from_trail(mounted: bool) -> void:
	if _logan_draw_t >= 0.0:                        # he rides back in after Logan shot him: Logan has put the gun away, and this is a new visit
		_logan_draw_t = -1.0
		_show_blocks_control = false
		eye_height = FPS_EYE_HEIGHT
		_look_pitch = 0.02
		if _logan != null:
			_logan.drop_prop("GoldenRemington")
			_logan.hold_clip("Idle")
		_hud.fade_to(0.0, 0.3)
		_hud.objective = "Logan's Lake · Meet Logan at the shore."
	if _horse == null:
		return
	if armory.horse_is_sound() and _horse_state in ["hurt", "gone"]:     # Dude has seen to it since
		_horse.visible = true
		_horse_state = "drink"
	if mounted:
		_riding = true
		_horse_state = "ridden"
		_mount_t = -1.0
		walk_speed = MOUNTED_SPEED
		eye_height = MOUNTED_EYE
		_place_horse(_player_pos, _look_yaw)
	else:
		_riding = false
		walk_speed = _foot_speed
		eye_height = FPS_EYE_HEIGHT

