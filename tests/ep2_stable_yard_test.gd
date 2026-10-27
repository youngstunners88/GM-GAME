extends Node
## Real supplied rigs/clip playback, five extra horses, solid yard, placeholder-only interaction and handoff.
var failures := 0
var checks := 0

func check(label: String, ok: bool) -> void:
	checks += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", label])
	if not ok: failures += 1

func _clip(ap: AnimationPlayer, key: String) -> String:
	for name in ap.get_animation_list():
		if str(name).to_lower().begins_with(key): return str(name)
	return ""

func _ready() -> void:
	await get_tree().process_frame
	var c: GoldTownChamber = load("res://src/episode2/chamber/gold_town.tscn").instantiate()
	add_child(c)
	c.setup(0, [], 0)
	c.set_physics_process(false)
	var yard: Ep2StableYard = c._stable_yard
	check("shared town builder restores the original Episode2 yard", yard != null and Ep2StableYard.STABLE_POS == Vector3(-16, 0, 1222))
	check("yard uses the original paddock, off the approach road", Ep2StableYard.PADDOCK == Rect2(-24, 1204, 20, 36) and Ep2StableYard.PADDOCK.end.x == -4.0)
	check("both supplied characters actually loaded", yard.actors.size() == 2)
	check("eight horses occupy the yard", yard.horses.size() == 8)
	var clear_yard := true
	for rocks in c._visuals.find_children("DesertRocks", "MultiMeshInstance3D", true, false):
		var mm: MultiMesh = (rocks as MultiMeshInstance3D).multimesh
		for i in mm.instance_count:
			var p: Vector3 = mm.get_instance_transform(i).origin
			clear_yard = clear_yard and not Ep2StableYard.PADDOCK.grow(6.0).has_point(Vector2(p.x, p.z)) and not Ep2StableYard.ACCESS_CLEAR.has_point(Vector2(p.x, p.z))
	check("desert rocks cannot obscure the restored yard or gate approach", clear_yard)
	var life: Ep2TownLife = c._visuals.find_child("TownLife", true, false)
	check("all four street horses plus their roamer remain", life.find_children("Horse?", "Node3D", false, false).size() == 4 and life.find_child("HorseRoaming", true, false) != null)
	for folk in yard.actors:
		var ap: AnimationPlayer = folk.anim_player()
		var rigs: Array = folk.model.find_children("*", "Skeleton3D", true, false)
		check(str(folk.name) + " retains the65joint rig", rigs.size() == 1 and (rigs[0] as Skeleton3D).get_bone_count() == 65)
		var meshes: Array = folk.model.find_children("*", "MeshInstance3D", true, false)
		var tris := 0
		for mi in meshes:
			var mesh: Mesh = (mi as MeshInstance3D).mesh
			if not (mesh is ArrayMesh):
				continue                                   # a chore prop on a hand (the assistant's brush), not the character's body
			for s in mesh.get_surface_count():
				var count: int = mesh.surface_get_array_index_len(s)
				tris += count / 3 if count > 0 else mesh.surface_get_array_len(s) / 3
		check(str(folk.name) + " is within8–10ktris (%d)" % tris, tris >= 8000 and tris <= 10000)
		for key in Ep2StableYard.CLIPS:
			var clip: String = _clip(ap, key)
			check(str(folk.name) + " has " + key, clip != "")
			if clip == "": continue
			var animation: Animation = ap.get_animation(clip)
			var cyclic: bool = key in ["idle", "walk", "run"]
			check(str(folk.name) + " " + key + " has correct loop policy", animation.loop_mode == (Animation.LOOP_LINEAR if cyclic else Animation.LOOP_NONE))
			folk.play_clip(key)
			ap.advance(0.2)
			var finite := true
			var head_rigid := true
			for t in [0.0, 0.25, 0.5, 0.75, 0.99]:
				ap.seek(animation.length * t, true)
				await get_tree().process_frame
				for sk in rigs:
					for bone in (sk as Skeleton3D).get_bone_count():
						var pose: Transform3D = (sk as Skeleton3D).get_bone_global_pose(bone)
						finite = finite and pose.origin.is_finite() and pose.basis.is_finite() and absf(pose.basis.determinant()) > 0.5
						if (sk as Skeleton3D).get_bone_name(bone).ends_with("Head"):
							head_rigid = head_rigid and pose.basis.get_scale().distance_to(Vector3.ONE) < 0.001
			check(str(folk.name) + " " + key + " plays finite whole-clip poses", finite and ap.is_playing())
			check(str(folk.name) + " " + key + " keeps head/hat scale rigid", head_rigid)
			ap.seek(animation.length * 0.9, true)
			ap.advance(animation.length * 0.25)
			check(str(folk.name) + " " + key + " really loops/finishes", ap.is_playing() if cyclic else not ap.is_playing())
		folk.hold_clip("idle")
		folk.anim_player().advance(0.2)
	var phases: Array = []
	for horse in yard.horses:
		var ap: AnimationPlayer = horse.find_children("*", "AnimationPlayer", true, false)[0]
		check(str(horse.name) + " plays a real horse clip", ap.is_playing() and ap.current_animation.begins_with("horse_"))
		check(str(horse.name) + " is solid", horse.get_node_or_null("YardBody/CollisionShape3D") != null or horse.find_child("YardBody", false, false) is StaticBody3D)
		phases.append(ap.current_animation_position)
	check("herd animation phase offsets differ", phases[0] != phases[1] and phases[2] != phases[3])
	for folk in yard.actors:
		var p: Vector2 = Vector2(folk.position.x, folk.position.z)
		var blocked: Vector2 = Ep2GoldTown.collide(p, 0.3, [], c._town_col["props"])
		check(str(folk.name) + " blocks the actual player collision path", blocked.distance_to(p) >= 0.66)
	var before: Dictionary = yard.snapshot()
	var old_pos: Vector3 = yard.actors[1].position
	for i in 2400: yard.step(1.0 / 60.0, Vector3(4, 0, 1222))
	check("assistant actually works a short yard path", old_pos.distance_to(yard.actors[1].position) > 0.2)
	check("walking horse stays in its slow paddock lane", yard.horses[4].position.z >= 1233 and yard.horses[4].position.z <= 1237 and yard.horses[4].position.x == -9)
	for folk in yard.actors:
		check(str(folk.name) + " never enters the street", Ep2StableYard.PADDOCK.has_point(Vector2(folk.position.x, folk.position.z)))
	var paused: Dictionary = yard.snapshot()
	yard.step(0, Vector3.ZERO)
	check("zero delta changes no routine or clip state", yard.snapshot() == paused)
	var stopped: Vector3 = yard.horses[4].position
	yard.step(2, Vector3(0, 0, 1425), true)
	check("duel quiet holds walking animals and both people", yard.horses[4].position == stopped and not yard.actors[0].is_walking() and not yard.actors[1].is_walking())
	var other := Node3D.new()
	add_child(other)
	Ep2GoldTown.build(other, false)
	var twin: Ep2StableYard = other.find_child("StableYard", true, false)
	var state: Dictionary = yard.snapshot()
	twin.restore(state)
	check("woods/town builder produces the same two actors and herd", twin.actors.size() == 2 and twin.horses.size() == 8)
	check("handoff preserves actor places", twin.actors[0].position == yard.actors[0].position and twin.actors[1].position == yard.actors[1].position)
	check("handoff preserves horse place and clip phase", twin.horses[4].position == yard.horses[4].position and absf((twin._horse_anims[2] as AnimationPlayer).current_animation_position - (yard._horse_anims[2] as AnimationPlayer).current_animation_position) < 0.00005)
	yard.restore(before)
	c._beat = GoldTownChamber.Beat.STREET
	c._hold = 0
	c._show_active = false
	c._player_pos = yard.actors[0].position + Vector3(2.5, 0, 0)
	yard.step(0.02, c._player_pos)
	var requests: Array = []
	c.stable_voice_requested.connect(func(id, voice): requests.append([id, voice]))
	check("E within3m starts the real ranch conversation", c.start_rig() and requests == [["dude_ranch_01", "Pe1gOSDKAuczOZqgCiEm"]])
	check("hook creates no purchase, map or story beat", c.get_beat() == GoldTownChamber.Beat.STREET and not c.has_map())
	c._player_pos += Vector3(4, 0, 0)
	check("E outside3m does nothing", not c.start_rig())
	c._player_pos = yard.actors[0].position + Vector3(2, 0, 0)
	c._beat = GoldTownChamber.Beat.DRAW
	check("Dude cannot interrupt the draw", not c.start_rig())
	c._beat = GoldTownChamber.Beat.STREET
	var gate: Vector3 = c._collide(Vector3(-5, 0, 1222))
	check("restored yard is reachable in the town room", gate.z == 1222 and gate.x == -5)
	var wf: String = FileAccess.get_file_as_string("res://.github/workflows/export-game.yml")
	check("main pack excludes only the two new canonical asset families", wf.contains("src/episode2/assets/town/dude_stable_owner*") and wf.contains("src/episode2/assets/town/stable_assistant*"))
	check("hard190MiB pack gate remains199229440B", FileAccess.get_file_as_string("res://scripts/pack-gate-fresh.sh").contains("LIMIT=199229440") and wf.contains("199229440"))
	check("web export remains nonthreaded", wf.contains("variant/thread_support=false"))
	check("full stable battery reached its final assertions", checks >= 70)
	print("EP2_STABLE_YARD: %s (%d checks)" % ["ALL PASS" if failures == 0 else "%d FAILURE(S)" % failures, checks])
	get_tree().quit(1 if failures else 0)
