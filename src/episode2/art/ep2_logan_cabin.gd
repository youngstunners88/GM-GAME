class_name Ep2LoganCabin
extends RefCounted
## Logan's personal home: optional visit, no economy or interaction writes.
const DIR := "res://src/episode2/extras/lake/cabin/"
const HOUSE := DIR + "cabin.glb"
const DETAILS := DIR + "details.glb"
const GM := "res://src/episode2/assets/textures/logos/logo_gold_mine.png"
const BTC := "res://src/episode2/assets/textures/tex_btc_coin.png"
const RH := "res://src/episode2/extras/town/posters/poster_rh.png"
const JACK := "res://src/episode2/extras/town/posters/poster_jack_hammer.jpg"
const SENTENCE := "Be a liquidity provider."
const POSITION := Vector3(-23, 1, 13)
const YARD := Rect2(-29, 6, 18, 14)
const BODY := Rect2(-25.8, 9.5, 5.7, 7.0)
var root: Node3D
var kit: Node3D
var ready_art: bool = false
var pictures: Dictionary = {}
var _dressed: bool = false

func build(parent: Node3D) -> void:
	if ready_art or not Ep2Extras.has(HOUSE) or not Ep2Extras.has(DETAILS): return
	root = Node3D.new()
	root.name = "LogansCabin"
	parent.add_child(root)
	root.position = POSITION
	root.rotation.y = PI / 2.0
	root.set_meta("lp_sentence", SENTENCE)
	root.set_meta("ownership", "LOGAN'S CABIN")
	root.set_meta("poster_paths", PackedStringArray([RH, JACK]))
	var shell := (load(HOUSE) as PackedScene).instantiate() as Node3D
	shell.name = "CabinShell"
	root.add_child(shell)
	for mesh in shell.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var original := mesh.mesh.surface_get_material(i) as StandardMaterial3D
			if original != null:
				var m := original.duplicate() as StandardMaterial3D
				m.roughness = .9
				m.albedo_color = Color(.84, .87, .79)
				mesh.set_surface_override_material(i, m)
	kit = (load(DETAILS) as PackedScene).instantiate() as Node3D
	kit.name = "PorchAndBelongings"
	root.add_child(kit)
	_picture("LiquiditySign", "LPFace", DIR + "liquidity_sign.png", Vector2(2.70, .84375))
	_picture("GMLogo", "GMFace", GM, Vector2(.86, .86), true)
	_picture("GoldmineWordmark", "GMWordmark", DIR + "goldmine_wordmark.png", Vector2(1.0, .25))
	_picture("BTCEmblem", "BTCFace", BTC, Vector2(.88, .88), true)
	_picture("WantedRH", "PosterRH", RH, Vector2(.72, .72), true)
	_picture("WantedJackHammer", "PosterJack", JACK, Vector2(.65, .894))
	_picture("BTCReserves", "ReserveLabel", DIR + "btc_reserves.png", Vector2(.88, .44))
	_picture("ReserveLedgerStamp", "LedgerFace", DIR + "btc_reserves.png", Vector2(.30, .15))
	(pictures["ReserveLedgerStamp"] as MeshInstance3D).rotation.x = -PI / 2.0
	_coin_faces()
	var light := OmniLight3D.new()
	light.name = "PorchOilLanternLight"
	kit.find_child("LanternLight", true, false).add_child(light)
	light.light_color = Color(1.0, .61, .25)
	light.light_energy = .60
	light.omni_range = 3.5
	light.shadow_enabled = false
	ready_art = true
	refresh_materials()

func _picture(label: String, socket: String, path: String, size: Vector2, cutout: bool = false) -> void:
	var anchor := kit.find_child(socket, true, false) as Node3D
	var image := MeshInstance3D.new()
	image.name = label
	var quad := QuadMesh.new()
	quad.size = size
	image.mesh = quad
	var m := StandardMaterial3D.new()
	m.resource_name = label + "_PhysicalImage"
	m.albedo_texture = load(path)
	m.roughness = .93
	if cutout:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = .4
	image.material_override = m
	anchor.add_child(image)
	image.position.z = .001
	image.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	image.set_meta("source_texture", path)
	pictures[label] = image

func _coin_faces() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 32:
		var a: float = float(i) / 32.0 * TAU
		var b: float = float(i + 1) / 32.0 * TAU
		for p in [Vector2.ZERO, Vector2(cos(a), sin(a)), Vector2(cos(b), sin(b))]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(p.x * .5 + .5, .5 - p.y * .5))
			st.add_vertex(Vector3(p.x * .059, 0, p.y * .059))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = st.commit()
	mm.instance_count = 8
	for i in 8:
		var marker := kit.find_child("CoinFace%d" % i, true, false) as Node3D
		mm.set_instance_transform(i, marker.transform)
	var coins := MultiMeshInstance3D.new()
	coins.name = "BTCReserveCoinFaces"
	coins.multimesh = mm
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(BTC)
	m.metallic = .38
	m.roughness = .42
	coins.material_override = m
	kit.add_child(coins)

func refresh_materials() -> void:
	if not ready_art or _dressed or not Ep2Pbr.available(): return
	Ep2Pbr.dress(kit, {
		"CabinCedar": ["planks_weathered", .8, 0.0, 1.0, Color(.25, .14, .065)],
		"CabinIron": ["steel_blued", .35, .45, .90, Color(.09, .105, .10)],
		"CabinGold": ["brass_worn", .14, .58, .75, Color(.72, .43, .09)],
		"CabinBurlap": ["fabric_burlap", .4, 0.0, 1.0, Color(.38, .29, .16)],
		"CabinLeather": ["leather_brown", .25, 0.0, 1.0, Color(.12, .055, .022)],
		"CabinStone": ["stone_rustic", .6, 0.0, 1.0, Color(.24, .25, .23)]
	}, [], true)
	_dressed = true

static func _push_rect(p: Vector3, rect: Rect2) -> Vector3:
	if not rect.has_point(Vector2(p.x, p.z)): return p
	var q := p
	var distances := [p.x - rect.position.x, rect.end.x - p.x, p.z - rect.position.y, rect.end.y - p.z]
	var index: int = distances.find(distances.min())
	match index:
		0: q.x = rect.position.x - .001
		1: q.x = rect.end.x + .001
		2: q.z = rect.position.y - .001
		3: q.z = rect.end.y + .001
	return q

static func collide(p: Vector3) -> Vector3:
	var q := p
	q.x = clampf(q.x, YARD.position.x, YARD.end.x)
	q.z = clampf(q.z, YARD.position.y, YARD.end.y)
	q = _push_rect(q, BODY)
	# Solid bench, reserves coffer and paper board. Main porch centre stays clear.
	for r in [Rect2(-20.0, 10.0, 1.5, 2.1), Rect2(-20.5, 14.1, 1.85, 2.3), Rect2(-19.5, 16.0, .8, 2.9), Rect2(-19.75, 6.8, .70, 3.8)]:
		q = _push_rect(q, r)
	return q

static func walk_height(p: Vector3) -> float:
	# Root yaw+PI/2: local forward maps to world+X; localX maps to world-Z.
	var local_x: float = 13.0 - p.z
	var local_z: float = p.x + 23.0
	if absf(local_x) < 3.2 and local_z > 2.4 and local_z < 5.1: return 1.24
	if absf(local_x) < .85 and local_z >= 5.1 and local_z < 6.1:
		return 1.0 + .24 * (6.1 - local_z)
	return Ep2LakeLandform.drawn_height(p.x, p.z)
