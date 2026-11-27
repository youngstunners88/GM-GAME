class_name LogansLakeChamber
extends Ep2Interlude
## Founder lock 2026-10-18: investigate / stage depth, player investigates; Logan may fish as background lake life.
## The surface route continues here after Rich & Utah's gear. No currency writes or rewards.
signal shipment_staged

enum Beat { ARRIVE, INVESTIGATE, STAGE, HANDOFF, OVERLOOK, ROAD }
const LOGAN := "res://src/episode2/extras/lake/logan.glb"
const DOCK := "res://src/episode2/assets/lake/staging_dock.glb"
const SPAWN := Vector3(-8, 0, -13)
const LOGAN_MARK := Vector3(-3.4, 0, 8)
const ARRIVAL_SIGN := Vector3(-12, 0, -4) # opposite the water; leave the rider-to-Logan sightline open
const STAGING_MARK := Vector3(-4.5, 0, 17)
const CARGO_START_Z := 53.0
const CARGO_END_Z := 76.0
const CARGO_SHOT_SECONDS := 7.5
const CARGO_HANDOFF_LINE := "LOGAN: The depth holds. Follow the outflow to the high ground."
const OVERLOOK := Vector3(-8, 6, 61)
## Logan's lesson, three plain sentences for someone who has never heard of liquidity (founder 2026-11-15: "more to say about Liquidity Providing to
## help newbies understand in 3 sentences"): what a liquidity provider is, what still deep water buys you, and what the providers get and must not do.
const LINES := [
	"LOGAN: This lake is a liquidity pool: providers like me pour our coins in so everyone else can trade against them.",
	"LOGAN: Deep, still water means even a big trade barely ripples the price, so the deeper the lake, the safer it is to trade in.",
	"LOGAN: Providers earn a small fee on every trade, so keep the bank secure, check the cargo at that staging marker, and never empty the lake.",
]
## Logan starts talking when he sees Lil Blunt come down to the shore - [E] is no longer how you meet him (founder 2026-11-15).
const GREET_R := 6.5
var _logan: Ep2TownFolk
var _cargo: Node3D
var _cargo_wake: MeshInstance3D
var _cargo_shot_t: float = -1.0
var _line: int = 0
var _talk_t: float = 0.0
var _gesture_t: float = 0.0
var _staged: bool = false
var _sharps_told: bool = false                     # the overlook has told him the ridge needs the Sharps (once per climb)
var _dialogue: Label
var _dialogue_panel: PanelContainer
var _marker_label: TextMesh
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
const HORSE_SHOT_LINE := "LOGAN: That horse is shot. It won't drink like that. I've farrier salve for half a Bitcoin - or Dude swaps it for a whole one."
## AFTER DAY-88 (founder brief PROMPT_LAKE_HORSE_REPAIR_AUCTION_ROAD_2026-11-08): Utah has the Shipment, and the session comes back here with
## his horse already at the water. Logan keeps working stock on the far shore, patches a shot horse for half a Bitcoin (Dude's whole-Bitcoin
## swap stays the dear reset, back up the trail), and the signpost by the arrival path sends him on the short ride to the auction.
const LOGAN_SALVE_BTC := 0.5                      # half a Bitcoin; paid through Ep2ArmoryState.pay_half_btc (whole faces + banked change)
const SALVE_REACH := 4.2                          # beside the shot horse or beside Logan
const SALVE_LINE := "LOGAN: Hold him steady. Farrier salve on the cuts, legs are sound... There. He'll carry you to the auction."
const SALVE_SHORT_LINE := "LOGAN: Salve's half a Bitcoin and you're short. Come back with a coin, or walk him up to Dude's."
const AUCTION_SIGN := Vector3(-3.0, 0, -9.0)      # beside the arrival path, clear of Logan's sightline and the trail mouth
const AUCTION_REACH := 3.4
const STOCK_ANGLES := [-0.42, -0.14, 0.12, 0.38]  # radians around the lake centre: the far (east) shore, opposite Logan's landing
const STOCK_CLIPS := ["horse_graze", "horse_stand", "horse_graze", "horse_walk"]
var after_day88: bool = false
var _stock: Array[Node3D] = []
var _auction_sign: Node3D
var _salve_t: float = -1.0
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
const DEAD_ROLL := -1.46                          # this actor's root faces +Z, so its roll is the Z axis
const DEAD_LYING_Y := 0.27
var _horse_state: String = "drink"                # lead -> drink; ridden; graze (left where he dismounted); hurt; gone (came down on the trail); dead (shot here)
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
func _build_steps() -> Array: return [_light, _land, _water, _shore, _vegetation, _people, _build_skiff, _build_cabin, _build_ambience, _build_horse, _build_stock]

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

