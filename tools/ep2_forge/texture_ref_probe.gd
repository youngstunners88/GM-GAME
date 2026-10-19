extends SceneTree
## Fails (exit 1) when the web export's exclude_filter removes a file that a shipped model still uses.
## Why: gltf/embedded_image_handling=1 extracts GLB textures to loose files and the imported scene points at them, so
## excluding those files from the pck makes the model render untextured (white) in the game (a089786a, 2026-10-18:
## rifle, lift cage, flame quad and the town cast all lost their textures).
## Run: godot --headless --path . --script tools/ep2_forge/texture_ref_probe.gd
## A GLB that is itself excluded is skipped (nothing ships it, e.g. the horse's dev-only AssetFurnace sources).
## It ALSO fails when any literal `res://` path written in src code / scenes / resources / data is itself excluded (a hard reference).

const WORKFLOW := "res://.github/workflows/export-game.yml"


func _init() -> void:
	var patterns := _exclude_patterns()
	if patterns.is_empty():
		push_error("texture_ref_probe: no exclude_filter found in %s" % WORKFLOW)
		quit(2)
		return
	var bad := {}
	var scanned := 0
	for glb in _glbs("res://src"):
		if _excluded(glb, patterns):
			continue
		var ps := load(glb) as PackedScene
		if ps == null:
			continue
		scanned += 1
		var root: Node = ps.instantiate()
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.mesh == null:
				continue
			for i in m.mesh.get_surface_count():
				var mat := m.mesh.surface_get_material(i)
				if not (mat is BaseMaterial3D):
					continue
				var b := mat as BaseMaterial3D
				for t in [b.albedo_texture, b.normal_texture, b.metallic_texture, b.roughness_texture, b.ao_texture, b.emission_texture, b.orm_texture if "orm_texture" in b else null]:
					if t != null and t.resource_path != "" and _excluded(t.resource_path, patterns):
						bad[t.resource_path] = glb
		root.free()
	for k in bad.keys():
		print("[FAIL] excluded from the pck but used by %s: %s" % [bad[k], k])
	var lit := _literal_refs("res://src", patterns)
	for k in lit.keys():
		print("[FAIL] excluded from the pck but referenced by a literal path in %s: %s" % [lit[k], k])
	bad.merge(lit)
	print("texture_ref_probe: %d models scanned, %d excluded-but-used textures" % [scanned, bad.size()])
	quit(1 if not bad.is_empty() else 0)


func _exclude_patterns() -> PackedStringArray:
	var out := PackedStringArray()
	var f := FileAccess.open(WORKFLOW, FileAccess.READ)
	if f == null:
		return out
	for line in f.get_as_text().split("\n"):
		var s := line.strip_edges()
		if s.begins_with("exclude_filter=\""):
			for p in s.trim_prefix("exclude_filter=\"").trim_suffix("\"").split(","):
				if p != "":
					out.append(p)
	return out


func _excluded(res_path: String, patterns: PackedStringArray) -> bool:
	var rel := res_path.trim_prefix("res://")
	for p in patterns:
		if rel.match(p):
			return true
	return false


func _glbs(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for sub in d.get_directories():
		out.append_array(_glbs(dir.path_join(sub)))
	for f in d.get_files():
		if f.ends_with(".glb"):
			out.append(dir.path_join(f))
	return out


## Every literal res:// path in the text files under `dir` that the export filter removes (paths built with % are skipped).
const STREAMED := "res://src/episode2/extras/"


func _literal_refs(dir: String, patterns: PackedStringArray) -> Dictionary:
	var out := {}
	var re := RegEx.new()
	re.compile("res://[^\"'\\s,)\\]]+")
	for f in _text_files(dir):
		var txt := FileAccess.get_file_as_string(f)
		for m in re.search_all(txt):
			var p: String = m.get_string()
			if p.contains("%") or p.ends_with("/"):
				continue
			# res://src/episode2/extras/ is left out of index.pck ON PURPOSE: it ships as the streamed ep2_extras.pck
			# (src/episode2/ep2_extras.gd); every caller checks Ep2Extras.has() and keeps a fallback
			if p.begins_with(STREAMED):
				continue
			if _excluded(p, patterns) and not _excluded(f, patterns):
				out[p] = f
	return out


func _text_files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for sub in d.get_directories():
		out.append_array(_text_files(dir.path_join(sub)))
	for f in d.get_files():
		if f.get_extension() in ["gd", "tscn", "tres", "json", "gdshader", "cfg"]:
			out.append(dir.path_join(f))
	return out
