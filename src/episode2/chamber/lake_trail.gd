class_name LakeTrailChamber
extends Ep2Interlude
## THE RIDE TO LOGAN'S LAKE (founder lock 2026-10-27). Dude's horse is transport, not a protocol: Lil Blunt waters it at
## Logan's Lake before Logan teaches him about liquidity and the day-88 river shipment. The room is one continuous first-person
## trail: desert, two bandit ambushes, a chasing rider, then trees and the glint of the lake. The lake room is built behind this
## one from the first moment of the ride, and the arrival waits for that build rather than freezing at the cut.
##
## Mounted: W/S ride forward/back relative to the view, A/D choose a lane inside +/-2.2 m, and the mouse looks
## freely through 360 degrees. Bandits always rise, draw, bark and show a gun glint for 0.8-1.2 seconds before firing.
## Three hearts belong to Lil Blunt; the horse has three separate wounds. Losing the horse is a playable UNHORSE event, not a game
## over: the camera stumbles down and rolls, then the trail continues on foot. Losing all hearts restores the whole attempt.

enum Beat { RIDE, SHORE, DONE }

const HORSE_MODEL := "res://src/episode2/assets/town/horse.glb"
const COWBOY_MODEL := "res://src/episode2/assets/town/cowboy.glb"
const WATER_SHADER := "res://src/episode2/art/water_river.gdshader"
const BLOOD_FX := "res://src/episode2/fx/ep2_blood_fx.gd"

const CRUISE_SPEED := 5.5
const MIN_RIDE_SPEED := -7.0
const MAX_RIDE_SPEED := 7.0
const FOOT_SPEED := 2.9
const LANE_LIMIT := 2.2
## The open ranch ground hands the horse to the trail once he is on the visible road (5.8 m wide: +-2.9, plus the horse) past 65 m...
const DEPART_CAPTURE_R := 3.6
## ...or, wherever the departure bounds would stop him, within this far of the road: the bound is the trail's way in, never a wall
## (founder 2026-11-03 "an invisible wall prevents the horse from moving forward": the old 2 m capture let a rider on the road's edge
## ride into the z = -80 bound and stop dead).
const DEPART_EDGE_CAPTURE_R := 16.0
const LANE_SETTLE := 3.0                       # m/s: a hand-off from beside the road eases onto the trail lane, never a snap
const LANE_RATE := 3.2
const LOOK_LIMIT := PI # Full azimuth; never clamp a combat camera.
const MOUNTED_EYE := 2.18
const SADDLE_HEIGHT := 1.28
const HORSE_CLIP_SPEED := 1.9          # ground metres per second represented by horse_walk at speed_scale 1
const HEALTH_MAX := 3
const HORSE_HP_MAX := 3
const SHOT_RANGE := 54.0
const AMBUSH_AHEAD := 48.0
const AMBUSH_BEHIND := 14.0
const RIDER_START_S := 215.0
const RIDER_END_S := 294.0
const UNHORSE_SECONDS := 1.4
const SHORE_SECONDS := 8.0
const LAKE_REVEAL_DISTANCE := 130.0     # founder 2026-11-01: a longer, readable shore approach (was 80 m)

## Catmull-Rom control points (x, z). The sampled route is about 560 m long.
const TRAIL_POINTS: Array = Ep2LakeRoad.POINTS
var _road_survey: Node3D
## Six men at each of two ambushes. `lat` is lateral metres from the trail; negative and positive sides alternate.
const BANDIT_SPECS: Array = [
	{"s":220.0,"lat":9.0,"ambush":0},{"s":234.0,"lat":-10.0,"ambush":0},
	{"s":248.0,"lat":11.0,"ambush":0},{"s":381.0,"lat":-9.0,"ambush":1},
	{"s":448.0,"lat":10.0,"ambush":1},{"s":461.0,"lat":-11.0,"ambush":1},
	{"s": 140.0, "lat": -8.5, "ambush": 0}, {"s": 151.0, "lat": 9.5, "ambush": 0},
	{"s": 162.0, "lat": -11.0, "ambush": 0},
	{"s": 176.0, "lat": 9.0, "ambush": 0}, {"s": 192.0, "lat": -8.0, "ambush": 0}, {"s": 315.0, "lat": 10.5, "ambush": 1},
	{"s": 327.0, "lat": -9.0, "ambush": 1},
	{"s": 352.0, "lat": -9.0, "ambush": 1}, {"s": 368.0, "lat": 11.0, "ambush": 1},
	{"s": 405.0, "lat": -10.0, "ambush": 1}, {"s": 421.0, "lat": 9.0, "ambush": 1}, {"s": 339.0, "lat": 12.0, "ambush": 1},
]
const BANDIT_BARKS: Array = ["jh_bandit_1", "jh_bandit_2", "jh_bandit_3"]
## TWO KINDS OF AMBUSHER (founder 2026-11-01: "some of the bandits actually run towards Lil Blunt while some hide behind the rocks").
## Holdouts stay crouched below their rock's crest and only rise to telegraph and fire. Rushers break cover when he comes in range and
## run at him across the open ground, stopping at the trail's edge or a few metres short of him, then fight standing in the open.
## Both keep the full rise / Draw / glint tell before every shot - nothing fires from stealth.
const RUSHER_SLOTS: Array = [1, 3]           # bandit index % 5 in these slots is a rusher (7 of the 18)
const RUSH_SPEED := 4.6
const RUSH_STANDOFF := 7.0
const RUSH_TRAIL_EDGE := 2.8
const RUSH_MAX_SECONDS := 6.0
const HOLDOUT_HIDE := 0.78                   # crouch depth: the head stays below the 1.1 m rock crest
## The chasing rider SITS the saddle (founder: mounted bandits "are actually standing on the horse. They need to be riding"): a rigged
## townsman with the ranch's solved RanchRide pose (Ep2RanchPose, the same seat Dude rides), hips placed on the saddle.
const RIDER_MODELS: Array = ["res://src/episode2/extras/people/townsman_rancher.glb", "res://src/episode2/assets/town/stable_assistant.glb"]
const RIDER_HIP_LIFT := 0.1
const LB_LINES: Dictionary = {
	"trail_lb_start": "Logan's Lake first. Dude's horse needs water in this heat.",
	"trail_lb_ambush": "Hammer's men on the ridge! Keep moving.",
	"trail_lb_unhorse": "She's down! Easy, girl... I'll finish this on foot.",
	"trail_lb_lake": "Logan's Lake. Easy, girl - drink up. Then I'll go find Logan.",
}
const BANDIT_TINTS: Array = [Color(0.34, 0.055, 0.035), Color(0.08, 0.13, 0.24), Color(0.38, 0.25, 0.07)]

var _route_pts: PackedVector3Array = PackedVector3Array()
var _route_arc: PackedFloat32Array = PackedFloat32Array()
var _route_total: float = 0.0
var _route_s: float = 0.0
var _speed: float = 0.0
var _town_walls: Array = []
var _town_props: Array = []
var _departure_yard: Ep2StableYard = null
var _return_crowd: Ep2TownPeople = null
var _in_departure_area: bool = true
var _lane: float = 0.0
var _travel_yaw: float = 0.0
var _previous_travel_yaw: float = 0.0
var _mounted: bool = true
var _ending: bool = false
var _end_t: float = 0.0
var _trail_time: float = 0.0

var _horse: Node3D = null
var _horse_anim: AnimationPlayer = null
var _horse_clip: String = ""
var _horse_hp: int = HORSE_HP_MAX
var _horse_left: bool = false
var _unhorse_active: bool = false
var _unhorse_t: float = 0.0
var _unhorse_events: int = 0
var _unhorse_roll: float = 0.0

var _bandits_root: Node3D = null
var _bandits: Array = []
var _bandits_down: int = 0
var _first_ambush_said: bool = false
## THE BUFFALO STAMPEDE (Ep2Stampede, founder 2026-11-01 "Guns Buff" §5): once per save, between the first ambush and the chasing rider.
const STAMPEDE_S := 165.0
var _stampede: Ep2Stampede = null
var _carrion: Ep2CarrionVultures = null
var _bandit_voice: AudioStreamPlayer3D
var _flashes: Array = []
var _blood_marks: Array = []
var _sand_material: ShaderMaterial
var _ecotone_material: ShaderMaterial
var _desert_env: Environment
var _lake_reference: Node3D
var _lake_preview: Node3D
var _preview_copied: Dictionary = {}
var _preview_nodes: Array = []
var _rng := RandomNumberGenerator.new()
var _health: int = HEALTH_MAX
var _invuln: float = 0.0
var _failing: bool = false
var _fail_t: float = 0.0
var _attempt: int = 0
var _armory_snapshot: Dictionary = {}
## Tests only: a full-travel run that must not be ended by the fight. Combat and damage are tested separately.
var debug_invulnerable: bool = false


func _init() -> void:
	title_card = "THE RIDE TO LOGAN'S LAKE"
	music_path = ""
	walk_speed = FOOT_SPEED
	viewmodel_exposure = 0.8
	camera_min = Vector3(-180.0, 0.3, -650.0)
	camera_max = Vector3(650.0, 60.0, 680.0)
	_rng.seed = 1886


func _chamber_id() -> String:
	return "lake_trail"


func _beat_label(b: int) -> String:
	return Beat.keys()[clampi(b, 0, Beat.size() - 1)]


# --- set -------------------------------------------------------------------------------------------------------------

func _build_steps() -> Array:
	return [_step_light, _step_path, _step_ground, _step_trail, _step_desert, _step_lake, _step_horse, _step_departure_yard, _step_departure_space, _step_departure_crowd, _step_bandits, _build_vultures, _step_warm_music]


## The ride song (2.5 MB) is read here, in a budgeted build step, not in the frame he swings into the saddle: that read used to land in
## the hand-over frame on top of the swap (founder 2026-11-01: the music "is not smooth ... a glitch" when mounting).
func _step_warm_music() -> void:
	Ep2DrawMusic.warm_trail()