## A signpost on the ground at (p.x, p.z): the words painted on both faces of its board (Ep2Signpost, founder 2026-11-22 "the words are
## floating in mid air"). The readable side faces the arrival (-Z), as the old label did.
func _sign(words: String, p: Vector3, width: float = 2.6) -> TextMesh:
	var wood: Material = _tex(TIMBER_TEX, Color(0.50, 0.33, 0.18), 0.5)
	var foot := Vector3(p.x, Ep2LakeLandform.drawn_height(p.x, p.z), p.z)
	return Ep2Signpost.standard(_visuals, words, foot, PI, width, wood, 1.5, 0.7, 1.85)

func _shore() -> void:
	var dock: Node3D = (load(DOCK) as PackedScene).instantiate()
	dock.name = "StagingDock"
	dock.position = Vector3(0, 0, 10)
	_visuals.add_child(dock)
	_landscape.register_dock(dock)
	_sign("LOGAN'S LAKE", ARRIVAL_SIGN, 3.2)
	_sign("RIVER OVERLOOK  >", Vector3(-4, path_height(34), 34), 3.3)
	_marker_label = _sign("STAGED CARGO", STAGING_MARK + Vector3(1.1, 0, 0.5), 3.4)
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
	_cargo_shot_t = -1.0
	release_camera()
	if _cargo != null:
		_cargo.queue_free()
		_cargo = null
	if _cargo_wake != null:
		_cargo_wake.queue_free()
		_cargo_wake = null
	_gesture_t = 0
	Ep2Signpost.retext(_marker_label, "STAGED CARGO")
	if _logan != null: _logan.hold_clip("Idle")
	if _skiff != null: _skiff.reset_routine()
	Ep2Extras.start(self)
	_vm.set_world_shadows(false)
	# the same key on the held gun as on the trail he rides in from (and the town and woods): the gun does not darken at the shore
	_vm.set_own_light(WoodsQuadChamber.VM_KEY_ENERGY, _sun)
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
	var horse_yaw: float = float(handoff.get("lake_horse_yaw", _look_yaw))   # it keeps the heading it walked in on
	_logan_draw_t = -1.0
	after_day88 = bool(handoff.get("after_day88", false))
	_salve_t = -1.0
	if _auction_sign != null:
		_auction_sign.visible = after_day88
	if after_day88:
		# He comes back from Utah's dock and the horse is already at the water: never stranded at the river. Sound, it drinks;
		# shot (even shot down on the ridge), it limped back here and stands for Logan's salve.
		_horse.visible = true
		_place_horse(HORSE_DRINK, HORSE_DRINK_YAW)
		if armory.horse_is_sound():
			_horse_state = "drink"
		else:
			_horse_state = "hurt"
			_set_horse_clip("horse_stand", 0.6)
		_staged = true
		Ep2Signpost.retext(_marker_label, "CARGO CHECKED")
	elif armory.horse_is_down():
		_horse_state = "gone"                       # shot out from under him on the trail: there is no horse at the lake to water or ride
		_horse.visible = false
	elif not armory.horse_is_sound():
		_place_horse(slid_off_at, horse_yaw)        # it carried him here, shot, and stands where he got down: it will not drink, and it cannot be ridden
		_horse_state = "hurt"
		_set_horse_clip("horse_stand", 0.6)
	elif bool(handoff.get("arrived_mounted", false)) and slid_off_at.distance_to(HORSE_DRINK) < 40.0:
		_place_horse(slid_off_at, horse_yaw)
		_horse_state = "lead"
		# mid-stride in the first frame, at the trail's own step (not blended in from the build's grazing pose)
		_set_horse_clip("horse_walk", HORSE_WALK / HORSE_CLIP_SPEED)
		if _horse_anim != null and _horse_anim.has_animation("horse_walk"):
			_horse_anim.play("horse_walk", 0.0)
			_horse_anim.seek(float(handoff.get("horse_anim_pos", 0.0)), true)
	else:
		_place_horse(HORSE_DRINK, HORSE_DRINK_YAW)
		_horse_state = "drink"
	_clear_water()
	if after_day88:
		_advance_to(Beat.ROAD)
	elif armory.river_gear and armory.day88_outflow_started:
		_staged = true
		Ep2Signpost.retext(_marker_label, "SHIPMENT AWAY")
		_advance_to(Beat.HANDOFF)
	else:
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
			prebuild_requested.emit("river_cover")          # the ridge builds off screen from the first word: ready long before he walks on
			_hud.objective = "Investigate the depth. Listen to Logan."
			_say(LINES[0], 6.5)
			_gesture("Greet", 2.5)
		Beat.STAGE:
			if armory.river_gear:
				_build_staged_shipment()
				_hud.objective = "Check the Day-88 Shipment at Logan's staging marker."
			else:
				_hud.objective = "Buy the Day-88 Shipment at Rich & Utah's counter, then return here."
			if not armory.horse_is_sound() and not _horse_line_said:
				_horse_line_said = true                    # Logan can see what came up that trail: he says so, and nobody offers it water
				_say(HORSE_GONE_LINE if armory.horse_is_down() else HORSE_SHOT_LINE, 5.0)
		Beat.HANDOFF:
			prebuild_requested.emit("river_cover")          # the ridge builds off screen while he walks the shore trail
			_hud.objective = "Follow the shore trail to the river overlook."
		Beat.OVERLOOK:
			_hud.objective = "Day-88 river · climb to the ridge."
			_say("The shipment is downstream. Climb to the ridge to cover it.", 4.0)
		Beat.ROAD:
			_road_objective()
			prebuild_requested.emit("auction_road")          # the road (and the auction grounds) build behind the lake: one-frame hand-over at the sign
			_say("LOGAN: Day-eighty-eight's in, then. Your horse found the water before you did. The auction's a short ride east - go see who's taking numbers.", 7.5)

