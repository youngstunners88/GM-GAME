extends Node
## Founder 2026-10-21: "create Jack Hammer and make him mean with a patch eye". Guards that the streamed model is really there and usable by the town's puppet
## (Ep2TownFolk): loads, skinned on the townfolk skeleton, the five clips, the right height, a separate head (the body scan's own head was smeared) and boots.
var failures: int = 0


func check(label: String, ok: bool, detail: String = "") -> void:
	print("  [PASS] " if ok else "  [FAIL] ", label, "" if ok or detail.is_empty() else "  (" + detail + ")")
	if not ok:
		failures += 1


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
	check("it is skinned on the townfolk skeleton (Head, Hand.L, Foot.R...)", sk != null and sk.find_bone("Head") >= 0 and sk.find_bone("Hand.L") >= 0 and sk.find_bone("Foot.R") >= 0 and sk.get_bone_count() >= 20)
	var ap: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var clips_ok := ap != null
	for c in ["Idle", "Walk", "Greet", "Point", "Carry"]:
		clips_ok = clips_ok and ap != null and ap.has_animation(c)
	check("the five townfolk clips are there", clips_ok)
	var lo := INF
	var hi := -INF
	var names: Array = []
	var tris := 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		names.append(String(m.name))
		var bb: AABB = m.global_transform * m.get_aabb()
		lo = minf(lo, bb.position.y)
		hi = maxf(hi, bb.end.y)
		for si in m.mesh.get_surface_count():
			tris += int(m.mesh.surface_get_array_len(si) / 3) if m.mesh.surface_get_array_index_len(si) == 0 else int(m.mesh.surface_get_array_index_len(si) / 3)
	check("he stands %.2f m with the hat (a tall man)" % Ep2JackHammer.HEIGHT_M, absf((hi - lo) - Ep2JackHammer.HEIGHT_M) < 0.06, "%.3f" % (hi - lo))
	check("he has his own head scan and boots (the body scan's head was cut off at the collar)", names.any(func(n): return String(n).contains("jack_head")) and names.any(func(n): return String(n).contains("boot_")), str(names))
	check("he is a light model (< 30k triangles)", tris > 10000 and tris < 30000, str(tris))
	check("the lock says eye patch, left eye", Ep2JackHammer.EYE_PATCH_EYE == "left")
	print("EP2_JACK_HAMMER_CHARACTER: ", "ALL PASS" if failures == 0 else "%d FAILED" % failures)
	get_tree().quit(1 if failures > 0 else 0)
