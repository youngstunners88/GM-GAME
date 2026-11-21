extends RefCounted
## THE TOWN STOCKPILE AND THE RESERVE (founder prompt STOCKPILE_RESERVE_PROMPT 2026-11-21 + his reference image of the open-front
## depot). Atmosphere only: no numbers, fees, timers or currencies anywhere.
##
## THE STOCKPILE - the town's open depot in the east back lot, its own section behind Bldg_F, off Main Street and out of the duel lane.
## Its open front faces west, into the gap after Bldg_F, so it reads from the street: gold bars stacked on pallets, crates heaped with
## nuggets, the platform scale, two ore carts, the fire pit, the STOCKPILE sign. The founder's Tripo model, opened and dressed
## (tools/ep2_blender/build_stockpile.py). The back-lot miners stay where they are, 20 m south; the wheelbarrows run between their
## ore pile and this yard (stockpile_workers.gd).
## THE RESERVE - a separate, sealed stone vault house at the town's south-east edge, under Fort Knox's hill on the lake side of the
## river: closed iron double door, iron bands, one lantern, a plain placard (tools/ep2_blender/build_stockpile_kit.py). Not attached to
## the Stockpile; nobody goes in.
##
## Called from Ep2GoldTown.build() (every room that draws the town: the same world coordinates, so the woods and the town agree). Both
## are streamed (Ep2Extras): where the extras are not mounted nothing is drawn and nothing blocks.

const STOCKPILE := "res://src/episode2/extras/stockpile/stockpile.glb"
const KIT := "res://src/episode2/extras/stockpile/stockpile_kit.glb"

## The Stockpile's frame: origin = middle of the building's front edge, local +Z = out of the open front (west), +X = north.
const FRONT := Vector3(29.0, 0.0, 1458.0)
const YAW := -PI * 0.5
const HALF_W := 6.86                 # the building (the yard in front of it reaches 6.8 m out)
const DEPTH := 7.5
## Yard pieces of the model (its local frame), measured from the model's loose parts.
const FIRE_PIT := Vector3(-6.05, 0.0, 3.97)
const SCALE_POST := Vector3(-3.2, 0.0, 2.25)
## The Reserve's frame: origin = middle of the front (the door), local +Z = out of the door (south, toward Fort Knox).
const RESERVE_FRONT := Vector3(38.0, 0.0, 1489.0)
const RESERVE_YAW := 0.0
const RESERVE_HALF := Vector2(4.4, 7.4)      # the plinth: x +-4.4, z 0.4 .. -7.4
const RESERVE_INSPECT := Vector3(0.0, 0.0, 1.6)
const RESERVE_LANTERN := Vector3(2.05, 2.64, 0.38)
## Where the desert scatter keeps clear (x, z): the Stockpile, its wheelbarrow loop and the Reserve.
const CLEAR := Rect2(19.0, 1428.0, 26.0, 66.0)

static var stockpile_drawn: bool = false
static var reserve_drawn: bool = false


static func xform() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, YAW), FRONT)


static func reserve_xform() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, RESERVE_YAW), RESERVE_FRONT)


static func to_world(local: Vector3) -> Vector3:
	return xform() * local


## Draw both into `root` and add their walls (segments [Vector2, Vector2]) and blockers to the town's lists.
static func build_site(root: Node3D, walls: Array, props: Array) -> void:
	stockpile_drawn = false
	reserve_drawn = false
	if ResourceLoader.exists(STOCKPILE):
		var sp: Node3D = (load(STOCKPILE) as PackedScene).instantiate() as Node3D
		sp.name = "Stockpile"
		sp.transform = xform()
		root.add_child(sp)
		var xf: Transform3D = xform()
		# the shell: two side walls and the back; the open front is walkable
		for seg in [[Vector3(-HALF_W, 0, 0), Vector3(-HALF_W, 0, -DEPTH)], [Vector3(HALF_W, 0, 0), Vector3(HALF_W, 0, -DEPTH)],
				[Vector3(-HALF_W, 0, -DEPTH), Vector3(HALF_W, 0, -DEPTH)]]:
			walls.append([_xz(xf * (seg[0] as Vector3)), _xz(xf * (seg[1] as Vector3))])
		# every solid prop, yard and inside (the model's Stockpile_Nav/Block_* rectangles)
		var nav: Node = sp.find_child("Stockpile_Nav", true, false)
		if nav != null:
			for c in nav.get_children():
				var b := c as Node3D
				if b != null and String(b.name).begins_with("Block_"):
					walls.append_array(_rect_walls(Vector2(b.position.x, b.position.z), Vector2(absf(b.scale.x), absf(b.scale.z)), xf))
		dress(sp)
		_embers(sp)
		stockpile_drawn = true
	if ResourceLoader.exists(KIT):
		var kit: Node3D = (load(KIT) as PackedScene).instantiate() as Node3D
		var src: Node3D = kit.find_child("Reserve", true, false) as Node3D
		if src != null:
			var r: Node3D = src.duplicate() as Node3D
			r.name = "Reserve"
			r.transform = reserve_xform()
			root.add_child(r)
			dress(r)
			var lamp := OmniLight3D.new()
			lamp.name = "ReserveLantern"
			lamp.light_color = Color(1.0, 0.72, 0.4)
			lamp.light_energy = 1.1
			lamp.omni_range = 6.0
			lamp.position = RESERVE_LANTERN
			r.add_child(lamp)
			walls.append_array(_rect_walls(Vector2(0.0, -(RESERVE_HALF.y - 0.4) * 0.5), Vector2(RESERVE_HALF.x, (RESERVE_HALF.y + 0.4) * 0.5),
				reserve_xform()))
			reserve_drawn = true
		kit.free()


