class_name Ep2StableYard
extends Node3D
## Founder stable yard, restored at the original Episode 2 surface-set coordinates.
## One chamber-owned clock; no independent process, story beats, sale or rewards.
signal voice_line_requested(line_id: String, voice_id: String)
## A chamber displays this line and plays its recording when one is available.
signal conversation_line(who: String, text: String, line_id: String, voice_id: String)
## The referral sale completed. `paid` is BTC-equivalent faces debited in one
## tender; `credit` is the BTC amount Dude carries until the auction.
signal horse_bought(paid: int, credit: int)

const DUDE := "res://src/episode2/assets/town/dude_stable_owner.glb"
const ASSISTANT := "res://src/episode2/assets/town/stable_assistant.glb"
const RANCH_POSE = preload("res://src/episode2/actors/ep2_ranch_pose.gd")
const DUDE_VOICE := "Pe1gOSDKAuczOZqgCiEm"
const LIL_BLUNT_VOICE := "HMGfKwZCRujgXyRDUW0b"
const GREET := "dude_greet_01"
const HORSE_PRICE := 2
const BUD_PRICE := 1
const BUD_PACK := 2
const STABLE_POS := Vector3(-16.0, 0.0, 1222.0)
const PADDOCK := Rect2(-24.0, 1204.0, 20.0, 36.0)
const ACCESS_CLEAR := Rect2(-4.0, 1216.0, 16.0, 12.0)
const TALK_RADIUS := 3.0
const CLIPS := ["idle", "walk", "run", "turn", "jump"]
const HORSES: Array = [
	[Vector3(-13.0, 0, 1213.5), PI, "horse_stand"],
	[Vector3(-13.0, 0, 1230.0), PI, "horse_stand"],
	[Vector3(-7.0, 0, 1209.0), 0.3, "horse_graze"],
	[Vector3(-6.5, 0, 1231.0), -0.5, "horse_graze"],
	[Vector3(-9.0, 0, 1234.0), -PI * 0.5, "horse_walk"],
	[Vector3(-21.3, 0, 1216.2), PI * 0.5, "horse_stand"],
	[Vector3(-18.4, 0, 1214.6), -0.4, "horse_graze"],
	[Vector3(-11.4, 0, 1206.8), 0.1, "horse_graze"],
]
const DUDE_PATH: Array = [Vector3(-13.4, 0, 1221.0), Vector3(-13.4, 0, 1224.0)]
const ASSISTANT_PATH: Array = [Vector3(-7.5, 0, 1216.8), Vector3(-7.5, 0, 1220.0), Vector3(-10.0, 0, 1220.0), Vector3(-10.0, 0, 1216.8)]
const WALKING_HORSE := "PaddockWalker"
const RIDE_MOUNT := Vector3(-11.8, 0.0, 1213.5)
const RIDE_ENTRY := Vector3(-12.0, 0.0, 1219.0)
const RIDE_LOOP: Array = [Vector3(-12.0, 0, 1222.0), Vector3(-6.0, 0, 1222.0),
	Vector3(-6.0, 0, 1226.0), Vector3(-12.0, 0, 1226.0), Vector3(-12.0, 0, 1222.0)]
const RIDE_ROOT_Y := 0.72
const RIDE_SPEED := 0.85
const TROUGH_POS := Vector3(-20.0, 0.0, 1216.4)
const BRUSH_SPOT := Vector3(-8.5, 0.0, 1210.2)
const HAY_STACK := Vector3(-5.5, 0.0, 1206.5)
const HAY_DROP := Vector3(-10.8, 0.0, 1208.6)
const FOREST_KIT := "res://src/episode2/assets/woods/forest_kit.glb"
const BARK_TEX := "res://src/episode2/assets/woods/tex_woods_bark.jpg"
const BRANCH_TEX := "res://src/episode2/assets/woods/tex_woods_branch.png"
const FOLIAGE_SHADER := "res://src/episode2/art/ep2_foliage_wind.gdshader"
const TROUGH_SHADER := "res://src/episode2/art/water_river.gdshader"
const TREE_SPOTS: Array = [
	Vector2(-30, 1207), Vector2(-32, 1215), Vector2(-31, 1224), Vector2(-33, 1233),
	Vector2(-29, 1243), Vector2(-37, 1210), Vector2(-38, 1222), Vector2(-36, 1236),
	Vector2(-23, 1198), Vector2(-16, 1196), Vector2(-9, 1198), Vector2(-2, 1196),
	Vector2(-22, 1245), Vector2(-15, 1247), Vector2(-8, 1245), Vector2(-1, 1244),
	Vector2(1, 1207), Vector2(2, 1237), Vector2(0, 1199), Vector2(1, 1249),
	Vector2(-27, 1211), Vector2(-28, 1230), Vector2(-34, 1201), Vector2(-35, 1245),
]
const CONV_LINES: Dictionary = {
	"dude_ranch_01": ["DUDE", "Easy there, friend. Name's Dude."],
	"dude_ranch_02": ["DUDE", "These are my horses. I sell to folks with business; the Minister knows me."],
	"dude_ranch_03": ["DUDE", "Long road, huh? Here, one of Dude's Chill Buds, grown right here on the ranch. A gift for the trail. Stay chill."],
	"dude_ranch_04": ["DUDE", "Anything else? Two Chill Buds for one BTC, partner. Good little road companions."],
	"dude_ranch_05": ["DUDE", "Pleasure. Two fresh Chill Buds, tucked safe in your tabs. Enjoy the easy road."],
	"dude_ranch_06": ["DUDE", "No worries. Come back when your purse is heavier; the buds keep, and so does the welcome."],
	"dude_ranch_07": ["LIL BLUNT", "Name's Lil Blunt. Minister Mike Dean told me to get a horse here."],
	"dude_ranch_08": ["DUDE", "Mike Dean sent you? Then you're good folk. A saddled horse is two BTC."],
	"dude_ranch_09": ["LIL BLUNT", "Two BTC? That's a steep climb for a ride, Dude."],
	"dude_ranch_10": ["DUDE", "Fair haggle. Two even, no fooling. That's the friend price, and she's worth it."],
	"dude_ranch_11": ["DUDE", "Deal. Two BTC, square and easy. She's yours, partner. Treat her gentle."],
	"dude_ranch_12": ["DUDE", "Short on coin? Take her on credit until the auction. Two BTC later. Mike's people are good for it."],
	"dude_ranch_13": ["DUDE", "First go to Logan's Lake so your horse can drink and cool down in this heat. It's on the map."],
	"dude_ranch_14": ["DUDE", "Anything else, partner? Your horse is ready when you are. No hurry around here."],
	"dude_ranch_15": ["DUDE", "Remember: Logan's Lake first. Let her drink and cool down. It's right there on the map."],
}

