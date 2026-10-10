extends Node
## Gate for the founder's Winchester logo (skill ep2-winchester-logo, founder 2026-10-10: "I told you to remove this brown outer
## circle! NOT EXPAND IT!!!! ... The top of the gun has random holes in it too").
##
## What it locks, measured on the SHIPPED import of winchester_1886_founder.glb (the file the viewmodel loads):
##  * no ring: no Badge_Steel / Badge_Gold surface (the dark steel ring + gold rim that overhung the receiver by 3.2 cm);
##  * not enlarged: the GM disc's radius stays <= 40 mm (it is 37.6 mm; the receiver side plate edge is 51 mm from its centre);
##  * flush: the disc lies in one plane (thickness < 3 mm), so it never stands off the receiver like a medal;
##  * the import keeps LODs OFF: Godot's auto-LOD folded the 0.9 mm-proud disc into the plate and cut the logo to a sliver;
##  * the export script has no delete-cylinder: the top strap holes came from deleting every face within 0.10 of the centre.
## Run: godot --headless res://tests/ep2_winchester_logo_test.tscn

const GLB := "res://src/episode2/assets/weapons/winchester_1886_founder.glb"
const EXPORT_SCRIPT := "res://tools/ep2_blender/rifle_export_game.py"
var _fail: int = 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])


func _ready() -> void:
	await get_tree().process_frame
	var packed: PackedScene = load(GLB) as PackedScene
	_check("the founder rifle imports", packed != null)
	if packed == null:
		_finish()
		return
	var root: Node3D = packed.instantiate() as Node3D
	add_child(root)
	var names: Array[String] = []
	var disc_pts := PackedVector3Array()
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var mat: Material = m.mesh.surface_get_material(i)
			var nm: String = String(mat.resource_name) if mat != null else ""
			names.append(nm)
			if nm.begins_with("Badge_Face"):
				var arr: Array = m.mesh.surface_get_arrays(i)
				for v in (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array):
					disc_pts.append(m.transform * v)
	print("-- NO RING")
	var ring := names.filter(func(n: String) -> bool: return n.begins_with("Badge_Steel") or n.begins_with("Badge_Gold"))
	_check("no steel ring or gold rim surface around the logo", ring.is_empty(), str(ring))
	_check("the GM disc is there", disc_pts.size() > 100, "verts %d" % disc_pts.size())
	if disc_pts.size() > 100:
		var c := Vector3.ZERO
		for p in disc_pts:
			c += p
		c /= disc_pts.size()
		var rmax := 0.0
		var xmin := INF
		var xmax := -INF
		for p in disc_pts:
			rmax = maxf(rmax, Vector2(p.y - c.y, p.z - c.z).length())
			xmin = minf(xmin, p.x)
			xmax = maxf(xmax, p.x)
		print("  disc radius %.4f m, thickness %.4f m" % [rmax, xmax - xmin])
		_check("NOT ENLARGED: disc radius <= 40 mm (plate edge is 51 mm away)", rmax <= 0.040, "r=%.4f" % rmax)
		_check("flush: the disc is one flat inlay (< 3 mm thick), not a medal", xmax - xmin < 0.003, "%.4f" % (xmax - xmin))
	print("-- IMPORT + SCRIPT")
	var imp := FileAccess.get_file_as_string(GLB + ".import")
	_check("LODs are OFF for the rifle import (auto-LOD hid the disc)", imp.contains("meshes/generate_lods=false"))
	var py := FileAccess.get_file_as_string(EXPORT_SCRIPT)
	_check("the export builds no Badge_Steel / Badge_Gold ring", not py.contains("\"Badge_Steel\"") and not py.contains("\"Badge_Gold\""))
	_check("the export deletes only faces lying entirely under the disc (no 0.10 cylinder through the top strap)",
		py.contains("def _under(f)") and not py.contains("< RH"))
	root.queue_free()
	_finish()


func _finish() -> void:
	print("EP2_WINCHESTER_LOGO: %s" % ("ALL PASS" if _fail == 0 else "%d FAILED" % _fail))
	get_tree().quit(0 if _fail == 0 else 1)
