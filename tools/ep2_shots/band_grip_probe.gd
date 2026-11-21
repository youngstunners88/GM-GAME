extends Node3D
## Headless: each hall musician's wrist-to-grip distance per arm (after the skeleton's modifiers ran), and the grand event's pieces.
##   godot --headless --path . res://tools/ep2_shots/band_grip_probe.tscn
func _ready() -> void:
	var house := Ep2AuctionHouse.new()
	add_child(house)
	house._kit = (load(Ep2AuctionHouse.KIT) as PackedScene).instantiate() as Node3D
	var plays: Array = []
	var x: float = -3.0
	for row in Ep2AuctionHouse.BAND:
		var f: Ep2TownFolk = house._person(str(row[0]), Vector3(x, 0, 0), 1.78)
		f.hold_clip("Idle")
		var kind: String = str(Ep2AuctionHouse.BAND_KIND.get(str(row[3]), "lead"))
		var play: Node = load(Ep2AuctionHouse.BAND_PLAY).new()
		f.add_child(play)
		play.setup(f, kind, house._kit_copy(str(row[3])) if str(row[3]) != "" else null, house._kit_copy("Auc_FiddleBow") if kind == "fiddle" else null)
		house._folk.append(f)
		if kind != "lead": plays.append(play)
		x += 1.5
	var worst: Dictionary = {}
	for play in plays:
		var sk: Skeleton3D = play._sk
		sk.skeleton_updated.connect(func() -> void:
			for arm in ["Left", "Right"]:
				var hand: Vector3 = sk.global_transform * sk.get_bone_global_pose(int(play._bones[arm + "Hand"])).origin
				var key: String = "%s %s" % [play.kind, arm]
				var ik: Ep2ArmIK = play._ik[arm]
				worst[key] = [maxf(float(worst.get(key, [0.0])[0]), hand.distance_to(ik.target_world)) if Engine.get_process_frames() > 10 else 0.0, ik.shortfall, hand.distance_to(ik.target_world)])
	for i in 40:
		for f in house._folk: (f as Ep2TownFolk).step(1.0 / 60.0)
		await get_tree().process_frame
	for k in worst: print("GRIP %-16s worst %.3f m  last %.3f  shortfall %.3f" % [k, worst[k][0], worst[k][2], worst[k][1]])
	var g: Node3D = load(Ep2AuctionHouse.SPECTACLE).new()
	add_child(g)
	g.build(Ep2AuctionHouse.SCONCES, 11.0)
	print("GRAND logos=", g.find_children("GMLogo*", "MeshInstance3D", true, false).size(), " all_mi=", g.find_children("*", "MeshInstance3D", true, false).size(),
		" particles=", g.find_children("*", "CPUParticles3D", true, false).size(), " need=", 6 + Ep2AuctionHouse.SCONCES.size())
	get_tree().quit()
