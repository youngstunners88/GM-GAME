extends Node
## Founder 2026-10-18: the train, the river (lake) and the horses belong in EPISODE 2. Guards the town's living backdrop built by
## Ep2GoldTown.build -> Ep2TownLife: horses at the hitch rails (solid, animated), the river, the railway and a train that crosses the
## valley in front of Fort Knox on a timer, and the desert scrub staying out of the river/rail corridor.
var failures: int = 0


func check(label: String, ok: bool, detail: String = "") -> void:
	print("  [PASS] " if ok else "  [FAIL] ", label, "" if ok or detail.is_empty() else "  (" + detail + ")")
	if not ok:
		failures += 1


func _ready() -> void:
	var world := Node3D.new()
	add_child(world)
	var info: Dictionary = Ep2GoldTown.build(world, false)
	var life: Ep2TownLife = world.find_child("TownLife", true, false) as Ep2TownLife
	check("the town builds a TownLife node (Episode 2, not Level 3)", life != null)
	if life == null:
		print("EP2_TOWN_LIFE: FAILED %d" % failures)
		get_tree().quit(1)
		return
	var horses: Array = life.find_children("Horse?", "AnimatedSprite3D", false, false)
	check("four horses stand in the street and by the armory lane", horses.size() == 4, "got %d" % horses.size())
	var animated: int = 0
	for h in horses:
		if h is AnimatedSprite3D and (h as AnimatedSprite3D).is_playing():
			animated += 1
	check("every horse is playing a real clip (stand / graze)", animated == 4, "%d animated" % animated)
	var roaming: Node3D = life.find_child("HorseRoaming", true, false) as Node3D
	check("a horse roams the street's edge", roaming != null)
	var solid: int = 0
	for p in info["props"]:
		var q: Vector2 = p[0]
		for h in horses:
			if Vector2((h as Node3D).position.x, (h as Node3D).position.z).is_equal_approx(q):
				solid += 1
	check("the tied horses are solid (Lil Blunt walks around them)", solid == 4, "%d solid" % solid)
	check("the river is a real water mesh with the flowing shader",
		life.find_child("River", true, false) is MeshInstance3D and ((life.find_child("River", true, false) as MeshInstance3D).material_override is ShaderMaterial))
	check("the railway has ballast, two rails and ties",
		life.find_child("Ballast", true, false) != null and life.find_child("Ties", true, false) is MultiMeshInstance3D)
	var river: MeshInstance3D = life.find_child("River", true, false) as MeshInstance3D
	var track: Node3D = life.find_child("Ballast", true, false) as Node3D
	check("the river lies between the church and the railway, both behind the walkable town",
		river.position.z > Ep2GoldTown.TOWN_Z + 95.0 - 1.0 and track.position.z > river.position.z and track.position.z < Ep2GoldTown.FORT_POS.z - 40.0,
		"river z %.0f track z %.0f" % [river.position.z, track.position.z])

	# the train: empty track first, then it comes through, crosses the valley and leaves; smoke while it runs
	var train: Node3D = life.find_child("Train", true, false) as Node3D
	check("the locomotive and its cars are built", train != null and train.find_child("Locomotive", true, false) != null and train.find_children("Car?", "Node3D", false, false).size() == Ep2TownLife.CARS)
	check("the track starts empty (the train is not parked in view)", not train.visible)
	var started: bool = false
	var moved: float = 0.0
	var last_x: float = 0.0
	var left: bool = false
	for i in 60 * 120:
		life._process(1.0 / 60.0)
		if train.visible and not started:
			started = true
			last_x = train.position.x
		elif train.visible:
			moved += last_x - train.position.x
			last_x = train.position.x
		if started and not train.visible:
			left = true
			break
	check("a train arrives, crosses the valley at speed and leaves again", started and left and moved > 300.0, "moved %.0f m" % moved)
	var came_back: bool = false
	for i in int((Ep2TownLife.TRAIN_GAP + 3.0) * 60.0):
		life._process(1.0 / 60.0)
		if train.visible:
			came_back = true
			break
	check("it keeps its schedule: the next train comes after the gap", came_back)
	var smoke: CPUParticles3D = train.find_child("Smoke", true, false) as CPUParticles3D
	check("it is a steam train: the funnel has a smoke plume that only runs while it is on the track", smoke != null and smoke.emitting == train.visible)
	check("the river and rail corridor (where the desert scatters no scrub or rock) sits behind the town and in front of the fort hill",
		Ep2GoldTown.RIVER_Z - Ep2GoldTown.RIVER_W > Ep2GoldTown.TOWN_Z + 90.0 and Ep2GoldTown.TRACK_Z + 8.0 < Ep2GoldTown.FORT_POS.z)
	world.queue_free()
	print("EP2_TOWN_LIFE: ALL PASS" if failures == 0 else "EP2_TOWN_LIFE: FAILED %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)