var actors: Array[Ep2TownFolk] = []
var horses: Array[Node3D] = []
var _brains: Array = []
var _horse_anims: Array = []
var _solids: Array = []
var _time: float = 0.0
var _horse_sound_left: float = 2.0
var _horse_sound_index: int = 0
var _talk_cd: float = 0.0
var _quiet: bool = false
var _distant_dt: float = 0.0
var ranch_trees: Array = []
var brush_strokes: int = 0
var hay_bales_moved: int = 0
var _brush_prop: Node3D = null
var _hay_prop: Node3D = null
var _sounds: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _referred: bool = false
var _greeted: bool = false
var _horse_deal_done: bool = false
var _deal_paid: int = 0
var _deal_credit: int = 0
var _horse_followup_said: bool = false
var _bud_packs_sold: int = 0
var _conv_active: bool = false
var _conv_queue: Array = []
var _conv_current: Dictionary = {}
var _conv_wait: float = 0.0
var _ride_state: String = ""
var _ride_next: float = 62.0
var _ride_path: Array = []
var _ride_index: int = 0
var _ride_mount_t: float = 0.0
var _ride_from: Vector3 = Vector3.ZERO
var _ride_distance: float = 0.0
var _assistant_task: String = ""
var _assistant_timer: float = 0.0
var _assistant_sound: float = 0.0
var _assistant_stroke: float = 0.0
var _drink_next: float = 16.0
var _drink_left: float = 0.0
var _drink_horse: int = 5
var _drink_cycle: int = 0


static func build(parent: Node3D, props: Array, walls: Array) -> Ep2StableYard:
	var yard := Ep2StableYard.new()
	yard.name = "StableYard"
	parent.add_child(yard)
	yard._rng.seed = 771027
	yard._build_set(walls)
	yard._build_ranch_props(props)
	yard._build_trees(props)
	yard._build_horses(props)
	if ResourceLoader.exists(DUDE) and ResourceLoader.exists(ASSISTANT):
		yard._build_actor("Dude", DUDE, 1.84, DUDE_PATH, 0.75, 9.0, props)
		yard._build_actor("StableAssistant", ASSISTANT, 1.72, ASSISTANT_PATH, 0.8, 3.0, props)
	return yard


func _part(parent: Node3D, label: String, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.material_override = mat
	n.position = at
	parent.add_child(n)
	return n


func _build_ranch_props(props: Array) -> void:
	var wood: StandardMaterial3D = _wood()
	var trough := Node3D.new()
	trough.name = "WaterTrough"
	trough.position = TROUGH_POS
	add_child(trough)
	_part(trough, "TroughBottom", Vector3(0, 0.18, 0), Vector3(0.95, 0.16, 3.0), wood)
	for sx in [-1.0, 1.0]:
		_part(trough, "TroughSide", Vector3(sx * 0.43, 0.48, 0), Vector3(0.12, 0.60, 3.0), wood)
		_part(trough, "TroughEnd", Vector3(0, 0.48, sx * 1.44), Vector3(0.95, 0.60, 0.12), wood)
	var water := MeshInstance3D.new()
	water.name = "TroughWater"
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.76, 2.74)
	water.mesh = plane
	water.position.y = 0.55
	if ResourceLoader.exists(TROUGH_SHADER):
		var shader_mat := ShaderMaterial.new()
		shader_mat.shader = load(TROUGH_SHADER)
		water.material_override = shader_mat
	else:
		var water_mat := StandardMaterial3D.new()
		water_mat.albedo_color = Color(0.20, 0.38, 0.42, 0.88)
		water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		water_mat.roughness = 0.22
		water.material_override = water_mat
	trough.add_child(water)
	_solid(trough, 1.0, 0.8, props)
	var stack := Node3D.new()
	stack.name = "HayStack"
	stack.position = HAY_STACK
	add_child(stack)
	var hay := StandardMaterial3D.new()
	hay.albedo_color = Color(0.62, 0.49, 0.19)
	hay.roughness = 0.98
	for i in 4:
		_part(stack, "StackBale", Vector3((i % 2) * 0.62 - 0.31, 0.23 + floori(i / 2.0) * 0.43, 0),
			Vector3(0.58, 0.42, 0.72), hay)
	_solid(stack, 0.72, 0.9, props)
	var feeder := Node3D.new()
	feeder.name = "HayFeeder"
	feeder.position = Vector3(-11.5, 0, 1208.0)
	add_child(feeder)
	_part(feeder, "FeederFloor", Vector3(0, 0.35, 0), Vector3(1.5, 0.12, 0.65), wood)
	for sx in [-1.0, 1.0]:
		_part(feeder, "FeederLeg", Vector3(sx * 0.58, 0.18, 0), Vector3(0.12, 0.36, 0.55), wood)
	_solid(feeder, 0.72, 0.55, props)