func start_rig(_payment: String = "") -> bool:
	if not has_player_control() or armory_open(): return false
	# NO [E] ARRIVALS (founder 2026-11-15: "it mustn't be something someone presses E to activate ... one world"): the ridge path and the road to
	# the auction both carry on by walking (the walk-on checks in _tick); [E] is only for doing things here.
	if _can_offer_salve():
		_buy_salve()
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
	if _beat == Beat.STAGE and armory.river_gear and _player_pos.distance_to(STAGING_MARK) < 2.8:
		_build_staged_shipment()
		_stage_calls += 1
		_show_blocks_control = true
		_hud.set_search_prompt("")
		_gesture("Point", 3.0)
		_cargo_shot_t = 0.0
		return true
	if can_mount_horse():
		_mount()
		return true
	return false

func _build_staged_shipment() -> void:
	if _cargo != null:
		return
	_cargo = Ep2ShipmentCrate.model(1.5)
	_cargo.position = _cargo_at(CARGO_START_Z)
	_visuals.add_child(_cargo)


func _cargo_at(z: float) -> Vector3:
	return Vector3(Ep2LakeLandform.flow_center(z), -0.23, z)


func _frame_cargo(snap: bool) -> void:
	var at: Vector3 = _cargo.position
	set_camera_shot(at + Vector3(5.7, 4.8, -8.2), at + Vector3(0, 0.3, 2.2), 48.0, snap)


func _advance_cargo_shot(delta: float) -> void:
	var previous: float = _cargo_shot_t
	_cargo_shot_t += delta
	# Give the crate a moment at rest, then accelerate as the channel takes it.
	var pull: float = clampf((_cargo_shot_t - 0.8) / (CARGO_SHOT_SECONDS - 0.8), 0.0, 1.0)
	_cargo.position = _cargo_at(lerpf(CARGO_START_Z, CARGO_END_Z, pow(pull, 1.45)))
	_cargo.position.y += 0.055 * sin(_cargo_shot_t * 5.0)
	_cargo.rotation.z = sin(_cargo_shot_t * 5.0) * 0.055
	_frame_cargo(is_zero_approx(previous))
	if pull > 0.06:
		if _cargo_wake == null:
			var plane := PlaneMesh.new()
			plane.size = Vector2(2.2, 4.6)
			var foam := ShaderMaterial.new()
			foam.shader = preload("res://src/episode2/art/lake_wake.gdshader")
			_cargo_wake = MeshInstance3D.new()
			_cargo_wake.mesh = plane
			_cargo_wake.material_override = foam
			_cargo_wake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_visuals.add_child(_cargo_wake)
		_cargo_wake.position = Vector3(_cargo.position.x, -0.13, _cargo.position.z - 2.2)
	if previous < 4.0 and _cargo_shot_t >= 4.0:
		_say(CARGO_HANDOFF_LINE, 3.2)
	if _cargo_shot_t < CARGO_SHOT_SECONDS:
		return
	_cargo_wake.queue_free()
	_cargo_wake = null
	_cargo_shot_t = -1.0
	_show_blocks_control = false
	release_camera()
	armory.mark_day88_outflow_started()
	_staged = true
	Ep2Signpost.retext(_marker_label, "SHIPMENT AWAY")
	_advance_to(Beat.HANDOFF)
	shipment_staged.emit()


