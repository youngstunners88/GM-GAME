extends Node
## Verify imported skeletal motion and actual contact landmarks, not node names alone.
var failures: int = 0
var checks: int = 0
func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("[PASS] " + label if ok else "[FAIL] " + label)
func _ready() -> void:
	var cart := Ep2RoadCart.new()
	add_child(cart)
	cart.build("", 1.0)
	check("streamed complete articulated assembly loads", cart.ready_art)
	if not cart.ready_art:
		get_tree().quit(1)
		return
	check("quadruped has deforming skeleton and all four hoof bones", cart._donkey_skeleton.get_bone_count() >= 17 and cart.hoof_positions().size() == 4)
	check("cart has two independent wheels at equal axle height", cart._wheels.size() == 2 and absf(cart._wheels[0].position.y - 0.62) < 0.001)
	var phases: Array = [0.25, 0.75, 0.0, 0.5]
	var max_slip: float = 0.0
	var min_height: float = 99.0
	var max_height: float = -99.0
	var contacts: int = 0
	var anchors: Dictionary = {}
	var stance_drift: float = 0.0
	for i in 120:
		var before: Array[Vector3] = cart.hoof_positions()
		var phase: float = fposmod(cart.distance_m / cart.STRIDE, 1.0)
		var dt: float = cart.WALK_SECONDS / 120.0
		cart.position.z += 2.4 * dt
		cart.advance_motion(dt, 2.4 * dt)
		var after: Array[Vector3] = cart.hoof_positions()
		for j in 4:
			min_height = minf(min_height, after[j].y)
			max_height = maxf(max_height, after[j].y)
			var p: float = fposmod(phase + float(phases[j]), 1.0)
			if p > 0.03 and p < 0.55:
				contacts += 1
				if not anchors.has(j): anchors[j] = before[j]
				stance_drift = maxf(stance_drift, (anchors[j] as Vector3).distance_to(after[j]))
				max_slip = maxf(max_slip, before[j].distance_to(after[j]))
			else:
				anchors.erase(j)
	print("CONTACT_METRICS slip=", max_slip, " min=", min_height, " max=", max_height, " samples=", contacts, " stance_drift=", stance_drift)
	check("planted soles stay within 6mm per sample in world space", contacts > 150 and max_slip < 0.006 and stance_drift < 0.02)
	check("hooves neither penetrate road nor float during stance; swing clears road", min_height >= -0.008 and min_height < 0.04 and max_height > 0.10 and max_height < 0.22)
	check("wheel angular displacement equals travelled distance / tyre radius", absf(angle_difference(cart._wheels[0].rotation.x, fposmod(cart.distance_m / cart.WHEEL_RADIUS, TAU))) < 0.001)
	# A material point at the bottom of a wheel moves backwards relative to the
	# axle at road speed for forward travel: sign matters as much as magnitude.
	var angle0: float = cart._wheels[0].rotation.x
	cart.advance_motion(0.01, 0.024)
	check("both wheels roll forward with the same axle sign", angle_difference(angle0, cart._wheels[0].rotation.x) > 0.0 and absf(cart._wheels[0].rotation.x - cart._wheels[1].rotation.x) < 0.001)
	var grip: Vector3 = cart.hand_position()
	var right0: Vector3 = cart._bone_world(cart._farmer_skeleton, "RightHand")
	var hip0: Vector3 = cart._bone_world(cart._farmer_skeleton, "Hips")
	cart.greet()
	var max_wave: float = 0.0
	var max_grip_error: float = 0.0
	var max_hip_error: float = 0.0
	var max_rein_error: float = 0.0
	for i in 90:
		cart.advance_motion(1.0 / 30.0, 0.0)
		max_wave = maxf(max_wave, right0.distance_to(cart._bone_world(cart._farmer_skeleton, "RightHand")))
		max_grip_error = maxf(max_grip_error, grip.distance_to(cart.hand_position()))
		max_hip_error = maxf(max_hip_error, hip0.distance_to(cart._bone_world(cart._farmer_skeleton, "Hips")))
		for side in 2:
			var verts: PackedVector3Array = cart._reins[side].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var a: Vector3 = cart.to_global((verts[0] + verts[5]) * 0.5)
			var b: Vector3 = cart.to_global((verts[15 * 12 + 1] + verts[15 * 12 + 2]) * 0.5)
			max_rein_error = maxf(max_rein_error, maxf(a.distance_to(cart.hand_position()), b.distance_to(cart.bridle_position(side))))
	print("GREETING_METRICS wave=", max_wave, " grip=", max_grip_error, " hip=", max_hip_error, " reins=", max_rein_error)
	check("right hand waves while the independent left grip stays planted", max_wave > 0.35 and max_grip_error < 0.003)
	check("farmer stays seated through the whole greeting", max_hip_error < 0.003)
	check("rendered rein ribbon endpoints stay on hand and both bridle cheeks", max_rein_error < 0.003)
	check("wave returns to seated driving after greeting", cart.greeting_time < 0.0)
	cart.reset_motion()
	check("retry resets gait, wheels and greeting", cart.distance_m == 0.0 and cart.greeting_time < 0.0 and absf(cart._wheels[0].rotation.x) < 0.001)
	print("EP2_ROAD_CART_MOTION: ", checks, " checks, ", failures, " failed")
	get_tree().quit(0 if failures == 0 else 1)
