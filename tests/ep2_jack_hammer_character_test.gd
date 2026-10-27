extends Node
## Jack Hammer, the founder's OWN model (Drive "Jack+Hammer.glb", 2026-10-27: "This is Jack Hammer. He will be at the auction") - it
## replaces our 2026-10-21 Hunyuan scan. Guards that the streamed model is really there and usable by the town's puppet (Ep2TownFolk):
## loads, skinned on its Mixamo rig, the game clips plus his own Tripo emotes, the right height, a light mesh, and on the auction list.
var failures: int = 0


func check(label: String, ok: bool, detail: String = "") -> void:
	print("  [PASS] " if ok else "  [FAIL] ", label, "" if ok or detail.is_empty() else "  (" + detail + ")")
	if not ok:
		failures += 1


## The first bone whose name ends with `suffix` (the importer may turn "mixamorig:Head" into "mixamorig_Head").
func _bone(sk: Skeleton3D, suffix: String) -> int:
	for i in sk.get_bone_count():
		if sk.get_bone_name(i).ends_with(suffix):
			return i
	return -1


func _ready() -> void:
	check("the model is in the streamed extras", Ep2Extras.has(Ep2Extras.JACK_HAMMER))
	var ps: PackedScene = load(Ep2Extras.JACK_HAMMER) as PackedScene
	check("it loads as a scene", ps != null)
	if ps == null:
		print("EP2_JACK_HAMMER_CHARACTER: ", "%d FAILED" % failures)
		get_tree().quit(1)
		return
	var root: Node3D = ps.instantiate() as Node3D
	add_child(root)
	var sk: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	check("it is skinned on his Mixamo rig (Head, LeftHand, RightFoot; 65 bones)", sk != null and _bone(sk, "Head") >= 0
		and _bone(sk, "LeftHand") >= 0 and _bone(sk, "RightFoot") >= 0 and sk.get_bone_count() == 65,
		str(sk.get_bone_count()) if sk != null else "no skeleton")
	var ap: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var clips_ok := ap != null
	for c in ["Idle", "Walk", "Greet", "Point", "Talk"]:
		clips_ok = clips_ok and ap != null and ap.has_animation(c)
	check("the game clips are there (Idle, Walk, Greet, Point, Talk)", clips_ok, str(ap.get_animation_list()) if ap != null else "")
	check("...and his own Tripo emotes, without Blender's .001 suffix", ap != null and ap.has_animation("angry_01") and ap.has_animation("cheer")
		and not ap.has_animation("angry_01.001"))
	var lo := INF
	var hi := -INF
	var tris := 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var bb: AABB = m.global_transform * m.get_aabb()
		lo = minf(lo, bb.position.y)
		hi = maxf(hi, bb.end.y)
		for si in m.mesh.get_surface_count():
			tris += int(m.mesh.surface_get_array_len(si) / 3) if m.mesh.surface_get_array_index_len(si) == 0 else int(m.mesh.surface_get_array_index_len(si) / 3)
	check("he stands %.2f m (a tall man)" % Ep2JackHammer.HEIGHT_M, absf((hi - lo) - Ep2JackHammer.HEIGHT_M) < 0.06, "%.3f" % (hi - lo))
	check("he is a light model (10k - 30k triangles)", tris > 10000 and tris < 30000, str(tris))
	var listed: bool = false
	for e in Ep2JackHammer.AUCTION_CAST:
		listed = listed or (str(e["id"]) == "jack_hammer" and str(e["model"]) == Ep2Extras.JACK_HAMMER)
	check("he is on the auction's cast list", listed)
	print("EP2_JACK_HAMMER_CHARACTER: ", "ALL PASS" if failures == 0 else "%d FAILED" % failures)
	get_tree().quit(failures)