func _build_trees(props: Array) -> void:
	var trunk: Mesh = null
	var crown: Mesh = null
	if ResourceLoader.exists(FOREST_KIT):
		var root: Node = (load(FOREST_KIT) as PackedScene).instantiate()
		for piece in ["Trunk", "Crown"]:
			var mi: MeshInstance3D = root.find_child(piece, true, false) as MeshInstance3D
			if mi != null and mi.mesh != null:
				if piece == "Trunk": trunk = mi.mesh
				else: crown = mi.mesh
		root.free()
	var kit: bool = trunk != null and crown != null
	if not kit:
		var tm := CylinderMesh.new()
		tm.top_radius = 0.72
		tm.bottom_radius = 1.0
		tm.height = 1.0
		tm.radial_segments = 7
		trunk = tm
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 1.0
		cm.height = 1.0
		cm.radial_segments = 8
		crown = cm
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.50, 0.35, 0.24)
	bark.roughness = 0.96
	if ResourceLoader.exists(BARK_TEX):
		bark.albedo_texture = load(BARK_TEX)
		bark.uv1_triplanar = true
		bark.uv1_world_triplanar = true
		bark.uv1_scale = Vector3(0.42, 0.36, 0.42)
	var leaves: Material = null
	if ResourceLoader.exists(FOLIAGE_SHADER):
		var wind := ShaderMaterial.new()
		wind.shader = load(FOLIAGE_SHADER)
		if ResourceLoader.exists(BRANCH_TEX): wind.set_shader_parameter("albedo_tex", load(BRANCH_TEX))
		wind.set_shader_parameter("tint", Color(1.05, 1.15, 0.98))
		wind.set_shader_parameter("sway", 0.32)
		wind.set_shader_parameter("speed", 0.9)
		wind.set_shader_parameter("bend_height", 12.0)
		wind.set_shader_parameter("flutter", 0.035)
		leaves = wind
	else:
		var plain := StandardMaterial3D.new()
		plain.albedo_color = Color(0.15, 0.31, 0.12)
		plain.roughness = 0.95
		leaves = plain
	var trunks: Array = []
	var crowns: Array = []
	for i in TREE_SPOTS.size():
		var p: Vector2 = TREE_SPOTS[i]
		if ACCESS_CLEAR.grow(2.0).has_point(p): continue
		var h: float = 10.0 + fposmod(float(i) * 3.7, 8.0)
		var radius: float = 0.23 + 0.035 * float(i % 4)
		var yaw: float = fposmod(float(i) * 2.399963, TAU)
		if kit:
			trunks.append(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(radius, h, radius)), Vector3(p.x, -0.1, p.y)))
			var cs: float = h / 40.0 * 1.35
			crowns.append(Transform3D(Basis(Vector3.UP, yaw + 0.8) * Basis.from_scale(Vector3.ONE * cs), Vector3(p.x, h - 40.5 * cs, p.y)))
		else:
			trunks.append(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(radius, h, radius)), Vector3(p.x, h * 0.5, p.y)))
			crowns.append(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(2.3, 5.5, 2.3)), Vector3(p.x, h * 0.72, p.y)))
		ranch_trees.append({"pos": p, "radius": radius + 0.25, "height": h})
		props.append([p, radius + 0.25])
	_tree_multi(trunk, trunks, bark, "RanchTrunks")
	_tree_multi(crown, crowns, leaves, "RanchCrowns")


func _tree_multi(mesh: Mesh, transforms: Array, mat: Material, label: String) -> void:
	if transforms.is_empty(): return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size(): mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = label
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.visibility_range_end = 190.0
	mmi.visibility_range_end_margin = 12.0
	add_child(mmi)


func _wood() -> StandardMaterial3D:
	return Ep2GoldTown._tex_mat("tex_siding.jpg", Color(0.51, 0.40, 0.27), 0.7)


