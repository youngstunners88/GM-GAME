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
	_test_ridge_reload()
	_test_ridge_cover()
	_test_lake_is_logans_alone()
	_test_continues_the_walk()
	_test_ranged_threat()
	_test_hammer_crews()
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
	check("Rich has come down to the dock to watch the last gate (founder 2026-11-15)", c.get_rich() != null and c.get_rich().visible and c.rich_state() != "")
	_wave_out(c, 22)
	_kill_river_bears(c)
	_advance(c, 60.0)
	check("the dock approach clear, Utah walks out onto the lower dock", c.utah_visible() and c.get_beat_name() in ["DOCK", "DONE"])
	_advance(c, 40.0)
	# one world (founder 2026-11-17): Utah has it, and he is NOT cut to the lake - he walks home along the same ridge
	check("Utah has the crate and he stays on the ridge: no cut to the lake from the dock", c.get_beat_name() == "DONE" and res.is_empty()
		and "Walk back up the ridge" in str(c.get_hud().objective), str(res))
	var pts: Array = RiverCoverChamber.RIDGE_POINTS
	for i in range(pts.size() - 1, -1, -1):
		var from: Vector3 = c._player_pos
		for k in 8:                                  # walk, a few metres a step, never a jump
			_stand(c, c._collide(from.lerp(pts[i], float(k + 1) / 8.0)))
			_advance(c, 0.1)
	check("walked back to Logan's path, the run resolves: three gates, no loss", res.size() == 1
		and bool(res[0].get("river_complete", false)) and int(res[0].get("gates", 0)) == 3 and int(res[0].get("losses", -1)) == 0, str(res))
	var hand: Dictionary = c.get_handoff()
	check("the lake goes on from where he stands on its path (same point, same heading)", hand.has("lake_player")
		and ((hand["lake_player"] as Vector3) + RiverCoverChamber.LAKE_OFFSET).distance_to(c._player_pos) < 0.01 and is_equal_approx(float(hand.get("lake_yaw", 99.0)), c._look_yaw), str(hand))
	check("Rich collected the shipment: he lifted the crate and carried it off the dock (a visible beat, not a line)", c.crate_collected() and c.get_crate() != null and not c.get_crate().visible)
	check("Logan stays at his lake", c.find_child("Logan", true, false) == null)
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
	var eddy_s: float = c.crate_s()
	_stand(c, on_way_down)                            # down the path towards the bend ledge, into the ledge bear's range
	_advance(c, 25.0)                                 # he stands still and lets it at him
	# founder 2026-11-06: downed AFTER the gate's wave is down must not send the crate back upstream to the launch pool
	check("downed after the gate is cleared: the crate stays waiting in the eddy, never jumps upstream", c.crate_s() >= eddy_s - 0.01,
		"eddy %.1f now %.1f" % [eddy_s, c.crate_s()])
	check("downed on the ridge: back to the current gate's overlook with full hearts, the crate not soft-locked", c.get_downs() > downs
		and c.get_health() == 3 and c.get_gate() == 0, "downs %d health %d gate %d" % [c.get_downs(), c.get_health(), c.get_gate()])
	c.free()


## Founder 2026-11-06: reload glitched on the ridge. The Sharps holds one round with a 1.1 s breech cycle; R pressed during the cycle
## was dropped, and the gate resupply read the never-decreasing purchase counter so the reserve could hit 0 with no top-up.
func _test_ridge_reload() -> void:
	var st := _armory(true, true)
	var c := _room(st)
	_arm_and_launch(c)
	var sharps: Ep2Winchester = st.firearm(Ep2ArmoryState.BUFF)
	sharps.rounds = 1
	sharps.reserve = 3
	check("ridge: the Sharps fires", sharps.trigger() == Ep2Winchester.Shot.OK)
	sharps.start_reload()                              # R straight after the shot, while the breech still cycles
	for i in 240:
		sharps.step(1.0 / 60.0)
	check("R during the breech cycle is not dropped: the round is loaded", sharps.rounds == 1 and not sharps.reloading,
		"rounds %d reloading %s" % [sharps.rounds, sharps.reloading])
	check("...and he can fire again", sharps.trigger() == Ep2Winchester.Shot.OK)
	sharps.rounds = 0
	sharps.reserve = 0
	st.sniper_rounds = 99                              # boxes bought earlier: must not hide an empty reserve
	c._resupply(1)
	check("gate resupply reads the real reserve, not the purchase counter", sharps.reserve > 0, str(sharps.reserve))
	sharps.start_reload()
	c._package_lost()                                  # a soft fail mid-reload
	check("after a soft-fail restore the gun is not left mid-reload", not sharps.reloading and not sharps.reload_queued)
	check("...and it can be reloaded and fired", (sharps.rounds > 0 or sharps.start_reload()) )
	c.free()


