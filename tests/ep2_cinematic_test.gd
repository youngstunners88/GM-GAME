extends Node
## Gate for the cliff-jump film (skill ep2-cinematic-cutscene). Founder 2026-09-30: the cart flies off the
## cliff, Lil Blunt jumps out "in the nick of time", slow-mo over the gap, rolls, hits his head, passes out.

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	print("  [%s] %s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fail += 1

func _ready() -> void:
	print("EP2 CINEMATIC:")
	var cam0 := Camera3D.new()
	add_child(cam0)
	cam0.make_current()
	var film := CliffJumpCinematic.new()
	add_child(film)
	await get_tree().process_frame
	var events: Array = []
	var real_at: Dictionary = {}
	var finished_n: Array = [0]
	film.event.connect(func(n: String) -> void:
		events.append(n)
		real_at[n] = film.get_real_time())
	film.finished.connect(func() -> void: finished_n[0] += 1)
	film.start()
	_check("the film takes the screen", get_viewport().get_camera_3d() != cam0)
	var hero_at_launch_plus := Vector3.ZERO
	var cart_at_launch_plus := Vector3.ZERO
	var hero_at_land := Vector3.ZERO
	var cart_at_crash := Vector3.ZERO
	var time_scale_ok := true
	var steps := 0
	while not film.is_finished() and steps < 60 * 30:
		film.step(1.0 / 60.0)
		steps += 1
		time_scale_ok = time_scale_ok and is_equal_approx(Engine.time_scale, 1.0)
		var a: float = film.get_action_time()
		if hero_at_launch_plus == Vector3.ZERO and a >= film.a_launch + 0.3:
			hero_at_launch_plus = film.hero_position()
			cart_at_launch_plus = film.cart_position()
		if cart_at_crash == Vector3.ZERO and a >= film.a_crash:
			cart_at_crash = film.cart_position()
		if hero_at_land == Vector3.ZERO and a >= film.a_land:
			hero_at_land = film.hero_position()
	var want := ["launch", "slowmo", "cart_crash", "land", "head_hit", "blackout"]
	_check("story beats in order", events == want, str(events))
	_check("he leaves the cart in the nick of time (%.2f m apart 0.3 s after the lip)" % hero_at_launch_plus.distance_to(cart_at_launch_plus),
		hero_at_launch_plus.distance_to(cart_at_launch_plus) > 1.0)
	_check("he clears the far lip (lands at z %.1f > %.1f)" % [hero_at_land.z, film.FAR_LIP_Z + 2.0], hero_at_land.z > film.FAR_LIP_Z + 2.0)
	_check("the cart does NOT make it (hits the far wall at y %.1f, lip at %.1f)" % [cart_at_crash.y, film.FAR_Y],
		cart_at_crash.y < film.FAR_Y - 3.0)
	var slow_real: float = float(real_at.get("cart_crash", 0.0)) - float(real_at.get("launch", 0.0))
	var slow_act: float = film.a_crash - film.a_launch
	_check("bullet time: %.2f real s for %.2f action s across the gap" % [slow_real, slow_act], slow_real > slow_act * 2.5 and slow_real > 3.0)
	_check("Engine.time_scale is never touched", time_scale_ok)
	_check("finished exactly once", finished_n[0] == 1, str(finished_n[0]))
	_check("the film is 10-15 s long (%.1f s)" % (float(steps) / 60.0), steps >= 600 and steps <= 900)
	_check("web-safe effects: no GPUParticles in the film", film.find_children("*", "GPUParticles3D", true, false).is_empty())
	film.release(0.2)
	for _i in 30:
		film.step(1.0 / 60.0) if is_instance_valid(film) else null
		await get_tree().process_frame
	_check("release() hands the camera back and frees the film", not is_instance_valid(film) and get_viewport().get_camera_3d() == cam0)
	# Skip mid-air.
	var f2 := CliffJumpCinematic.new()
	add_child(f2)
	await get_tree().process_frame
	var fin2: Array = [0]
	f2.finished.connect(func() -> void: fin2[0] += 1)
	f2.start()
	for _i in 200:
		f2.step(1.0 / 60.0)
	f2.skip()
	f2.skip()
	_check("skip() mid-air ends the film once", f2.is_finished() and fin2[0] == 1, str(fin2[0]))
	print("EP2_CINEMATIC: %s" % ("ALL PASS" if _fail == 0 else "FAIL (%d)" % _fail))
	get_tree().quit(0 if _fail == 0 else 1)
