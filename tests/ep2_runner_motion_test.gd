extends Node
## Gate for the Episode 2 MOTION + EMOTION layer (runner_motion.gd) and its asset
## contract with the Meshy rigs. Pure picks are unit-tested; the rig check proves
## every clip the tables name exists in the shipped GLB (a re-rig that drops a
## clip would otherwise just freeze that emotion silently). The last block runs a
## real leg with the view live so any runtime SCRIPT ERROR shows in the log.
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/ep2_runner_motion_test.tscn

const SCENE := preload("res://src/episode2/runner/runner_graybox.tscn")
var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	print("EP2_RUNNER_MOTION:")
	var M := RunnerMotion
	# Rider priorities.
	_check("zipline beats everything", M.pick_rider(true, true, true, true, 0, 0, 0, 0, 0) == "zip")
	_check("a hit reaction beats duck/jump", M.pick_rider(false, true, true, false, 0.1, 99, 99, 99, 99) == "hit")
	_check("swipe beats duck", M.pick_rider(false, true, false, false, 99, 99, 0.1, 99, 99) == "swipe")
	_check("duck while held", M.pick_rider(false, true, false, false, 99, 99, 99, 99, 99) == "duck")
	_check("airborne = jump", M.pick_rider(false, false, true, false, 99, 99, 99, 99, 99) == "jump")
	_check("fresh hop = hop", M.pick_rider(false, false, false, false, 99, 99, 99, 0.1, 99) == "hop")
	_check("a shot does not hijack the body (aim modifier owns it); reload then cheer",
		M.pick_rider(false, false, false, false, 99, 0.1, 99, 99, 99) == "idle"
		and M.pick_rider(false, false, false, true, 99, 99, 99, 99, 0.1) == "reload"
		and M.pick_rider(false, false, false, false, 99, 99, 99, 99, 0.1) == "cheer")
	_check("calm = idle", M.pick_rider(false, false, false, false, 99, 99, 99, 99, 99) == "idle")
	# Archer.
	_check("dead archer dies", M.pick_archer(false, 0.1, 10.0) == "die")
	_check("archer looses just before its arrow flies", M.pick_archer(true, 0.2, 30.0) == "loose")
	_check("archer aims in range", M.pick_archer(true, 3.0, 50.0) == "aim")
	_check("archer idles far away", M.pick_archer(true, 9.0, 200.0) == "idle")

	# Rig contract: every named clip exists in the shipped GLB.
	# The rigged rider (seated clips) was retired 2026-09-29 for the founder's posed hero;
	# its clip tables stay valid if the rig is ever restored, so only bears are contract-checked.
	for pair in [[M.BEAR_RIG, M.BEAR_CLIPS]]:
		var path: String = pair[0]
		var table: Dictionary = pair[1]
		_check("%s exists" % path.get_file(), ResourceLoader.exists(path))
		if not ResourceLoader.exists(path):
			continue
		var n: Node = (load(path) as PackedScene).instantiate()
		var an: RefCounted = M.Anim.new(n, table)
		_check("%s has an AnimationPlayer" % path.get_file(), an.ok())
		if an.ok():
			for mood in table:
				var clip: String = str(table[mood][0])
				_check("%s: mood '%s' -> clip %s present" % [path.get_file(), mood, clip], an.player.has_animation(clip))
			for lc in M.LOOPING:
				if an.player.has_animation(lc):
					_check("%s: %s loops" % [path.get_file(), lc], an.player.get_animation(lc).loop_mode == Animation.LOOP_LINEAR)
		n.free()

	# Hero body language (procedural, pure): recoil kicks back, chop leans forward, duck sinks.
	var calm: Dictionary = M.hero_pose(99, 99, 99, 99, 99, false, false, false, 20.0, 0.0)
	var shot: Dictionary = M.hero_pose(99, 0.0, 99, 99, 99, false, false, false, 20.0, 0.0)
	var chop: Dictionary = M.hero_pose(99, 99, 0.22, 99, 99, false, false, false, 20.0, 0.0)
	var duck: Dictionary = M.hero_pose(99, 99, 99, 99, 99, true, false, false, 20.0, 0.0)
	var hit: Dictionary = M.hero_pose(0.0, 99, 99, 99, 99, false, false, false, 20.0, 0.0)
	_check("hero: a shot kicks the body BACK (pitch %.2f < %.2f)" % [shot["pitch"], calm["pitch"]], float(shot["pitch"]) < float(calm["pitch"]) - 0.1)
	_check("hero: the pickaxe chop leans FORWARD (%.2f)" % chop["pitch"], float(chop["pitch"]) > float(calm["pitch"]) + 0.5)
	_check("hero: a duck sinks him ~a metre into the cart (%.2f)" % duck["sink"], float(duck["sink"]) > 0.8 and float(calm["sink"]) == 0.0)
	_check("hero: a hit throws him back and drops him", float(hit["pitch"]) < -0.3 and float(hit["sink"]) > 0.1)
	_check("hero: impulses decay (shot 0.6 s ago ~ calm)", absf(float(M.hero_pose(99, 0.6, 99, 99, 99, false, false, false, 20.0, 0.0)["pitch"]) - float(calm["pitch"])) < 0.01)

	# Gun-arm aim: on the real rig, shoulder→hand must end up pointing at the target
	# (left and right), i.e. the modifier really overrides the playing clip.
	if ResourceLoader.exists(M.RIDER_RIG):
		var rig: Node3D = (load(M.RIDER_RIG) as PackedScene).instantiate()
		add_child(rig)
		var ran: RefCounted = M.Anim.new(rig, M.RIDER_CLIPS)
		ran.want("idle", 0.0)
		var sk: Skeleton3D = rig.find_children("*", "Skeleton3D", true, false)[0]
		var am := RunnerAimModifier.new()
		sk.add_child(am)
		am.influence = 1.0
		for tgt in [Vector3(-6.0, 1.2, 6.0), Vector3(6.0, 2.5, 6.0)]:
			am.target = rig.global_position + tgt
			# Godot 4.3 exposes the MODIFIED pose only during skeleton_updated.
			var got: Array = []
			var cb := func() -> void:
				got.append([(sk.global_transform * sk.get_bone_global_pose(sk.find_bone("RightArm"))).origin,
					(sk.global_transform * sk.get_bone_global_pose(sk.find_bone("RightHand"))).origin])
			sk.skeleton_updated.connect(cb)
			for _f in 4:
				await get_tree().process_frame
			sk.skeleton_updated.disconnect(cb)
			var dot: float = -1.0
			if not got.is_empty():
				var sh: Vector3 = got[-1][0]
				var hd: Vector3 = got[-1][1]
				dot = (hd - sh).normalized().dot((am.target - sh).normalized())
			_check("gun arm points at the reticle target %s (dot %.2f)" % [str(tgt), dot], dot > 0.9)
		rig.queue_free()

	# danger_eta on a real sim.
	var r: Node3D = SCENE.instantiate()
	add_child(r)
	r.set_physics_process(false)
	r.setup(300.0, [{"z": 40.0, "lane": 1, "type": "boulder"}])
	_check("danger ETA to own boulder = 2 s at 20 m/s (%.2f)" % M.danger_eta(r, 1, 0.0, 20.0),
		absf(M.danger_eta(r, 1, 0.0, 20.0) - 2.0) < 0.01)
	_check("no danger on a clear rail", M.danger_eta(r, 0, 0.0, 20.0) == INF)
	r.queue_free()

	# Live leg with the view: 4 s of real frames, rider rig driven.
	var live: Node3D = SCENE.instantiate()
	add_child(live)
	var leg: Dictionary = Episode2Tracks.LEG_DESCENT
	live.setup(float(leg["chamber_z"]), leg["obstacles"], leg["zip_segments"], leg["archers"], true,
		{"rail_events": leg["rail_events"], "carts_start": leg["carts_start"], "speed": leg["speed"]})
	for _i in 240:
		await get_tree().process_frame
	var view: Node = live.get_node("View")
	_check("rider is driven (rigged clips or the posed hero)", view._hero_mode or (view._rider_anim != null and view._rider_anim.ok()))
	# REGRESSION (founder 2026-09-29: "He doesn't even have his golden revolver nor his
	# pick axe"): the rider must BE the posed hero — a visible, textured model whose
	# baked revolver + pickaxe stick out of the cart — and the muzzle pivot must ride it.
	_check("the rider is the founder's posed hero (revolver + pickaxe baked in)", view._hero_mode and view._hero_body != null)
	_check("revolver is in his RIGHT hand: the posed model is mirrored (founder 2026-09-29)", view._hero_body != null and view._hero_body.scale.x < 0.0)
	if view._hero_mode:
		# RIGGED hero, NO clips (every clip hunched or floated him — founder: "a creature from a failed lab"):
		# bind pose + a resting pickaxe arm + an aimed gun arm.
		_check("the hero keeps the bind pose: no rider clip player driving him", view._rider_anim == null)
		_check("gun-arm aim modifier sits on the hero skeleton", view._aim_mod != null and view._aim_mod.get_parent() is Skeleton3D)
		_check("pickaxe arm is rested by RunnerArmRest (the arm does not stay up)", view._arm_rest != null and view._arm_rest.get_parent() is Skeleton3D)
		var mz: Vector3 = view._muzzle_pos()
		_check("muzzle flash point is out in front of the body (%s)" % str(mz), mz.distance_to(view._rider.global_position) > 1.0)
		_check("the separate revolver/pickaxe meshes are NOT drawn on top of the baked ones",
			not view._gun_spin_node.visible and not view._axe_pivot.visible)
	else:
		_check("gun-arm aim modifier sits on the rider skeleton", view._aim_mod != null and view._aim_mod.get_parent() is Skeleton3D)
	_check("the leg advanced with the view live (d=%.0f)" % live.get_distance(), live.get_distance() > 20.0)
	# REGRESSION (founder 2026-09-29: "the bitcoin gold coins are masked with a stupid filter"):
	# a coin must be solid geometry with the Bitcoin face — lit metal, NO alpha/transparency,
	# NO translucent halo shell.
	var coin_n: Node3D = null
	for gn in view._gold_nodes:
		if gn != null:
			coin_n = gn
			break
	_check("the leg has coins", coin_n != null)
	if coin_n:
		var faces := 0
		var see_through := false
		for mi in coin_n.find_children("*", "MeshInstance3D", true, false):
			var mat := (mi as MeshInstance3D).material_override as StandardMaterial3D
			if mat == null:
				continue
			if mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or mat.albedo_color.a < 0.99:
				see_through = true
			if mat.albedo_texture != null:
				faces += 1
		_check("coin has two textured Bitcoin faces (%d)" % faces, faces == 2)
		_check("coin has no transparent/halo parts", not see_through)
		# Regression: metallic > 0.5 with no reflections renders BLACK in the web build (coins were invisible).
		var mats_ok := true
		for mi2 in coin_n.find_children("*", "MeshInstance3D", true, false):
			var m2 := (mi2 as MeshInstance3D).material_override as StandardMaterial3D
			if m2 != null and (m2.metallic > 0.5 or not m2.emission_enabled):
				mats_ok = false
		_check("coin stays visible without reflections (low metallic + emission)", mats_ok)
		_check("coin is lit metal (not unshaded)", (coin_n.find_children("*", "MeshInstance3D", true, false)[1] as MeshInstance3D).material_override.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED)

	# Regression: the bear rig's Armature carries a 0.01 scale, and measuring it
	# through the node chain drew it 130x too big (off-screen) on the web build.
	var rs: float = view._rider_model.scale.y
	_check("rider scale sane (%.2f)" % rs, rs > 0.5 and rs < 5.0)
	for id in view._archer_nodes:
		var bear: Node3D = view._archer_nodes[id]
		for c in bear.get_children():
			if bear.has_meta("statue"):
				var sbb: AABB = view._measure(bear)
				_check("archer statue %s is ledge-sized (h=%.2f)" % [id, sbb.size.y], sbb.size.y > 2.0 and sbb.size.y < 3.2)
				break
			if c is Node3D and String(c.name).contains("rigged"):
				var bs: float = (c as Node3D).scale.y
				_check("archer %s rig scale sane (%.2f)" % [id, bs], bs > 0.5 and bs < 5.0)
	live.queue_free()
	print("EP2_RUNNER_MOTION: " + ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(1 if _fail else 0)