## The ridge takes the launched crate when it adopts this shoreline.
func take_staged_shipment() -> Node3D:
	var shipment: Node3D = _cargo
	_cargo = null
	return shipment


func _tick(delta: float) -> void:
	if _logan_draw_t >= 0.0:
		_tick_logan_draw(delta)
		return
	_tick_horse(delta)
	_tick_salve(delta)
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
		if _beat == Beat.ROAD:
			_road_objective()
		else:
			_on_beat_entered(_beat)
	_build_skiff()
	# A Continue can arrive before the extras pack. Recreate the staged model once Logan's assets are ready.
	if _staged and not after_day88 and _cargo == null:
		_build_staged_shipment()
		_cargo.position = _cargo_at(CARGO_END_Z)
	_logan.step(delta)
	if _player_pos.distance_to(LOGAN_MARK) < 7:
		_logan.face_point(_player_pos)
	if _beat == Beat.ARRIVE and _player_pos.distance_to(LOGAN_MARK) < GREET_R and has_player_control():
		_advance_to(Beat.INVESTIGATE)                    # he sees him: the talk begins by itself
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
	if _cargo_shot_t >= 0.0:
		_advance_cargo_shot(delta)
		return
	var prompt := ""
	if _beat == Beat.ARRIVE and _player_pos.distance_to(LOGAN_MARK) < 3.2:
		prompt = ""
	elif _beat == Beat.STAGE and armory.river_gear and _player_pos.distance_to(STAGING_MARK) < 2.8:
		prompt = "Check Day-88 Shipment [E]"
	elif _beat == Beat.ROAD and _near_auction_sign() and not _can_leave_for_auction():
		prompt = "Patch the horse first: Logan's salve or Dude" if _horse_state == "hurt" else "Mount your horse first"
	elif _can_offer_salve():
		prompt = ("Logan's salve · 0.5 BTC [E]" if armory.can_pay_half_btc() else "Logan's salve · 0.5 BTC (short) · or Dude, 1 BTC")
	elif _riding:
		prompt = "Dismount [E]"
	elif can_mount_horse():
		prompt = "Mount the horse [E]"
	elif _horse_state == "hurt" and Vector2(_player_pos.x - _horse.position.x, _player_pos.z - _horse.position.z).length() < HORSE_REACH:
		prompt = "The horse is shot: Logan's salve (0.5 BTC) or Dude's swap (1 BTC)"
	if prompt != "" and not TouchUi.keys_shown():
		prompt = prompt.replace(" [E]", "")
	_hud.set_search_prompt(prompt)
	if _skiff != null:
		_skiff.advance(delta, _staged and _talk_t <= 0.0)
	if _beat == Beat.HANDOFF and _player_pos.z > 59:
		_advance_to(Beat.OVERLOOK)
	# walking on up the path is enough: the ridge continues from here, [E] only says so sooner. Never waits on a line (founder
	# 2026-11-07 "no pause climbing the hill from the cargo check"): the ridge carries the caption on (RiverCoverChamber.adopt_lake)
	if _beat == Beat.OVERLOOK and _staged and armory.river_gear and armory.day88_outflow_started and _player_pos.z >= WALK_ON_Z and not _resolved and has_player_control() and _handoff_ok():
		if armory.sniper_owned:
			_resolve({"next_chamber": "river_cover", "lake_complete": true, "river_ready": true, "companion": ""})
		elif not _sharps_told:
			# The ridge cannot be covered without the long rifle, and there is no way back down from it: he is turned round HERE, where the
			# trail to Rich & Utah's counter is still open (audit 2026-11-17: the ridge's only answer was to end the run).
			_sharps_told = true
			_hud.objective = "The day-88 run needs the Sharps buffalo gun from Rich & Utah's counter. Ride back to town for it."
			_hud.toast("NO SHARPS  -  BACK TO RICH & UTAH'S", 3.4)
	elif _sharps_told and _player_pos.z < WALK_ON_Z - 4.0:
		_sharps_told = false                           # said again each time he climbs back up without it
	# the road to the auction is the same: riding (or walking, when the horse is gone) past the signpost IS leaving - no key
	if _beat == Beat.ROAD and _on_road_start() and _can_leave_for_auction() and not _resolved and has_player_control() and _handoff_ok():
		_leave_for_auction()

