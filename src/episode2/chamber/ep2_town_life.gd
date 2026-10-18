class_name Ep2TownLife
extends Node3D
## THE TOWN'S LIFE (founder 2026-10-18: the train, the river and the horses belong in EPISODE 2): horses tied at the street's hitch
## rails, a river across the desert behind the church and a railway beyond it with a steam train that crosses the valley in front of
## Fort Knox. Built by Ep2GoldTown.build, so the bear woods (the town grows out of the desert as the quad comes down the road) and the
## walkable town chamber show the very same scene at the same world coordinates.
##
## Pack budget: the train is the Level 3 / Blender locomotive that already ships (src/assets/models/goldmine_train, 1:1 metres,
## front toward -X); the horse is the AssetFurnace horse shrunk to 7k tris / one 1024 texture (tools/ep2_blender/horse_game.py).

const HORSE := "res://src/episode2/assets/town/horse.glb"           # head toward +X, 3 clips: horse_stand / horse_graze / horse_walk
const LOCO := "res://src/assets/models/goldmine_train/goldmine_train.glb"
const WATER_SHADER := "res://src/episode2/art/water_river.gdshader"
const ROCK := "res://src/episode2/assets/woods/woods_rock.glb"

const TRAIN_SPEED := 7.0                         # m/s
const TRAIN_FROM_X := 170.0
const TRAIN_TO_X := -230.0                       # the whole 41 m train is past the left edge of the view
const TRAIN_GAP := 22.0                          # seconds of empty track between trains
const RAIL_TOP := 0.52
const CARS := 3

var _train: Node3D
var _smoke: CPUParticles3D
var _train_x: float = TRAIN_FROM_X
var _wait: float = 4.0
var _walker: Node3D
var _walker_dir: float = 1.0
var _t: float = 0.0
var _rng := RandomNumberGenerator.new()


## [x, z, yaw, clip]: horses tied at the hitch rails (head to the rail), one grazing by the armory lane. Yaw 0 = head toward +X.
const HORSES: Array = [
	[-4.5, 1418.0, PI, "horse_stand"], [4.5, 1431.0, 0.0, "horse_graze"], [-4.5, 1441.0, PI, "horse_stand"],
	[-24.0, 1472.0, 2.4, "horse_graze"],
]
const WALK_FROM := Vector3(8.0, 0.0, 1449.0)
const WALK_TO := Vector3(8.0, 0.0, 1472.0)


static func build(root: Node3D, props: Array) -> void:
	var life := Ep2TownLife.new()
	life.name = "TownLife"
	root.add_child(life)
	life._build_river()
	life._build_railway()
	life._build_train()
	life._build_horses(props)


func _build_river() -> void:
	var z: float = Ep2GoldTown.RIVER_Z
	var w: float = Ep2GoldTown.RIVER_W
	var bank := MeshInstance3D.new()
	bank.name = "RiverBank"
	var bm := PlaneMesh.new()
	bm.size = Vector2(520.0, w + 7.0)
	bank.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.33, 0.25, 0.16)
	bmat.roughness = 1.0
	bank.material_override = bmat
	bank.position = Vector3(0.0, 0.02, z)
	add_child(bank)
	var water := MeshInstance3D.new()
	water.name = "River"
	var pm := PlaneMesh.new()
	pm.size = Vector2(520.0, w)
	water.mesh = pm
	if ResourceLoader.exists(WATER_SHADER):
		var sm := ShaderMaterial.new()
		sm.shader = load(WATER_SHADER)
		water.material_override = sm
	else:
		var fallback := StandardMaterial3D.new()
		fallback.albedo_color = Color(0.08, 0.26, 0.34)
		water.material_override = fallback
	water.position = Vector3(0.0, 0.07, z)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	# boulders on the banks so the river sits in the land (the town's own rock, hashed so both rooms agree)
	if ResourceLoader.exists(ROCK):
		var rock_scene: PackedScene = load(ROCK)
		for i in 14:
			var rx: float = -120.0 + float(i) * 18.0 + 6.0 * sin(float(i) * 2.3)
			var side: float = -1.0 if i % 2 == 0 else 1.0
			var r: Node3D = rock_scene.instantiate() as Node3D
			r.position = Vector3(rx, -0.2, z + side * (w * 0.5 + 1.2 + float(i % 3)))
			r.rotation.y = float(i) * 1.7
			r.scale = Vector3.ONE * (0.8 + 0.5 * float(i % 4))
			add_child(r)


