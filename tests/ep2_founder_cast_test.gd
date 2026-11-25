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
	check("%s is skinned (a Head bone) with the Idle clip" % label, sk != null and _bone(sk, "Head") >= 0 and ap != null and ap.has_animation("Idle"))
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
	for row in [["the General Store keeper", Ep2Extras.SHOPKEEPER_GENERAL, 1.66], ["the Hotel desk keeper", Ep2Extras.SHOPKEEPER_HOTEL, 1.68],
			["Bam Bankman Free (the cell, fix pack 2026-10-27)", Ep2TownLaw.BAM_MODEL, 1.92]]:
		_keeper_model(str(row[0]), str(row[1]), float(row[2]))
	print("-- the town's Sheriff")
	var c: GoldTownChamber = TOWN.instantiate()
	add_child(c)
	c.setup(0, [], 0)
	await get_tree().process_frame
	var sheriff: Ep2TownFolk = c._sheriff
	check("the town restores the founder's previous Sheriff", sheriff != null and sheriff.model != null
		and sheriff.model.scene_file_path == GoldTownChamber.SHERIFF_MODEL)
	check("the previous Sheriff's pipe smoke remains", sheriff.get_node_or_null("CigSmoke") != null)
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
	if Ep2GoldTown.kit_v2:
		_jam_shop(c)
	c.queue_free()
	await get_tree().process_frame
	print("EP2_FOUNDER_CAST: %s" % ["ALL PASS" if failures == 0 else "%d FAILURE(S)" % failures])
	get_tree().quit(failures)


## The storefront woman's jam (founder 2026-11-25): labelled jars on the General Store's counter top, her recorded walk-in line when Lil
## Blunt steps inside (heard from her: a 3D player on her), the second at her counter, nothing while he is out in the street.
func _jam_shop(c: GoldTownChamber) -> void:
	print("-- the General Store's jam and the storekeeper's voice (2026-11-25)")
	var js: Dictionary = c.get_jam_shop()
	var disp: Node3D = js["display"]
	check("jars of jam stand on the General Store's counter", disp != null and int(disp.jars) >= 8)
	if disp == null:
		return
	var tops: Array = []
	for j in disp.find_children("Jar_*", "Node3D", false, false):
		tops.append((j as Node3D).global_position.y)
	var counter: Vector3 = Ep2GoldTown.shop_spots("Bldg_A")["counter"]
	var off: float = Vector2(disp.global_position.x - counter.x, disp.global_position.z - counter.z).length()
	check("...resting on the counter top (jar centres 1.06-1.35 m), at the counter (%.2f m from its customer spot)" % off,
		tops.size() >= 8 and tops.min() > 1.06 and tops.max() < 1.35 and off < 2.2, str(tops))
	var labels: int = disp.find_children("Label", "MeshInstance3D", true, false).size()
	check("each jar is labelled and the card reads HOMEMADE JAM (one good only)", labels == int(disp.jars)
		and disp.find_child("Sign_HOMEMADE_JAM", true, false) != null)
	for id in GoldTownChamber.JAM_LINES:
		check("her line %s is recorded in the main pack" % id, Ep2TownVoiceBank.stream(id) != null
			and str(Ep2TownVoiceBank.LINES[id]["path"]).begins_with("res://src/episode2/audio/town_main/"))
	c._player_pos = Ep2GoldTown.shop_spots("Bldg_A")["out"]
	for i in 30:
		c.step(1.0 / 60.0)
	check("out in the street she says nothing", (js["said"] as Array).is_empty())
	c._player_pos = Ep2GoldTown.local_to_world("Bldg_A", Vector3(0.0, 0.0, -1.2))
	c.step(1.0 / 60.0)
	check("walking in: \"Afternoon, sugar! Fresh jam today...\" from her own mouth", (js["said"] as Array) == [GoldTownChamber.JAM_LINES[0]]
		and (js["voice"] as AudioStreamPlayer3D).stream != null and (js["voice"] as AudioStreamPlayer3D).get_parent() == js["keeper"], str(js["said"]))
	c._player_pos = Vector3(counter.x, 0.0, counter.z)
	for i in 60 * 8:
		c.step(1.0 / 60.0)
	check("at her counter: the second line, once", (js["said"] as Array) == GoldTownChamber.JAM_LINES, str(js["said"]))