func _collide(p: Vector3) -> Vector3:
	if Ep2LoganCabin.YARD.has_point(Vector2(p.x, p.z)) or (_player_pos.x < -11.5 and p.x < -11.5):
		return Ep2LoganCabin.collide(p)
	if _on_road_band(p):
		return p                                       # off the path at the signpost onto the auction road (its cut, one world)
	var q := p
	q.z = clampf(q.z, -16, 64)
	# up the overlook path the bank narrows to the ridge trail's own width (RiverCoverChamber.RIDGE_HALF about its first point), so the
	# ridge takes him on where he stands instead of pushing him sideways in the frame it takes over
	var narrow: float = clampf((q.z - 50.0) / 10.0, 0.0, 1.0)
	q.x = clampf(q.x, lerpf(-11.5, -10.9, narrow), lerpf(-4.1, -5.2, narrow))
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
	if _horse != null and _horse.visible and _horse_state != "dead" and _bullet_hits_horse():
		_wound_lake_horse()
		return
	if _player_pos.distance_to(LOGAN_MARK) < 35:
		if _talk_t <= 0.0:   # heard, not toasted (founder 2026-11-22 "no subtitles"); never cut a lesson line short
			_say("LOGAN: Easy. Keep the staging bank secure.", 2.5)


func _bullet_hits_horse() -> bool:
	var eye: Vector3 = _player_pos + Vector3(0, eye_height, 0)
	var cp: float = cos(_look_pitch)
	var dir := Vector3(sin(_look_yaw) * cp, sin(_look_pitch), cos(_look_yaw) * cp)
	# The actor faces +Z (the model inside it is turned), so that is the length of the body.
	var centre: Vector3 = _horse.global_position + Vector3(0, 1.05, 0)
	var axis: Vector3 = _horse.global_transform.basis.z.normalized()
	return WoodsQuadChamber._ray_capsule(eye, dir, centre - axis * 0.92, centre + axis * 0.92, 0.61) >= 0.0


## Dude's horse is a creature here too. A shot wounds it through the same travelling state as the trail, and the third puts it
## down: it falls and lies where it stood, and Lil Blunt simply walks. Dude patches it up on the road back, so this is never a dead
## end. A wound in the saddle puts him down at once: the "hurt" rule says nobody rides a shot horse.
func _wound_lake_horse() -> void:
	armory.wound_horse()
	_horse_whinny()
	if _riding:
		_dismount()
	if _hud != null:
		_hud.hit_marker(armory.horse_is_down())
	if armory.horse_is_down():
		_horse_state = "dead"
		if _horse_anim != null:
			_horse_anim.pause()
		Ep2CreatureHealth.topple(_horse, _horse.rotation.x, DEAD_ROLL, _horse.position.y + DEAD_LYING_Y)
	else:
		_horse_state = "hurt"
		_set_horse_clip("horse_stand", 0.6)


func _horse_whinny() -> void:
	var path := "res://src/episode2/extras/audio/town/horse_whinny.ogg"
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	p.stream = load(path) as AudioStream
	p.volume_db = -3.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


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
	_say("LOGAN: Wrong water to start a fight.", 1.6)   # recorded take (logan_wrong_water); the box only shows if the take is missing


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
	result["eye"] = eye_height
	result["road_mounted"] = _riding
	return result