func _build_railway() -> void:
	var z: float = Ep2GoldTown.TRACK_Z
	var ballast := MeshInstance3D.new()
	ballast.name = "Ballast"
	var bm := BoxMesh.new()
	bm.size = Vector3(520.0, 0.36, 3.6)
	ballast.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.36, 0.33, 0.30)
	bmat.roughness = 1.0
	ballast.material_override = bmat
	ballast.position = Vector3(0.0, 0.18, z)
	add_child(ballast)
	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = Color(0.30, 0.28, 0.30)
	rail_mat.metallic = 0.0
	rail_mat.roughness = 0.6
	for s in [-0.78, 0.78]:
		var rail := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(520.0, 0.14, 0.14)
		rail.mesh = rm
		rail.material_override = rail_mat
		rail.position = Vector3(0.0, RAIL_TOP - 0.04, z + float(s))
		add_child(rail)
	var tie_mesh := BoxMesh.new()
	tie_mesh.size = Vector3(0.26, 0.15, 2.5)
	var tie_mat := StandardMaterial3D.new()
	tie_mat.albedo_color = Color(0.20, 0.13, 0.08)
	tie_mat.roughness = 1.0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = tie_mesh
	var n: int = 640
	mm.instance_count = n
	for i in n:
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(-224.0 + float(i) * 0.7, 0.42, z)))
	var ties := MultiMeshInstance3D.new()
	ties.name = "Ties"
	ties.multimesh = mm
	ties.material_override = tie_mat
	ties.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ties)


func _build_train() -> void:
	_train = Node3D.new()
	_train.name = "Train"
	add_child(_train)
	if ResourceLoader.exists(LOCO):
		var loco: Node3D = (load(LOCO) as PackedScene).instantiate() as Node3D
		loco.name = "Locomotive"
		_train.add_child(loco)
	var wood := [Color(0.42, 0.17, 0.12), Color(0.30, 0.22, 0.14), Color(0.36, 0.14, 0.10)]
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.10, 0.09, 0.09)
	for i in CARS:
		var car := Node3D.new()
		car.name = "Car%d" % i
		car.position = Vector3(12.4 + float(i) * 9.6, 0.0, 0.0)
		var body := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(8.8, 2.6, 2.4)
		body.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = wood[i % wood.size()]
		mat.roughness = 0.95
		body.material_override = mat
		body.position = Vector3(0.0, 1.95, 0.0)
		car.add_child(body)
		var roof := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(9.1, 0.2, 2.7)
		roof.mesh = rm
		roof.material_override = dark
		roof.position = Vector3(0.0, 3.35, 0.0)
		car.add_child(roof)
		var frame := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(9.0, 0.3, 2.2)
		frame.mesh = fm
		frame.material_override = dark
		frame.position = Vector3(0.0, 0.62, 0.0)
		car.add_child(frame)
		for wx in [-3.2, -2.3, 2.3, 3.2]:
			for wz in [-0.9, 0.9]:
				var wheel := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.42
				cm.bottom_radius = 0.42
				cm.height = 0.14
				wheel.mesh = cm
				wheel.material_override = dark
				wheel.rotation.x = PI * 0.5
				wheel.position = Vector3(float(wx), 0.42, float(wz))
				car.add_child(wheel)
		_train.add_child(car)
	_smoke = CPUParticles3D.new()
	_smoke.name = "Smoke"
	var puff := SphereMesh.new()
	puff.radius = 0.55
	puff.height = 1.1
	puff.radial_segments = 8
	puff.rings = 4
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.vertex_color_use_as_albedo = true
	pmat.albedo_color = Color(0.86, 0.84, 0.82)
	puff.material = pmat
	_smoke.mesh = puff
	_smoke.amount = 34
	_smoke.lifetime = 4.5
	_smoke.local_coords = false
	_smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_smoke.emission_sphere_radius = 0.25
	_smoke.direction = Vector3(0.0, 1.0, 0.0)
	_smoke.spread = 14.0
	_smoke.initial_velocity_min = 1.6
	_smoke.initial_velocity_max = 2.8
	_smoke.gravity = Vector3(1.0, 0.5, 0.0)           # the wind drags the plume back along the track as it climbs
	_smoke.scale_amount_min = 0.7
	_smoke.scale_amount_max = 1.2
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 2.6))
	_smoke.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(0.78, 0.76, 0.74, 0.75))
	fade.set_color(1, Color(0.95, 0.93, 0.90, 0.0))
	_smoke.color_ramp = fade
	_smoke.position = Vector3(-4.85, 3.95, 0.0)          # the funnel, at the front of the locomotive (-X)
	_train.add_child(_smoke)
	_train.position = Vector3(TRAIN_FROM_X, RAIL_TOP + 0.08, Ep2GoldTown.TRACK_Z)
	_train.visible = false
	_smoke.emitting = false


