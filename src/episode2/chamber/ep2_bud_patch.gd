class_name Ep2BudPatch
extends RefCounted
## DUDE'S CHILL BUD PATCH (founder 2026-11-01: "some weed plant in a small patch so that if Lil Blunt wants more he can just go to it
## and purchase it just like the way he purchases from the armory"). A small fenced bed of healthy, friendly plants just outside the
## ranch fence (south of the gate road, never on Main Street). It is a SHOP, not farming: E opens a leather-and-brass panel like Rich &
## Utah's, the purse pays, and the buds go into Tabs as the same Chill Bud Dude sells (GameManager.add_chill_buds; one bud = full
## hearts when used). Nothing is free and nothing stacks without a payment.

const POS := Vector3(-1.2, 0.0, 1210.6)         # outside the paddock's east fence (x = -4), 10 m south of the lake road
const REACH := 2.6                               # E works within this many metres of the bed's centre
const BED := Vector2(2.6, 1.7)
## The patch's stock (single source for the panel and the room that debits it). Prices are feel-values in purse coins (any tender).
const STOCK: Array = [
	{"id": "buds_two", "name": "TWO CHILL BUDS", "note": "FRESH FROM THE PATCH", "price": 1, "buds": 2},
	{"id": "buds_five", "name": "A POUCH OF FIVE", "note": "FOR THE LONG TRAIL", "price": 2, "buds": 5},
]


static func item(id: String) -> Dictionary:
	for row in STOCK:
		if str(row["id"]) == id:
			return row
	return {}


static func in_reach(player: Vector3) -> bool:
	return Vector2(player.x - POS.x, player.z - POS.z).length() < REACH


## Build the bed under `parent` (the stable yard, in town coordinates). Returns the patch root.
static func build(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "ChillBudPatch"
	root.position = POS
	parent.add_child(root)
	var soil := StandardMaterial3D.new()
	soil.albedo_color = Color(0.24, 0.16, 0.09)
	soil.roughness = 1.0
	_box(root, "TilledBed", Vector3(0, 0.06, 0), Vector3(BED.x, 0.12, BED.y), soil)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.30, 0.16)
	wood.roughness = 0.9
	# a knee-high rail fence on three sides, open toward the road so the bed reads as a place to walk up to
	for p in [Vector2(-1.45, -1.0), Vector2(1.45, -1.0), Vector2(-1.45, 1.0), Vector2(1.45, 1.0)]:
		_box(root, "PatchPost", Vector3(p.x, 0.32, p.y), Vector3(0.09, 0.64, 0.09), wood)
	_box(root, "PatchRail", Vector3(0, 0.5, -1.0), Vector3(2.98, 0.06, 0.06), wood)
	_box(root, "PatchRail", Vector3(-1.45, 0.5, 0), Vector3(0.06, 0.06, 2.0), wood)
	_box(root, "PatchRail", Vector3(1.45, 0.5, 0), Vector3(0.06, 0.06, 2.0), wood)
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.30, 0.58, 0.22)
	leaf_mat.roughness = 0.75
	leaf_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var bud_mat := StandardMaterial3D.new()
	bud_mat.albedo_color = Color(0.52, 0.70, 0.30)
	bud_mat.roughness = 0.85
	var leaf: ArrayMesh = _leaflet()
	var i: int = 0
	for row in [-0.45, 0.45]:
		for col in [-0.9, -0.3, 0.3, 0.9]:
			var plant := _plant(leaf, leaf_mat, bud_mat, 0.55 + 0.12 * float((i * 5) % 3), float(i) * 1.37)
			plant.position = Vector3(col, 0.12, row)
			plant.name = "ChillBudPlant%d" % i
			root.add_child(plant)
			i += 1
	var sign := Label3D.new()
	sign.name = "PatchSign"
	sign.text = "DUDE'S PATCH\nCHILL BUDS"
	sign.font_size = 34
	sign.pixel_size = 0.008
	sign.modulate = Color(0.97, 0.86, 0.58)
	sign.outline_size = 4
	sign.position = Vector3(1.75, 1.05, 0.0)
	sign.rotation.y = PI * 0.5               # faces the road side (+X)
	root.add_child(sign)
	_box(root, "SignPost", Vector3(1.75, 0.5, 0.0), Vector3(0.08, 1.0, 0.08), wood)
	return root


## One plant: a short stem, two tiers of five-fingered leaf fans and a pale green bud on top. Friendly, healthy, not a prop gag.
static func _plant(leaf: ArrayMesh, leaf_mat: Material, bud_mat: Material, height: float, spin: float) -> Node3D:
	var plant := Node3D.new()
	plant.name = "ChillBudPlant"
	plant.rotation.y = spin
	var stem := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.012
	cyl.bottom_radius = 0.022
	cyl.height = height
	cyl.radial_segments = 6
	stem.mesh = cyl
	stem.material_override = leaf_mat
	stem.position.y = height * 0.5
	plant.add_child(stem)
	for tier in 2:
		var y: float = height * (0.45 + 0.35 * float(tier))
		var size: float = 0.30 - 0.08 * float(tier)
		for fan in 3:
			var fan_yaw: float = float(fan) * TAU / 3.0 + float(tier) * 0.6
			for finger in 5:
				var spread: float = (float(finger) - 2.0) * 0.42
				var mi := MeshInstance3D.new()
				mi.mesh = leaf
				mi.material_override = leaf_mat
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mi.position = Vector3(0, y, 0)
				# the fan points outward and droops a little; fingers splay around its axis
				mi.basis = Basis(Vector3.UP, fan_yaw) * Basis(Vector3.RIGHT, -1.05) * Basis(Vector3.FORWARD, spread)
				mi.scale = Vector3.ONE * size * (1.0 - absf(float(finger) - 2.0) * 0.18)
				plant.add_child(mi)
	var bud := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.16
	sphere.radial_segments = 8
	sphere.rings = 4
	bud.mesh = sphere
	bud.material_override = bud_mat
	bud.position.y = height + 0.04
	plant.add_child(bud)
	return plant


## A slender pointed leaflet, 1 m long along local +Y (scaled down per finger), flat in the XY plane.
static func _leaflet() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring: Array = []
	var steps: int = 6
	for k in steps + 1:
		var t: float = float(k) / float(steps)
		var w: float = sin(t * PI) * 0.11 * (1.0 - t * 0.35)
		ring.append([Vector3(-w, t, 0), Vector3(w, t, 0)])
	for k in steps:
		var a: Array = ring[k]
		var b: Array = ring[k + 1]
		for v in [a[0], b[0], a[1], a[1], b[0], b[1]]:
			st.set_normal(Vector3.BACK)
			st.add_vertex(v)
	return st.commit()


static func _box(parent: Node3D, label: String, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = label
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi
