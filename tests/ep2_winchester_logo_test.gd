extends Node
## Gate for the founder's Winchester logo (skill ep2-winchester-logo). Founder 2026-10-10: "I told you to remove this brown outer
## circle! NOT EXPAND IT!!!! ... The top of the gun has random holes in it too", then (same day) "The rifle that I gave you is Lil
## Blunt's rifle, you can see that his arm is green. I want you to fix the issue of the logo on it, but dont fuck it up like before!!!!"
##
## The shipped winchester_1886_founder.glb is now HIS Tripo rifle (green arm + glove baked in). Its logo was a smeared gold blob in a
## recessed dish; it was fixed WITHOUT adding geometry (tools/ep2_forge/repaint_rifle_logo.py): the founder-approved emblem projected
## into the texture, the dish flattened (vertices moved, none deleted). What this locks, on the SHIPPED import and the fix report:
##  * no ring: no Badge_Steel / Badge_Gold surface, ONE material (no separate bezel / disc / medal mesh can sneak back);
##  * no holes: the fix kept the mesh topology (same faces before and after), moved no vertex outside the receiver, none above it;
##  * not enlarged: the logo radius <= the old blob's radius on both sides, and <= 45 mm;
##  * the band round the logo on the side the player sees is not darker than it was (no new ring by shading);
##  * the import keeps LODs OFF (auto-LOD folded the old 0.9 mm disc into the plate);
##  * the rifle is in the viewmodel's frame: ~1.2 m, muzzle +Z.
## Run: godot --headless res://tests/ep2_winchester_logo_test.tscn

const GLB := "res://src/episode2/assets/weapons/winchester_1886_founder.glb"
const REPORT := "res://docs/episode2-quality/lil-blunt-rifle-logo-2026-10-10/logo_fix_report.json"
const FIX_SCRIPT := "res://tools/ep2_forge/repaint_rifle_logo.py"
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
	_check("Lil Blunt's rifle imports", packed != null)
	if packed == null:
		_finish()
		return
	var root: Node3D = packed.instantiate() as Node3D
	add_child(root)
	var names: Array[String] = []
	var aabb := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var bb: AABB = m.global_transform * m.mesh.get_aabb()
		aabb = bb if first else aabb.merge(bb)
		first = false
		for i in m.mesh.get_surface_count():
			var mat: Material = m.mesh.surface_get_material(i)
			names.append(String(mat.resource_name) if mat != null else "")
	print("-- NO RING")
	var ring := names.filter(func(n: String) -> bool: return n.begins_with("Badge_Steel") or n.begins_with("Badge_Gold") or n.begins_with("Badge"))
	_check("no steel ring / gold rim / badge disc surface", ring.is_empty(), str(ring))
	_check("one material: the logo lives in the rifle's own texture, no extra medal mesh", names.size() == 1, str(names))
	print("-- FRAME")
	_check("viewmodel frame: ~1.2 m long, muzzle toward +Z", absf(aabb.size.z - 1.2) < 0.06 and aabb.end.z > 0.55, str(aabb))
	print("-- THE FIX (measured report)")
	var rep: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REPORT)) if FileAccess.file_exists(REPORT) else {}
	_check("fix report present", not rep.is_empty())
	if not rep.is_empty():
		_check("NO HOLES: same mesh topology before and after (no face deleted)", bool(rep["topology_identical"])
			and int(rep["faces_before"]) == int(rep["faces_after"]), "%s -> %s" % [rep["faces_before"], rep["faces_after"]])
		_check("nothing moved outside the receiver side plates, nothing above the receiver top",
			int(rep["verts_moved_outside_receiver"]) == 0 and float(rep["moved_max_height_m"]) < float(rep["receiver_top_height_m"]))
		for s in rep["sites"]:
			_check("NOT ENLARGED (side %s): logo radius %.1f mm <= old blob %.1f mm and <= 45 mm" % [s["side"], s["logo_radius_mm"], s["blob_radius_mm"]],
				float(s["logo_radius_mm"]) <= float(s["blob_radius_mm"]) and float(s["logo_radius_mm"]) <= 45.0)
		var seen: Dictionary = rep["render_band_over_plate"]["left_side_seen_in_first_person"]
		_check("the side the player sees has no ring by shading (band/plate after >= before and >= 0.85)",
			float(seen["after"]) >= float(seen["before"]) and float(seen["after"]) >= 0.85, str(seen))
	var py := FileAccess.get_file_as_string(FIX_SCRIPT)
	_check("the fix script deletes no faces (texture + vertex moves only)", not py.contains("update_faces") and not py.contains("remove_faces")
		and py.contains("geometry_changed=False"))
	print("-- IMPORT")
	var imp := FileAccess.get_file_as_string(GLB + ".import")
	_check("LODs are OFF for the rifle import", imp.contains("meshes/generate_lods=false"))
	root.queue_free()
	_finish()


func _finish() -> void:
	print("EP2_WINCHESTER_LOGO: %s" % ("ALL PASS" if _fail == 0 else "%d FAILED" % _fail))
	get_tree().quit(0 if _fail == 0 else 1)