func _box(label: String, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.material_override = mat
	n.position = at
	add_child(n)
	return n


func _wall(a: Vector2, b: Vector2, walls: Array, visual: bool = true) -> void:
	walls.append([a, b])
	var mid: Vector2 = (a + b) * 0.5
	var body := StaticBody3D.new()
	body.name = "StableFenceCollision"
	body.position = Vector3(mid.x, 0.65, mid.y)
	body.rotation.y = -atan2(b.y - a.y, b.x - a.x)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(a.distance_to(b), 1.3, 0.12)
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	if not visual: return
	var steps: int = maxi(1, int(ceil(a.distance_to(b) / 2.4)))
	var mat: Material = _wood()
	for i in steps + 1:
		var p: Vector2 = a.lerp(b, float(i) / float(steps))
		_box("PaddockPost", Vector3(p.x, 0.65, p.y), Vector3(0.14, 1.3, 0.14), mat)
	for y in [0.5, 1.0]:
		var rail := _box("PaddockRail", Vector3(mid.x, y, mid.y), Vector3(a.distance_to(b), 0.12, 0.09), mat)
		rail.rotation.y = body.rotation.y


func _build_set(walls: Array) -> void:
	# Original facade, not the unrelated Level1–3 stable. No new large texture.
	var barn := Sprite3D.new()
	barn.name = "OriginalStableFacade"
	barn.texture = load("res://src/assets/sprites/sprite_prop_stable.png")
	barn.pixel_size = 20.0 / 1348.0
	barn.position = STABLE_POS + Vector3(0, 131.0 * barn.pixel_size, 0)
	barn.rotation.y = PI * 0.5
	barn.shaded = true
	barn.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	add_child(barn)
	# Solid barn footprint behind the facade; the owner works outside its doors.
	for edge in [[Vector2(-23, 1218.8), Vector2(-16, 1218.8)], [Vector2(-16, 1218.8), Vector2(-16, 1225.2)],
		[Vector2(-16, 1225.2), Vector2(-23, 1225.2)], [Vector2(-23, 1225.2), Vector2(-23, 1218.8)]]:
		_wall(edge[0], edge[1], walls, false)
	# East gate is six metres wide and thirteen metres off the quad's approach road.
	for edge in [[Vector2(-24, 1204), Vector2(-4, 1204)], [Vector2(-24, 1240), Vector2(-4, 1240)],
		[Vector2(-24, 1204), Vector2(-24, 1240)], [Vector2(-4, 1204), Vector2(-4, 1218)], [Vector2(-4, 1224), Vector2(-4, 1240)],
		[Vector2(-14.6, 1212), Vector2(-14.6, 1215)], [Vector2(-14.6, 1228.5), Vector2(-14.6, 1231.5)]]:
		_wall(edge[0], edge[1], walls)
	var sign := Label3D.new()
	sign.name = "StableSign"
	sign.text = "STABLES"
	sign.font_size = 44
	sign.pixel_size = 0.014
	sign.position = STABLE_POS + Vector3(0.1, 3.45, 0)
	sign.rotation.y = PI * 0.5
	add_child(sign)


func _solid(node: Node3D, radius: float, height: float, props: Array) -> void:
	var row: Array = [Vector2(node.position.x, node.position.z), radius]
	props.append(row)
	_solids.append([node, row])
	var body := StaticBody3D.new()
	body.name = "YardBody"
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = maxf(height, radius * 2.0)
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5
	body.add_child(shape)
	node.add_child(body)


static func configure_clips(ap: AnimationPlayer) -> void:
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for key in ap.get_animation_list():
		var n: String = str(key).to_lower()
		ap.get_animation(key).loop_mode = Animation.LOOP_LINEAR if n.begins_with("idle") or n.begins_with("walk") or n.begins_with("run") else Animation.LOOP_NONE


func _build_actor(label: String, path: String, height: float, route: Array, speed: float, wait: float, props: Array) -> void:
	var folk := Ep2TownFolk.new()
	folk.name = label
	folk.looping_clips.assign(["idle", "walk", "run"])
	folk.procedural_bob = false
	folk.clip_blend = 0.18
	folk.walk_clip = "walk"
	folk.walk_clip_speed = speed
	add_child(folk)
	if not folk.setup(path, height):
		folk.queue_free()
		return
	folk.place(route[0])
	folk.face_yaw(PI * 0.5)
	folk.rotation.y = PI * 0.5
	configure_clips(folk.anim_player())
	_install_poses(folk)
	folk.hold_clip("idle")
	folk.anim_player().seek(0.7 + actors.size() * 2.1, true)
	actors.append(folk)
	_brains.append({"route": route, "index": 0, "wait": wait, "rest": wait, "speed": speed})
	_solid(folk, 0.37, height, props)
	# Dude wears his own glasses (the founder's model has rectangular black frames): no second, procedural pair.
	if label != "Dude": _make_chore_props(folk)


func _install_poses(folk: Ep2TownFolk) -> void:
	var ap: AnimationPlayer = folk.anim_player()
	if ap == null or folk.model == null: return
	for node in folk.model.find_children("*", "Skeleton3D", true, false):
		var skel: Skeleton3D = node
		var relative: Transform3D = folk.model.global_transform.affine_inverse() * skel.global_transform
		var inverse: Basis = relative.basis.inverse()
		var fwd: Vector3 = (inverse * Vector3.BACK).normalized()
		var up: Vector3 = (inverse * Vector3.UP).normalized()
		var unit: float = maxf(0.0001, folk.model.global_transform.basis.get_scale().y * relative.basis.get_scale().y)
		RANCH_POSE.install_ride(ap, skel, fwd, up, unit)
		RANCH_POSE.install_brush(ap, skel, fwd, up, unit)
		RANCH_POSE.install_carry(ap, skel, fwd, up, unit)
		return


func _make_chore_props(folk: Ep2TownFolk) -> void:
	_brush_prop = Node3D.new()
	_brush_prop.name = "HorseBrush"
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.30, 0.16, 0.07)
	var bristle := StandardMaterial3D.new()
	bristle.albedo_color = Color(0.12, 0.10, 0.07)
	_part(_brush_prop, "BrushBack", Vector3.ZERO, Vector3(0.12, 0.025, 0.065), wood)
	_part(_brush_prop, "BrushBristles", Vector3(0, -0.025, 0), Vector3(0.105, 0.035, 0.055), bristle)
	if not folk.attach_prop(_brush_prop, "RightHand", Vector3(0, 0.03, 0.02), Vector3(0, 0, 90)):
		folk.add_child(_brush_prop)
		_brush_prop.position = Vector3(0.25, 1.0, 0.25)
	_brush_prop.visible = false
	_hay_prop = Node3D.new()
	_hay_prop.name = "CarriedHay"
	folk.add_child(_hay_prop)
	var hay := StandardMaterial3D.new()
	hay.albedo_color = Color(0.65, 0.51, 0.20)
	hay.roughness = 0.98
	_part(_hay_prop, "Bale", Vector3(0, 1.02, 0.38), Vector3(0.64, 0.38, 0.42), hay)
	var twine := StandardMaterial3D.new()
	twine.albedo_color = Color(0.20, 0.15, 0.08)
	for sx in [-0.19, 0.19]:
		_part(_hay_prop, "BaleTwine", Vector3(sx, 1.02, 0.38), Vector3(0.018, 0.39, 0.43), twine)
	_hay_prop.visible = false


