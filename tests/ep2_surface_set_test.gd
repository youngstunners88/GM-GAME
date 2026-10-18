extends Node
## Gate for the EPISODE 2 SURFACE SET (founder 2026-10-18, PROMPT_EPISODE2_HORSES_STABLE_TRAIN_LAKE_WRONG_STAGE.md): after Lil Blunt and
## Inferno leave the forest the desert approach shows a lake, a rail line with the GoldMine train, and a stable with horses. It is built
## by Ep2GoldTown.build(), which BOTH the bear woods (the quad ride) and the town chamber call, so it is there for the whole approach.
## Run: godot --headless res://tests/ep2_surface_set_test.tscn

var _fail: int = 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])


func _ready() -> void:
	var root := Node3D.new()
	add_child(root)
	Ep2GoldTown.build(root, false)
	var set: Node = root.find_child("SurfaceSet", true, false)
	_check("Ep2GoldTown.build makes the SurfaceSet (so the quad ride AND the town room both have it)", set != null)
	if set == null:
		print("EP2_SURFACE_SET: FAIL")
		get_tree().quit(1)
		return
	for part in ["Lake", "Rails", "Train", "Stable"]:
		_check("the set has its %s" % part, set.find_child(part, true, false) != null)
	_check("the lake has water and a shore", set.find_child("Water", true, false) != null and set.find_child("Shore", true, false) != null)
	_check("the rail line has a bed, rails and ties", set.find_child("Bed", true, false) != null and set.find_child("Ties", true, false) != null)
	_check("the stable has its barn + corral", set.find_child("Barn", true, false) != null)

	# the horses: the Runpod/AssetFurnace frames that already ship (walk 8, graze 6, stand 1)
	for h in ["Grazer", "Sentry", "Roamer"]:
		var hs := set.find_child(h, true, false) as AnimatedSprite3D
		_check("horse %s is an AnimatedSprite3D" % h, hs != null)
		if hs == null:
			continue
		var f: SpriteFrames = hs.sprite_frames
		_check("horse %s has the shipped frames (8 walk / 6 graze / 1 stand)" % h, f.get_frame_count("walk") == 8 and f.get_frame_count("graze") == 6 and f.get_frame_count("stand") == 1)
		_check("horse %s stands on the ground, not in the air or buried" % h, hs.position.y > 0.3 and hs.position.y < 1.8)
	_check("the horses use only sprites that are already in the pack (no new heavy asset)", ResourceLoader.exists("res://src/assets/sprites/horse_walk_00.png") and ResourceLoader.exists(Ep2SurfaceSet.STABLE_TEX) and ResourceLoader.exists(Ep2SurfaceSet.TRAIN_TEX))
	_check("no rigged 3D horse in the set (size gate)", set.find_children("*", "Skeleton3D", true, false).is_empty())

	# where it is: on the desert approach, between the forest exit and the town, not in a different coordinate system
	var lo: float = WoodsQuadChamber.FOREST_END_Z
	var hi: float = Ep2GoldTown.TOWN_Z
	var zs: Array = [Ep2SurfaceSet.RAIL_Z0, Ep2SurfaceSet.RAIL_Z1, Ep2SurfaceSet.LAKE_RECT.position.y, Ep2SurfaceSet.LAKE_RECT.end.y, Ep2SurfaceSet.STABLE_POS.z]
	var inside: bool = true
	for z in zs:
		inside = inside and float(z) > lo and float(z) < hi
	_check("the lake, the rails and the stable lie between the forest exit (z %d) and the town (z %d)" % [int(lo), int(hi)], inside)
	_check("the rails run between the road and the lake", Ep2SurfaceSet.RAIL_X < Ep2SurfaceSet.LAKE_RECT.position.x)
	_check("the stable is on the other side of the road from the rails", Ep2SurfaceSet.STABLE_POS.x < 0.0 and Ep2SurfaceSet.RAIL_X > 0.0)
	_check("the quad's road (x about -10..10 on this stretch) is clear of the set", Ep2SurfaceSet.PADDOCK.end.x < -2.0 and Ep2SurfaceSet.RAIL_X - 6.0 > 20.0)

	# the desert scatter leaves the set's ground clear
	_check("blocks() holds the lake, the rails and the paddock", Ep2SurfaceSet.blocks(Vector2(100.0, 1200.0)) and Ep2SurfaceSet.blocks(Vector2(Ep2SurfaceSet.RAIL_X, 1200.0)) and Ep2SurfaceSet.blocks(Vector2(-12.0, 1220.0)))
	_check("blocks() leaves the road alone", not Ep2SurfaceSet.blocks(Vector2(7.0, 1200.0)))
	var scatter := Node3D.new()
	add_child(scatter)
	var road: Array = WoodsQuadChamber.RIDE_TRAIL
	var box := BoxMesh.new()
	Ep2GoldTown.build_desert(scatter, road, WoodsQuadChamber.FOREST_END_Z, WoodsQuadChamber.WORLD_END_Z, box, box, StandardMaterial3D.new(), StandardMaterial3D.new())
	var inside_zone: int = 0
	var total: int = 0
	for mmi in scatter.find_children("*", "MultiMeshInstance3D", true, false):
		if str(mmi.name) == "Mesas":
			continue
		var mm: MultiMesh = (mmi as MultiMeshInstance3D).multimesh
		for i in mm.instance_count:
			var o: Vector3 = mm.get_instance_transform(i).origin
			total += 1
			if Ep2SurfaceSet.blocks(Vector2(o.x, o.z)):
				inside_zone += 1
	_check("the desert has scrub and boulders (%d placed)" % total, total > 100)
	_check("no scrub or boulder stands inside the set's area (%d do)" % inside_zone, inside_zone == 0)

	# motion: the train stays on its line and the roamer stays in its paddock
	var sv := set as Ep2SurfaceSet
	for i in 4000:
		sv._process(0.1)
		if i % 400 == 0:
			var tz: float = sv.get_node("TrainHolder/Train").position.z
			_check("the train stays on the line (t=%.0fs, z=%.0f)" % [float(i) * 0.1, tz], tz >= Ep2SurfaceSet.RAIL_Z0 and tz <= Ep2SurfaceSet.RAIL_Z1)
			var rz: float = (set.find_child("Roamer", true, false) as Node3D).position.z
			_check("the roamer stays in the paddock (z=%.1f)" % rz, rz >= Ep2SurfaceSet.PADDOCK.position.y - 1.0 and rz <= Ep2SurfaceSet.PADDOCK.end.y + 1.0)

	# Episode 1 Level 3 is not the home of this set: it still builds only what it built before this pass
	var l3: String = FileAccess.get_file_as_string("res://src/level/level_03_gold_rush.gd")
	_check("Level 3 was not extended with the set", not l3.contains("SurfaceSet"))

	print("EP2_SURFACE_SET: %s" % ("ALL PASS" if _fail == 0 else "FAIL (%d)" % _fail))
	get_tree().quit(1 if _fail > 0 else 0)
