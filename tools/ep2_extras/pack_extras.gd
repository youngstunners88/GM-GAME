extends SceneTree
## Pack res://src/episode2/extras/ into ep2_extras.pck for the web build (see src/episode2/ep2_extras.gd).
## Run AFTER the project is imported, with the CI Godot (4.3):
##   godot --headless --path . --script tools/ep2_extras/pack_extras.gd -- web/game/ep2_extras.pck
## For an imported resource the pack holds its `.import` remap file plus every file in its dest_files (all texture-compression
## variants, so the runtime picks s3tc or etc2 like a normal export); the raw source (the .glb/.jpg) is NOT shipped, exactly like
## an export. Plain resources without an .import (.tres, .json) are packed as they are. Prints EXTRAS_PACK: <n> files, <bytes>.

const ROOT := "res://src/episode2/extras"


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "web/game/ep2_extras.pck"
	var files: Array = []
	_walk(ROOT, files)
	var pk := PCKPacker.new()
	if pk.pck_start(out) != OK:
		push_error("EXTRAS_PACK: cannot write " + out)
		quit(1)
		return
	var n: int = 0
	var missing: Array = []
	for f in files:
		var p: String = str(f)
		if p.ends_with(".import"):
			var cf := ConfigFile.new()
			if cf.load(p) != OK:
				missing.append(p)
				continue
			pk.add_file(p, ProjectSettings.globalize_path(p))
			n += 1
			for d in cf.get_value("deps", "dest_files", []):
				var dp: String = str(d)
				if not FileAccess.file_exists(dp):
					missing.append(dp)
					continue
				pk.add_file(dp, ProjectSettings.globalize_path(dp))
				n += 1
		elif not FileAccess.file_exists(p + ".import") and not p.ends_with(".uid"):
			pk.add_file(p, ProjectSettings.globalize_path(p))
			n += 1
	pk.flush()
	var size: int = FileAccess.get_file_as_bytes(out).size() if FileAccess.file_exists(out) else 0
	if not missing.is_empty():
		push_error("EXTRAS_PACK: missing (import the project first): " + str(missing))
		quit(1)
		return
	print("EXTRAS_PACK: %d files, %d bytes -> %s" % [n, size, out])
	quit(0 if n > 0 else 1)


func _walk(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		out.append(dir.path_join(f))
	for sub in d.get_directories():
		_walk(dir.path_join(sub), out)