## At the top of the shore path with the ridge not yet built: the root spends more of each frame on it (never seen when built early).
func _wants_handoff() -> bool: return (_beat == Beat.OVERLOOK and _staged and _player_pos.z > 59 and armory.river_gear and armory.day88_outflow_started and armory.sniper_owned) or (_beat == Beat.ROAD and _near_auction_sign() and _can_leave_for_auction())

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
	Ep2HorseCoat.apply(_horse, Ep2HorseCoat.ridden)     # founder 2026-11-17: the same horse he rode in on - same coat, no saddle appearing at the water
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
		"hurt", "gone", "dead":
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
	if _horse == null or _riding or _horse_state in ["lead", "hurt", "gone", "dead"] or _beat == Beat.INVESTIGATE or not has_player_control():
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
	_clear_water()
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
	if _beat == Beat.ROAD:
		_road_objective()


## The trail clears this same water material by his distance to Logan as he rides in (LakeTrailChamber.water_clarity); at the shore it is
## clear, and it stays clear here whatever way he arrived.
func _clear_water() -> void:
	if _landscape.water_material != null:
		_landscape.water_material.set_shader_parameter("clarity", 1.0)


# --- After day-88: Logan's stock, his salve, and the road on to the auction (founder brief 2026-11-08) ----------------------------

## Background stock on the far (east) shore: Logan's working horses, the same supplied horse, each on its own idle/drink loop.
## Placements only - no ride AI, no herd logic. Also builds the auction signpost (shown only after day-88).
func _build_stock() -> void:
	if not _stock.is_empty():
		return
	var scene: PackedScene = load(HORSE_MODEL) if ResourceLoader.exists(HORSE_MODEL) else null
	for i in STOCK_ANGLES.size():
		var a: float = float(STOCK_ANGLES[i])
		var r: float = 1.07 * Ep2LakeLandform.rim_radius(a)
		var x: float = Ep2LakeLandform.CENTER_X + Ep2LakeLandform.RADIUS_X * r * cos(a)
		var z: float = 20.0 + Ep2LakeLandform.RADIUS_Z * r * sin(a)
		var actor := Node3D.new()
		actor.name = "LoganStock%d" % i
		_visuals.add_child(actor)
		actor.position = Vector3(x, terrain_height(x, z), z)
		actor.rotation.y = atan2(Ep2LakeLandform.CENTER_X - x, 20.0 - z)   # muzzle to the water
		var model: Node3D = scene.instantiate() as Node3D if scene != null else null
		if model != null:
			model.rotation.y = -PI * 0.5
			actor.add_child(model)
			var anim: AnimationPlayer = null
			for node in model.find_children("*", "AnimationPlayer", true, false):
				anim = node as AnimationPlayer
				break
			if anim != null:
				var clip: String = str(STOCK_CLIPS[i])
				if not anim.has_animation(clip):
					clip = "horse_graze"
				if anim.has_animation(clip):
					anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
					anim.play(clip)
					anim.speed_scale = 0.0 if clip == "horse_walk" else 0.5 + 0.08 * i   # a walk clip held mid-stride reads as standing
					anim.seek(1.3 * i, true)
		else:
			_box(Vector3(0.76, 0.82, 1.75), Vector3(0.0, 1.02, 0.0), _plain(Color(0.33, 0.2, 0.11)), actor)
		_stock.append(actor)
	_auction_sign = Node3D.new()
	_auction_sign.name = "AuctionSign"
	_visuals.add_child(_auction_sign)
	_auction_sign.position = Vector3(AUCTION_SIGN.x, Ep2LakeLandform.drawn_height(AUCTION_SIGN.x, AUCTION_SIGN.z), AUCTION_SIGN.z)
	var wood: StandardMaterial3D = _plain(Color(0.36, 0.24, 0.13), 0.9)
	Ep2Signpost.standard(_auction_sign, "AUCTION GROUNDS  >", Vector3.ZERO, 0.0, 2.3, wood, 1.85, 0.46, 2.1, Color(0.95, 0.88, 0.7))
	_auction_sign.visible = after_day88


func get_stock_count() -> int:
	return _stock.size()


func _road_objective() -> void:
	if armory.horse_is_sound() or _horse_state == "dead":
		_hud.objective = "Ride to the auction grounds · the signpost by the arrival path."
	else:
		_hud.objective = "Your horse is shot · Logan's salve (0.5 BTC) here, or Dude's swap (1 BTC) back up the trail."


