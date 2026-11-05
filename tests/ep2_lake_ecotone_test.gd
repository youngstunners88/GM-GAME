extends Node
## Founder 2026-11-04 (screenshot 3, asked three times): "after Hammer's men the land must slowly transition into lush greenery ... There mustn't be
## desert sand by the edge of the water." Guards the three things that kept it sandy: the lake terrain borrowing the desert texture for its wet edge
## and slopes, a road that stayed desert dust to the shore, and a default specular that glared the grass to a pale khaki toward the low sun.
const LAKE := preload("res://src/episode2/chamber/logans_lake.tscn")
const DESERT := "tex_desert"
var failures: int = 0


func check(label: String, ok: bool, detail: String = "") -> void:
	print("  [%s] %s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures += 1


func _desert_textures(root: Node) -> Array:
	var found: Array = []
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		var m: Material = (n as GeometryInstance3D).material_override
		if m is ShaderMaterial:
			for u in (m as ShaderMaterial).shader.get_shader_uniform_list():
				var v: Variant = (m as ShaderMaterial).get_shader_parameter(u["name"])
				if v is Texture2D and DESERT in (v as Texture2D).resource_path:
					found.append("%s.%s" % [n.name, u["name"]])
		elif m is BaseMaterial3D and (m as BaseMaterial3D).albedo_texture != null and DESERT in (m as BaseMaterial3D).albedo_texture.resource_path:
			found.append(str(n.name))
	return found


func _ready() -> void:
	print("-- EP2 LAKE ECOTONE")
	var lake: LogansLakeChamber = LAKE.instantiate() as LogansLakeChamber
	add_child(lake)
	lake.set_physics_process(false)
	lake.setup(0, [], 0)
	check("nothing in Logan's Lake is drawn with the desert's texture", _desert_textures(lake).is_empty(), str(_desert_textures(lake)))
	lake.free()
	var ground: String = FileAccess.get_file_as_string("res://src/episode2/art/lake_ground.gdshader")
	check("the lake's grass does not glare (the pale 'sand dune' toward the sun)", "SPECULAR=0.06" in ground)
	var parent := Node3D.new()
	add_child(parent)
	var road: Node3D = Ep2LakeRoad.build(parent)
	var trail_road: MeshInstance3D = road.get_node("LakeTrail") as MeshInstance3D
	var mat: ShaderMaterial = trail_road.material_override as ShaderMaterial
	var from_k: float = float(mat.get_shader_parameter("green_from"))
	var to_k: float = float(mat.get_shader_parameter("green_to"))
	var drawn: float = Ep2LakeRoad.GREEN_FROM_S / from_k
	check("the road sheds its dust only after the first ambush (s 248)", from_k * drawn >= 248.0, "%.0f m" % (from_k * drawn))
	check("...and is a dirt track before the road ends at the shore", to_k < 1.0, "green_to %.2f" % to_k)
	var last_ambush: float = 0.0
	for spec in LakeTrailChamber.BANDIT_SPECS:
		last_ambush = maxf(last_ambush, float(spec["s"]))
	check("...and well before the last of Hammer's men", to_k * drawn < last_ambush, "%.0f vs %.0f" % [to_k * drawn, last_ambush])
	var ret: ShaderMaterial = (road.get_node("TownReturnRoad") as MeshInstance3D).material_override as ShaderMaterial
	check("the town's return road stays desert (it keeps the shader's default: never green)", ret != mat and ret.get_shader_parameter("green_from") == null)
	parent.free()
	print("LAKE_ECOTONE: %s" % ("ALL PASS" if failures == 0 else "%d FAIL" % failures))
	get_tree().quit(1 if failures else 0)
