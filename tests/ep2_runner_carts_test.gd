extends Node
## Gate for Episode 2 CART ATTRITION + speed ramp + gold (founder, 2026-09-27),
## and a SOLVABILITY bot that plays every real leg in Episode2Tracks.
##
## Why the bot: with carts that die, a track can be unwinnable (a boulder with no
## reachable live cart left) while every rule-level test stays green. The bot
## plays each leg with human-like lookahead and must reach the chamber with no
## hits; a do-nothing run must FAIL, so the leg also has teeth.
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/ep2_runner_carts_test.tscn

const SCENE := preload("res://src/episode2/runner/runner_graybox.tscn")
const DT := 1.0 / 60.0

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

func _run_to(r: Node3D, target: float) -> void:
	var i := 0
	while r.get_distance() < target and r.is_running() and i < 200000:
		r.step(DT)
		i += 1

## THE SHOVEL LINE (founder 2026-09-30): a row of bears across every rail. Rails, hops, jumps and
## ducks do not get past; the zipline does. Proves the zipline has a REASON to exist.
func _shovels() -> void:
	var row: Array = [{"z": 60.0, "lane": 0, "type": "shovels"}, {"z": 60.0, "lane": 1, "type": "shovels"},
		{"z": 60.0, "lane": 2, "type": "shovels"}]
	var plain: Node3D = _spawn()
	plain.setup(200.0, row, [], [], true, {})
	var h0: int = plain.get_health()
	_run_to(plain, 80.0)
	_check("shovel line: plain rails take a smack (health %d -> %d)" % [h0, plain.get_health()], plain.get_health() < h0)
	var jumper: Node3D = _spawn()
	jumper.setup(200.0, row, [], [], true, {})
	var hj: int = jumper.get_health()
	var i := 0
	while jumper.get_distance() < 80.0 and jumper.is_running() and i < 20000:
		if jumper.get_distance() > 50.0 and jumper.get_distance() < 58.0:
			jumper.jump()
		jumper.step(DT)
		i += 1
	_check("shovel line: jumping the rails does not get past (health %d -> %d)" % [hj, jumper.get_health()], jumper.get_health() < hj)
	var flyer: Node3D = _spawn()
	flyer.setup(200.0, row, [{"start_z": 30.0, "end_z": 90.0}], [], true, {})
	var hf: int = flyer.get_health()
	i = 0
	while flyer.get_distance() < 100.0 and flyer.is_running() and i < 20000:
		if flyer.get_distance() > 24.0 and flyer.get_distance() < 29.0:
			flyer.jump()
		flyer.step(DT)
		i += 1
	_check("shovel line: the zipline goes over them untouched (health %d -> %d)" % [hf, flyer.get_health()], flyer.get_health() == hf)