func _build_horses(props: Array) -> void:
	if not ResourceLoader.exists(HORSE):
		return
	var scene: PackedScene = load(HORSE)
	for i in HORSES.size():
		var h: Array = HORSES[i]
		var horse := _horse(scene, str(h[3]))
		horse.name = "Horse%d" % i
		horse.position = Vector3(float(h[0]), 0.0, float(h[1]))
		horse.rotation.y = float(h[2])
		add_child(horse)
		props.append([Vector2(float(h[0]), float(h[1])), 1.0])         # solid: Lil Blunt walks around a horse
	_walker = _horse(scene, "horse_walk")
	_walker.name = "HorseRoaming"
	_walker.position = WALK_FROM
	_walker.rotation.y = -PI * 0.5                                         # head toward +Z, up the street
	add_child(_walker)


func _horse(scene: PackedScene, clip: String) -> Node3D:
	var horse: Node3D = scene.instantiate() as Node3D
	var aps: Array = horse.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		var ap: AnimationPlayer = aps[0]
		for cn in ap.get_animation_list():
			ap.get_animation(cn).loop_mode = Animation.LOOP_LINEAR
		if ap.has_animation(clip):
			ap.play(clip)
			ap.seek(_rng.randf() * ap.get_animation(clip).length, true)          # the herd is never in lock-step
	return horse


func _process(delta: float) -> void:
	_t += delta
	if _train != null:
		if _train.visible:
			_train_x -= TRAIN_SPEED * delta
			_train.position.x = _train_x
			_train.position.y = RAIL_TOP + 0.08 + sin(_t * 9.0) * 0.012            # a faint judder on the rails
			if _train_x < TRAIN_TO_X:
				_train.visible = false
				_smoke.emitting = false
				_wait = TRAIN_GAP
		else:
			_wait -= delta
			if _wait <= 0.0:
				_train_x = TRAIN_FROM_X
				_train.position.x = _train_x
				_train.visible = true
				_smoke.emitting = true
	if is_instance_valid(_walker):
		var step: float = 0.95 * delta                                              # matches the walk cycle's stride
		_walker.position.z += _walker_dir * step
		if _walker.position.z > WALK_TO.z:
			_walker_dir = -1.0
			_walker.rotation.y = PI * 0.5
		elif _walker.position.z < WALK_FROM.z:
			_walker_dir = 1.0
			_walker.rotation.y = -PI * 0.5
