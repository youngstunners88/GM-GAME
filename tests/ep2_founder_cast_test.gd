extends Node
## EP2 FOUNDER CAST (founder 2026-10-27, Drive): "This is the new sheriff that needs to replace the current one ... He is sheriff James
## so just replace them and keep the narrative and the voice as is"; "This is Renegade the charismatic auctioneer. He hosts the auction."
## Both are the founder's own Tripo models, rigged (Mixamo), reduced with meshoptimizer (clean faces: no Blender decimate), CMU clips,
## streamed in ep2_extras.pck. The town's Sheriff IS Sheriff James: the retired static model is gone, he walks on his clip, talks
## while his line plays and goes back to idle.
## Run: godot --headless res://tests/ep2_founder_cast_test.tscn
const TOWN := preload("res://src/episode2/chamber/gold_town.tscn")
var failures: int = 0


func check(label: String, ok: bool, detail: String = "") -> void:
	print("  [PASS] " if ok else "  [FAIL] ", label, "" if ok or detail.is_empty() else "  (" + detail + ")")
	if not ok:
		failures += 1


func _bone(sk: Skeleton3D, suffix: String) -> int:
	for i in sk.get_bone_count():
		if sk.get_bone_name(i).ends_with(suffix):
			return i
	return -1


## Load a streamed character, check rig, clips, height and budget; returns the instance (freed by the caller) or null.
func _character(label: String, path: String, height: float, clips: Array) -> Node3D:
	check("%s is in the streamed extras" % label, Ep2Extras.has(path))
	var ps: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
	if ps == null:
		check("%s loads" % label, false)
		return null
	var root: Node3D = ps.instantiate() as Node3D
	add_child(root)
	var skels: Array = root.find_children("*", "Skeleton3D", true, false)
	var sk: Skeleton3D = skels[0] as Skeleton3D if not skels.is_empty() else null
	check("%s is skinned on a 65-bone Mixamo rig" % label, sk != null and sk.get_bone_count() == 65 and _bone(sk, "Head") >= 0 and _bone(sk, "RightHand") >= 0)
	var aps: Array = root.find_children("*", "AnimationPlayer", true, false)
	var ap: AnimationPlayer = aps[0] as AnimationPlayer if not aps.is_empty() else null
	var missing: Array = []
	for c in clips:
		if ap == null or not ap.has_animation(c):
			missing.append(c)
	check("%s has his clips %s" % [label, str(clips)], missing.is_empty(), "missing %s" % str(missing))
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
	check("%s stands %.2f m on the ground" % [label, height], absf((hi - lo) - height) < 0.05 and absf(lo) < 0.05, "%.3f m, feet %.3f" % [hi - lo, lo])
	check("%s is a light model (10k - 25k triangles)" % label, tris > 10000 and tris < 25000, str(tris))
	return root


## A shopkeeper scan: streamed, skinned on the townfolk skeleton (Head bone), her Idle clip, her height, a light mesh.
func _keeper_model(label: String, path: String, height: float) -> void:
	check("%s is in the streamed extras" % label, Ep2Extras.has(path))
	var ps: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
	if ps == null:
		check("%s loads" % label, false)
		return
	var root: Node3D = ps.instantiate() as Node3D
	add_child(root)
	var skels: Array = root.find_children("*", "Skeleton3D", true, false)
	var sk: Skeleton3D = skels[0] as Skeleton3D if not skels.is_empty() else null
	var aps: Array = root.find_children("*", "AnimationPlayer", true, false)
	var ap: AnimationPlayer = aps[0] as AnimationPlayer if not aps.is_empty() else null
	check("%s is skinned (a Head bone) with her Idle clip" % label, sk != null and _bone(sk, "Head") >= 0 and ap != null and ap.has_animation("Idle"))
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
	check("%s stands %.2f m on the ground" % [label, height], absf((hi - lo) - height) < 0.06 and absf(lo) < 0.05, "%.3f m, feet %.3f" % [hi - lo, lo])
	check("%s is a light model (10k - 32k triangles)" % label, tris > 10000 and tris < 32000, str(tris))
	root.queue_free()


