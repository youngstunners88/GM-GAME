extends Node
## Gate for the Episode 2 golden revolver (6-shot cylinder, mouse ray, reload),
## and the pickaxe-swipe "boarder" hazard in runner_graybox.gd.
## Same harness as ep2_runner_graybox_test.gd: spawn the packed scene, disable
## physics_process, drive the sim by hand with step().
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/ep2_runner_revolver_test.tscn

const SCENE := preload("res://src/episode2/runner/runner_graybox.tscn")

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _spawn() -> Node3D:
	var r: Node3D = SCENE.instantiate()
	add_child(r)
	r.set_physics_process(false)
	return r

func _run_to_distance(r: Node3D, target: float, dt: float = 0.05, cap: int = 100000) -> void:
	var i := 0
	while r.get_distance() < target and r.is_running() and i < cap:
		r.step(dt)
		i += 1

func _bear() -> Array:
	return [{"id": "b1", "z": 30.0, "side": 1}]

func _volley() -> Array:
	return [{"z": 30.0, "lane": 1, "type": "arrow", "archer": "b1"}]

func _chest(z: float, side: float) -> Vector3:
	return Vector3(-side * RunnerGraybox.ARCHER_X, RunnerGraybox.ARCHER_Y + RunnerGraybox.ARCHER_CHEST, z)

## A ray straight up from the rider: hits nothing.
func _fire_miss(r: Node3D) -> Dictionary:
	var res: Dictionary = r.fire_ray(Vector3(0.0, 3.0, r.get_distance()), Vector3.UP)
	return res

