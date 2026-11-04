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


func _wave_out(c: RiverCoverChamber, n: int) -> void:
	for i in 40:                                     # until the whole wave has come off the banks (3 s apart)
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
	_look_at(c, Vector3(80, 0, 0))
	_advance(c, 1.0)
	check("...looking away from the pool does not launch it", not c.is_launched())
	_look_at(c, c.river_point(c.river_s_of(RiverCoverChamber.LAUNCH_POINT)))
	_advance(c, 1.0)
	check("on the overlook, looking down at the launch pool, the shipment goes into the current: GATE 1/3", c.is_launched() and c.get_gate() == 0
		and "GATE 1/3" in str(c.get_hud().objective), str(c.get_hud().objective))
	var s0: float = c.crate_s()
	_advance(c, 3.0)
	check("he can see it move: the crate drifts downstream", c.crate_s() > s0 + 1.0, "%.1f -> %.1f" % [s0, c.crate_s()])
	# gate 1: two bears, then the eddy waits for him on the bend ledge
	_wave_out(c, 2)
	check("gate 1 brings its wave off the banks (2 bears)", c.get_bears().size() == 2, str(c.get_bears().size()))
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
	_wave_out(c, 6)
	var river_bears: int = 0
	for b in c.get_bears():
		if not bool(b["ridge"]): river_bears += 1
	check("the bend is the densest gate (4 more bears)", river_bears == 6, str(river_bears))
	_kill_river_bears(c)
	_advance(c, 70.0)
	for b in c.get_bears():
		if bool(b["ridge"]): c.damage_bear(b, 99)
	check("Utah is not on the river before the dock approach is clear", not c.utah_visible())
	_stand(c, RiverCoverChamber.OVERLOOKS[2])
	_advance(c, 0.5)
	check("on the dock ledge: GATE 3/3 DOCK APPROACH", c.get_gate() == 2 and "GATE 3/3" in str(c.get_hud().objective))
	_wave_out(c, 9)
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
	_wave_out(c, 2)
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