## The kit's flat named materials get the town's own textures (no texture bytes in the kit): fort stone, timber; iron and gold keep
## their imported metal.
static func dress(n: Node) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var src: Material = m.mesh.surface_get_material(i)
			var nm: String = src.resource_name if src != null else ""
			var mat: Material = null
			if nm == "RS_Stone":
				mat = Ep2GoldTown._tex_mat("tex_fortstone.jpg", Color(0.86, 0.82, 0.76), 0.35)
			elif nm == "SP_Wood":
				mat = Ep2GoldTown._tex_mat("", Color(0.78, 0.66, 0.52), 0.9, Ep2GoldTown.TIMBER_TEX)
			elif nm == "RS_Wood":
				var board := StandardMaterial3D.new()                   # the placard: plain pale boards, so its word reads
				board.albedo_color = Color(0.78, 0.66, 0.48)
				board.roughness = 0.9
				mat = board
			elif nm == "RS_Ink":
				var ink := StandardMaterial3D.new()
				ink.albedo_color = Color(0.09, 0.06, 0.04)
				ink.roughness = 0.95
				ink.cull_mode = BaseMaterial3D.CULL_DISABLED              # a flat painted word: seen from the front whatever its winding
				mat = ink
			elif nm in ["SP_Gold", "Stockpile_Gold"]:
				mat = gold()
			if mat != null:
				m.set_surface_override_material(i, mat)


static var _gold: StandardMaterial3D = null


## Gold that reads as gold in the desert light: warm, half metal (a full metal only mirrors the pale sky and turns grey-green).
static func gold() -> StandardMaterial3D:
	if _gold == null:
		_gold = StandardMaterial3D.new()
		_gold.albedo_color = Color(0.93, 0.66, 0.17)
		_gold.metallic = 0.55
		_gold.metallic_specular = 0.7
		_gold.roughness = 0.32
		_gold.emission_enabled = true
		_gold.emission = Color(0.55, 0.36, 0.06)
		_gold.emission_energy_multiplier = 0.25          # a little of its own warmth in the depot's shade
	return _gold


## Embers in the fire pit: a glowing bed and a low flickering light (the fire tender keeps it going, stockpile_workers.gd).
static func _embers(sp: Node3D) -> void:
	var bed := MeshInstance3D.new()
	bed.name = "Embers"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.55
	cm.bottom_radius = 0.6
	cm.height = 0.08
	cm.radial_segments = 10
	bed.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.08, 0.02)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.36, 0.08)
	mat.emission_energy_multiplier = 1.6
	bed.material_override = mat
	bed.position = FIRE_PIT + Vector3(0.0, 0.12, 0.0)
	sp.add_child(bed)
	var glow := OmniLight3D.new()
	glow.name = "FireGlow"
	glow.light_color = Color(1.0, 0.55, 0.22)
	glow.light_energy = 0.9
	glow.omni_range = 5.0
	glow.position = FIRE_PIT + Vector3(0.0, 0.6, 0.0)
	sp.add_child(glow)


static func _xz(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


## A local rectangle (centre, half extents in x/z) as four world wall segments.
static func _rect_walls(c: Vector2, h: Vector2, xf: Transform3D) -> Array:
	var pts: Array = [Vector3(c.x - h.x, 0, c.y - h.y), Vector3(c.x + h.x, 0, c.y - h.y), Vector3(c.x + h.x, 0, c.y + h.y), Vector3(c.x - h.x, 0, c.y + h.y)]
	var out: Array = []
	for i in 4:
		out.append([_xz(xf * (pts[i] as Vector3)), _xz(xf * (pts[(i + 1) % 4] as Vector3))])
	return out