func _ready() -> void:
	await get_tree().process_frame
	print("EP2 RUNNER REVOLVER:")

	# 1. A fresh armed run starts with a full cylinder.
	var r1 := _spawn()
	r1.setup(200.0, [], [], _bear(), true)
	_check("starts with %d rounds (ammo=%d)" % [RunnerGraybox.CYLINDER, int(r1.get_ammo())],
		int(r1.get_ammo()) == RunnerGraybox.CYLINDER and not bool(r1.is_reloading()))

	# 2. fire_ray consumes exactly one round.
	var res1: Dictionary = _fire_miss(r1)
	_check("fire_ray fires and consumes one round (ammo=%d)" % int(r1.get_ammo()),
		bool(res1["fired"]) and int(r1.get_ammo()) == RunnerGraybox.CYLINDER - 1)
	r1.queue_free()

	# 3. A ray through an archer kills it, and its volley never lands.
	var r2 := _spawn()
	r2.setup(200.0, _volley(), [], _bear(), true)
	var origin := Vector3(0.0, 3.0, 0.0)
	var dir: Vector3 = (_chest(30.0, 1.0) - origin).normalized()
	var res2: Dictionary = r2.fire_ray(origin, dir)
	var hit_id: String = str(res2["hit"])
	_check("a ray through an archer kills it (hit=%s)" % hit_id,
		bool(res2["fired"]) and hit_id == "b1" and int(r2.archers_alive()) == 0)
	var pt: Vector3 = res2["point"]
	_check("the resolved point is on the archer (%.1f from chest)" % pt.distance_to(_chest(30.0, 1.0)),
		pt.distance_to(_chest(30.0, 1.0)) <= RunnerGraybox.ARCHER_HIT_R + 0.01)
	_run_to_distance(r2, 40.0)
	_check("a shot archer's volley never lands (health=%d)" % int(r2.get_health()), int(r2.get_health()) == 3)
	r2.queue_free()

	# 4. A ray that misses kills nothing.
	var r3 := _spawn()
	r3.setup(200.0, _volley(), [], _bear(), true)
	var res3: Dictionary = _fire_miss(r3)
	_check("a missing ray fires but kills nothing",
		bool(res3["fired"]) and str(res3["hit"]) == "" and int(r3.archers_alive()) == 1)
	r3.queue_free()

	# 5. Six shots empty the cylinder → auto reload; firing mid-reload doesn't fire;
	#    after RELOAD_TIME the cylinder is full again.
	var r4 := _spawn()
	r4.setup(400.0, [], [], [], true)
	var fired_count: int = 0
	for _i in RunnerGraybox.CYLINDER:
		var rs: Dictionary = _fire_miss(r4)
		if bool(rs["fired"]):
			fired_count += 1
		r4.step(RunnerGraybox.SHOOT_COOLDOWN + 0.01)
	_check("six shots all fire (fired=%d)" % fired_count, fired_count == RunnerGraybox.CYLINDER)
	_check("empty cylinder auto-reloads (ammo=%d, reloading=%s)" % [int(r4.get_ammo()), str(r4.is_reloading())],
		int(r4.get_ammo()) == 0 and bool(r4.is_reloading()))
	var shots := {"n": 0}
	r4.shot_fired.connect(func() -> void: shots["n"] = int(shots["n"]) + 1)
	var rs_mid: Dictionary = _fire_miss(r4)
	_check("firing during reload does not fire",
		not bool(rs_mid["fired"]) and int(shots["n"]) == 0 and int(r4.get_ammo()) == 0)
	r4.step(RunnerGraybox.RELOAD_TIME + 0.01)
	_check("after RELOAD_TIME the cylinder is full (ammo=%d)" % int(r4.get_ammo()),
		int(r4.get_ammo()) == RunnerGraybox.CYLINDER and not bool(r4.is_reloading()))
	r4.queue_free()

	# 6. Manual reload at 3 rounds starts; at 6 it's a no-op.
	var r5 := _spawn()
	r5.setup(400.0, [], [], [], true)
	var reloads := {"n": 0}
	r5.reload_started.connect(func() -> void: reloads["n"] = int(reloads["n"]) + 1)
	for _i in 3:
		_fire_miss(r5)
		r5.step(RunnerGraybox.SHOOT_COOLDOWN + 0.01)
	r5.reload()
	_check("manual reload at 3 rounds starts (ammo=%d)" % int(r5.get_ammo()),
		int(r5.get_ammo()) == 3 and bool(r5.is_reloading()) and int(reloads["n"]) == 1)
	r5.queue_free()
	var r6 := _spawn()
	r6.setup(400.0, [], [], [], true)
	var reloads6 := {"n": 0}
	r6.reload_started.connect(func() -> void: reloads6["n"] = int(reloads6["n"]) + 1)
	r6.reload()
	_check("manual reload with a full cylinder is a no-op",
		not bool(r6.is_reloading()) and int(reloads6["n"]) == 0)
	r6.queue_free()

	# 7. Dry fire at 0 rounds (not already reloading) emits dry_fire and reloads.
	var r7 := _spawn()
	r7.setup(400.0, [], [], [], true)
	r7.set("_ammo", 0)
	var dry := {"n": 0}
	r7.dry_fire.connect(func() -> void: dry["n"] = int(dry["n"]) + 1)
	var rs7: Dictionary = _fire_miss(r7)
	_check("dry fire at 0 emits dry_fire and does not fire",
		not bool(rs7["fired"]) and int(dry["n"]) == 1 and bool(r7.is_reloading()))
	r7.queue_free()

	# 8. can_shoot false never fires.
	var r8 := _spawn()
	r8.setup(200.0, _volley(), [], _bear(), false)
	var res8: Dictionary = r8.fire_ray(origin, dir)
	_check("unarmed fire_ray never fires",
		not bool(res8["fired"]) and int(r8.archers_alive()) == 1 and int(r8.get_ammo()) == RunnerGraybox.CYLINDER)
	r8.queue_free()

	# 9. Cooldown blocks an instant second shot.
	var r9 := _spawn()
	r9.setup(200.0, [], [], [], true)
	var a9: Dictionary = _fire_miss(r9)
	var b9: Dictionary = _fire_miss(r9)
	_check("cooldown blocks an instant second shot (ammo=%d)" % int(r9.get_ammo()),
		bool(a9["fired"]) and not bool(b9["fired"]) and int(r9.get_ammo()) == RunnerGraybox.CYLINDER - 1)
	r9.queue_free()

	# 10. A boarder with no swipe costs 1 health.
	var boarder := [{"z": 10.0, "lane": -1, "type": "boarder"}]
	var r10 := _spawn()
	r10.setup(200.0, boarder)
	_run_to_distance(r10, 13.0)
	_check("an unanswered boarder costs 1 health (health=%d)" % int(r10.get_health()), int(r10.get_health()) == 2)
	r10.queue_free()

	# 10b. lane -1 follows the rider: hopping carts doesn't dodge it.
	var r10b := _spawn()
	r10b.setup(200.0, boarder)
	r10b.switch_lane_left()
	_run_to_distance(r10b, 13.0)
	_check("a boarder boards whichever cart you're in (health=%d)" % int(r10b.get_health()),
		int(r10b.get_health()) == 2)
	r10b.queue_free()

	# 11. A swipe just before costs nothing and emits boarder_repelled.
	var r11 := _spawn()
	r11.setup(200.0, boarder)
	var rep := {"n": 0}
	r11.boarder_repelled.connect(func() -> void: rep["n"] = int(rep["n"]) + 1)
	_run_to_distance(r11, 7.0)
	r11.swipe()
	_run_to_distance(r11, 13.0)
	_check("a swipe just before repels the boarder (health=%d, repelled=%d)" % [int(r11.get_health()), int(rep["n"])],
		int(r11.get_health()) == 3 and int(rep["n"]) == 1)
	r11.queue_free()

	# 12. Jump does not clear a boarder.
	var r12 := _spawn()
	r12.setup(200.0, boarder)
	_run_to_distance(r12, 6.8)
	r12.jump()
	_run_to_distance(r12, 13.0)
	_check("jumping does NOT clear a boarder (health=%d)" % int(r12.get_health()), int(r12.get_health()) == 2)
	r12.queue_free()

	# 13. ray_hits_archer is a pure query.
	var r13 := _spawn()
	r13.setup(200.0, _volley(), [], _bear(), true)
	var shots13 := {"n": 0}
	r13.shot_fired.connect(func() -> void: shots13["n"] = int(shots13["n"]) + 1)
	var q: String = str(r13.ray_hits_archer(origin, dir))
	var q_miss: String = str(r13.ray_hits_archer(origin, Vector3.UP))
	_check("ray_hits_archer reports the archer under the ray (%s) and '' for a miss" % q,
		q == "b1" and q_miss == "")
	_check("ray_hits_archer has no side effects",
		int(r13.archers_alive()) == 1 and int(r13.get_ammo()) == RunnerGraybox.CYLINDER and int(shots13["n"]) == 0)
	var after_q: Dictionary = r13.fire_ray(origin, dir)
	_check("a real shot right after the query still fires (no cooldown set by it)", bool(after_q["fired"]))
	r13.queue_free()

	print("EP2_RUNNER_REVOLVER: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)
