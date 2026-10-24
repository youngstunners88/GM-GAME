extends SceneTree
## Run from an EMPTY project, never the source checkout: verify the exact exported remaps,
## imported textures,65bone skins and five clips with no raw-GLB/disk fallback.
const LIMIT := 199229440
const ACTORS := ["dude_stable_owner", "stable_assistant"]
var failures := 0

func check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["PASS" if ok else "FAIL", label])
	if not ok: failures += 1

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Pass absolute main and extras pack paths from an empty project")
		quit(1)
		return
	for path in args:
		var file := FileAccess.open(path, FileAccess.READ)
		check("pack below unchanged199229440B gate", file != null and file.get_length() <= LIMIT)
		check("pack mounts", ProjectSettings.load_resource_pack(path, true))
	for id in ACTORS:
		var path: String = "res://src/episode2/assets/town/%s.glb" % id
		check(id + " has no raw GLB fallback", not FileAccess.file_exists(path))
		var packed: PackedScene = load(path)
		check(id + " imported scene is packaged", packed != null)
		if packed == null: continue
		var actor: Node3D = packed.instantiate()
		var rigs: Array = actor.find_children("*", "Skeleton3D", true, false)
		check(id + " retains65bones", rigs.size() == 1 and (rigs[0] as Skeleton3D).get_bone_count() == 65)
		var players: Array = actor.find_children("*", "AnimationPlayer", true, false)
		for key in ["idle", "walk", "run", "turn", "jump"]:
			var found := false
			if players.size() == 1:
				for clip in (players[0] as AnimationPlayer).get_animation_list():
					if str(clip).to_lower().begins_with(key): found = true
			check(id + " packaged " + key, found)
		for child in actor.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (child as MeshInstance3D).mesh
			for s in mesh.get_surface_count():
				var material: StandardMaterial3D = mesh.surface_get_material(s) as StandardMaterial3D
				check(id + " material is present", material != null)
				if material == null: continue
				for texture in [material.albedo_texture, material.normal_texture, material.metallic_texture]:
					check(id + " imported texture is present and <=1024", texture != null and (texture as Texture2D).get_width() > 0 and (texture as Texture2D).get_width() <= 1024 and (texture as Texture2D).get_height() <= 1024)
		actor.free()
	print("STABLE_PACK: ", "ALL PASS" if failures == 0 else "%d FAILURE(S)" % failures)
	quit(1 if failures else 0)