## The auction road leaves the path at its signpost (Ep2LakeLandform.ROAD_FROM, south-east through the lake's own cut). Once the signpost
## is up he may ride off the path onto the road's width; crossing its start line hands him to the road room, exactly where he is.
func _on_road_band(p: Vector3) -> bool:
	if _auction_sign == null or not _auction_sign.visible:
		return false
	var f: Vector2 = Ep2LakeLandform.road_frame(p.x, p.z)
	return f.x >= -3.0 and f.x <= 12.0 and absf(f.y) <= AuctionRoadChamber.NEAR_LAKE_HALF


func _on_road_start() -> bool:
	var f: Vector2 = Ep2LakeLandform.road_frame(_player_pos.x, _player_pos.z)
	# the line is half a metre before the signpost (road s START_S - 0.5); the road hands him back only a metre further behind it
	return f.x >= -0.5 and f.x <= 12.0 and absf(f.y) <= AuctionRoadChamber.NEAR_LAKE_HALF + 0.5


## THE ROAD AHEAD: once the road room is built behind the lake, its visuals are copied here in their place (the road strip, the open
## ground past the lake's terrain, the claim wagon, the auction grounds far off), one root child per frame, as the trail shows the lake.
var _road_ahead: Node3D = null
var _road_copied: Dictionary = {}
func preview_road(room: Node) -> void:
	var visuals: Node3D = room.get("_visuals")
	if visuals == null:
		return
	if _road_ahead == null:
		_road_ahead = Node3D.new()
		_road_ahead.name = "RoadAhead"
		_road_ahead.transform = AuctionRoadChamber.lake_xform().affine_inverse()
		_visuals.add_child(_road_ahead)
	for child in visuals.get_children():
		if child.name in ["Desert", "LakeBehind", "Player"] or _road_copied.has(child.get_instance_id()):
			continue
		var copy: Node = child.duplicate(0)            # visual hierarchy only; never run duplicated constructors
		copy.process_mode = Node.PROCESS_MODE_DISABLED
		if child.name == "DesertBeyond":
			(copy as Node3D).visible = true
		_road_ahead.add_child(copy)
		_road_copied[child.get_instance_id()] = copy
		break


func _near_auction_sign() -> bool:
	return Vector2(_player_pos.x - AUCTION_SIGN.x, _player_pos.z - AUCTION_SIGN.z).length() < AUCTION_REACH


## Mounted by default. On foot only when there is no horse left to ride (shot dead at the water); a shot horse is patched first.
func _can_leave_for_auction() -> bool:
	if has_meta("road_parked"):
		return false                  # the road he already rode is kept: the world routes carry him onto it (one world)
	return _riding or _horse_state == "dead"


func _leave_for_auction() -> void:
	_resolve({"next_chamber": "auction_road", "road_mounted": _riding, "lake_return": true, "companion": ""})


## Logan's farrier salve: beside the shot horse or beside Logan, any visit, while Logan is not drawing on him.
func _can_offer_salve() -> bool:
	if _horse == null or _horse_state != "hurt" or _salve_t >= 0.0 or _logan_draw_t >= 0.0 or not has_player_control():
		return false
	var by_horse: bool = Vector2(_player_pos.x - _horse.position.x, _player_pos.z - _horse.position.z).length() < SALVE_REACH
	return by_horse or _player_pos.distance_to(LOGAN_MARK) < SALVE_REACH


## Pay half a Bitcoin, then a short beat of Logan working the salve in; short of coin is a clear line, never a lock.
func _buy_salve() -> bool:
	if not armory.pay_half_btc():
		_say(SALVE_SHORT_LINE, 5.0)
		return false
	_salve_t = 0.0
	_hud.toast("LOGAN'S SALVE · -0.5 BTC", 2.5)
	_say(SALVE_LINE, 5.5)
	if _logan != null:
		_gesture("Greet", 2.5)
	return true


func _tick_salve(delta: float) -> void:
	if _salve_t < 0.0:
		return
	_salve_t += delta
	if _logan != null and _horse != null:
		_logan.face_point(_horse.position)
	if _salve_t >= 3.0:
		_salve_t = -1.0
		armory.treat_horse()
		_horse_state = "drink"                      # patched up: it walks its nose back down to the water, rideable again
		if _beat == Beat.ROAD:
			_road_objective()


func salve_running() -> bool:
	return _salve_t >= 0.0