func _build_horses(props: Array) -> void:
	if not ResourceLoader.exists(Ep2TownLife.HORSE): return
	var scene: PackedScene = load(Ep2TownLife.HORSE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 241024
	for i in HORSES.size():
		var horse: Node3D = scene.instantiate()
		horse.name = WALKING_HORSE if i == 4 else "StableHorse%d" % i
		horse.position = HORSES[i][0]
		horse.rotation.y = float(HORSES[i][1])
		add_child(horse)
		horses.append(horse)
		var ap: AnimationPlayer = horse.find_children("*", "AnimationPlayer", true, false)[0]
		ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var clip: String = HORSES[i][2]
		ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		ap.play(clip)
		ap.speed_scale = 0.68 if clip == "horse_walk" else 1.0
		var phase: float = rng.randf_range(0.0, ap.get_animation(clip).length)
		ap.seek(phase, true)
		_horse_anims.append(ap)
		_solid(horse, 0.95, 1.8, props)


## True when Dude is at the yard, off his horse and able to have a conversation.
func can_talk(player: Vector3) -> bool:
	return not _quiet and not _conv_active and _ride_state == "" and actors.size() == 2 and player.distance_to(actors[0].position) <= TALK_RADIUS


## Start or continue Dude's yard-owned conversation. Chambers only present the
## emitted lines; every purchase and story flag remains here across handoff.
func try_talk(player: Vector3) -> bool:
	if not can_talk(player) or _talk_cd > 0.0: return false
	_talk_cd = 0.35
	actors[0].stop()
	actors[0].face_point(player)
	var lines: Array = []
	if _referred and not _horse_deal_done:
		_greeted = true
		lines.append(_line("dude_ranch_07"))
		lines.append(_line("dude_ranch_08"))
		lines.append(_line("dude_ranch_09"))
		lines.append(_line("dude_ranch_10"))
		lines.append(_line("dude_ranch_11" if _tender_for(HORSE_PRICE) != "" else "dude_ranch_12", "horse_deal"))
		lines.append(_line("dude_ranch_13"))
		lines.append({"who":"DUDE", "text":"Mount your saddled horse here at the stables, partner. Follow the trail on your map to Logan’s Lake.", "id":"", "voice":""})
		# fix pack 2026-10-27 step 11: in the same talk Dude offers his Chill Buds (the first one is his gift; more on the next talk)
		if not GameManager.dude_free_bud_claimed:
			lines.append(_line("dude_ranch_03", "free_bud"))
	elif not _greeted:
		_greeted = true
		lines.append(_line("dude_ranch_01"))
		lines.append(_line("dude_ranch_02"))
		if not GameManager.dude_free_bud_claimed:
			lines.append(_line("dude_ranch_03", "free_bud"))
	elif _horse_deal_done and not _horse_followup_said:
		_horse_followup_said = true
		lines.append(_line("dude_ranch_14"))
		lines.append(_line("dude_ranch_15"))
	else:
		lines.append(_line("dude_ranch_04"))
		lines.append(_line("dude_ranch_05" if _tender_for(BUD_PRICE) != "" else "dude_ranch_06", "buy_buds" if _tender_for(BUD_PRICE) != "" else ""))
	_begin_conversation(lines)
	return true


## Mike Dean's second-visit referral unlocks the horse negotiation, never a new
## protocol product or a staking mechanic.
func set_referred(on: bool) -> void:
	_referred = on


## Buy two Chill Buds for one face in the first affordable Armory tender.
func buy_buds() -> bool:
	if _charge(BUD_PRICE) != BUD_PRICE: return false
	GameManager.add_chill_buds(BUD_PACK)
	_bud_packs_sold += 1
	return true


## True while a yard conversation still has captions to present.
func conversation_active() -> bool:
	return _conv_active


## True during the mount, ridden loop and dismount performance.
func is_dude_riding() -> bool:
	return _ride_state in ["mount", "ride", "dismount"]


func _line(id: String, action: String = "") -> Dictionary:
	var row: Array = CONV_LINES[id]
	var who: String = str(row[0])
	return {"id": id, "who": who, "text": str(row[1]), "voice": DUDE_VOICE if who == "DUDE" else LIL_BLUNT_VOICE, "action": action}


func _begin_conversation(lines: Array) -> void:
	_conv_queue = lines.duplicate(true)
	_conv_current.clear()
	_conv_wait = 0.0
	_conv_active = not _conv_queue.is_empty()
	if _conv_active: _emit_next_line()


func _emit_next_line() -> void:
	if _conv_queue.is_empty():
		_conv_active = false
		_conv_current.clear()
		return
	_conv_current = (_conv_queue.pop_front() as Dictionary).duplicate(true)
	_perform_conversation_action(str(_conv_current.get("action", "")))
	_conv_wait = _line_seconds(str(_conv_current["id"]), str(_conv_current["text"]))
	conversation_line.emit(str(_conv_current["who"]), str(_conv_current["text"]), str(_conv_current["id"]), str(_conv_current["voice"]))
	voice_line_requested.emit(str(_conv_current["id"]), str(_conv_current["voice"]))


func _line_seconds(id: String, text: String) -> float:
	var seconds: float = clampf(1.3 + float(text.length()) * 0.052, 2.4, 6.2)
	if id != "" and Ep2TownVoiceBank.LINES.has(id):
		seconds = maxf(seconds, Ep2TownVoiceBank.seconds(id) + 0.3)
	return seconds


func _perform_conversation_action(action: String) -> void:
	match action:
		"free_bud":
			GameManager.claim_dude_free_bud()
		"buy_buds":
			buy_buds()
		"horse_deal":
			if _horse_deal_done: return
			var paid: int = _charge(HORSE_PRICE)
			_deal_paid = paid
			_deal_credit = 0 if paid == HORSE_PRICE else HORSE_PRICE
			if _deal_credit > 0: GameManager.record_dude_credit(_deal_credit)
			_horse_deal_done = true
			_greeted = true
			horse_bought.emit(_deal_paid, _deal_credit)


func _tender_for(amount: int) -> String:
	for token_variant in Ep2ArmoryState.ARMORY_TENDER:
		var token: String = str(token_variant)
		if GameManager.purse_balance(token) >= amount: return token
	return ""


func _charge(amount: int) -> int:
	var token: String = _tender_for(amount)
	if token == "" or not GameManager.purse_spend(token, amount): return 0
	return amount


func _tick_conversation(delta: float, quiet: bool) -> void:
	if quiet or not _conv_active: return
	_conv_wait = maxf(0.0, _conv_wait - delta)
	if _conv_wait <= 0.0: _emit_next_line()


func step(delta: float, player: Vector3, quiet: bool = false) -> void:
	if delta <= 0.0: return
	_quiet = quiet
	_talk_cd = maxf(0, _talk_cd - delta)
	# Offscreen routines tick at2Hz; nearby people and animals retain full rate.
	_distant_dt += delta
	if player.distance_to(STABLE_POS) > 150.0 and _distant_dt < 0.5: return
	var dt: float = _distant_dt
	_distant_dt = 0.0
	if not quiet: _time += dt
	_tick_conversation(dt, quiet)
	_tick_dude(dt, player, quiet)
	_tick_assistant(dt, quiet)
	if not quiet: _tick_walking_horse()
	_tick_drink(dt, quiet)
	if not quiet and player.distance_to(STABLE_POS) < 65.0 and not horses.is_empty():
		_horse_sound_left -= dt
		if _horse_sound_left <= 0.0:
			var i: int = _horse_sound_index % horses.size()
			_sfx3d("horse_whinny" if _horse_sound_index % 3 == 0 else "horse_snort", horses[i].position + Vector3(0,1.5,0), -4.0, 55.0)
			_horse_sound_index += 1
			_horse_sound_left = 9.0 + float((_horse_sound_index * 7) % 8)
	for ap in _horse_anims:
		(ap as AnimationPlayer).advance(dt if not quiet else 0.0)
	for entry in _solids:
		var p: Vector3 = (entry[0] as Node3D).position
		(entry[1] as Array)[0] = Vector2(p.x, p.z)


func _advance_folk(folk: Ep2TownFolk, delta: float) -> void:
	folk.step(delta)
	if folk.anim_player() != null: folk.anim_player().advance(delta)


func _tick_routine(index: int, delta: float) -> void:
	var folk: Ep2TownFolk = actors[index]
	var brain: Dictionary = _brains[index]
	brain["wait"] = float(brain["wait"]) - delta
	if not folk.is_walking() and float(brain["wait"]) <= 0.0:
		brain["index"] = (int(brain["index"]) + 1) % (brain["route"] as Array).size()
		folk.walk_to(brain["route"][brain["index"]], float(brain["speed"]))
		brain["wait"] = float(brain["rest"]) + 4.0
	_advance_folk(folk, delta)


func _tick_dude(delta: float, player: Vector3, quiet: bool) -> void:
	if actors.is_empty(): return
	var dude: Ep2TownFolk = actors[0]
	if quiet:
		if _ride_state in ["", "to_horse"]: dude.stop()
		_advance_folk(dude, 0.0)
		return
	if _ride_state in ["", "to_horse"] and (_conv_active or player.distance_to(dude.position) < 3.0):
		if _ride_state == "to_horse":
			_ride_state = ""
			_ride_next = _time + 12.0
		dude.stop()
		dude.face_point(player)
		_advance_folk(dude, delta)
		return
	match _ride_state:
		"":
			if _time >= _ride_next and horses.size() >= 1 and player.distance_to(dude.position) > 5.0:
				_ride_state = "to_horse"
				dude.hold_clip("idle")
				dude.walk_to(RIDE_MOUNT, 0.75)
				_advance_folk(dude, delta)
			else:
				_tick_routine(0, delta)
		"to_horse":
			if not dude.is_walking(): _begin_mount()
			_advance_folk(dude, delta)
		"mount":
			_tick_mount(dude, delta)
		"ride":
			_tick_ride(dude, delta, player)
		"dismount":
			_tick_dismount(dude, delta, player)


func _begin_mount() -> void:
	var dude: Ep2TownFolk = actors[0]
	dude.stop()
	_ride_state = "mount"
	_ride_mount_t = 0.0
	_ride_from = dude.position
	dude.hold_clip(RANCH_POSE.RIDE)
	_play_horse(0, "horse_stand", 1.0)


func _seat_position() -> Vector3:
	var horse: Node3D = horses[0]
	return horse.position + Basis(Vector3.UP, horse.rotation.y) * Vector3(0, RIDE_ROOT_Y, -0.08)


func _tick_mount(dude: Ep2TownFolk, delta: float) -> void:
	_ride_mount_t += delta
	var k: float = clampf(_ride_mount_t / 1.15, 0.0, 1.0)
	var e: float = k * k * (3.0 - 2.0 * k)
	dude.position = _ride_from.lerp(_seat_position(), e) + Vector3(0, 0.28 * sin(PI * e), 0)
	dude.facing = horses[0].rotation.y
	dude.rotation.y = dude.facing
	dude.anim_player().advance(delta)
	if k < 1.0: return
	_ride_state = "ride"
	_ride_path = [RIDE_ENTRY]
	_ride_path.append_array(RIDE_LOOP)
	_ride_path.append(RIDE_ENTRY)
	_ride_path.append(HORSES[0][0])
	_ride_index = 0
	_ride_distance = 0.0
	_play_horse(0, "horse_walk", RIDE_SPEED / 1.25)


func _tick_ride(dude: Ep2TownFolk, delta: float, player: Vector3) -> void:
	if _ride_index >= _ride_path.size():
		_begin_dismount()
		return
	var horse: Node3D = horses[0]
	var target: Vector3 = _ride_path[_ride_index]
	var offset: Vector3 = target - horse.position
	offset.y = 0.0
	if offset.length() < 0.08:
		_ride_index += 1
		return
	var direction: Vector3 = offset.normalized()
	var candidate: Vector3 = horse.position + direction * minf(RIDE_SPEED * delta, offset.length())
	var blocked: bool = _ride_blocked(candidate, player)
	_play_horse(0, "horse_walk", 0.0 if blocked else RIDE_SPEED / 1.25)
	if not blocked:
		horse.position = candidate
		_ride_distance += RIDE_SPEED * delta
		horse.rotation.y = lerp_angle(horse.rotation.y, atan2(direction.x, direction.z), clampf(4.0 * delta, 0.0, 1.0))
	dude.position = _seat_position()
	dude.facing = horse.rotation.y
	dude.rotation.y = dude.facing
	dude.anim_player().advance(delta)


func _ride_blocked(candidate: Vector3, player: Vector3) -> bool:
	if player.distance_to(candidate) < 2.6 or player.distance_to(horses[0].position) < 2.2: return true
	if actors.size() > 1 and actors[1].position.distance_to(candidate) < 2.2: return true
	for i in range(1, horses.size()):
		if horses[i].position.distance_to(candidate) < 1.85: return true
	if candidate.x < -22.9 or candidate.x > -5.1 or candidate.z < 1205.1 or candidate.z > 1238.9: return true
	# The barn footprint, expanded by the horse's shoulder.
	if candidate.x > -23.7 and candidate.x < -15.3 and candidate.z > 1218.1 and candidate.z < 1225.9: return true
	return false


func _begin_dismount() -> void:
	var dude: Ep2TownFolk = actors[0]
	var horse: Node3D = horses[0]
	horse.position = HORSES[0][0]
	horse.rotation.y = float(HORSES[0][1])
	_play_horse(0, "horse_stand", 1.0)
	_ride_state = "dismount"
	_ride_mount_t = 0.0
	_ride_from = dude.position


func _tick_dismount(dude: Ep2TownFolk, delta: float, player: Vector3) -> void:
	if player.distance_to(RIDE_MOUNT) < 1.6:
		dude.anim_player().advance(delta)
		return
	_ride_mount_t += delta
	var k: float = clampf(_ride_mount_t / 1.0, 0.0, 1.0)
	var e: float = k * k * (3.0 - 2.0 * k)
	dude.position = _ride_from.lerp(RIDE_MOUNT, e) + Vector3(0, 0.18 * sin(PI * e), 0)
	dude.anim_player().advance(delta)
	if k < 1.0: return
	dude.place(RIDE_MOUNT)
	dude.hold_clip("idle")
	dude.face_yaw(PI * 0.5)
	dude.rotation.y = dude.facing
	_ride_state = ""
	_ride_path.clear()
	_ride_index = 0
	_ride_next = _time + _rng.randf_range(60.0, 90.0)
	_brains[0]["wait"] = 2.0


func _play_horse(index: int, clip: String, speed: float) -> void:
	if index < 0 or index >= _horse_anims.size(): return
	var ap: AnimationPlayer = _horse_anims[index]
	if not ap.has_animation(clip): return
	ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	if ap.current_animation != clip or not ap.is_playing(): ap.play(clip)
	ap.speed_scale = speed


func _tick_walking_horse() -> void:
	for horse in horses:
		if horse.name != WALKING_HORSE: continue
		var travel: float = fposmod(_time * 0.65, 8.0)
		horse.position.z = 1233.0 + (travel if travel < 4.0 else 8.0 - travel)
		horse.rotation.y = -PI * 0.5 if travel < 4.0 else PI * 0.5
		return


func _assistant_travel(task: String, points: Array) -> void:
	var assistant: Ep2TownFolk = actors[1]
	_assistant_task = task
	assistant.walk_clip = RANCH_POSE.CARRY if task == "carry" else "walk"
	assistant.walk_path(points, 0.85)


func _start_brush() -> void:
	var assistant: Ep2TownFolk = actors[1]
	_assistant_task = "brush"
	_assistant_timer = 8.0
	_assistant_sound = 0.0
	_assistant_stroke = 0.0
	assistant.stop()
	assistant.walk_clip = "walk"
	assistant.face_point(HORSES[2][0])
	assistant.hold_clip(RANCH_POSE.BRUSH)
	_brush_prop.visible = true


func _tick_assistant(delta: float, quiet: bool) -> void:
	if actors.size() < 2: return
	var assistant: Ep2TownFolk = actors[1]
	if quiet:
		assistant.stop()
		_advance_folk(assistant, 0.0)
		return
	if _assistant_task == "":
		_assistant_travel("to_brush", [BRUSH_SPOT])
	elif _assistant_task in ["to_brush", "to_stack", "carry"] and not assistant.is_walking():
		match _assistant_task:
			"to_brush":
				_start_brush()
			"to_stack":
				_assistant_task = "pickup"
				_assistant_timer = 0.7
				assistant.hold_clip(RANCH_POSE.CARRY)
			"carry":
				_assistant_task = "drop"
				_assistant_timer = 0.7
				assistant.hold_clip(RANCH_POSE.CARRY)
	elif _assistant_task == "brush":
		_assistant_timer -= delta
		_assistant_sound -= delta
		_assistant_stroke += delta
		if _assistant_sound <= 0.0:
			_assistant_sound = 2.6
			_sfx3d("hay_rustle", assistant.position + Vector3(0, 1.0, 0), -20.0, 18.0)
		if _assistant_stroke >= 1.6:
			_assistant_stroke -= 1.6
			brush_strokes += 1
		if _assistant_timer <= 0.0:
			_brush_prop.visible = false
			assistant.hold_clip("idle")
			_assistant_travel("to_stack", [Vector3(-9.5, 0, 1212.0), Vector3(-5.5, 0, 1212.0), HAY_STACK])
	elif _assistant_task == "pickup":
		_assistant_timer -= delta
		if _assistant_timer <= 0.0:
			_hay_prop.visible = true
			_sfx3d("hay_rustle", assistant.position + Vector3(0, 0.8, 0), -18.0, 18.0)
			_assistant_travel("carry", [Vector3(-5.5, 0, 1212.0), Vector3(-10.5, 0, 1212.0), HAY_DROP])
	elif _assistant_task == "drop":
		_assistant_timer -= delta
		if _assistant_timer <= 0.0:
			_hay_prop.visible = false
			hay_bales_moved += 1
			_sfx3d("hay_rustle", assistant.position + Vector3(0, 0.8, 0), -18.0, 18.0)
			assistant.hold_clip("idle")
			_assistant_travel("to_brush", [Vector3(-10.5, 0, 1212.0), BRUSH_SPOT])
	_advance_folk(assistant, delta)


func _tick_drink(_delta: float, quiet: bool) -> void:
	if quiet or horses.size() < 8: return
	if _drink_left > 0.0:
		_drink_left -= _delta
		if _drink_left <= 0.0:
			_play_horse(_drink_horse, str(HORSES[_drink_horse][2]), 1.0)
			_drink_next = _time + 22.0 + float(_drink_cycle % 3) * 4.0
		return
	if _time < _drink_next: return
	_drink_cycle += 1
	_drink_horse = 5 + _drink_cycle % 2
	_drink_left = 5.5
	_play_horse(_drink_horse, "horse_graze", 0.55)
	_sfx3d("water_trough", TROUGH_POS + Vector3(0, 0.6, 0), -19.0, 20.0)


func _sound(id: String) -> AudioStream:
	if _sounds.has(id): return _sounds[id]
	var stream: AudioStream = null
	for pattern in ["res://src/assets/sounds/%s.ogg", "res://src/assets/sounds/%s.mp3", "res://src/assets/sounds/%s.wav",
		"res://src/episode2/assets/audio/%s.wav", "res://src/episode2/assets/audio/%s.mp3", "res://src/episode2/assets/audio/%s.ogg"]:
		var path: String = (pattern as String) % id
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	_sounds[id] = stream
	return stream


func _sfx3d(id: String, at: Vector3, db: float, max_distance: float) -> void:
	var stream: AudioStream = _sound(id)
	if stream == null: return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = "SFX"
	player.volume_db = db
	player.unit_size = 4.0
	player.max_distance = max_distance
	add_child(player)
	player.position = at
	player.play()
	player.finished.connect(player.queue_free)


## Serialize the live yard for the woods-to-town handoff, including an in-flight
## conversation, referral/sale state, chores and the riding performance.
func snapshot() -> Dictionary:
	var people: Array = []
	for i in actors.size():
		var f: Ep2TownFolk = actors[i]
		people.append({"pos": f.position, "facing": f.facing, "walking": f.is_walking(), "goal": f._goal,
			"clip": f.current_clip(), "phase": f.anim_player().current_animation_position,
			"index": _brains[i]["index"], "wait": _brains[i]["wait"]})
	var horse_state: Array = []
	for i in horses.size():
		horse_state.append({"pos": horses[i].position, "yaw": horses[i].rotation.y,
			"clip": (_horse_anims[i] as AnimationPlayer).current_animation,
			"speed": (_horse_anims[i] as AnimationPlayer).speed_scale})
	return {"time": _time, "talk_cd": _talk_cd, "people": people,
		"horse_phases": _horse_anims.map(func(ap): return ap.current_animation_position), "horse_state": horse_state,
		"greeted": _greeted, "referred": _referred, "horse_deal_done": _horse_deal_done,
		"deal_paid": _deal_paid, "deal_credit": _deal_credit, "horse_followup": _horse_followup_said,
		"bud_packs_sold": _bud_packs_sold,
		"conversation": {"active": _conv_active, "queue": _conv_queue.duplicate(true), "current": _conv_current.duplicate(true), "wait": _conv_wait},
		"ride": {"state": _ride_state, "next": _ride_next, "path": _ride_path.duplicate(), "index": _ride_index,
			"mount_t": _ride_mount_t, "from": _ride_from, "distance": _ride_distance},
		"chore": {"task": _assistant_task, "timer": _assistant_timer, "sound": _assistant_sound, "stroke": _assistant_stroke,
			"brush_strokes": brush_strokes, "bales": hay_bales_moved},
		"drink": {"next": _drink_next, "left": _drink_left, "horse": _drink_horse, "cycle": _drink_cycle}, "rng_state": _rng.state}


## Restore a same-build yard without replaying captions or repeating a grant or
## debit. The current caption simply finishes its remaining reading time.
func restore(data: Dictionary) -> void:
	_time = float(data.get("time", 0.0))
	_talk_cd = float(data.get("talk_cd", 0.0))
	_greeted = bool(data.get("greeted", false))
	_referred = bool(data.get("referred", false))
	_horse_deal_done = bool(data.get("horse_deal_done", false))
	_deal_paid = int(data.get("deal_paid", 0))
	_deal_credit = int(data.get("deal_credit", 0))
	_horse_followup_said = bool(data.get("horse_followup", false))
	_bud_packs_sold = int(data.get("bud_packs_sold", 0))
	_rng.state = int(data.get("rng_state", _rng.state))
	var conversation: Dictionary = data.get("conversation", {})
	_conv_active = bool(conversation.get("active", false))
	_conv_queue = (conversation.get("queue", []) as Array).duplicate(true)
	_conv_current = (conversation.get("current", {}) as Dictionary).duplicate(true)
	_conv_wait = float(conversation.get("wait", 0.0))
	var people: Array = data.get("people", [])
	for i in mini(actors.size(), people.size()):
		var row: Dictionary = people[i]
		var f: Ep2TownFolk = actors[i]
		f.place(row.get("pos", DUDE_PATH[0] if i == 0 else ASSISTANT_PATH[0]))
		f.face_yaw(float(row.get("facing", PI * 0.5)))
		f.rotation.y = f.facing
		_brains[i]["index"] = int(row.get("index", 0))
		_brains[i]["wait"] = float(row.get("wait", 0.0))
		if row.get("walking", false): f.walk_to(row["goal"], float(_brains[i]["speed"]))
		f.step(0.0)
		f.play_clip(str(row.get("clip", "idle")))
		f.anim_player().seek(float(row.get("phase", 0.0)), true)
	var horse_state: Array = data.get("horse_state", [])
	for i in mini(horse_state.size(), horses.size()):
		var row: Dictionary = horse_state[i]
		horses[i].position = row.get("pos", HORSES[i][0])
		horses[i].rotation.y = float(row.get("yaw", float(HORSES[i][1])))
		_play_horse(i, str(row.get("clip", str(HORSES[i][2]))), float(row.get("speed", 1.0)))
	var phases: Array = data.get("horse_phases", [])
	for i in mini(phases.size(), _horse_anims.size()):
		(_horse_anims[i] as AnimationPlayer).seek(float(phases[i]), true)
	_tick_walking_horse()
	var ride: Dictionary = data.get("ride", {})
	_ride_state = str(ride.get("state", ""))
	_ride_next = float(ride.get("next", 62.0))
	_ride_path = (ride.get("path", []) as Array).duplicate()
	_ride_index = int(ride.get("index", 0))
	_ride_mount_t = float(ride.get("mount_t", 0.0))
	_ride_from = ride.get("from", Vector3.ZERO)
	_ride_distance = float(ride.get("distance", 0.0))
	if _ride_state != "" and actors.size() == 2 and not horses.is_empty():
		var dude: Ep2TownFolk = actors[0]
		dude.stop()
		dude.hold_clip(RANCH_POSE.RIDE)
		if _ride_state == "to_horse":
			dude.hold_clip("idle")
			dude.walk_to(RIDE_MOUNT, 0.75)
		elif _ride_state == "ride":
			dude.position = _seat_position()
			dude.facing = horses[0].rotation.y
			dude.rotation.y = dude.facing
			_play_horse(0, "horse_walk", RIDE_SPEED / 1.25)
	var chore: Dictionary = data.get("chore", {})
	_assistant_task = str(chore.get("task", ""))
	_assistant_timer = float(chore.get("timer", 0.0))
	_assistant_sound = float(chore.get("sound", 0.0))
	_assistant_stroke = float(chore.get("stroke", 0.0))
	brush_strokes = int(chore.get("brush_strokes", 0))
	hay_bales_moved = int(chore.get("bales", 0))
	if actors.size() == 2:
		if _assistant_task == "brush":
			actors[1].hold_clip(RANCH_POSE.BRUSH)
		elif _assistant_task in ["pickup", "drop"]:
			actors[1].hold_clip(RANCH_POSE.CARRY)
		elif _assistant_task == "to_brush":
			_assistant_travel("to_brush", [BRUSH_SPOT])
		elif _assistant_task == "to_stack":
			_assistant_travel("to_stack", [HAY_STACK])
		elif _assistant_task == "carry":
			_assistant_travel("carry", [HAY_DROP])
	if _brush_prop != null: _brush_prop.visible = _assistant_task == "brush"
	if _hay_prop != null: _hay_prop.visible = _assistant_task in ["carry", "drop"]
	var drink: Dictionary = data.get("drink", {})
	_drink_next = float(drink.get("next", 16.0))
	_drink_left = float(drink.get("left", 0.0))
	_drink_horse = int(drink.get("horse", 5))
	_drink_cycle = int(drink.get("cycle", 0))
	for entry in _solids:
		var p: Vector3 = (entry[0] as Node3D).position
		(entry[1] as Array)[0] = Vector2(p.x, p.z)