## Founder 2026-11-08: duck behind the barrack, reload safe, pop up over the bags and fire.
func _test_ridge_cover() -> void:
	var st := _armory(true, true)
	var c := _room(st)
	_arm_and_launch(c)
	check("on the gate overlook he is at a barrack", c.at_barrack())
	check("ridge creates exactly one standard touch Cover", c._cover_button != null and c._cover_button.glyph == VirtualButton.Glyph.COVER and c.find_children("Cover", "", true, false).size() == 1)
	var finger := InputEventScreenTouch.new()
	finger.index = 1
	finger.pressed = true
	c._cover_button._gui_input(finger)
	check("a Cover touch enters the existing cover state", c.in_cover())
	finger.pressed = false
	c._cover_button._gui_input(finger)
	finger.pressed = true
	c._cover_button._gui_input(finger)
	check("a second Cover touch peeks out through the same toggle", not c.in_cover())
	finger.pressed = false
	c._cover_button._gui_input(finger)
	check("C drops him into cover", c.toggle_cover() and c.in_cover())
	_advance(c, 0.6)
	check("...his eye sinks below the sandbag crest", c.eye_height <= RiverCoverChamber.COVER_EYE + 0.01, "%.2f" % c.eye_height)
	c._invuln = 0.0
	var before: int = c.get_health()
	for i in 4:
		c._hurt_player()
	check("in cover the bears and men out front cannot hurt him", c.get_health() == before, "%d -> %d" % [before, c.get_health()])
	var sharps: Ep2Winchester = st.firearm(Ep2ArmoryState.BUFF)
	sharps.rounds = 0
	sharps.reserve = 3
	check("R reloads in cover", c.reload() or sharps.reloading)
	for i in 240:
		sharps.step(1.0 / 60.0)
	check("...and he is still covered when the round is in", c.in_cover() and sharps.rounds > 0)
	check("a click in cover pops him up instead of firing into the bags", not c.shoot() and not c.in_cover())
	_advance(c, 0.6)
	check("...back at full eye height over the barrack", absf(c.eye_height - RiverCoverChamber.FPS_EYE_HEIGHT) < 0.01, "%.2f" % c.eye_height)
	c._invuln = 0.0
	c._hurt_player()
	check("out of cover he is exposed again", c.get_health() == before - 1)
	c.toggle_cover()
	_stand(c, RiverCoverChamber.OVERLOOKS[0] + Vector3(0, 0, 12.0))
	_advance(c, 0.1)
	check("walking off the overlook stands him up", not c.in_cover())
	check("away from a barrack C does nothing", not c.toggle_cover() and not c.in_cover())
	c.free()


func _test_lake_is_logans_alone() -> void:
	var lake: LogansLakeChamber = LAKE.instantiate() as LogansLakeChamber
	add_child(lake)
	lake.set_physics_process(false)
	lake.setup(0, [], 0)
	check("Logan's Lake: never Rich, never Utah (Rich is at the dock, not the lake)", lake.find_child("Rich", true, false) == null and lake.find_child("Utah", true, false) == null)
	lake.free()
	# walked home from the dock (2026-11-17): the lake starts him on its path where the ridge left him, after day 88, heading kept
	var home: Vector3 = (RiverCoverChamber.RIDGE_POINTS[0] as Vector3) - RiverCoverChamber.LAKE_OFFSET
	var back: LogansLakeChamber = LAKE.instantiate() as LogansLakeChamber
	back.handoff = {"after_day88": true, "lake_player": home, "lake_yaw": PI, "lake_pitch": 0.0}
	add_child(back)
	back.set_physics_process(false)
	back.setup(0, [], 0)
	for i in 10: back.step(1.0 / 30.0)
	check("home from the dock: the lake picks him up on Logan's path, not at its spawn", Vector2(back._player_pos.x - home.x, back._player_pos.z - home.z).length() < 1.0
		and back.after_day88 and is_equal_approx(back._look_yaw, PI), "%s vs %s" % [back._player_pos, home])
	back.free()


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


## Founder River Assets 2026-11-15: Hammer's men are not one clone; some carry rifles; some rafts carry one man.
func _test_hammer_crews() -> void:
	var c := _room(_armory(true, true))
	for g in [1, 2]:
		for i in (RiverCoverChamber.RAFT_CREWS[g] as Array).size():
			c._spawn_raft(g, i, 120.0)
	var solo: Array = []
	var paired: int = 0
	for r in c.get_rafts():
		if (r["men"] as Array).size() == 1:
			solo.append(r)
		elif (r["men"] as Array).size() == 2:
			paired += 1
	check("solo and paired rafts are mixed down the river", solo.size() >= 2 and paired >= 2, "%d solo, %d paired" % [solo.size(), paired])
	var rifles: int = 0
	var pistols: int = 0
	var looks: Dictionary = {}
	var founder_body: bool = true
	var muzzle_ok: bool = true
	for m in c.get_raiders():
		var folk: Ep2TownFolk = m["folk"]
		looks["%s/%.2f/%.2f" % [str(m["gun"]), folk.height_m, folk.model.scale.x / folk.model.scale.y]] = true
		if str(m["gun"]) == "rifle":
			rifles += 1
			founder_body = founder_body and folk.model.scene_file_path == RiverCoverChamber.RIFLEMAN_MODEL
			muzzle_ok = muzzle_ok and absf((m["glint"] as Node3D).position.y - RiverCoverChamber.RIFLE_MUZZLE.y * folk.height_m) < 0.01
		else:
			pistols += 1
	check("some men carry the founder's rifleman and his long gun, others keep sidearms", rifles >= 2 and pistols >= 2, "%d rifles, %d pistols" % [rifles, pistols])
	check("...the riflemen are the River Assets body, their glint at the muzzle", founder_body and muzzle_ok)
	check("no two men on the water share one look", looks.size() == c.get_raiders().size(), "%d looks / %d men" % [looks.size(), c.get_raiders().size()])
	var lone: Dictionary = (solo[0]["men"] as Array)[0] if not solo.is_empty() else {}
	check("a man alone on a raft is a rifleman", not lone.is_empty() and str(lone["gun"]) == "rifle")
	if not lone.is_empty():
		c.damage_raider(lone)
		_advance(c, 2.0)
		check("...shot, he still goes overboard into the river", c.raider_overboard(lone))
	c.queue_free()