func _warm_views() -> Array:
	var first: Array = _route_sample(0.0)
	var ambush: Array = _route_sample(105.0)
	var shore: Array = _route_sample(maxi(0, int(_route_total) - 35))
	return [
		{"eye": (first[0] as Vector3) + Vector3(0.0, MOUNTED_EYE, 0.0), "yaw": float(first[1]), "pitch": -0.08},
		{"eye": (first[0] as Vector3) + Vector3(0.0, MOUNTED_EYE, 0.0), "yaw": float(first[1]) + 0.8, "pitch": -0.1},
		{"eye": (ambush[0] as Vector3) + Vector3(0.0, MOUNTED_EYE, 0.0), "yaw": float(ambush[1]), "pitch": -0.04},
		{"eye": (shore[0] as Vector3) + Vector3(0.0, MOUNTED_EYE, 0.0), "yaw": float(shore[1]), "pitch": -0.03},
	]


func _step_light() -> void:
	var env := Environment.new()
	_env_node.environment = env
	Ep2GoldTown.apply_desert_grade(env, _sun, 1.0)
	_desert_env=env.duplicate(true)
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 85.0
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS


func _step_path() -> void:
	_route_pts = _smooth(TRAIL_POINTS, 1.5)
	_route_arc = PackedFloat32Array()
	_route_arc.append(0.0)
	var total: float = 0.0
	for i in range(1, _route_pts.size()):
		total += _route_pts[i].distance_to(_route_pts[i - 1])
		_route_arc.append(total)
	_route_total = total


func _step_departure_yard() -> void:
	# Town, ranch, river, train and landmark placements share the town's actual survey.
	# Only the origin changes: the saddle is (0,0,0). The town remains behind us.
	var parent := Node3D.new()
	parent.name = "DepartureTown"
	_visuals.add_child(parent)
	parent.position = -GoldTownChamber.DEPART_HORSE
	var survey: Dictionary = Ep2GoldTown.build(parent, true, false)
	_town_walls = survey.get("walls", [])
	_town_props = survey.get("props", [])
	_departure_yard = parent.find_child("StableYard", true, false) as Ep2StableYard
	# The purchased horse is beneath the camera, never duplicated in the paddock.
	if _departure_yard != null and _departure_yard.horses.size() > 1:
		_departure_yard.horses[1].hide()
		for entry in _departure_yard._solids.duplicate():
			if entry[0] == _departure_yard.horses[1]:
				_town_props.erase(entry[1])
				_departure_yard._solids.erase(entry)
	_departure_survey = survey
	_departure_parent = parent


## The town crowd behind the departure is its own two steps (graph, people), not part of the town step (founder 2026-11-01: no stalls).
var _departure_survey: Dictionary = {}
var _departure_parent: Node3D = null
func _step_departure_space() -> void:
	_return_crowd = Ep2TownPeople.new()
	_return_crowd.configure_space(_departure_survey)


func _step_departure_crowd() -> void:
	if _return_crowd != null and _departure_parent != null:
		_return_crowd.build(_departure_parent)

func _step_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "TrailDesertFloor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(1400.0, 1300.0)
	ground.mesh = plane
	_sand_material=ShaderMaterial.new()
	_sand_material.shader=load("res://src/episode2/art/trail_sand.gdshader")
	_sand_material.set_shader_parameter("sand",load("res://src/episode2/assets/town/tex_desert.jpg"))
	_sand_material.set_shader_parameter("lake_inverse",lake_transform().affine_inverse())
	if ResourceLoader.exists(Ep2LakeLandscape.FLOOR):
		_sand_material.set_shader_parameter("forest",load(Ep2LakeLandscape.FLOOR))
		_sand_material.set_shader_parameter("has_forest",true)
		var start: Vector3 = lake_transform().affine_inverse() * _route_pts[0]
		_sand_material.set_shader_parameter("approach_dir",(Vector2(start.x, start.z) - Vector2(Ep2LakeLandform.CENTER_X, 20.0)).normalized())
	ground.material_override = _sand_material
	ground.position = Vector3(170.0, -0.012, -140.0)
	_visuals.add_child(ground)


func _step_trail() -> void:
	_road_survey=Ep2LakeRoad.build(_visuals)

	var ecotone := ShaderMaterial.new()
	_ecotone_material=ecotone
	ecotone.shader=load("res://src/episode2/art/trail_ecotone.gdshader")
	ecotone.set_shader_parameter("lake_inverse",lake_transform().affine_inverse())
	ecotone.set_shader_parameter("sand",load("res://src/episode2/assets/town/tex_desert.jpg"))
	ecotone.set_shader_parameter("forest",load(Ep2LakeLandscape.FLOOR))
	var field: MeshInstance3D = _ribbon(_route_pts,190.0,ecotone,0.006)
	field.name="GradualGrassApproach"
	_build_lake_signpost()


## A trail sign well before the shore (founder 2026-11-01: "we cant anticipate that Logan is in the distance"): it names the lake and
## Logan's camp and points at the smoke column the lake room raises beside his landing.
const SIGNPOST_BEFORE_END := 175.0
func _build_lake_signpost() -> void:
	var sample: Array = _route_sample(_route_total - SIGNPOST_BEFORE_END)
	var yaw: float = float(sample[1])
	var right := Vector3(-cos(yaw), 0.0, sin(yaw))
	var root := Node3D.new()
	root.name = "LogansLakeSignpost"
	_visuals.add_child(root)
	root.position = (sample[0] as Vector3) - right * 3.4
	root.rotation.y = yaw + PI            # the board faces the oncoming rider
	var wood: Material = _plain(Color(0.42, 0.27, 0.14), 0.9)
	_box(Vector3(0.16, 2.6, 0.16), Vector3(0, 1.3, 0), wood, root)
	_box(Vector3(2.5, 0.62, 0.1), Vector3(0, 2.05, 0), wood, root)
	_box(Vector3(1.9, 0.42, 0.1), Vector3(0.18, 1.42, 0), wood, root)
	for row in [["LOGAN'S LAKE", 2.05, 44], ["LOGAN'S CAMP AHEAD", 1.42, 30]]:
		var label := Label3D.new()
		label.text = str(row[0])
		label.position = Vector3(0, float(row[1]), 0.06)      # the rider's side of the board (root +Z points back at him)
		label.font_size = int(row[2])
		label.pixel_size = 0.0095
		label.modulate = Color(0.97, 0.84, 0.56)
		label.outline_size = 4
		root.add_child(label)


func _step_desert() -> void:
	var meshes: Array = Ep2GoldTown.desert_meshes()
	Ep2GoldTown.build_desert(_visuals, TRAIL_POINTS, -650.0, 300.0, meshes[0], meshes[1],
		Ep2GoldTown.scrub_mat(), Ep2GoldTown.desert_rock_mat(), 365.0)


func _step_lake() -> void:
	# Use the lake's authored firs on the approach, rather than primitive tree stand-ins.
	if not Ep2Extras.has(Ep2LakeLandscape.KIT): return
	var kit: Node3D=(load(Ep2LakeLandscape.KIT) as PackedScene).instantiate()
	var landscape:=Ep2LakeLandscape.new()
	var placements: Array=[]
	for i in 100:
		var progress: float=float(i)/99.0
		var sample: Array=_route_sample(180.0+(1.0-pow(1.0-progress,0.65))*(_route_total-180.0))
		if (sample[0] as Vector3).distance_to(_route_pts[-1]) < LAKE_REVEAL_DISTANCE:continue
		var yaw: float=float(sample[1])
		var side:=Vector3(-cos(yaw),0,sin(yaw))
		var at: Vector3=(sample[0] as Vector3)+side*(11.0+float((i*7)%15))*(1.0 if i%2==0 else -1.0)
		var local: Vector3=lake_transform().affine_inverse()*at
		if local.x>=-130 and local.x<=170 and local.z>=-100 and local.z<=210:
			at.y=Ep2LakeLandform.terrain_height(local.x,local.z)
		placements.append(Transform3D(Basis(Vector3.UP,float(i)*2.4).scaled(Vector3.ONE*(0.55+progress*.55)),at))
	for piece in ["Wood","Needles"]:
		var template: MeshInstance3D=kit.find_child("FirA_"+piece,true,false)
		landscape._instances(_visuals,template.mesh,placements,landscape._bark() if piece=="Wood" else landscape._foliage(Ep2LakeLandscape.BRANCH,12.0,.1),"ApproachFir_"+piece)
	kit.free()


func _smooth(points: Array, spacing: float) -> PackedVector3Array:
	return Ep2LakeRoad.smooth(points,spacing)

func _ribbon(points: PackedVector3Array, width: float, mat: Material, y: float) -> MeshInstance3D:
	return Ep2LakeRoad.ribbon(_visuals,points,width,mat,y)

func _route_sample(distance: float) -> Array:
	if _route_pts.is_empty():
		return [Vector3.ZERO, 0.0]
	var s: float = clampf(distance, 0.0, _route_total)
	var i: int = 1
	while i < _route_arc.size() - 1 and _route_arc[i] < s:
		i += 1
	var a: Vector3 = _route_pts[i - 1]
	var b: Vector3 = _route_pts[i]
	var segment: float = maxf(_route_arc[i] - _route_arc[i - 1], 0.001)
	var t: float = clampf((s - _route_arc[i - 1]) / segment, 0.0, 1.0)
	return [a.lerp(b, t), atan2(b.x - a.x, b.z - a.z)]


# --- the horse -------------------------------------------------------------------------------------------------------

func _step_horse() -> void:
	_horse = _horse_instance(_visuals)
	_horse.name = "DudesHorse"
	_horse_anim = _find_horse_anim(_horse)
	var leather: StandardMaterial3D = _plain(Color(0.16, 0.075, 0.035), 0.82)
	_box(Vector3(0.72, 0.13, 0.76), Vector3(0.0, SADDLE_HEIGHT, -0.15), leather, _horse)
	_box(Vector3(0.82, 0.07, 0.12), Vector3(0.0, SADDLE_HEIGHT + 0.11, -0.47), leather, _horse)
	for side in [-1.0, 1.0]:
		_box(Vector3(0.035, 0.52, 0.055), Vector3(side * 0.43, SADDLE_HEIGHT - 0.27, -0.12), leather, _horse)
		_box(Vector3(0.13, 0.035, 0.22), Vector3(side * 0.43, SADDLE_HEIGHT - 0.52, -0.12), leather, _horse)
	_set_horse_clip("horse_stand", 1.0)


