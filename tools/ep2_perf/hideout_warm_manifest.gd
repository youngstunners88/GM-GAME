extends Node
## Lists every resource the Smelting Facility loads while it builds (the room that is built BEHIND the cart-exit film), with what each
## costs to load cold, and writes them into Ep2HideoutWarm.PATHS so Episode 2 can load them before the run starts instead of inside
## the film (mobile sprint 2026-11-10: on a phone-class CPU the film froze for 27 of its 61 seconds while the room loaded).
##   <godot> --headless --path . res://tools/ep2_perf/hideout_warm_manifest.tscn            # print the list
##   <godot> --headless --path . res://tools/ep2_perf/hideout_warm_manifest.tscn -- write   # ...and rewrite the PATHS block
const FACILITY := "res://src/episode2/chamber/smelting_facility.tscn"
const TARGET := "res://src/episode2/session/ep2_hideout_warm.gd"
const EXT := ["glb", "gltf", "res", "tres", "scn", "tscn", "png", "jpg", "jpeg", "webp", "ogg", "mp3", "wav", "gdshader"]


## Sees every load the engine is asked for (it sits in front of the real loaders and always declines, so they do the work). A diff of
## ResourceLoader.has_cached() misses most of it: a PackedScene is dropped as soon as it has been instanced.
class Spy extends ResourceFormatLoader:
	var seen: PackedStringArray = PackedStringArray()
	func _get_recognized_extensions() -> PackedStringArray:
		return PackedStringArray(EXT)
	func _recognize_path(_path: String, _type: StringName) -> bool:
		return true
	func _handles_type(_type: StringName) -> bool:
		return true
	func _get_resource_type(_path: String) -> String:
		return ""
	func _load(_path: String, original_path: String, _use_sub_threads: bool, _cache_mode: int) -> Variant:
		if original_path.begins_with("res://src/") and EXT.has(original_path.get_extension().to_lower()) and not seen.has(original_path):
			seen.append(original_path)
		return ERR_FILE_UNRECOGNIZED


func _ready() -> void:
	var spy := Spy.new()
	ResourceLoader.add_resource_format_loader(spy, true)
	var c: Node = (load(FACILITY) as PackedScene).instantiate()
	c.set("intro_film", false)
	add_child(c)
	c.call("setup", 0, [], 0)
	await get_tree().process_frame
	await get_tree().process_frame
	ResourceLoader.remove_resource_format_loader(spy)
	var loaded := PackedStringArray()
	for p in spy.seen:
		if p != FACILITY and not p.ends_with(".tscn"):
			loaded.append(p)
	loaded.sort()
	# the streamed extras are not there when the run starts on the web (the pack mounts later): they cannot be warmed, only listed
	var main := PackedStringArray()
	var extras := PackedStringArray()
	for p in loaded:
		if p.begins_with("res://src/episode2/extras/"):
			extras.append(p)
		else:
			main.append(p)
	print("HIDEOUT_WARM %d resources loaded by the build (%d in the main pack, %d streamed extras)" % [loaded.size(), main.size(), extras.size()])
	for p in main:
		print("HIDEOUT_WARM   ", p)
	if "write" in OS.get_cmdline_user_args():
		var src: String = FileAccess.get_file_as_string(TARGET)
		var a: int = src.find("# --- generated: begin")
		var b: int = src.find("# --- generated: end")
		if a < 0 or b < 0:
			push_error("markers missing in " + TARGET)
			get_tree().quit(1)
			return
		var block: String = "# --- generated: begin (tools/ep2_perf/hideout_warm_manifest.tscn -- write)\nconst PATHS: PackedStringArray = [\n"
		# the main pack first, then the streamed extras: those are skipped at run time until their pack is mounted
		for p in main + extras:
			block += "\t\"%s\",\n" % p
		block += "]\n"
		var f := FileAccess.open(TARGET, FileAccess.WRITE)
		f.store_string(src.substr(0, a) + block + src.substr(b))
		f.close()
		print("HIDEOUT_WARM wrote %d paths into %s" % [loaded.size(), TARGET])
	get_tree().quit(0)