func _ready() -> void:
	print("EP2 FOUNDER CAST:")
	var james: Node3D = _character("Sheriff James", Ep2Extras.SHERIFF_JAMES, 1.80, ["Idle", "Walk", "Greet", "Point", "Talk", "Counter", "CigarPuff"])
	if james != null:
		james.queue_free()
	var renegade: Node3D = _character("Renegade", Ep2Extras.RENEGADE, 1.82, ["Idle", "Walk", "Greet", "Point", "Talk", "Counter"])
	if renegade != null:
		renegade.queue_free()
	var host: bool = false
	for e in Ep2JackHammer.AUCTION_CAST:
		host = host or (str(e["id"]) == "renegade" and str(e["role"]) == "host" and str(e["model"]) == Ep2Extras.RENEGADE)
	check("Renegade hosts the auction (the auction's cast list)", host)
	check("the retired static Sheriff is gone from the main pack", not ResourceLoader.exists("res://src/episode2/assets/town/sheriff.glb"))

	print("-- the walk-in shops' keepers (fix pack 2026-10-27: two more shopkeepers, women, behind the counters)")
	for row in [["the General Store keeper", Ep2Extras.SHOPKEEPER_GENERAL, 1.66], ["the Hotel desk keeper", Ep2Extras.SHOPKEEPER_HOTEL, 1.68]]:
		_keeper_model(str(row[0]), str(row[1]), float(row[2]))
	print("-- the town's Sheriff")
	var c: GoldTownChamber = TOWN.instantiate()
	add_child(c)
	c.setup(0, [], 0)
	await get_tree().process_frame
	var sheriff: Ep2TownFolk = c._sheriff
	check("the town's Sheriff is Sheriff James (the streamed rig, with clips)", sheriff != null and sheriff.has_clips()
		and sheriff.model != null and sheriff.model.scene_file_path == Ep2Extras.SHERIFF_JAMES,
		sheriff.model.scene_file_path if sheriff != null and sheriff.model != null else "no model")
	check("...his walk is stride-matched and the statue bob is off", sheriff != null and is_equal_approx(sheriff.walk_clip_speed, GoldTownChamber.SHERIFF_WALK_STRIDE)
		and not sheriff.procedural_bob)
	var smoke: Node3D = sheriff.get_node_or_null("CigSmoke") as Node3D if sheriff != null else null
	check("...his pipe smoke rises at the pipe bowl, below his mouth", smoke != null and smoke.position.y > 1.4 and smoke.position.y < 1.6,
		str(smoke.position) if smoke != null else "no smoke")
	if sheriff != null:
		var text: String = "A fair draw, Minister. The stranger called it. The little fella was faster."
		c._caption_line("SHERIFF", text)
		for i in 3:
			sheriff.step(1.0 / 60.0)
		check("while his line plays he talks (Talk clip)", sheriff.current_clip() == "talk", sheriff.current_clip())
		await get_tree().create_timer(c._caption_seconds("SHERIFF", text) + 0.3).timeout
		for i in 3:
			sheriff.step(1.0 / 60.0)
		check("...and goes back to idle when it ends", sheriff.current_clip() == "idle", sheriff.current_clip())
	var keepers: Array = c.get_shopkeepers()
	var placed: int = 0
	for row in GoldTownChamber.SHOPKEEPERS:
		var spots: Dictionary = Ep2GoldTown.shop_spots(str(row[0]))
		for k in keepers:
			if not spots.is_empty() and str((k as Node).name) == "Shopkeeper_" + str(row[0]):
				var to_counter: Vector3 = (spots["counter"] as Vector3) - (k as Ep2TownFolk).position
				var facing_ok: bool = absf(wrapf(atan2(to_counter.x, to_counter.z) - (k as Ep2TownFolk).rotation.y, -PI, PI)) < 0.35
				if Vector2((k as Ep2TownFolk).position.x - (spots["face"] as Vector3).x, (k as Ep2TownFolk).position.z - (spots["face"] as Vector3).z).length() < 0.2 and facing_ok:
					placed += 1
	check("both shopkeepers stand behind their counters (General Store, Hotel desk), facing the customer's side",
		not Ep2GoldTown.kit_v2 or placed == 2, "%d of %d placed (kit_v2 %s)" % [placed, keepers.size(), str(Ep2GoldTown.kit_v2)])
	c.queue_free()
	await get_tree().process_frame
	print("EP2_FOUNDER_CAST: %s" % ["ALL PASS" if failures == 0 else "%d FAILURE(S)" % failures])
	get_tree().quit(failures)
