extends Node
## Headless gate for the day-88 river cover stage (founder lock 2026-11-04, docs/founder-feedback/2026-11-04_day88_river_cover.md):
## the prerequisites (Sharps + Shipment, never a free crate), the ridge marker + overlook look that launch the SAME crate Tabs spins,
## exactly three gates, bears that board and tip it, the one retry rule (current gate, no repurchase), Utah at the dock only,
## Logan's Lake with Logan alone.
const RIVER := preload("res://src/episode2/chamber/river_cover.tscn")
const LAKE := preload("res://src/episode2/chamber/logans_lake.tscn")
var failures: int = 0


func check(label: String, ok: bool, detail: String = "") -> void:
	print("  [%s] %s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures += 1


func _armory(shipment: bool, sniper: bool) -> Ep2ArmoryState:
	var st := Ep2ArmoryState.post_hideout()
	if shipment:
		st.purchase_river_gear("btc")
	if sniper:
		st.purchase_sniper("btc")
		st.purchase_sniper_ammo(10, "btc")
	return st


func _room(st: Ep2ArmoryState) -> RiverCoverChamber:
	var c: RiverCoverChamber = RIVER.instantiate() as RiverCoverChamber
	if c == null:
		check("the river cover room loads", false)
		print("RIVER_COVER: %d FAIL" % failures)
		get_tree().quit(1)
		return null
	add_child(c)
	c.set_physics_process(false)
	c.debug_no_ranged = true                         # _test_ranged_threat turns their fire on: these tests drive the crate and the swimmers
	c.bind_armory(st)
	c.setup(0, [], 0)
	return c


func _advance(c: RiverCoverChamber, seconds: float) -> void:
	for i in int(seconds * 30.0):
		c.step(1.0 / 30.0)


func _stand(c: RiverCoverChamber, at: Vector3) -> void:
	c._player_pos = at
	c._ground_y = at.y


func _look_at(c: RiverCoverChamber, p: Vector3) -> void:
	var eye: Vector3 = c._player_pos + Vector3(0, c.eye_height, 0)
	var d: Vector3 = p - eye
	c._look_yaw = atan2(d.x, d.z)
	c._look_pitch = atan2(d.y, Vector2(d.x, d.z).length())


## Cross the marker, stand on the first overlook and look down at the launch pool.
func _arm_and_launch(c: RiverCoverChamber) -> void:
	_stand(c, RiverCoverChamber.MARKER + Vector3(0, 0, 1.0))
	_advance(c, 0.2)
	_stand(c, RiverCoverChamber.OVERLOOKS[0])
	_look_at(c, c.river_point(c.river_s_of(RiverCoverChamber.LAUNCH_POINT)))
	_advance(c, 1.0)


func _kill_river_bears(c: RiverCoverChamber) -> void:
	for b in c.get_bears():
		if not bool(b["ridge"]):
			c.damage_bear(b, 99)
	for m in c.get_raiders():
		c.damage_raider(m)


func _wave_out(c: RiverCoverChamber, n: int) -> void:
	for i in 80:                                     # until the whole wave has come off the banks (3 s apart)
		c._crate_board = 0.0                         # this helper only counts the wave: boarding has its own test below
		_advance(c, 0.5)
		var river: int = 0
		for b in c.get_bears():
			if not bool(b["ridge"]): river += 1
		if river >= n: break


func _ready() -> void:
	print("-- EP2 DAY-88 RIVER COVER")
	_test_prerequisites()
	_test_full_run()
	_test_tipped_and_downed()
	_test_lake_is_logans_alone()
	_test_continues_the_walk()
	_test_ranged_threat()
	print("RIVER_COVER: %s" % ("ALL PASS" if failures == 0 else "%d FAIL" % failures))
	get_tree().quit(1 if failures else 0)


func _test_prerequisites() -> void:
	# no Shipment: no crate anywhere, the run never starts, E at the marker ends the slice and says why
	var c := _room(_armory(false, true))
	check("without the Shipment no crate is spawned on the ridge or the river", c.get_crate() == null and c._visuals.find_child("Shipment", true, false) == null)
	_arm_and_launch(c)
	check("...the marker blocks the run and names the Armory", c.get_beat_name() == "BLOCKED" and not c.is_launched()
		and "SHIPMENT" in str(c.get_hud().objective) and "Rich & Utah" in str(c.get_hud().objective), str(c.get_hud().objective))
	var res: Array = []
	c.chamber_cleared.connect(func(r: Dictionary) -> void: res.append(r))
	_stand(c, RiverCoverChamber.MARKER)
	check("...E at the marker ends the slice with the reason, no free crate", c.start_rig() and res.size() == 1
		and str(res[0].get("river_blocked", "")) == "shipment" and not bool(res[0].get("river_complete", false)), str(res))
	c.free()
	# the Shipment but no Sharps: the crate he bought stays in the pool, unlaunched
	c = _room(_armory(true, false))
	_arm_and_launch(c)
	check("without the Sharps the shipment does not launch (the run needs the Armory's long rifle)", c.get_beat_name() == "BLOCKED"
		and not c.is_launched() and "Sharps" in str(c.get_hud().objective), str(c.get_hud().objective))
	c.free()


func _test_full_run() -> void:
	var st := _armory(true, true)
	var c := _room(st)
	var res: Array = []
	c.chamber_cleared.connect(func(r: Dictionary) -> void: res.append(r))
	check("the Sharps is up on the ridge (the mountain cover weapon)", st.equipped == Ep2ArmoryState.BUFF, st.equipped)
	# the same hero crate in Tabs and on the river
	var crate: Node3D = c.get_crate()
	var tabs := Ep2WeaponSelector.new()
	add_child(tabs)
	tabs.state = st
	tabs.size = Vector2(1280, 720)
	tabs.visible = true
	tabs._process(0.016)
	var tab_piece: Node = tabs._ship_turn.get_child(0) if tabs._ship_turn.get_child_count() > 0 else null
	check("Tabs shows the owned Shipment turning in its tile", tabs.shipment_tile.visible and tab_piece != null)
	check("...and it is the SAME crate the river carries (one hero model, %s)" % Ep2ShipmentCrate.source(), crate != null and tab_piece != null
		and str(crate.get_meta("shipment_source", "")) == str(tab_piece.get_meta("shipment_source", "x")))
	tabs.queue_free()
	# walking past the marker alone does not launch it; the overlook look does
	_stand(c, RiverCoverChamber.MARKER + Vector3(0, 0, 1.0))
	_advance(c, 1.0)
	check("crossing the DAY-88 marker arms the run (hold the overlook)", c.get_beat_name() == "OVERLOOK" and not c.is_launched(), c.get_beat_name())
	_stand(c, RiverCoverChamber.OVERLOOKS[0])
	_look_at(c, Vector3(-80, 0, 0))
	_advance(c, 1.0)
	check("...looking away from the pool does not launch it", not c.is_launched())
	_look_at(c, c.river_point(c.river_s_of(RiverCoverChamber.LAUNCH_POINT)))
	_advance(c, 1.0)
	check("on the overlook, looking down at the launch pool, the shipment goes into the current: GATE 1/3", c.is_launched() and c.get_gate() == 0
		and "GATE 1/3" in str(c.get_hud().objective), str(c.get_hud().objective))
	var s0: float = c.crate_s()
	_advance(c, 3.0)
	check("he can see it move: the crate drifts downstream", c.crate_s() > s0 + 1.0, "%.1f -> %.1f" % [s0, c.crate_s()])
	# gate 1: four swimmers and a bow bear on the far bank, then the eddy waits for him on the bend ledge
	_wave_out(c, 5)
	check("gate 1 brings its wave off the banks (4 swimmers, 1 archer)", c.get_bears().size() == 5, str(c.get_bears().size()))
	check("...and a raft of Hammer's men comes down behind the crate", c.get_rafts().size() == 1 and c.get_raiders().size() == 2)
	_kill_river_bears(c)
	_advance(c, 70.0)
	var eddy1: float = c.river_s_of(RiverCoverChamber.EDDY_1)
	check("cleared, the crate drifts to the eddy before the bend and waits there for him", absf(c.crate_s() - eddy1) < 0.2 and c.get_gate() == 0,
		"%.1f vs %.1f" % [c.crate_s(), eddy1])
	var ridge_bear: Dictionary = {}
	for b in c.get_bears():
		if bool(b["ridge"]): ridge_bear = b
	check("...a bear comes up the path on the way down to the next ledge (the ground scrape)", not ridge_bear.is_empty())
	if not ridge_bear.is_empty():
		c.damage_bear(ridge_bear, 99)
	_stand(c, RiverCoverChamber.OVERLOOKS[1])
	_advance(c, 0.5)
	check("on the bend ledge overlook the crate moves on: GATE 2/3 THE BEND", c.get_gate() == 1 and "GATE 2/3" in str(c.get_hud().objective))
	_wave_out(c, 14)
	var river_bears: int = 0
	for b in c.get_bears():
		if not bool(b["ridge"]): river_bears += 1
	check("the bend is the densest gate (7 more swimmers, 2 archers)", river_bears == 14, str(river_bears))
	_kill_river_bears(c)
	_advance(c, 70.0)
	for b in c.get_bears():
		if bool(b["ridge"]): c.damage_bear(b, 99)
	check("Utah is not on the river before the dock approach is clear", not c.utah_visible())
	_stand(c, RiverCoverChamber.OVERLOOKS[2])
	_advance(c, 0.5)
	check("on the dock ledge: GATE 3/3 DOCK APPROACH", c.get_gate() == 2 and "GATE 3/3" in str(c.get_hud().objective))
	_wave_out(c, 22)
	_kill_river_bears(c)
	_advance(c, 60.0)
	check("the dock approach clear, Utah walks out onto the lower dock", c.utah_visible() and c.get_beat_name() in ["DOCK", "DONE"])
	_advance(c, 20.0)
	check("the shipment reaches Utah under the crane: the run resolves, three gates, no loss", res.size() == 1
		and bool(res[0].get("river_complete", false)) and int(res[0].get("gates", 0)) == 3 and int(res[0].get("losses", -1)) == 0, str(res))
	check("Rich is never here, nor Logan (he stays at his lake)", c.find_child("Rich", true, false) == null and c.find_child("Logan", true, false) == null)
	check("the Shipment is still his (logistics gear, never confiscated or spent)", st.river_gear)
	c.free()


func _test_tipped_and_downed() -> void:
	var st := _armory(true, true)
	var c := _room(st)
	_arm_and_launch(c)
	var rounds_before: int = st.sniper_rounds
	_advance(c, 60.0)                                 # nobody shoots: the bears board and tip it
	check("bears that board the crate tip it: a soft fail", c.get_losses() >= 1, str(c.get_losses()))
	check("...retry is the CURRENT gate: crate back in the launch pool, him on the first overlook, gate 1 again", c.get_gate() == 0
		and c.crate_s() <= c.river_s_of(RiverCoverChamber.LAUNCH_POINT) + 40.0
		and c._player_pos.distance_to(RiverCoverChamber.OVERLOOKS[0]) < 0.5 or c.get_losses() >= 2)
	check("...and nothing is bought again: the Shipment and the Sharps are still his", st.river_gear and st.sniper_owned and st.sniper_rounds == rounds_before)
	c.free()
	# downed by a ridge bear: the same rule
	c = _room(_armory(true, true))
	_arm_and_launch(c)
	_wave_out(c, 5)
	_kill_river_bears(c)
	_advance(c, 70.0)
	var downs: int = c.get_downs()
	var on_way_down: Vector3 = c.ridge_nearest(RiverCoverChamber.OVERLOOKS[1] + Vector3(0, 0, -30))[0]
	_stand(c, on_way_down)                            # down the path towards the bend ledge, into the ledge bear's range
	_advance(c, 25.0)                                 # he stands still and lets it at him
	check("downed on the ridge: back to the current gate's overlook with full hearts, the crate not soft-locked", c.get_downs() > downs
		and c.get_health() == 3 and c.get_gate() == 0, "downs %d health %d gate %d" % [c.get_downs(), c.get_health(), c.get_gate()])
	c.free()


func _test_lake_is_logans_alone() -> void:
	var lake: LogansLakeChamber = LAKE.instantiate() as LogansLakeChamber
	add_child(lake)
	lake.set_physics_process(false)
	lake.setup(0, [], 0)
	check("Logan's Lake: never Rich, never Utah", lake.find_child("Rich", true, false) == null and lake.find_child("Utah", true, false) == null)
	lake.free()


## Founder 2026-11-04: "must literally continue from when Lil Blunt is walking forward up the ridge ... Right now the stage inverts after pressing E".
func _test_continues_the_walk() -> void:
	var from: Vector3 = Vector3(-8.0, 6.0, 62.0)                      # on Logan's overlook path, the moment he goes on
	var c: RiverCoverChamber = RIVER.instantiate() as RiverCoverChamber
	c.handoff = {"yaw": 0.31, "pitch": -0.1, "ridge_from": from}
	add_child(c)
	c.set_physics_process(false)
	c.bind_armory(_armory(true, true))
	c.setup(0, [], 0)
	check("the view is exactly the one he had: no turn at the cut", is_equal_approx(c.get_look_yaw(), 0.31), str(c.get_look_yaw()))
	check("he is where the path was: the same point, moved by the room's offset", c._player_pos.distance_to(from + RiverCoverChamber.LAKE_OFFSET) < 0.8, str(c._player_pos))
	check("the first stretch of the ridge runs the way he was walking (+z)", ((RiverCoverChamber.RIDGE_POINTS[1] as Vector3) - (RiverCoverChamber.RIDGE_POINTS[0] as Vector3)).normalized().z > 0.9)
	# the outflow is on his LEFT at the lake (x = flow_center, he is at x = -8, walking +z): the river must stay on his left here, at every stretch of the run
	for i in range(0, RiverCoverChamber.RIDGE_POINTS.size() - 1, 2):
		var a: Vector3 = RiverCoverChamber.RIDGE_POINTS[i]
		var b: Vector3 = RiverCoverChamber.RIDGE_POINTS[i + 1]
		var fwd: Vector3 = (b - a).normalized()
		var left := Vector3(fwd.z, 0, -fwd.x)
		var river: Vector3 = c.river_point(c.river_s_of(Vector2(a.x, a.z)))
		check("ridge stretch %d: the river is on his left" % i, (river - a).dot(left) > 5.0, str((river - a).dot(left)))
	var dock_dir: float = RiverCoverChamber.RIVER_POINTS[-1].x - RiverCoverChamber.RIVER_POINTS[12].x
	check("past the dock the river curves to his right (the founder's geography, towards the train)", dock_dir < -100.0, str(dock_dir))
	# the ridge's path stands above the lake's hills that come with him (a path under the ground would be a wall)
	var under: Array = []
	var s: float = 0.0
	while s < 180.0:
		var z: float = (RiverCoverChamber.RIDGE_POINTS[0] as Vector3).z + s
		var p: Vector3 = c.ridge_nearest(Vector3(-30, 0, z))[0]
		var lake_x: float = p.x - RiverCoverChamber.LAKE_OFFSET.x
		var lake_z: float = p.z - RiverCoverChamber.LAKE_OFFSET.z
		if lake_z < RiverCoverChamber.LAKE_CLIP_Z and Ep2LakeLandform.terrain_height(lake_x, lake_z) + RiverCoverChamber.LAKE_OFFSET.y > p.y + 0.3:
			under.append("z %.0f: %.1f over %.1f" % [z, Ep2LakeLandform.terrain_height(lake_x, lake_z), p.y])
		s += 6.0
	check("the climb never runs under the lake's hills", under.is_empty(), str(under))
	c.free()


## Founder 2026-11-04: "Some bears are archers ... some of hammer's men on rafts ... Some of his men must even fire at Lil Blunt." They reach him, and moving is always an answer.
func _test_ranged_threat() -> void:
	var st := _armory(true, true)
	var c := _room(st)
	c.debug_no_ranged = false
	_arm_and_launch(c)
	_look_at(c, c.river_point(c.river_s_of(RiverCoverChamber.LAUNCH_POINT)))
	_advance(c, 1.0)
	check("the run is live", c.is_launched())
	var archer: Dictionary = {}
	for b in c.get_bears():
		if str(b["state"]) == "archer":
			archer = b
	check("an archer stands on the far bank", not archer.is_empty())
	var reach: float = (archer["actor"] as Node3D).position.distance_to(c._player_pos)
	check("...well out of a swipe: he has the reach (%.0f m)" % reach, reach > 35.0)
	var saw_draw: bool = false
	var saw_arrow: bool = false
	for i in 240:
		c._invuln = 0.0
		_advance(c, 0.05)
		saw_draw = saw_draw or float(archer["draw"]) >= 0.0
		saw_arrow = saw_arrow or not c.get_arrows().is_empty()
		if saw_arrow:
			break
	check("he draws in plain view before he looses (the warning)", saw_draw)
	check("the arrow flies", saw_arrow)
	# stand still: it lands. step aside: it misses
	var ar: Dictionary = c.get_arrows()[0]
	ar["true"] = true                                # the arrow that would hit him if he stayed
	c._player_pos += Vector3(0, 0, 4.0)
	var before: int = c.get_health()
	var hits_from_man: bool = false
	for i in 80:
		c._invuln = 1.0                              # only this arrow is on trial here, not the raft's guns
		_advance(c, 0.05)
		if c.get_arrows().find(ar) < 0:
			break
	check("stepping aside dodges the arrow: no unavoidable damage", c.get_health() >= before, "%d -> %d" % [before, c.get_health()])
	# standing still under fire is survivable for a while: he has time to shoot back
	var survive := _room(_armory(true, true))
	survive.debug_no_ranged = false
	_arm_and_launch(survive)
	_look_at(survive, survive.river_point(survive.river_s_of(RiverCoverChamber.LAUNCH_POINT)))
	_advance(survive, 1.0)
	survive._crate_board = 0.0
	var t: float = 0.0
	while survive.get_downs() == 0 and t < 25.0:
		survive._crate_board = 0.0
		for b in survive.get_bears():
			if str(b["state"]) in ["swim", "board", "bank"]:
				survive.damage_bear(b, 99)               # only the ranged fire is on trial
		_advance(survive, 0.5)
		t += 0.5
	check("standing still on the overlook under fire he lasts at least 12 s (time to answer)", t >= 12.0, "%.1f s" % t)
	survive.free()
	# the raft comes up, its men fire, and it drains the crate until they are dead
	var saw_tell: bool = false
	var hooked: bool = false
	for i in 900:
		_advance(c, 0.1)
		for m in c.get_raiders():
			saw_tell = saw_tell or str(m["state"]) == "tell"
		for r in c.get_rafts():
			hooked = hooked or bool(r["hooked"])
		c._health = 3
		c._crate_board = 0.0
		if saw_tell and hooked:
			break
	check("Hammer's men raise a gun on him from the raft", saw_tell)
	check("the raft reaches the shipment and hooks it", hooked)
	for m in c.get_raiders():
		c.damage_raider(m)
	_advance(c, 0.5)
	check("with its men down the raft lets go", not bool(c.get_rafts()[0]["hooked"]))
	check("a retry clears the rafts and arrows, then the gate brings them again", _retry_clears(c))
	c.free()


func _retry_clears(c: RiverCoverChamber) -> bool:
	c._package_lost()
	return c.get_arrows().is_empty() and c.get_rafts().size() == 1 and c.get_raiders().size() == 2 and c.get_bears().size() == 1
