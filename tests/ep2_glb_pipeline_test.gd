extends Node
## Gate proving the Blender→GLB→Godot pipeline end-to-end, entirely in-container.
## The GLBs were built headless by tools/blender/build_asset.py (bpy, no GPU).
## This proves Godot 4.3 actually IMPORTS and LOADS them into real mesh scenes
## — not just that the files exist. Closes the loop the founder's research doc
## described.
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/ep2_glb_pipeline_test.tscn

const ASSETS := {
	"minecart": "res://src/episode2/assets/minecart.glb",
	"gold_nugget": "res://src/episode2/assets/gold_nugget.glb",
	"rail_segment": "res://src/episode2/assets/rail_segment.glb",
}

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _count_meshes(n: Node) -> int:
	var c := 0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		c += 1
	for child in n.get_children():
		c += _count_meshes(child)
	return c

func _ready() -> void:
	await get_tree().process_frame
	print("EP2 GLB PIPELINE:")
	for name in ASSETS:
		var path: String = ASSETS[name]
		if not ResourceLoader.exists(path):
			_check("%s imported by Godot" % name, false, "not importable: %s" % path)
			continue
		var packed = load(path)
		var ok_packed: bool = packed is PackedScene
		_check("%s loads as PackedScene" % name, ok_packed)
		if not ok_packed:
			continue
		var inst: Node = packed.instantiate()
		add_child(inst)
		var meshes := _count_meshes(inst)
		_check("%s instantiates with real mesh(es) (found %d)" % [name, meshes], meshes >= 1,
			"no MeshInstance3D with a mesh under the loaded scene")
		inst.queue_free()
	# The minecart is the hero prop — expect several parts (hull/rim/wheels/emblem).
	var cart = load(ASSETS["minecart"])
	if cart is PackedScene:
		var ci: Node = cart.instantiate()
		add_child(ci)
		var m := _count_meshes(ci)
		_check("minecart has multiple parts (%d meshes: hull/rim/wheels/emblem)" % m, m >= 5)
		ci.queue_free()
	print("EP2_GLB_PIPELINE: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)
