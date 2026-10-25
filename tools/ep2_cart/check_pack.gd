extends SceneTree
## Verify the actual web-export imports from an empty project (no disk fallback).
const DIR := "res://src/episode2/extras/road_cart/"
var failed: int = 0
var count: int = 0
func check(label: String, ok: bool) -> void:
	count += 1
	print("[PASS] " + label if ok else "[FAIL] " + label)
	if not ok: failed += 1
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(1)
		return
	for p in args:
		check("export pack below 190 MiB", FileAccess.get_file_as_bytes(p).size() < 199229440)
		check("export pack mounts", ProjectSettings.load_resource_pack(p, true))
	for name in ["donkey", "farmer", "cart"]:
		var path: String = DIR + name + ".glb"
		check(name + " has no raw source fallback", not FileAccess.file_exists(path))
		var packed: PackedScene = load(path)
		check(name + " imported scene exists in shipped extras", packed != null)
		if packed == null: continue
		var actor := packed.instantiate() as Node3D
		root.add_child(actor)
		for node in actor.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			for s in mesh.mesh.get_surface_count():
				var material := mesh.mesh.surface_get_material(s) as StandardMaterial3D
				check(name + " material loads", material != null)
				if material != null and material.albedo_texture != null:
					check(name + " texture is present at <=1024", material.albedo_texture.get_width() > 0 and material.albedo_texture.get_width() <= 1024)
		if name == "cart":
			check("both axle pivots ship", actor.find_child("Wheel_L", true, false) != null and actor.find_child("Wheel_R", true, false) != null)
		else:
			var rigs := actor.find_children("*", "Skeleton3D", true, false)
			var players := actor.find_children("*", "AnimationPlayer", true, false)
			check(name + " imported skeleton and animation player", rigs.size() == 1 and players.size() == 1)
			if rigs.size() == 1 and players.size() == 1:
				var sk := rigs[0] as Skeleton3D
				var ap := players[0] as AnimationPlayer
				check(name + " expected bone count", sk.get_bone_count() == (17 if name == "donkey" else 24))
				var required: Array = ["donkey_walk"] if name == "donkey" else ["seated_drive", "seated_greet"]
				for clip in required:
					var found: StringName = &""
					for candidate in ap.get_animation_list():
						if str(candidate).ends_with(clip): found = candidate
					check(name + " packaged clip " + clip, found != &"")
					if found != &"":
						ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
						ap.play(found)
						ap.seek(0.0, true)
						sk.force_update_all_bone_transforms()
						var bone: int = sk.find_bone("front_L_hoof" if name == "donkey" else "RightHand")
						var first: Vector3 = sk.get_bone_global_pose(bone).origin
						ap.seek(0.31 if name == "donkey" else 1.2, true)
						sk.force_update_all_bone_transforms()
						var moved: float = first.distance_to(sk.get_bone_global_pose(bone).origin)
						if clip != "seated_drive": check(name + " packaged motion changes bone pose", moved > 0.05)
		actor.free()
	print("ROAD_CART_PACK: ", count, " checks, ", failed, " failed")
	quit(0 if failed == 0 else 1)
