extends Node3D
## Whole-interval tests on the shipped rigs, sampling AFTER all modifiers.
## Independent paw surface landmarks were measured on the source mesh, before solving.
var failures: int = 0
var worst: float = 0.0
var samples: int = 0


func check(label: String, ok: bool) -> void:
	print("  [PASS] " if ok else "  [FAIL] ", label)
	if not ok:
		failures += 1


func _ready() -> void:
	var bear := Ep2BearKit.make_bear(self, Vector3.ZERO)
	Ep2BearKit.add_bow(bear)
	var contacts: Ep2HandContacts = bear.get_meta("contacts")
	var sk := bear.skeleton
	# A neutral source must transfer exactly to the target's different rest pose.
	var source: Node = (load(Ep2BearKit.WALK_CLIP) as PackedScene).instantiate()
	var source_sk: Skeleton3D = source.find_children("*", "Skeleton3D", true, false)[0]
	var neutral := Animation.new()
	var track: int = neutral.add_track(Animation.TYPE_ROTATION_3D)
	neutral.track_set_path(track, NodePath("Armature/Skeleton3D:LeftArm"))
	neutral.track_insert_key(track, 0.0, source_sk.get_bone_rest(source_sk.find_bone("LeftArm")).basis.get_rotation_quaternion())
	bear._retarget_clip(neutral, source)
	var target_q: Quaternion = sk.get_bone_rest(sk.find_bone("LeftArm")).basis.get_rotation_quaternion()
	check("neutral source maps to bear rest", (neutral.track_get_key_value(track, 0) as Quaternion).angle_to(target_q) < 0.0001)
	source.free()

	# Sample actual skinned vertices, not just a solver's reported wrist position.
	var mesh: MeshInstance3D = bear.model.find_children("*", "MeshInstance3D", true, false)[0]
	var arrays: Array = mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var binds: Array[int] = []
	for bind in mesh.skin.get_bind_count():
		binds.append(sk.find_bone(mesh.skin.get_bind_name(bind)))
	var landmarks: Dictionary = {}
	# Godot may reorder vertices while importing. Resolve the measured source positions.
	for side in ["Left", "Right"]:
		var expected := Vector3(0.907851 if side == "Left" else -0.907851, 1.337888, 0.120132)
		var nearest: int = 0
		var distance: float = INF
		for vertex in vertices.size():
			var d: float = vertices[vertex].distance_squared_to(expected)
			if d < distance:
				nearest = vertex
				distance = d
		landmarks[side] = nearest
		check("%s measured paw surface is present" % side, distance < 0.000001)
		for slot in 4:
			if weights[nearest * 4 + slot] > 0.9:
				var bind: int = bones[nearest * 4 + slot]
				check("%s paw is bound to its own hand" % side, mesh.skin.get_bind_name(bind) == side + "Hand")
	sk.skeleton_updated.connect(func() -> void:
		for side in contacts.targets:
			var vertex: int = landmarks[side]
			var surface_world := Vector3.ZERO
			for slot in 4:
				var bind: int = bones[vertex * 4 + slot]
				var weight: float = weights[vertex * 4 + slot]
				if weight > 0.0:
					surface_world += (sk.global_transform * sk.get_bone_global_pose(binds[bind]) * mesh.skin.get_bind_pose(bind) * vertices[vertex]) * weight
			worst = maxf(worst, surface_world.distance_to(contacts.targets[side].global_position))
			samples += 1)
	for heading in [0.0, PI * 0.5]:
		bear.facing = heading
		bear.rotation.y = heading
		for state in ["sit_read", "aim", "shot"]:
			Ep2BearKit.pose(bear, state)
			worst = 0.0
			samples = 0
			var frames: int = 480 if state == "sit_read" else 120 if state == "aim" else 36
			for frame in frames:
				Ep2BearKit.tick_pose(bear, 1.0 / 60.0)
				bear.step(1.0 / 60.0)
				await get_tree().process_frame
				if frame == 24 and state != "shot":
					worst = 0.0                  # approach/blend precedes the declared hold interval
					samples = 0
			check("%s yaw %.2f skinned contact %.4f m (%d samples)" % [state, heading, worst, samples], samples > 0 and worst < 0.015)
		check("release frees drawing paw", not contacts.targets.has("Right"))

	Ep2BearKit.pose(bear, "idle")
	var clock: float = bear.motion_time
	var phase: float = bear.anim.current_animation_position
	for frame in 10:
		await get_tree().process_frame
	check("render frames without step do not advance animation or acting", bear.motion_time == clock and bear.anim.current_animation_position == phase)
	bear.walk_to(Vector3(0, 0, 20), 1.5)
	for frame in 100:
		bear.step(1.0 / 60.0)
		await get_tree().process_frame
	check("walking advances root and gait on the same clock", bear.position.length() > 1.0 and bear.anim.current_animation_position > 0.01)
	bear.queue_free()

	var bull := Ep2Actor.new()
	add_child(bull)
	bull.setup(SmeltingFacilityChamber.BULL_RIG_MODEL, 2.4, 2.9, {"walk": SmeltingFacilityChamber.BULL_WALK_CLIP}, [SmeltingFacilityChamber.BULL_IDLE])
	bull.idle_clip = SmeltingFacilityChamber.BULL_IDLE
	bull.play(bull.idle_clip, 1.0, 0.0)
	var hero := Ep2BullHero.dress(bull)
	var gun_error: Array[float] = [0.0]
	bull.skeleton.skeleton_updated.connect(func() -> void:
		var hand: Transform3D = bull.skeleton.global_transform * bull.skeleton.get_bone_global_pose(bull.skeleton.find_bone("LeftHand"))
		var palm: Vector3 = hand * (Ep2BullHero.LEFT_PALM_M * bull.height_m / 2.4 / bull.skeleton.global_transform.basis.get_scale().x)
		gun_error[0] = maxf(gun_error[0], palm.distance_to(hero.rifle.to_global(Vector3(0, 0, -Ep2BullHero.GRIP_ALONG)))))
	for frame in 180:
		if frame % 60 == 0:
			hero.fire_at(Vector3(3.0, 1.5, 10.0))
		bull.step(1.0 / 60.0)
		await get_tree().process_frame
	check("Bull aim, recoil and recovery preserve primary rifle grip %.4f m" % gun_error[0], gun_error[0] < 0.015)
	check("one rifle: the prop is drawn exactly when no rifle is sculpted into the model", hero.rifle.visible == (not Ep2BullHero.RIFLE_IN_MESH))
	# Motion fix T1 (2026-11-21): the rifle is sculpted into his left fist. Its barrel must be skinned to LeftHand ONLY
	# (it was on Head/neck/Spine02 and the stock on LeftUpLeg, so it stretched like taffy whenever he moved).
	var barrel_total: int = 0
	var barrel_bad: int = 0
	for mi in bull.model.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh == null or m.skin == null:
			continue
		var lh: int = -1
		for bi in m.skin.get_bind_count():
			if m.skin.get_bind_name(bi) == "LeftHand" or (m.skin.get_bind_bone(bi) >= 0 and bull.skeleton.get_bone_name(m.skin.get_bind_bone(bi)) == "LeftHand"):
				lh = bi
		for si in m.mesh.get_surface_count():
			var arr: Array = m.mesh.surface_get_arrays(si)
			var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bidx: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var wts: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			if bidx.is_empty():
				continue
			var per: int = bidx.size() / pos.size()
			for vi in pos.size():
				var v: Vector3 = pos[vi]
				# upper barrel, glTF axes of the 2.4 m model: x 0.50-0.58, height 1.75-2.15, toward the front 0.45-0.62
				if v.x > 0.50 and v.x < 0.58 and v.y > 1.75 and v.y < 2.15 and v.z > 0.45 and v.z < 0.62:
					barrel_total += 1
					for k in per:
						if wts[vi * per + k] > 0.001 and bidx[vi * per + k] != lh:
							barrel_bad += 1
							break
	if Ep2BullHero.RIFLE_IN_MESH:
		check("Bull's sculpted barrel is skinned to LeftHand only (%d of %d vertices off)" % [barrel_bad, barrel_total], barrel_total > 100 and barrel_bad == 0)
	else:
		# the new Inferno (2026-11-23): no sculpted rifle, so nothing of the body may sit where the old barrel was
		check("new Inferno: no sculpted barrel in the model (%d vertices there), the rifle is the prop in his hand" % barrel_total, barrel_total < 20)
	# Hip fire: the visible (sculpted) barrel comes level on the target and the rifle never changes length.
	var target := bull.global_position + Basis(Vector3.UP, bull.facing) * Vector3(0.6, 1.2, 9.0)
	var hip_err: Array[float] = [999.0]
	var len_span: Array[float] = [INF, -INF]
	hero.hip.modification_processed.connect(func() -> void:
		if hero.hip.weight < 0.99:
			return
		var g: Vector3 = Ep2BullHero.grip_world(bull)
		var mz: Vector3 = Ep2BullHero.muzzle_world(bull)
		hip_err[0] = minf(hip_err[0], rad_to_deg((mz - g).angle_to(target - g)))
		len_span[0] = minf(len_span[0], g.distance_to(mz))
		len_span[1] = maxf(len_span[1], g.distance_to(mz)))
	for frame in 90:
		hero.aim_at(target)
		bull.step(1.0 / 60.0)
		await get_tree().process_frame
	check("Bull hip fire points the sculpted barrel at the target (%.1f deg)" % hip_err[0], hip_err[0] < 8.0)
	check("Bull's rifle stays rigid under the hip fire (length span %.4f m)" % (len_span[1] - len_span[0]), len_span[1] - len_span[0] < 0.002)
	print("EP2_CHARACTER_MOTION: ", "ALL PASS" if failures == 0 else "%d FAILURES" % failures)
	get_tree().quit(0 if failures == 0 else 1)