func _ready() -> void:
	print("EP2_RUNNER_CARTS:")
	_rules()
	_shovels()
	_legs()
	print("EP2_RUNNER_CARTS: " + ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(1 if _fail else 0)

func _rules() -> void:
	# 1. A boulder down an EMPTY rail smashes that cart; the rider is untouched.
	var r := _spawn()
	var wrecked: Array = []
	r.cart_wrecked.connect(func(l: int, c: String) -> void: wrecked.append([l, c]))
	r.setup(300.0, [{"z": 20.0, "lane": 2, "type": "boulder"}])
	_run_to(r, 25.0)
	_check("boulder on an empty rail wrecks that cart", not r.is_cart_alive(2) and wrecked.size() == 1)
	_check("...and the rider is untouched", r.get_health() == RunnerGraybox.START_HEALTH and r.get_lane() == 1)

	# 2. A hop onto the dead rail is refused.
	var blocked: Array = []
	r.hop_blocked.connect(func(l: int) -> void: blocked.append(l))
	r.switch_lane_right()
	_check("hop onto a wrecked rail is refused", r.get_lane() == 1 and blocked == [2])
	r.queue_free()

	# 3. A dead centre cart splits the convoy: 0 cannot reach 2.
	var r2 := _spawn()
	r2.setup(300.0, [{"z": 20.0, "lane": 1, "type": "boulder"}], [], [], false, {"start_lane": 0})
	_run_to(r2, 25.0)
	r2.switch_lane_right()
	_check("dead centre blocks the crossing (lane stays 0)", r2.get_lane() == 0)
	r2.queue_free()

	# 4. Boulder on the rider's own rail: one hit, thrown to the nearest live cart.
	var r3 := _spawn()
	var bails: Array = []
	r3.rider_bailed.connect(func(a: int, b: int) -> void: bails.append([a, b]))
	r3.setup(300.0, [{"z": 20.0, "lane": 1, "type": "boulder"}])
	_run_to(r3, 26.0)
	_check("own cart smashed: exactly one hit (health=%d)" % r3.get_health(), r3.get_health() == RunnerGraybox.START_HEALTH - 1)
	_check("own cart smashed: bailed to a live neighbour (%s)" % str(bails),
		bails.size() == 1 and r3.is_cart_alive(r3.get_lane()) and r3.get_lane() != 1)
	r3.queue_free()

	# 5. A spawn event brings a dead rail back.
	var r4 := _spawn()
	r4.setup(300.0, [{"z": 20.0, "lane": 2, "type": "boulder"}], [], [], false,
		{"rail_events": [{"z": 60.0, "lane": 2, "type": "spawn"}]})
	_run_to(r4, 40.0)
	_check("rail dead before its spawn", not r4.is_cart_alive(2))
	_run_to(r4, 61.0)
	r4.switch_lane_right()
	_check("spawned cart is hoppable", r4.is_cart_alive(2) and r4.get_lane() == 2)
	r4.queue_free()

	# 6. Rail end under the rider: hit + bail. Rail end with no other cart: derailed.
	var r5 := _spawn()
	r5.setup(300.0, [], [], [], false, {"rail_events": [{"z": 30.0, "lane": 1, "type": "end"}]})
	_run_to(r5, 32.0)
	_check("rail end under the rider costs a hit and bails", r5.get_health() == RunnerGraybox.START_HEALTH - 1
		and r5.get_lane() != 1 and r5.is_running())
	r5.queue_free()
	var r6 := _spawn()
	var failed: Array = [false]
	r6.run_failed.connect(func() -> void: failed[0] = true)
	r6.setup(300.0, [], [], [], false, {"carts_start": [false, true, false],
		"rail_events": [{"z": 30.0, "lane": 1, "type": "end"}]})
	_run_to(r6, 40.0)
	_check("no live cart left = derailed, run fails", failed[0] and not r6.is_running())
	r6.queue_free()

	# 7. Speed ramps base → max.
	var r7 := _spawn()
	r7.setup(2000.0, [], [], [], false, {"speed": {"base": 20.0, "max": 30.0}})
	r7.step(DT)
	var s0: float = r7.get_speed()
	_run_to(r7, RunnerGraybox.SPEED_RAMP_DIST + 5.0)
	_check("speed ramps (%.1f → %.1f)" % [s0, r7.get_speed()], absf(s0 - 20.0) < 0.2 and absf(r7.get_speed() - 30.0) < 0.01)
	r7.queue_free()

	# 8. Gold: taken in its lane, not from the next lane.
	var r8 := _spawn()
	r8.setup(300.0, [{"z": 20.0, "lane": 1, "type": "gold"}, {"z": 30.0, "lane": 0, "type": "gold"}])
	_run_to(r8, 40.0)
	_check("gold collected in lane only (gold=%d)" % r8.get_gold(), r8.get_gold() == 1
		and r8.get_health() == RunnerGraybox.START_HEALTH)
	r8.queue_free()

	# 9. Zipline over a dead centre drops you on the nearest live cart.
	var r9 := _spawn()
	r9.setup(300.0, [{"z": 12.0, "lane": 1, "type": "boulder"}], [{"start_z": 20.0, "end_z": 40.0}], [], false,
		{"start_lane": 0})
	_run_to(r9, 20.0 - RunnerGraybox.RUN_SPEED * 0.15)
	r9.jump()
	_run_to(r9, 50.0)
	_check("zip dismount avoids the dead centre (lane %d)" % r9.get_lane(), r9.get_lane() != 1
		and r9.is_cart_alive(r9.get_lane()) and r9.is_running())
	r9.queue_free()

# --- Solvability bot ----------------------------------------------------------

func _legs() -> void:
	for leg in Episode2Tracks.LEGS:
		var ld: Dictionary = leg
		var name: String = str(ld.get("name", "?"))
		var played: Dictionary = _play(ld, true)
		_check("%s: bot reaches the chamber with no hits (hp=%d, gold=%d, wrecks=%d, d=%.0f)" % [
				name, played["hp"], played["gold"], played["wrecks"], played["d"]],
			played["reached"] and played["hp"] == RunnerGraybox.START_HEALTH)
		_check("%s: attrition actually happens (wrecks=%d)" % [name, played["wrecks"]], played["wrecks"] >= 4)
		var idle: Dictionary = _play(ld, false)
		_check("%s: a do-nothing run fails (reached=%s, d=%.0f)" % [name, str(idle["reached"]), idle["d"]],
			not idle["reached"])

func _setup_leg(r: Node3D, ld: Dictionary) -> void:
	r.setup(float(ld["chamber_z"]), ld.get("obstacles", []), ld.get("zip_segments", []),
		ld.get("archers", []), bool(ld.get("armed", false)),
		{"rail_events": ld.get("rail_events", []), "carts_start": ld.get("carts_start", [true, true, true]),
		"start_lane": int(ld.get("start_lane", 1)), "speed": ld.get("speed", {})})

func _play(ld: Dictionary, smart: bool) -> Dictionary:
	var r := _spawn()
	var st: Dictionary = {"reached": false, "wrecks": 0}
	r.chamber_reached.connect(func() -> void: st["reached"] = true)
	r.cart_wrecked.connect(func(_l: int, _c: String) -> void: st["wrecks"] = int(st["wrecks"]) + 1)
	if smart:
		# Name every hit the bot takes: the lane/distance is the design bug to fix.
		r.obstacle_hit.connect(func(hp: int) -> void: print("    bot hit at d=%.1f lane=%d y=%.2f hp=%d" % [
			r.get_distance(), r.get_lane(), r.get_cart_y(), hp]))
	_setup_leg(r, ld)
	var i := 0
	while r.is_running() and i < 200000:
		if smart:
			RunnerAutopilot.tick(r)
		r.step(DT)
		i += 1
	var out := {"reached": st["reached"], "hp": r.get_health(), "gold": r.get_gold(),
		"wrecks": st["wrecks"], "d": r.get_distance()}
	r.queue_free()
	return out

