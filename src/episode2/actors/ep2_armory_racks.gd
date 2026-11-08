class_name Ep2ArmoryRacks
extends RefCounted
## THE ARMORY'S STOCK IS THE FOUNDER'S OWN GUNS (founder 2026-11-08: "no placeholder sticks on either floor").
##
## armory2.glb carries Arm2_Guns: one empty per gun, Gun_<Rack|Near>_<family>_<n> (tools/ep2_blender/build_armory2.py). rack_guns.glb holds
## each family's founder model cut to a rack budget (tools/ep2_blender/build_rack_guns.py; the web renderer has no mesh LODs) with no
## images. Here each piece gets its SOURCE GLB's materials back, so the racks, cases, counter and gallery wear the same textures as the
## Tabs showcase and the guns in his hands. One mesh per piece is shared by every instance; nothing is drawn beyond GUN_DRAW_M.

## Each family's founder GLB (the one rack_guns.glb was cut from): its materials go on the cut piece.
const SOURCES := {
	"winchester": Ep2Extras.SHOWCASE_DIR + "winchester_1886.glb",
	"sharps": Ep2Extras.SHOWCASE_DIR + "sharps.glb",
	"coach": Ep2Extras.SHOWCASE_DIR + "coach_shotgun.glb",
	"tommy": Ep2Extras.SHOWCASE_DIR + "golden_tommy.glb",
	"mp18": Ep2Extras.SHOWCASE_DIR + "machine_gun.glb",
	"borchardt": Ep2Extras.SHOWCASE_DIR + "borchardt.glb",
	"remington": Ep2Extras.SHOWCASE_DIR + "gold_remington.glb",
	"bergmann": "res://src/episode2/assets/weapons/armory/bergmann_mp18.glb",
	"goldrev": "res://src/episode2/assets/weapons/armory/golden_revolver_gun.glb",
	"rem75": "res://src/episode2/assets/weapons/armory/remington_1875_gold.glb",
	"longbow": "res://src/episode2/assets/weapons/armory/bear_longbow.glb",
	"gatling": "res://src/episode2/assets/hideout/gatling.glb",
}
const GUN_DRAW_M := 45.0          # the guns are only drawn within this of the camera (the room is 12 m deep)


## Puts a founder gun on every Arm2_Guns slot of `a2`, at the building transform `xf`, under one node in `root`. Returns the count.
static func fill(root: Node3D, a2: Node3D, xf: Transform3D) -> int:
	var slots: Node3D = a2.find_child("Arm2_Guns", true, false) as Node3D
	if slots == null or not Ep2Extras.has(Ep2Extras.RACK_GUNS):
		return 0
	var lib: Node3D = (load(Ep2Extras.RACK_GUNS) as PackedScene).instantiate() as Node3D
	var meshes: Dictionary = {}
	for mi in lib.find_children("*", "MeshInstance3D", true, false):
		meshes[String(mi.name)] = (mi as MeshInstance3D).mesh
	lib.free()
	var holder := Node3D.new()
	holder.name = "Arm2_Guns_Bldg_Armory"
	holder.transform = xf * slots.transform
	root.add_child(holder)
	var dressed: Dictionary = {}           # "Rack_winchester" -> the piece wearing its source's materials
	var n: int = 0
	for s in slots.get_children():
		var parts: PackedStringArray = String(s.name).split("_")     # Gun, Rack|Near, family, n
		if parts.size() < 4:
			continue
		var key: String = parts[1] + "_" + parts[2]
		if not dressed.has(key):
			dressed[key] = _dress(meshes.get(key) as ArrayMesh, str(SOURCES.get(parts[2], "")))
		if dressed[key] == null:
			continue
		var g := MeshInstance3D.new()
		g.name = String(s.name)
		g.mesh = dressed[key]
		g.transform = (s as Node3D).transform
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF      # indoors under the gallery: the lamps cast none either
		g.visibility_range_end = GUN_DRAW_M
		holder.add_child(g)
		n += 1
	return n


## A copy of the cut piece with each surface wearing the source GLB's material of the same name (Blender's ".001" suffix ignored;
## a one-material source dresses every surface).
static func _dress(mesh: ArrayMesh, src: String) -> ArrayMesh:
	if mesh == null:
		return null
	var out: ArrayMesh = mesh.duplicate() as ArrayMesh
	if src == "" or not ResourceLoader.exists(src):
		return out
	var by_name: Dictionary = {}
	var model: Node = (load(src) as PackedScene).instantiate()
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		for si in m.get_surface_count():
			var mat: Material = m.surface_get_material(si)
			if mat != null:
				by_name[String(mat.resource_name)] = mat
	model.free()
	for si in out.get_surface_count():
		var cur: Material = out.surface_get_material(si)
		var nm: String = String(cur.resource_name) if cur != null else ""
		if not by_name.has(nm) and nm.length() > 4 and nm.substr(nm.length() - 4, 1) == ".":
			nm = nm.left(-4)
		if by_name.has(nm):
			out.surface_set_material(si, by_name[nm])
		elif by_name.size() == 1:
			out.surface_set_material(si, by_name.values()[0])
	return out