func _horse_instance(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var model: Node3D = null
	if ResourceLoader.exists(HORSE_MODEL):
		model = (load(HORSE_MODEL) as PackedScene).instantiate() as Node3D
	if model != null:
		model.rotation.y = -PI * 0.5       # the supplied horse faces +X; every trail actor faces local +Z
		root.add_child(model)
		var anim: AnimationPlayer = _find_horse_anim(root)
		if anim != null:
			for clip in anim.get_animation_list():
				anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	else:
		var coat: StandardMaterial3D = _plain(Color(0.30, 0.16, 0.075), 0.92)
		var dark: StandardMaterial3D = _plain(Color(0.09, 0.055, 0.03), 0.95)
		_box(Vector3(0.76, 0.82, 1.75), Vector3(0.0, 1.02, 0.0), coat, root)
		var neck := _box(Vector3(0.43, 0.92, 0.48), Vector3(0.0, 1.48, 0.70), coat, root)
		neck.rotation.x = -0.38
		_box(Vector3(0.40, 0.42, 0.70), Vector3(0.0, 1.82, 1.08), coat, root)
		_box(Vector3(0.10, 0.48, 1.05), Vector3(0.0, 1.47, 0.43), dark, root)
		for sx in [-0.26, 0.26]:
			for sz in [-0.58, 0.58]:
				_cyl(0.075, 0.095, 0.92, Vector3(sx, 0.46, sz), coat, root, 7)
	return root


func _find_horse_anim(root: Node) -> AnimationPlayer:
	for node in root.find_children("*", "AnimationPlayer", true, false):
		return node as AnimationPlayer
	return null


func _set_horse_clip(clip: String, speed_scale: float) -> void:
	_horse_clip = clip
	if _horse_anim == null:
		return
	if _horse_anim.current_animation != clip or not _horse_anim.is_playing():
		if _horse_anim.has_animation(clip):
			_horse_anim.play(clip, 0.18)
	_horse_anim.speed_scale = speed_scale


func _update_horse(_delta: float) -> void:
	if _horse == null:
		return
	if not _horse_left and (_mounted or _unhorse_active):
		_horse.position.x = _player_pos.x
		_horse.position.z = _player_pos.z
		_horse.rotation.y = _travel_yaw + (PI if _speed < -0.05 else 0.0)
	if _unhorse_active:
		return
	if _horse_left:
		_set_horse_clip("horse_stand", 1.0)
	elif _ending and _mounted:
		_set_horse_clip("horse_graze", 0.85)
	elif _mounted:
		_set_horse_clip("horse_walk", clampf(absf(_speed) / HORSE_CLIP_SPEED, 0.1, 3.8)) if absf(_speed) > 0.05 else _set_horse_clip("horse_stand", 1.0)
	else:
		_set_horse_clip("horse_stand", 1.0)


# --- bandits and their cover -----------------------------------------------------------------------------------------

func _step_bandits() -> void:
	_build_ambush_cover()
	_spawn_bandits()


func _build_ambush_cover() -> void:
	var rock: StandardMaterial3D = _tex(ROCK_TEX, Color(0.43, 0.35, 0.27), 0.32)
	for i in BANDIT_SPECS.size():
		var spec: Dictionary = BANDIT_SPECS[i]
		var sample: Array = _route_sample(float(spec["s"]))
		var yaw: float = float(sample[1])
		var right := Vector3(-cos(yaw), 0.0, sin(yaw))
		var home: Vector3 = (sample[0] as Vector3) + right * float(spec["lat"])
		var toward: Vector3 = (sample[0] as Vector3) - home
		toward.y = 0.0
		toward = toward.normalized()
		var cover := _sphere(1.0, home + toward * 1.15 + Vector3(0.0, 0.42, 0.0), rock, _visuals, 0.68)
		cover.scale = Vector3(1.65 + float(i % 2) * 0.35, 1.0, 1.25)
		cover.rotation.y = float(i) * 1.17
		if i % 3 == 2:
			# One man in each group watches from a low ridge rather than from the same rock silhouette.
			var ridge := _sphere(2.6, home + Vector3(0.0, -0.12, 0.0), rock, _visuals, 0.24)
			ridge.scale = Vector3(1.25, 1.0, 1.1)


func _spawn_bandits() -> void:
	_bandits.clear()
	_bandits_root = Node3D.new()
	_bandits_root.name = "TrailBandits"
	_visuals.add_child(_bandits_root)
	for i in BANDIT_SPECS.size():
		var spec: Dictionary = BANDIT_SPECS[i]
		var sample: Array = _route_sample(float(spec["s"]))
		var yaw: float = float(sample[1])
		var right := Vector3(-cos(yaw), 0.0, sin(yaw))
		var home: Vector3 = (sample[0] as Vector3) + right * float(spec["lat"])
		home.y = 0.42 if i % 3 == 2 else 0.0
		var root := Node3D.new()
		root.name = "Ambusher%d" % i
		_bandits_root.add_child(root)
		var role: String = "rush" if RUSHER_SLOTS.has(i % 5) else "hold"
		root.position = home + Vector3(0.0, -HOLDOUT_HIDE, 0.0)
		var height: float = 1.74 + float(i % 3) * 0.055
		var parts: Dictionary = _make_bandit(root, height, BANDIT_TINTS[i % BANDIT_TINTS.size()])
		var folk: Ep2TownFolk = parts["folk"]
		folk.face_yaw(atan2((sample[0] as Vector3).x - home.x, (sample[0] as Vector3).z - home.z))
		_bandits.append({"root": root, "home": home, "s": float(spec["s"]), "ambush": int(spec["ambush"]),
			"state": "cover", "cool": 0.25 + float(i % 3) * 0.42, "tell": 0.0, "tell_need": 1.0,
			"last_tell": 0.0, "shots": 0, "rider": false, "released": true, "chase_s": 0.0,
			"horse_anim": null, "height": height, "folk": folk, "gun": parts["gun"], "glint": parts["glint"],
			"accents": parts["accents"], "role": role, "exposed": false, "rush_t": 0.0})
	_spawn_rider()


func _make_bandit(root: Node3D, height: float, tint: Color) -> Dictionary:
	var folk := Ep2TownFolk.new()
	root.add_child(folk)
	folk.setup(COWBOY_MODEL, height, Color(0.22, 0.16, 0.11), false)
	folk.set_pose("idle")
	var accent_mat: StandardMaterial3D = _plain(tint, 0.9)
	var accents: Array = []
	accents.append(_box(Vector3(0.30, 0.13, 0.045), Vector3(0.0, height * 0.76, 0.13), accent_mat, folk))
	accents.append(_box(Vector3(0.38, 0.05, 0.36), Vector3(0.0, height * 0.94, 0.0), accent_mat, folk))
	var gun := Node3D.new()
	gun.name = "BanditRevolver"
	folk.add_child(gun)
	# Jack Hammer's men carry the same Colt Single Action Army as the stranger in the town draw (the CAD kit's, real size); the old
	# primitive stands in until the streamed kit mounts
	var steel: StandardMaterial3D = _plain(Color(0.20, 0.20, 0.22), 0.35, 0.8)
	var grip: StandardMaterial3D = _plain(Color(0.30, 0.18, 0.09), 0.75)
	Ep2KitProps.place(gun, "Kit_Revolver", Transform3D.IDENTITY, Transform3D.IDENTITY, func(h: Node3D) -> void:
		_box(Vector3(0.03, 0.03, 0.22), Vector3(0.0, 0.0, 0.10), steel, h)
		_box(Vector3(0.035, 0.11, 0.045), Vector3(0.0, -0.065, -0.035), grip, h))
	gun.position = GoldTownChamber.COWBOY_HAND_DRAW * height
	gun.visible = false
	var glint := _sphere(0.055, Vector3(0.0, 0.0, 0.23), _glow(Color(1.0, 0.91, 0.60), 5.0), gun)
	glint.name = "TelegraphGlint"
	glint.visible = false
	glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return {"folk": folk, "gun": gun, "glint": glint, "accents": accents}


func _spawn_rider() -> void:
	var root := Node3D.new()
	root.name = "ChasingRider"
	_bandits_root.add_child(root)
	root.visible = false
	var horse: Node3D = _horse_instance(root)
	horse.name = "BanditHorse"
	var anim: AnimationPlayer = _find_horse_anim(horse)
	var height: float = 1.86
	var parts: Dictionary = _make_rider(root, Color(0.24, 0.035, 0.025))
	if parts.is_empty():
		parts = _make_bandit(root, height, Color(0.24, 0.035, 0.025))
		parts["seat_y"] = SADDLE_HEIGHT
	var folk: Ep2TownFolk = parts["folk"]
	folk.position.y = float(parts["seat_y"])
	if bool(parts.get("seated", false)):
		height = 1.0          # seated: saddle to the crown of his hat is the target, not a standing man
	_bandits.append({"root": root, "home": Vector3.ZERO, "s": 0.0, "ambush": 2, "state": "cover",
		"cool": 0.5, "tell": 0.0, "tell_need": 1.0, "last_tell": 0.0, "shots": 0, "rider": true,
		"released": false, "chase_s": 0.0, "horse_anim": anim, "height": height, "folk": folk,
		"gun": parts["gun"], "glint": parts["glint"], "accents": parts["accents"], "role": "ride",
		"exposed": true, "rush_t": 0.0, "seat_y": float(parts["seat_y"]), "seated": bool(parts.get("seated", false))})


## A rigged rider in the RanchRide pose with his hips on the saddle, or {} when no rigged townsman is in the build.
func _make_rider(root: Node3D, tint: Color) -> Dictionary:
	var path: String = ""
	for candidate in RIDER_MODELS:
		if (str(candidate).begins_with(Ep2Extras.PEOPLE_DIR) and Ep2Extras.has(str(candidate))) or (not str(candidate).begins_with(Ep2Extras.PEOPLE_DIR) and ResourceLoader.exists(str(candidate))):
			path = str(candidate)
			break
	if path == "":
		return {}
	var folk := Ep2TownFolk.new()
	folk.name = "SeatedRider"
	root.add_child(folk)
	if not folk.setup(path, 1.78) or not folk.has_clips():
		folk.queue_free()
		return {}
	var ap: AnimationPlayer = folk.anim_player()
	var skel: Skeleton3D = null
	for node in folk.model.find_children("*", "Skeleton3D", true, false):
		skel = node
		break
	if skel == null:
		folk.queue_free()
		return {}
	# axes and metres of the skeleton relative to the folk model (the stable yard's own recipe for Dude)
	var relative: Transform3D = _relative_to(skel, folk.model)
	var inverse: Basis = relative.basis.inverse()
	var unit: float = maxf(0.0001, folk.model.scale.y * relative.basis.get_scale().y)
	if not Ep2RanchPose.install_ride(ap, skel, (inverse * Vector3.BACK).normalized(), (inverse * Vector3.UP).normalized(), unit):
		folk.queue_free()
		return {}
	folk.hold_clip(Ep2RanchPose.RIDE)
	ap.seek(0.0, true)
	# Sit him: the hips (measured in the solved pose) land just above the saddle board, over its centre.
	var hips: int = -1
	for b in skel.get_bone_count():
		if skel.get_bone_name(b).to_lower().ends_with("hips"):
			hips = b
			break
	var hip_local: Vector3 = Vector3(0, 0.95, 0)
	if hips >= 0:
		hip_local = (folk.model.transform * relative) * skel.get_bone_global_pose(hips).origin
	var seat_y: float = SADDLE_HEIGHT + RIDER_HIP_LIFT - hip_local.y
	folk.position = Vector3(-hip_local.x, seat_y, -0.15 - hip_local.z)
	var accent_mat: StandardMaterial3D = _plain(tint, 0.9)
	var accents: Array = []
	accents.append(_box(Vector3(0.30, 0.13, 0.045), hip_local + Vector3(0.0, 0.42, 0.13), accent_mat, folk))   # bandana
	var gun := Node3D.new()
	gun.name = "BanditRevolver"
	folk.add_child(gun)
	var steel: StandardMaterial3D = _plain(Color(0.20, 0.20, 0.22), 0.35, 0.8)
	var grip: StandardMaterial3D = _plain(Color(0.30, 0.18, 0.09), 0.75)
	Ep2KitProps.place(gun, "Kit_Revolver", Transform3D.IDENTITY, Transform3D.IDENTITY, func(h: Node3D) -> void:
		_box(Vector3(0.03, 0.03, 0.22), Vector3(0.0, 0.0, 0.10), steel, h)
		_box(Vector3(0.035, 0.11, 0.045), Vector3(0.0, -0.065, -0.035), grip, h))
	gun.position = hip_local + Vector3(0.24, 0.42, 0.38)       # gun hand out over the horse's shoulder
	gun.visible = false
	var glint := _sphere(0.055, Vector3(0.0, 0.0, 0.23), _glow(Color(1.0, 0.91, 0.60), 5.0), gun)
	glint.name = "TelegraphGlint"
	glint.visible = false
	glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return {"folk": folk, "gun": gun, "glint": glint, "accents": accents, "seat_y": seat_y, "seated": true}


func _relative_to(node: Node3D, top: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = node
	while c != null and c != top:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t


## The rest pose between shots: a seated rider goes back to his ride clip (the rig's "idle" would stand him up on the saddle).
func _bandit_rest(b: Dictionary) -> void:
	var folk: Ep2TownFolk = b["folk"]
	if bool(b.get("seated", false)):
		folk.pose_name = "idle"
		folk.play_clip(Ep2RanchPose.RIDE)
	else:
		folk.set_pose("idle")


func _tick_bandits(delta: float) -> void:
	var telegraphs: int = 0
	for i in _bandits.size():
		if str((_bandits[i] as Dictionary)["state"]) == "telegraph":
			telegraphs += 1
	for i in _bandits.size():
		var b: Dictionary = _bandits[i]
		var root: Node3D = b["root"]
		var folk: Ep2TownFolk = b["folk"]
		if str(b["state"]) == "dead":
			folk.step(delta)
			if bool(b["rider"]):
				# shot out of the saddle: he slides off the horse's side to the ground
				folk.position.y = move_toward(folk.position.y, 0.0, delta * 2.6)
				folk.position.x = move_toward(folk.position.x, 1.1, delta * 1.6)
			continue
		var rider: bool = bool(b["rider"])
		var active: bool = false
		if rider:
			active = _tick_rider(b, delta)
		else:
			var spec_s: float = float(b["s"])
			if _route_s > spec_s + AMBUSH_BEHIND:
				_outrun_bandit(b)
			active = str(b["state"]) != "outrun" and _route_s > spec_s - AMBUSH_AHEAD and _route_s <= spec_s + AMBUSH_BEHIND
		if not active:
			if str(b["state"]) == "telegraph":
				_cancel_telegraph(b)
			folk.step(delta)
			if rider:
				folk.position.y = float(b["seat_y"])
			continue
		if str(b["state"]) == "rush":
			_tick_rush(b, delta)
			continue
		if str(b["state"]) == "cover" and str(b.get("role", "")) == "rush" and not bool(b["exposed"]) \
				and _bandit_world_position(b).distance_to(_player_pos) <= SHOT_RANGE:
			_begin_rush(b)
			continue
		_bandit_face_player(b)
		var distance: float = _bandit_world_position(b).distance_to(_player_pos)
		var state: String = str(b["state"])
		if state != "telegraph":
			b["cool"] = maxf(0.0, float(b["cool"]) - delta)
		if state == "telegraph":
			b["tell"] = float(b["tell"]) + delta
			var tell: float = float(b["tell"])
			if not rider and not bool(b["exposed"]):
				var home: Vector3 = b["home"]
				var rise: float = clampf(tell / 0.28, 0.0, 1.0)
				root.position.y = home.y - HOLDOUT_HIDE * (1.0 - rise)
			var glint: MeshInstance3D = b["glint"]
			glint.scale = Vector3.ONE * (1.0 + 0.35 * sin(tell * 25.0))
			if tell >= float(b["tell_need"]):
				if distance <= SHOT_RANGE + 4.0:
					_fire_bandit(i)
				else:
					_cancel_telegraph(b)
		elif float(b["cool"]) <= 0.0 and distance <= SHOT_RANGE and telegraphs < 2:
			_begin_telegraph(i)
			telegraphs += 1
		folk.step(delta)
		if rider:
			folk.position.y = float(b["seat_y"])


## A rusher leaves his rock: he stands, draws nothing yet, and runs at Lil Blunt.
func _begin_rush(b: Dictionary) -> void:
	b["state"] = "rush"
	b["exposed"] = true
	b["rush_t"] = 0.0
	var root: Node3D = b["root"]
	var home: Vector3 = b["home"]
	root.position.y = home.y
	_bandit_rest(b)


## Run across the open ground toward him; stop at the trail's edge, a few metres short of him, or after RUSH_MAX_SECONDS, then
## fight standing (state "cover" with `exposed`, so the normal telegraph/fire cycle runs without ducking behind anything).
func _tick_rush(b: Dictionary, delta: float) -> void:
	var folk: Ep2TownFolk = b["folk"]
	b["rush_t"] = float(b["rush_t"]) + delta
	var at: Vector3 = _bandit_world_position(b)
	var to: Vector3 = _player_pos - at
	to.y = 0.0
	# his distance from the trail's centre line, measured where his ambush sits on it (not where Lil Blunt is)
	var sample: Array = _route_sample(float(b["s"]))
	var yaw: float = float(sample[1])
	var right := Vector3(-cos(yaw), 0.0, sin(yaw))
	var lateral: float = absf((at - (sample[0] as Vector3)).dot(right))
	if to.length() <= RUSH_STANDOFF or lateral <= RUSH_TRAIL_EDGE or float(b["rush_t"]) >= RUSH_MAX_SECONDS:
		folk.stop()
		b["state"] = "cover"
		b["cool"] = minf(float(b["cool"]), 0.35)
		_bandit_face_player(b)
		folk.step(delta)
		return
	folk.walk_to(folk.position + to.normalized() * 2.0, RUSH_SPEED)
	folk.step(delta)


func _tick_rider(b: Dictionary, delta: float) -> bool:
	var root: Node3D = b["root"]
	if not bool(b["released"]):
		if _route_s < RIDER_START_S:
			return false
		b["released"] = true
		b["chase_s"] = maxf(0.0, _route_s - 20.0)
		root.visible = true
	if _route_s >= RIDER_END_S:
		_outrun_bandit(b)
		return false
	if str(b["state"]) == "outrun":
		return false
	var chase_speed: float = maxf(6.4, _speed + 0.45)
	b["chase_s"] = minf(_route_s - 8.5, float(b["chase_s"]) + chase_speed * delta)
	var sample: Array = _route_sample(float(b["chase_s"]))
	var yaw: float = float(sample[1])
	var right := Vector3(-cos(yaw), 0.0, sin(yaw))
	root.position = (sample[0] as Vector3) + right * 1.55
	root.rotation.y = yaw
	b["home"] = root.position
	var anim: AnimationPlayer = b["horse_anim"] as AnimationPlayer
	if anim != null:
		if anim.current_animation != "horse_walk" or not anim.is_playing():
			anim.play("horse_walk", 0.15)
		anim.speed_scale = chase_speed / HORSE_CLIP_SPEED
	return true


func _outrun_bandit(b: Dictionary) -> void:
	if str(b["state"]) == "dead":
		return
	_cancel_telegraph(b)
	b["state"] = "outrun"
	var root: Node3D = b["root"]
	if not bool(b["rider"]):
		var home: Vector3 = b["home"]
		root.position = home


func _begin_telegraph(index: int) -> void:
	var b: Dictionary = _bandits[index]
	var folk: Ep2TownFolk = b["folk"]
	b["state"] = "telegraph"
	b["tell"] = 0.0
	b["tell_need"] = _rng.randf_range(0.85, 1.2)
	folk.set_pose("draw")
	(b["gun"] as Node3D).visible = true
	var glint: MeshInstance3D = b["glint"]
	glint.visible = true
	glint.scale = Vector3.ONE
	_bandit_bark(index)


func _cancel_telegraph(b: Dictionary) -> void:
	if str(b["state"]) == "telegraph":
		b["state"] = "cover"
		b["cool"] = maxf(float(b["cool"]), 0.45)
	(b["gun"] as Node3D).visible = false
	(b["glint"] as MeshInstance3D).visible = false
	_bandit_rest(b)
	if not bool(b["rider"]) and not bool(b["exposed"]):
		var root: Node3D = b["root"]
		var home: Vector3 = b["home"]
		root.position.y = home.y - HOLDOUT_HIDE


func _fire_bandit(index: int) -> void:
	var b: Dictionary = _bandits[index]
	var folk: Ep2TownFolk = b["folk"]
	b["last_tell"] = float(b["tell"])
	b["shots"] = int(b["shots"]) + 1
	b["state"] = "recover"
	b["cool"] = _rng.randf_range(1.35, 2.15)
	(b["gun"] as Node3D).visible = false
	(b["glint"] as MeshInstance3D).visible = false
	_bandit_rest(b)
	folk.kick()
	var muzzle: Vector3 = _bandit_world_position(b) + Vector3(0.0, 1.25 + (SADDLE_HEIGHT if bool(b["rider"]) else 0.0), 0.0)
	_flash(muzzle)
	_sfx("ep2_revolver_blast_1")
	if not bool(b["rider"]) and not bool(b["exposed"]):
		# a holdout ducks straight back behind his rock after the shot
		var root: Node3D = b["root"]
		var home: Vector3 = b["home"]
		root.position.y = home.y - HOLDOUT_HIDE
	var distance: float = muzzle.distance_to(_player_pos)
	var hit_chance: float = clampf(0.46 - distance * 0.004 - clampf(_speed / MAX_RIDE_SPEED, 0.0, 1.0) * 0.08, 0.16, 0.36)
	if _rng.randf() >= hit_chance:
		return
	if _mounted and _rng.randf() < 0.55:
		_hurt_horse()
	else:
		_hurt_player()


func _bandit_face_player(b: Dictionary) -> void:
	var folk: Ep2TownFolk = b["folk"]
	var at: Vector3 = _bandit_world_position(b)
	folk.face_yaw(atan2(_player_pos.x - at.x, _player_pos.z - at.z))


func _bandit_world_position(b: Dictionary) -> Vector3:
	var root: Node3D = b["root"]
	var at: Vector3 = root.global_position if root.is_inside_tree() else root.position
	if not bool(b["rider"]):
		# a rusher's body has run away from his rock: the folk's own ground offset under the (unrotated) ambush root
		var folk: Ep2TownFolk = b["folk"]
		at += Vector3(folk.position.x, 0.0, folk.position.z)
	return at


# --- setup and movement ----------------------------------------------------------------------------------------------

func _on_setup() -> void:
	Ep2DrawMusic.begin_trail(self)
	_armory_snapshot = armory.snapshot()
	_beat = Beat.RIDE
	_health = HEALTH_MAX
	_horse_hp = HORSE_HP_MAX - armory.horse_wounds   # a horse shot earlier is still shot (a saved run, a later ride)
	_mounted = bool(handoff.get("horse", true)) and _horse_hp > 0   # Dude's horse (the town hands it over)
	_ending = false
	_trail_time = 0.0
	_rng.seed = 1886
	if _bandits.is_empty():
		_spawn_bandits()
	eye_height = MOUNTED_EYE
	_ground_y = 0.0
	_place_at_distance(0.0)
	_speed = 0.0
	# the gaze he mounted with, whole (founder 2026-11-01: the old +-0.65 rad clamp swung his view round to the road the moment the
	# trail took over - "forces the player to turn around"). Free look is the trail's normal state while riding.
	_apply_handoff_gaze(_travel_yaw, -0.075, PI)
	_clamp_look()
	_player_yaw = _travel_yaw
	if _hud != null:
		_hud.objective = "Ride to Logan's Lake — or turn back to town. W/S ride, A/D steer; mouse looks freely." if TouchUi.keys_shown() else "Ride to Logan's Lake — or turn back to town."
		_hud.show_health = true
	if _vm != null:
		_vm.set_world_shadows(false)
		_vm.set_own_light(WoodsQuadChamber.VM_KEY_ENERGY, _sun)
	_say_trail_line("trail_lb_start")
	# The next room starts building now, not when the horse reaches the shore.
	prebuild_requested.emit("logans_lake")


func has_player_control() -> bool:
	return _running and not _resolved and not _show_blocks_control and not _failing and not _unhorse_active and not armory_open()


## Back at Dude's on foot with a shot horse: he patches it up and it is under him again.
func _dude_treats_horse() -> void:
	if armory.horse_is_sound() or _departure_yard == null:
		return
	if _player_pos.distance_to(_departure_yard.dude_position()) > GoldTownChamber.DUDE_TREATS_WITHIN:
		return
	armory.treat_horse()
	set_return_mounted(true)
	if _hud != null:
		_hud.toast("DUDE PATCHES UP THE HORSE", 2.6)


func _move_player(delta: float) -> void:
	if _in_departure_area and not _ending and not _failing and not _unhorse_active:
		_dude_treats_horse()
		_move_departure_area(delta)
		return
	if _ending or _failing or _unhorse_active:
		_moving = false
		return
	var lane_wish: float = clampf(_lane + _move_input.x * LANE_RATE * delta, -LANE_LIMIT, LANE_LIMIT)
	if absf(_lane) > LANE_LIMIT:
		_lane = move_toward(_lane, lane_wish, LANE_SETTLE * delta)     # just handed off from beside the road: ease onto the lane
	else:
		_lane = lane_wish
	var facing: float = cos(_look_yaw - _travel_yaw)
	var direction: float = signf(facing) if absf(facing) > 0.15 else 0.0
	var wanted: float = _move_input.y * direction * (MAX_RIDE_SPEED if _mounted else FOOT_SPEED)
	_speed = move_toward(_speed, wanted, 6.0 * delta)
	_moving = absf(_speed) > 0.05
	if _moving:
		_walk_phase += delta * absf(_speed) * 1.4
	_route_s = clampf(_route_s + _speed * delta, 0.0, _route_total)
	_sync_route_pose(delta)
	if _route_s < 60.0:
		_in_departure_area = true


func _move_departure_area(delta: float) -> void:
	# The ranch and town remain freely traversable in the saddle. Looking behind never
	# turns the horse unless the player actually asks it to move that way.
	var forward := Vector3(sin(_look_yaw),0,cos(_look_yaw))
	var right := Vector3(-cos(_look_yaw),0,sin(_look_yaw))
	var wish: Vector3 = forward * _move_input.y + right * _move_input.x
	var at_bound: bool = false
	var target_speed: float = (MAX_RIDE_SPEED if _mounted else FOOT_SPEED) * minf(1.0,wish.length())
	_speed = move_toward(absf(_speed),target_speed,6.0*delta)
	_moving = wish.length() > 0.05 and _speed > 0.05
	if _moving:
		var direction: Vector3 = wish.normalized()
		_travel_yaw = atan2(direction.x,direction.z)
		_previous_travel_yaw = _travel_yaw
		var candidate: Vector3 = _player_pos + direction * _speed * delta
		var town_pos: Vector3 = candidate + GoldTownChamber.DEPART_HORSE
		var corrected: Vector2 = Ep2GoldTown.collide(Vector2(town_pos.x,town_pos.z),0.65,_town_walls,_town_props)
		var free := Vector3(corrected.x-GoldTownChamber.DEPART_HORSE.x,0,corrected.y-GoldTownChamber.DEPART_HORSE.z)
		_player_pos = Vector3(clampf(free.x,-60.0,85.0),0,clampf(free.z,-80.0,265.0))
		at_bound = not free.is_equal_approx(_player_pos)
		_walk_phase += delta * _speed * 1.4
	var best: float = INF
	var nearest: int = 0
	for i in _route_pts.size():
		var d: float = _player_pos.distance_squared_to(_route_pts[i])
		if d < best:
			best = d
			nearest = i
	_route_s = _route_arc[nearest]
	if _route_s > 65.0 and (best < DEPART_CAPTURE_R * DEPART_CAPTURE_R or (at_bound and best < DEPART_EDGE_CAPTURE_R * DEPART_EDGE_CAPTURE_R)):
		_in_departure_area = false
		var sample: Array = _route_sample(_route_s)
		_travel_yaw = float(sample[1])
		_previous_travel_yaw = _travel_yaw
		# keep the true offset (eased onto the lane in _move_player), so the hand-off is never a sideways jump
		_lane = clampf((_player_pos-(sample[0] as Vector3)).dot(Vector3(-cos(_travel_yaw),0,sin(_travel_yaw))),-DEPART_EDGE_CAPTURE_R,DEPART_EDGE_CAPTURE_R)

func _sync_route_pose(delta: float) -> void:
	var sample: Array = _route_sample(_route_s)
	var wanted_yaw: float = float(sample[1])
	if delta > 0.0:
		_travel_yaw = lerp_angle(_travel_yaw, wanted_yaw, clampf(7.0 * delta, 0.0, 1.0))
	else:
		_travel_yaw = wanted_yaw
		_previous_travel_yaw = wanted_yaw
	_look_yaw += angle_difference(_previous_travel_yaw, _travel_yaw)
	_previous_travel_yaw = _travel_yaw
	_clamp_look()
	var right := Vector3(-cos(_travel_yaw), 0.0, sin(_travel_yaw))
	var centre: Vector3 = sample[0]
	_player_pos = centre + right * _lane

	_player_pos.y = 0.0
	_ground_y = 0.0
	_vel_y = 0.0
	_player_yaw = _travel_yaw


func _place_at_distance(distance: float) -> void:
	_in_departure_area = distance < 60.0
	_route_s = clampf(distance, 0.0, _route_total)
	_sync_route_pose(0.0)


func _update_vertical(_delta: float) -> void:
	# The route is a surveyed trail; riding and the post-stumble walk never fall through its ribbon.
	_ground_y = 0.0
	_player_pos.y = 0.0
	_vel_y = 0.0


func _can_jump() -> bool:
	return false


func look(relative: Vector2) -> void:
	super.look(relative)
	_clamp_look()


func _clamp_look() -> void:
	_look_yaw = wrapf(_look_yaw, -PI, PI)


func _fps_camera(_delta: float) -> void:
	var ads: float = _vm.gun.ads if _vm != null else 0.0
	var bob: float = 0.0
	if _mounted and not _unhorse_active:
		bob = sin(_anim_t * (7.0 + _speed * 0.65)) * 0.026 * clampf(absf(_speed) / CRUISE_SPEED, 0.0, 1.4)
	elif _moving:
		bob = sin(_walk_phase) * 0.035 * lerpf(1.0, 0.25, ads)
	_camera.position = Vector3(_player_pos.x, _player_pos.y + eye_height + bob, _player_pos.z)
	var kick: float = _vm.cam_kick if _vm != null else 0.0
	var pitch: float = clampf(_look_pitch + kick, -1.4, 1.4)
	var cp: float = cos(pitch)
	var direction := Vector3(sin(_look_yaw) * cp, sin(pitch), cos(_look_yaw) * cp)
	_camera.look_at(_camera.position + direction, Vector3.UP)
	var roll: float = _unhorse_roll
	if _mounted and not _unhorse_active:
		roll += sin(_anim_t * 4.2) * 0.004
	if absf(roll) > 0.0001:
		_camera.rotate_object_local(Vector3(0.0, 0.0, 1.0), roll)
	var ads_k: float = ads * ads * (3.0 - 2.0 * ads)
	_camera.fov = lerpf(FPS_FOV, FPS_ADS_FOV, ads_k)


# --- per-frame story -------------------------------------------------------------------------------------------------

func _tick(delta: float) -> void:
	_blend_lake_light()
	if _route_s >= _route_total-LAKE_REVEAL_DISTANCE:
		Ep2DrawMusic.begin_lake(self)
	else:
		Ep2DrawMusic.begin_trail(self)
	_invuln = maxf(0.0, _invuln - delta)
	_tick_flashes(delta)
	var town_player: Vector3 = _player_pos + GoldTownChamber.DEPART_HORSE
	if _departure_yard != null:
		_departure_yard.step(delta, town_player)
	if _return_crowd != null and _in_departure_area:
		_return_crowd.step(delta, town_player)
	if _failing:
		_tick_fail(delta)
		return
	if _carrion != null:
		_carrion.step(delta, _player_pos)
	_trail_time += delta
	if _unhorse_active:
		_tick_unhorse(delta)
	else:
		if not _first_ambush_said and _route_s >= 94.0:
			_first_ambush_said = true
			_say_trail_line("trail_lb_ambush")
			if _hud != null:
				_hud.objective = "Bandits! Watch for the rise, the Draw pose and the gun glint. Shoot or outrun them."
		if not _ending:
			_tick_bandits(delta)
			_tick_stampede(delta)
		if _route_s >= _route_total - 0.001 and not _ending:
			_begin_shore()
	if _ending:
		_tick_shore(delta)
	_update_horse(delta)


func _tick_stampede(delta: float) -> void:
	if _stampede == null:
		if GameManager.ep2_stampede_done or not _mounted or _route_s < STAMPEDE_S or _route_s > RIDER_START_S - 20.0:
			return
		_begin_stampede()
	if _stampede.active:
		_stampede.step(delta, _player_pos)


## The herd aims at where he WILL be if he keeps riding as he is: holding his pace runs him into it, so he must rein back, push on
## harder, or shoot (founder: "the option of shooting them or getting out the way").
func _begin_stampede() -> void:
	_stampede = Ep2Stampede.new()
	_stampede.name = "Stampede"
	_visuals.add_child(_stampede)
	var arrive: float = Ep2Stampede.TELEGRAPH + Ep2Stampede.START_DIST / Ep2Stampede.SPEED
	var ahead: float = clampf(_route_s + maxf(_speed, 2.5) * arrive, _route_s + 8.0, _route_total - 30.0)
	var sample: Array = _route_sample(ahead)
	var target: Vector3 = sample[0]
	var dir: Vector3 = Vector3(sin(float(sample[1])), 0.0, cos(float(sample[1])))
	_stampede.begin(target, dir, -1.0)          # out of the open desert (the pine line stands on the other side)
	_stampede.trampled.connect(_on_trampled)
	_stampede.bison_down.connect(func(at: Vector3) -> void:
		if _carrion != null:
			_carrion.add_body(at, 1.7))
	_stampede.finished.connect(func(_killed: int) -> void:
		GameManager.ep2_stampede_done = true
		if _hud != null:
			_hud.toast("THE HERD HAS PASSED" if TouchUi.keys_shown() else "", 2.0))
	if _hud != null:
		_hud.toast("STAMPEDE! Shoot them or get out of the way (S reins back)" if TouchUi.keys_shown() else "", 4.0)
		_hud.objective = "STAMPEDE - shoot the buffalo or ride clear of the herd."


func _on_trampled() -> void:
	if _invuln > 0.0 or _failing or _resolved:
		return
	_look_pitch = clampf(_look_pitch + 0.22, -1.2, 1.2)        # the jolt of the herd going through
	if _hud != null:
		_hud.toast("TRAMPLED!" if TouchUi.keys_shown() else "", 1.4)
	var horse_first: bool = _mounted and _horse_hp > 1
	_hurt_player()
	if horse_first:
		_invuln = 0.0
		_hurt_horse()


func _tick_unhorse(delta: float) -> void:
	_unhorse_t += delta
	var t: float = _unhorse_t
	if t < 0.55:
		var k: float = clampf(t / 0.55, 0.0, 1.0)
		eye_height = lerpf(MOUNTED_EYE, 0.88, k * k * (3.0 - 2.0 * k))
		_unhorse_roll = 0.58 * k
	else:
		var k2: float = clampf((t - 0.55) / (UNHORSE_SECONDS - 0.55), 0.0, 1.0)
		eye_height = lerpf(0.88, FPS_EYE_HEIGHT, k2)
		_unhorse_roll = 0.58 * (1.0 - k2)
	if _horse != null:
		var stumble: float = clampf(t / 0.8, 0.0, 1.0)
		_horse.rotation.x = -0.13 * sin(stumble * PI)
		_horse.rotation.z = -0.92 * stumble
	if t >= UNHORSE_SECONDS:
		_unhorse_active = false
		_unhorse_roll = 0.0
		eye_height = FPS_EYE_HEIGHT
		_speed = 0.0
		_horse_left = true
		if _horse != null:
			var right := Vector3(-cos(_travel_yaw), 0.0, sin(_travel_yaw))
			_horse.position += right * 1.25
			_horse.rotation.x = 0.0
			_horse.rotation.z = -1.12
		if _hud != null:
			_hud.objective = "On foot to Logan's Lake. Hold W to follow the trail." if TouchUi.keys_shown() else "On foot to Logan's Lake. Follow the trail."


func _begin_shore() -> void:
	_ending = true
	_end_t = 0.0
	Ep2DrawMusic.begin_lake(self)
	_speed = 0.0
	_moving = false
	_route_s = _route_total
	_sync_route_pose(0.0)
	_advance_to(Beat.SHORE)
	if _mounted:
		_set_horse_clip("horse_graze", 0.85)
	_say_trail_line("trail_lb_lake")
	if _hud != null:
		_hud.objective = ("Logan's Lake. You made it on foot; Logan waits at the shore." if not _mounted else
			("Logan's Lake. The horse drinks; Logan waits at the shore." if armory.horse_is_sound() else "Logan's Lake. The horse is shot and will not drink; Logan waits at the shore."))


func _tick_shore(delta: float) -> void:
	_end_t += delta
	var dismount: float=smoothstep(SHORE_SECONDS-1.6,SHORE_SECONDS,_end_t)
	_player_pos=_route_pts[_route_pts.size()-1]+lake_transform().basis.x*(1.3*dismount if _mounted else 0.0)
	eye_height=lerpf(MOUNTED_EYE,FPS_EYE_HEIGHT,dismount) if _mounted else FPS_EYE_HEIGHT
	if _end_t < SHORE_SECONDS or not _handoff_ok():
		return
	_advance_to(Beat.DONE)
	_resolve({"next_chamber": "logans_lake", "arrived_mounted": _mounted and _horse_hp > 0,
		"trail_seconds": _trail_time, "bandits_down": _bandits_down, "companion": ""})


func _wants_handoff() -> bool:
	return _ending and _end_t >= SHORE_SECONDS - 0.35


# --- player fire, hits and blood --------------------------------------------------------------------------------------

func _on_player_shot() -> void:
	if _camera == null:
		return
	var eye: Vector3 = _camera.global_position
	var direction: Vector3 = -_camera.global_transform.basis.z
	if _carrion != null:
		_carrion.notify_shot(eye, direction)
	if _stampede != null and _stampede.active:
		var before: int = _stampede.killed
		var t_hit: float = _stampede.shoot(eye, direction, armory.equipped == Ep2ArmoryState.BUFF)
		if t_hit >= 0.0:
			if _hud != null:
				_hud.hit_marker(_stampede.killed > before)
			return
	var best: int = -1
	var best_t: float = 181.0
	for i in _bandits.size():
		var b: Dictionary = _bandits[i]
		if not (b["root"] as Node3D).visible:
			continue
		var t: float = _bandit_ray_hit(b, eye, direction)
		if t >= 0.0 and t < best_t:
			best_t = t
			best = i
	if best >= 0:
		_drop_bandit(best)
		if _hud != null:
			_hud.hit_marker(true)
		var hit_folk: Ep2TownFolk = (_bandits[best] as Dictionary)["folk"]
		_blood(eye + direction * best_t, direction, hit_folk.model if hit_folk.model != null else hit_folk)


func aim_on_target(eye: Vector3, dir: Vector3) -> bool:
	if _stampede != null and _stampede.active and _stampede.under_sight(eye, dir):
		return true
	for b in _bandits:
		if (b["root"] as Node3D).visible and str(b["state"]) != "dead" and _bandit_ray_hit(b, eye, dir) >= 0.0:
			return true
	return false


func _bandit_ray_hit(b: Dictionary, eye: Vector3, direction: Vector3) -> float:
	var base: Vector3 = _bandit_world_position(b)
	if bool(b["rider"]):
		base.y += SADDLE_HEIGHT
	var a: Vector3 = base + Vector3(0.0, 0.28, 0.0)
	var top: Vector3 = base + Vector3(0.0, float(b["height"]), 0.0)
	if str(b["state"]) == "dead":
		var folk: Ep2TownFolk = b["folk"]
		var pose: Transform3D = folk.global_transform * Transform3D(folk.model.basis.orthonormalized(),folk.model.position)
		a = pose * Vector3(0,0.25,0)
		top = pose * Vector3(0,float(b["height"])*0.85,0)
	var axis: Vector3 = top - a
	var d: Vector3 = direction.normalized()
	var w0: Vector3 = eye - a
	var aa: float = d.dot(d)
	var bb: float = d.dot(axis)
	var cc: float = axis.dot(axis)
	var dd: float = d.dot(w0)
	var ee: float = axis.dot(w0)
	var denominator: float = aa * cc - bb * bb
	var along_ray: float = 0.0
	var along_body: float = 0.0
	if denominator > 1e-6:
		along_ray = (bb * ee - cc * dd) / denominator
		along_body = clampf((aa * ee - bb * dd) / denominator, 0.0, 1.0)
	along_ray = maxf(along_ray, 0.0)
	var miss: float = (eye + d * along_ray).distance_to(a + axis * along_body)
	# buckshot (the coach gun) spreads: its pattern forgives a wider miss, but only at shotgun range
	var spread: float = _vm.gun.hit_scale if _vm != null and _vm.gun != null and along_ray <= 30.0 else 1.0
	return along_ray if miss <= 0.46 * spread and along_ray <= 180.0 else -1.0


func _drop_bandit(index: int) -> void:
	var b: Dictionary = _bandits[index]
	if str(b["state"]) == "dead":
		return
	_cancel_telegraph(b)
	b["state"] = "dead"
	var folk: Ep2TownFolk = b["folk"]
	folk.fall_dead()
	if _carrion != null:
		var body_at: Vector3 = _bandit_world_position(b)
		_carrion.add_body(Vector3(body_at.x, _player_pos.y, body_at.z))
	(b["gun"] as Node3D).visible = false
	(b["glint"] as MeshInstance3D).visible = false
	for accent in b["accents"]:
		(accent as Node3D).visible = false
	_bandits_down += 1
	var anim: AnimationPlayer = b["horse_anim"] as AnimationPlayer
	if anim != null and anim.has_animation("horse_stand"):
		anim.play("horse_stand", 0.2)


func _hurt_player() -> void:
	if _invuln > 0.0 or _failing or _resolved or debug_invulnerable:
		return
	_health = clampi(_health - 1, 0, HEALTH_MAX)
	_invuln = 1.15
	if _hud != null:
		_hud.hurt()
	_sfx("damage")
	if _health <= 0:
		_fail()


func _hurt_horse() -> void:
	if not _mounted or _horse_hp <= 0 or _invuln > 0.0 or _failing or _resolved or debug_invulnerable:
		return
	_horse_hp = maxi(0, _horse_hp - 1)
	armory.wound_horse()                             # it stays shot beyond this ride: the lake, the road back, the save
	_invuln = 0.8
	if _hud != null:
		_hud.toast("HORSE WOUNDED - %d/3" % _horse_hp, 1.8)
	if _horse_hp == 0:
		_unhorse()


func _unhorse() -> void:
	if _unhorse_active or not _mounted:
		return
	_mounted = false
	_unhorse_active = true
	_unhorse_t = 0.0
	_unhorse_roll = 0.0
	_unhorse_events += 1
	_speed = 0.0
	_move_input = Vector2.ZERO
	set_aim(false)
	_set_horse_clip("horse_stand", 1.0)
	_say_trail_line("trail_lb_unhorse")
	if _hud != null:
		_hud.objective = "UNHORSE - stay with the trail."


func get_health() -> int:
	return _health


func _shows_health() -> bool:
	return true


func _heal_full() -> bool:
	if _health <= 0 or _health >= HEALTH_MAX or _failing:
		return false
	_health = HEALTH_MAX
	if _hud != null:
		_hud.health = _health
		_hud.health_max = HEALTH_MAX
		_hud.show_health = true
	return true


# --- failure and a fresh attempt --------------------------------------------------------------------------------------

func _fail() -> void:
	if _failing:
		return
	_failing = true
	_fail_t = 0.0
	_move_input = Vector2.ZERO
	set_aim(false)
	if _hud != null:
		_hud.fade_to(1.0, 0.55)
		_hud.toast("SHOT DOWN - BACK TO THE TRAIL START", 2.0)


func _tick_fail(delta: float) -> void:
	_fail_t += delta
	if _fail_t >= 0.9:
		_retry_trail()


func _retry_trail() -> void:
	if not _armory_snapshot.is_empty():
		armory.restore(_armory_snapshot)
	armory.treat_horse()                             # back at Dude's: he patches the horse up or swaps it, "fresh horse, fresh attempt"
	_attempt += 1
	for flash in _flashes:
		if is_instance_valid(flash[0]):
			(flash[0] as Node).queue_free()
	_flashes.clear()
	for effect in _blood_marks:
		if is_instance_valid(effect[0]):
			(effect[0] as Node).queue_free()
	_blood_marks.clear()
	if _bandits_root != null and is_instance_valid(_bandits_root):
		_bandits_root.queue_free()
	_bandits_root = null
	_bandits.clear()
	if _carrion != null:
		_carrion.clear()
	if _stampede != null and is_instance_valid(_stampede) and not _stampede.done:
		_stampede.queue_free()            # a failed attempt meets the herd again; a passed herd never returns
		_stampede = null
	_rng.seed = 1886 + _attempt * 31
	_spawn_bandits()
	_health = HEALTH_MAX
	_horse_hp = HORSE_HP_MAX
	_mounted = true
	_horse_left = false
	_unhorse_active = false
	_unhorse_t = 0.0
	_unhorse_roll = 0.0
	_ending = false
	_end_t = 0.0
	_trail_time = 0.0
	_bandits_down = 0
	_first_ambush_said = false
	_invuln = 1.4
	_speed = CRUISE_SPEED
	_lane = 0.0
	_failing = false
	_fail_t = 0.0
	eye_height = MOUNTED_EYE
	if _horse != null:
		_horse.visible = true
		_horse.rotation = Vector3.ZERO
		_horse.position = Vector3.ZERO
	_set_horse_clip("horse_walk", _speed / HORSE_CLIP_SPEED)
	_place_at_distance(0.0)
	_speed = 0.0
	_look_pitch = -0.075
	_beat = Beat.RIDE
	beat_changed.emit(_beat)
	if _hud != null:
		_hud.objective = "Fresh horse, fresh attempt. Ride to Logan's Lake."
		_hud.fade_to(0.0, 0.8)
		_hud.toast("BACK AT THE TRAIL START", 2.0)


# --- lines and restrained effects -------------------------------------------------------------------------------------

func _say_trail_line(id: String) -> void:
	var caption: String = ""
	if LB_LINES.has(id):
		caption = "LIL BLUNT: " + str(LB_LINES[id])
	else:
		var line: Dictionary = Ep2JackHammer.line(id)
		if not line.is_empty():
			caption = Ep2JackHammer.toast_text(line)
	if _hud != null and caption != "":
		_hud.speech(caption, Ep2Speech.pace(id, caption), Ep2Speech.voiced(id))   # heard, not subtitled (founder 2026-11-01)
	_speak(id)


func _bandit_bark(index: int) -> void:
	var b: Dictionary = _bandits[index]
	# Hammer's men see what has happened: nobody calls to shoot a horse already shot, or to take him off a horse he has lost (skill ep2-npc-reality-awareness)
	var barks: Array = Ep2WorldFacts.fitting(BANDIT_BARKS, Ep2WorldFacts.now(armory, _mounted, _sun))
	if barks.is_empty():
		return
	var id: String = str(barks[(index + int(b["shots"])) % barks.size()])
	if _bandit_voice != null and _bandit_voice.playing: return
	var stream: AudioStream = Ep2TownVoiceBank.stream(id)
	if stream == null: return
	if _bandit_voice == null:
		_bandit_voice=AudioStreamPlayer3D.new()
		_bandit_voice.bus="SFX"
		_bandit_voice.unit_size=24.0
		_bandit_voice.volume_db=2.5
		_bandit_voice.max_distance=80.0
		add_child(_bandit_voice)
	_bandit_voice.stream=stream
	_bandit_voice.position=_bandit_world_position(b)+Vector3(0,1.5,0)
	_bandit_voice.play()
	AudioManager.duck_for_speech(stream.get_length())


func _flash(at: Vector3) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.78, 0.42)
	light.light_energy = 4.0
	light.omni_range = 5.0
	_visuals.add_child(light)
	light.global_position = at
	var flash := _sphere(0.10, at, _glow(Color(1.0, 0.82, 0.45), 5.0))
	_flashes.append([light, 0.07])
	_flashes.append([flash, 0.05])


func _tick_flashes(delta: float) -> void:
	for i in range(_flashes.size() - 1, -1, -1):
		_flashes[i][1] = float(_flashes[i][1]) - delta
		if float(_flashes[i][1]) <= 0.0:
			if is_instance_valid(_flashes[i][0]):
				(_flashes[i][0] as Node).queue_free()
			_flashes.remove_at(i)
	for i in range(_blood_marks.size() - 1, -1, -1):
		_blood_marks[i][1] = float(_blood_marks[i][1]) - delta
		if float(_blood_marks[i][1]) <= 0.0:
			if is_instance_valid(_blood_marks[i][0]):
				(_blood_marks[i][0] as Node).queue_free()
			_blood_marks.remove_at(i)


func _blood(at: Vector3, dir: Vector3, body: Node3D) -> void:
	# The shared restrained effect (Ep2BloodFx: a short spurt where the round lands and a stain on the body); loaded by path, so a
	# build without it simply shows none - never a large fallback splatter.
	if not ResourceLoader.exists(BLOOD_FX):
		return
	var fx: Script = load(BLOOD_FX) as Script
	if fx == null:
		return
	var spray: Variant = fx.call("spurt", _visuals, at, dir)
	if body != null:
		fx.call("stain", body, at, -dir.normalized())
	if spray is Node:
		_blood_marks.append([spray, 2.5])


# --- hand-off and read-only state -------------------------------------------------------------------------------------

func get_handoff() -> Dictionary:
	var result: Dictionary = super.get_handoff()
	result["horse"] = true
	result["lake_yaw"] = wrapf(_look_yaw-lake_transform().basis.get_euler().y,-PI,PI)
	result["lake_pitch"] = _look_pitch
	result["lake_player"] = lake_transform().affine_inverse()*_player_pos
	result["arrived_mounted"] = _mounted and _horse_hp > 0
	result["trail_seconds"] = _trail_time
	result["bandits_down"] = _bandits_down
	return result


## Back from the lake (world routes): in the saddle of Dude's horse, or on foot because the horse was left drinking at the water.
## There is one horse - when it stayed at the lake, the trail's copy is not shown.
func set_return_mounted(on: bool) -> void:
	_mounted = on
	_unhorse_active = false
	_unhorse_roll = 0.0
	_horse_left = not on
	if on:
		_horse_hp = HORSE_HP_MAX - armory.horse_wounds
		eye_height = MOUNTED_EYE
	else:
		eye_height = FPS_EYE_HEIGHT
	if _horse != null:
		_horse.visible = on
		_horse.rotation = Vector3.ZERO


## True while Lil Blunt is mounted and the trail is still being ridden.
func is_riding() -> bool:
	return _mounted and not _ending and not _unhorse_active and not _failing


## True while the UNHORSE camera stumble is playing.
func is_unhorsing() -> bool:
	return _unhorse_active


## Whether he still has Dude's horse beneath him.
func is_mounted() -> bool:
	return _mounted


## Logan shot him: "you start all over from Dude on the horse" (founder 2026-11-04). The whole ride again from Dude's end of the trail, the horse
## patched up (Dude's care is what clears a wound), hearts full. The trail's own retry does exactly that.
func respawn_at_dude() -> void:
	_failing = false
	_resolved = false
	_retry_trail()
	if _hud != null:
		_hud.objective = "Dude patched you up and put you back on the horse. Ride to Logan's Lake, and leave Logan's back alone."
		_hud.toast("BACK AT DUDE'S", 2.0)


## The horse's three-wound state; zero has already produced the UNHORSE event.
func get_horse_hp() -> int:
	return _horse_hp


## Number of UNHORSE events in this room (retries do not erase the evidence).
func get_unhorse_count() -> int:
	return _unhorse_events


## The visible horse node, for pose and camera-clearance checks.
func get_horse_node() -> Node3D:
	return _horse


## Current horse animation name (horse_walk, horse_stand or horse_graze).
func get_horse_clip() -> String:
	return _horse_clip


## Route length in metres.
func get_route_length() -> float:
	return _route_total


## Arc length travelled in this attempt, in metres.
func get_route_distance() -> float:
	return _route_s


## Current ground speed in metres per second.
func get_route_speed() -> float:
	return _speed


## Signed lateral lane offset; within +/-2.2 m (a hand-off from beside the road eases into that band at LANE_SETTLE).
func get_lane_offset() -> float:
	return _lane


## Bandits dropped by Lil Blunt in this attempt.
func get_bandits_down() -> int:
	return _bandits_down


## Ambushers plus the single chasing rider.
func get_bandit_count() -> int:
	return _bandits.size()


## One bandit's AI state: cover, telegraph, recover, outrun or dead.
func get_bandit_state(index: int) -> String:
	return str((_bandits[index] as Dictionary)["state"]) if index >= 0 and index < _bandits.size() else ""


## True only while the rise / Draw / bark / glint tell is actually visible.
func is_bandit_telegraphing(index: int) -> bool:
	if index < 0 or index >= _bandits.size():
		return false
	var b: Dictionary = _bandits[index]
	return str(b["state"]) == "telegraph" and (b["glint"] as MeshInstance3D).visible \
		and (b["gun"] as Node3D).visible and (b["folk"] as Ep2TownFolk).pose_name == "draw"


## Seconds of visible tell immediately before the last shot.
func get_bandit_last_tell(index: int) -> float:
	return float((_bandits[index] as Dictionary)["last_tell"]) if index >= 0 and index < _bandits.size() else 0.0


## Shots fired by one bandit.
func get_bandit_shots(index: int) -> int:
	return int((_bandits[index] as Dictionary)["shots"]) if index >= 0 and index < _bandits.size() else 0


## A body-centre aim point for the current pose (including the chasing rider's saddle height).
func get_bandit_aim_position(index: int) -> Vector3:
	if index < 0 or index >= _bandits.size():
		return Vector3.ZERO
	var b: Dictionary = _bandits[index]
	var at: Vector3 = _bandit_world_position(b)
	at.y += (SADDLE_HEIGHT + 0.6) if bool(b["rider"]) else 1.05
	return at


## Current attempt number; zero is the first ride.
func get_attempt() -> int:
	return _attempt


## True during the short out-of-hearts attempt ending.
func is_failing() -> bool:
	return _failing

func lake_transform() -> Transform3D:
	var heading: float = float(_route_sample(_route_total)[1])
	var basis := Basis(Vector3.UP,heading-0.1)
	return Transform3D(basis,_route_pts[_route_pts.size()-1]-basis*LogansLakeChamber.SPAWN)

## Reuse the exact prebuilt destination geometry, one root child per frame.
## What becomes visible on the horizon is what the player later walks into.
func preview_lake(room: Node3D) -> void:
	if _lake_preview == null:
		_lake_reference=room
		_lake_preview=Node3D.new()
		_lake_preview.name="ActualLogansLake"
		_visuals.add_child(_lake_preview)
		_lake_preview.transform=lake_transform()
	# The prebuilt room does not simulate: retry streamed Logan before copying.
	if room.has_method("prepare_approach"):room.prepare_approach()
	else:
		room._people()
		room._build_skiff()
	for id in _preview_copied.keys():
		if not is_instance_id_valid(id):
			if is_instance_valid(_preview_copied[id]):_preview_copied[id].free()
			_preview_copied.erase(id)
	_preview_nodes=room._visuals.get_children()
	for child in _preview_nodes:
		if child.name=="Player" or _preview_copied.has(child.get_instance_id()):continue
		var copy: Node=child.duplicate(0) # visual hierarchy only; never run duplicated constructors
		copy.process_mode=Node.PROCESS_MODE_DISABLED
		_lake_preview.add_child(copy)
		_preview_copied[child.get_instance_id()]=copy
		if child.name=="ShoreAndMountain":
			_sand_material.set_shader_parameter("lake_visible",true)
			_ecotone_material.set_shader_parameter("lake_visible",true)
		break # one new root per frame; late streamed children are not lost

var _adopted_town: Node3D
func adopt_departure(town: Node3D, woods: Node3D = null) -> void:
	# The exact visited street/cast/body is moved into the mounted world; no rebuilt copy.
	var copy: Node = _visuals.get_node_or_null("DepartureTown")
	if copy != null: copy.free()
	_adopted_town=town
	# The saloon piano and the street chatter ride with the streets (founder 2026-11-01: the music/sound "is not smooth" on mounting):
	# they fade with distance as he rides out instead of stopping dead when the town is parked.
	if is_instance_valid(town._town_audio) and town._town_audio.get_parent()==town: town._town_audio.reparent(town._visuals)
	if town._visuals.get_parent()!=_visuals: town._visuals.reparent(_visuals)
	town._visuals.position=-GoldTownChamber.DEPART_HORSE
	# The retained town already has this exact road. Draw it once at the mapped origin.
	if _road_survey != null: _road_survey.hide()
	_town_walls=town._town_col.get("walls",[])
	_town_props=town._town_col.get("props",[])
	_departure_yard=town._stable_yard
	_return_crowd=town._people
	if _departure_yard != null:
		_departure_yard.horses[1].hide()
		for entry in _departure_yard._solids.duplicate():
			if entry[0]==_departure_yard.horses[1]:
				_town_props.erase(entry[1]);_departure_yard._solids.erase(entry)
	if woods != null and _visuals.get_node_or_null("ExistingWoodsHorizon")==null:
		var backdrop := Node3D.new()
		backdrop.name="ExistingWoodsHorizon"
		_visuals.add_child(backdrop)
		backdrop.position=-GoldTownChamber.DEPART_HORSE
		for child in woods._visuals.get_children():
			if str(child.name).begins_with("Forest") or child.name in ["LoggingRoad","SneakTrail","LiftPad"]:
				backdrop.add_child(child.duplicate())

func restore_departure() -> void:
	if is_instance_valid(_adopted_town):
		_adopted_town._visuals.reparent(_adopted_town)
		_adopted_town._visuals.position=Vector3.ZERO
		if is_instance_valid(_adopted_town._town_audio) and _adopted_town._town_audio.get_parent()==_adopted_town._visuals:
			_adopted_town._town_audio.reparent(_adopted_town)
		_adopted_town=null
	if _road_survey != null: _road_survey.show()

func _blend_lake_light() -> void:
	if not is_instance_valid(_lake_reference) or _desert_env==null:return
	var blend: float=smoothstep(200.0,_route_total,_route_s)
	var env: Environment=_env_node.environment
	var target: Environment=_lake_reference._env_node.environment
	for prop in ["ambient_light_color","fog_light_color"]:
		env.set(prop,(_desert_env.get(prop) as Color).lerp(target.get(prop),blend))
	for prop in ["ambient_light_energy","fog_density","fog_sun_scatter","fog_sky_affect","tonemap_exposure","tonemap_white","adjustment_saturation","adjustment_contrast"]:
		env.set(prop,lerpf(float(_desert_env.get(prop)),float(target.get(prop)),blend))
	var sky: ProceduralSkyMaterial=env.sky.sky_material
	var start: ProceduralSkyMaterial=_desert_env.sky.sky_material
	var finish: ProceduralSkyMaterial=target.sky.sky_material
	for prop in ["sky_top_color","sky_horizon_color","ground_horizon_color","ground_bottom_color"]:
		sky.set(prop,(start.get(prop) as Color).lerp(finish.get(prop),blend))
	sky.sky_energy_multiplier=lerpf(start.sky_energy_multiplier,finish.sky_energy_multiplier,blend)
	sky.sun_angle_max=lerpf(start.sun_angle_max,finish.sun_angle_max,blend)
	var target_basis: Basis=lake_transform().basis*_lake_reference._sun.basis
	_sun.basis=Basis.from_euler(Vector3(deg_to_rad(-16),deg_to_rad(160),0)).slerp(target_basis,blend)
	_sun.light_color=Color(1,.80,.56).lerp(_lake_reference._sun.light_color,blend)
	_sun.light_energy=lerpf(2.3,_lake_reference._sun.light_energy,blend)

func _build_vultures() -> void:
	var flock := preload("res://src/episode2/art/ep2_trail_vultures.gd").new()
	flock.name="CirclingVultures"
	_visuals.add_child(flock)
	flock.position = _route_sample(160.0)[0]
	_carrion = Ep2CarrionVultures.new()
	_carrion.name = "CarrionVultures"
	_visuals.add_child(_carrion)
