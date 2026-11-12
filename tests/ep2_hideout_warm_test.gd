extends Node
## Gate for the hideout warm-up (mobile sprint 2026-11-10, Ep2HideoutWarm): the Smelting Facility is built behind the cart-exit film,
## and on the web its loading froze the film (7 s of 61 on a desktop CPU, 27 s at a phone-class throttle). The resources are read
## before the cart starts instead. This gate keeps that true:
##   1. after the warm-up, building the room asks the disk for NOTHING that is not already loaded (the list is complete);
##   2. the warm-up is budgeted (never the whole list in one frame), holds what it loads, and lets go when the room is built;
##   3. nothing happens off the web (native builds decode on their own threads) unless forced.
## Run: godot --headless res://tests/ep2_hideout_warm_test.tscn    Regenerate the list: tools/ep2_perf/hideout_warm_manifest.tscn -- write
const FACILITY := preload("res://src/episode2/chamber/smelting_facility.tscn")
const EXT := ["glb", "gltf", "res", "tres", "scn", "png", "jpg", "jpeg", "webp", "ogg", "mp3", "wav", "gdshader"]

var _pass: int = 0
var _fail: int = 0


## Sees every load the engine is asked for and declines it (the real loaders then do the work).
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


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])


func _ready() -> void:
	print("-- EP2 HIDEOUT WARM")
	await test_warm_off_the_web_is_inert()
	await test_warm_is_budgeted_and_complete()
	print("EP2_HIDEOUT_WARM: %s (%d pass, %d fail)" % ["ALL PASS" if _fail == 0 and _pass == 8 else "FAIL", _pass, _fail])
	get_tree().quit(0 if _fail == 0 and _pass == 8 else 1)


func test_warm_off_the_web_is_inert() -> void:
	# Arrange / Act
	Ep2HideoutWarm.force = false
	Ep2HideoutWarm.release()
	# Assert
	_check("off the web the warm-up is not wanted (native builds do not share one thread with the film)", not Ep2HideoutWarm.wanted() or OS.has_feature("web"))
	_check("the generated list is there", Ep2HideoutWarm.paths().size() >= 60, str(Ep2HideoutWarm.paths().size()))
	await get_tree().process_frame


func test_warm_is_budgeted_and_complete() -> void:
	# Arrange
	Ep2HideoutWarm.force = true
	Ep2HideoutWarm.release()
	# Act 1: the warm-up, a frame at a time
	var frames: int = 0
	var most_in_a_frame: int = 0
	while not Ep2HideoutWarm.done() and frames < 2000:
		var before: float = Ep2HideoutWarm.progress()
		Ep2HideoutWarm.step(4.0)
		most_in_a_frame = maxi(most_in_a_frame, roundi((Ep2HideoutWarm.progress() - before) * Ep2HideoutWarm.paths().size()))
		frames += 1
		if frames % 8 == 0:
			await get_tree().process_frame
	var held: int = Ep2HideoutWarm.held_count()
	_check("it finishes, over several frames (%d), never the whole list at once (most in one frame: %d of %d)" % [frames, most_in_a_frame, Ep2HideoutWarm.paths().size()],
		Ep2HideoutWarm.done() and frames >= 4 and most_in_a_frame < Ep2HideoutWarm.paths().size())
	_check("it holds what it loaded (%d resources), so the room's own loads are cache hits" % held, held >= 60)
	_check("every listed file exists in this checkout (a renamed asset fails here, not silently on a phone)",
		Array(Ep2HideoutWarm.paths()).all(func(p: String) -> bool: return ResourceLoader.exists(p)))
	# Act 2: build the room and watch what it still has to read
	var cached_before: Dictionary = {}
	for p in Ep2HideoutWarm.paths():
		cached_before[p] = ResourceLoader.has_cached(p)
	var spy := Spy.new()
	ResourceLoader.add_resource_format_loader(spy, true)
	var c: SmeltingFacilityChamber = FACILITY.instantiate()
	c.intro_film = false
	add_child(c)
	c.setup(0, [], 0)
	c.set_physics_process(false)
	await get_tree().process_frame
	await get_tree().process_frame
	ResourceLoader.remove_resource_format_loader(spy)
	# Assert: a load the spy saw is a real disk read only if the resource was not already in the cache
	var cold: Array = []
	for p in spy.seen:
		if not p.ends_with(".tscn") and not Ep2HideoutWarm.paths().has(p):
			cold.append(p)
	_check("the room reads nothing from disk that the warm-up had not loaded (%d unlisted)" % cold.size(), cold.is_empty(), str(cold.slice(0, 6)))
	_check("...and the warmed resources were still in the cache when it asked for them", cached_before.values().count(false) == 0,
		"%d not cached" % cached_before.values().count(false))
	_check("once the room is built the warm-up lets go (it can warm again for a later run)", Ep2HideoutWarm.held_count() == 0 and not Ep2HideoutWarm.done())
	Ep2HideoutWarm.force = false
	c.queue_free()
	await get_tree().process_frame
