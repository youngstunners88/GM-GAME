extends Node
## Loads EVERY GDScript and scene in the project and asserts they actually
## compile and instantiate.
##
## WHY THIS EXISTS: `gdparse` is syntax-only and the Godot web export reported
## "0 SCRIPT ERROR" while three boss scripts were failing to compile. The
## failure mode is silent and severe — a GDScript parse error does not stop the
## scene loading, it just attaches NO script, so the node becomes an inert body
## with no behaviour. That is how bosses 2 and 3 shipped with no AI, no health
## bar and no death sequence, and nothing in the pipeline noticed.
##
## Errors this catches that gdparse and export do not:
##   - a subclass shadowing an inherited member (`sprite` in EnemyBase)
##   - referencing a class_name that no longer exists
##   - a bad `extends` target
##   - preloading a resource path that has been moved
##
## Run: godot --headless res://tests/script_compile_test.tscn

const ROOTS := ["res://src", "res://tests"]
## Scenes that intentionally take over the game (they change state or load
## other scenes on _ready), so instantiating them here would be noisy.
const SCENE_SKIP := ["prototype_room.tscn", "main_menu.tscn", "scene_transition.tscn"]

var _script_failures: Array[String] = []
var _scene_failures: Array[String] = []
var _scripts := 0
var _scenes := 0

func _ready() -> void:
	for root in ROOTS:
		_walk(root)
	print("checked %d scripts, %d scenes" % [_scripts, _scenes])

	if _script_failures.is_empty():
		print("  [PASS] every GDScript compiles")
	else:
		print("  [FAIL] %d script(s) failed to compile:" % _script_failures.size())
		for f in _script_failures:
			print("      %s" % f)

	if _scene_failures.is_empty():
		print("  [PASS] every scene instantiates with its script attached")
	else:
		print("  [FAIL] %d scene(s) broken:" % _scene_failures.size())
		for f in _scene_failures:
			print("      %s" % f)

	var failed := _script_failures.size() + _scene_failures.size()
	if failed == 0:
		print("SCRIPT_COMPILE: ALL PASS")
		get_tree().quit(0)
	else:
		print("SCRIPT_COMPILE: %d FAILURE(S)" % failed)
		get_tree().quit(1)

func _walk(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			_walk(full)
		elif name.ends_with(".gd"):
			_check_script(full)
		elif name.ends_with(".tscn"):
			_check_scene(full, name)
		name = dir.get_next()
	dir.list_dir_end()

func _check_script(path: String) -> void:
	_scripts += 1
	var res := load(path)
	if res == null:
		_script_failures.append(path + "  (load returned null)")
		return
	# `load()` does NOT return null for a script that fails to parse — it hands
	# back a GDScript object with the error only on stderr, which is precisely
	# why the first version of this gate reported ALL PASS with the boss bug
	# reintroduced. can_instantiate() is the signal that actually discriminates:
	# a broken script reports false and an empty base type.
	if res is GDScript and not res.can_instantiate():
		_script_failures.append(path + "  (parse error — script will not attach)")

func _check_scene(path: String, file_name: String) -> void:
	for skip in SCENE_SKIP:
		if file_name == skip:
			return
	_scenes += 1
	var packed: PackedScene = load(path)
	if packed == null or not packed.can_instantiate():
		_scene_failures.append(path + "  (would not load)")
		return
	# The root's script must survive instantiation. This is the check that the
	# boss bug slipped past: the scene loaded fine, the script silently did not.
	var inst := packed.instantiate()
	var declares_script := _scene_declares_root_script(path)
	var root_script: Variant = inst.get_script()
	if declares_script:
		if root_script == null:
			_scene_failures.append(path + "  (root script missing)")
		elif root_script is GDScript and not root_script.can_instantiate():
			# The scene still instantiates; the node just silently has no
			# behaviour. This is the exact shape of the boss 2/3 bug.
			_scene_failures.append(path + "  (root script failed to compile)")
	inst.free()

## Read the .tscn text to see whether the ROOT node is supposed to carry a
## script, so scenes that legitimately have none don't get flagged.
func _scene_declares_root_script(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	f.close()
	# The root node is the first [node ...] block; its script= line appears
	# before any 'parent=' node is declared.
	var first_child := text.find("parent=")
	var script_line := text.find("script = ExtResource")
	if script_line == -1:
		return false
	return first_child == -1 or script_line < first_child
