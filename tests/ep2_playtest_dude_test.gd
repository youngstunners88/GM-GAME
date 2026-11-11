extends Node
## Headless gate for the founder playtest preset "dude" (PROMPT 2026-11-09): the warp lands in the gold town on the STABLES beat beside
## Dude with the yard's talk open, every Episode 2 gun owned with a deep reserve, a fat BTC purse, the horse mountable once bought, and
## a save made there continues at Dude's again. Without the preset nothing changes: no warp is pending and a normal town save opens on
## the STREET beat.
var failed := 0
var checks := 0


func check(label: String, ok: bool, detail: String = "") -> void:
	checks += 1
	if not ok: failed += 1
	print("  [%s] %s %s" % ["PASS" if ok else "FAIL", label, detail])


func _session() -> Ep2SessionRoot:
	var s := Ep2SessionRoot.new()
	add_child(s)
	s.set_process(false)
	s.configure(Episode2Tracks.LEGS, true)
	return s


func _town(s: Ep2SessionRoot) -> GoldTownChamber:
	var t: GoldTownChamber = s.get_active() as GoldTownChamber
	if t != null: t.set_physics_process(false)
	return t


func _ready() -> void:
	print("EP2_PLAYTEST_DUDE")
	check("no preset is pending in normal play", Ep2Playtest.take() == "")
	var overlay: String = FileAccess.get_file_as_string("res://src/autoload/debug_overlay.gd")
	check("the URL entry needs ?playtest=dude exactly", "get('playtest') || ''\", true)) == \"dude\"" in overlay)
	check("the F8 chord only works with the F3 overlay on", "KEY_F8 and _on" in overlay)
	var entry: String = FileAccess.get_file_as_string("res://src/episode2/ep2_entry.gd")
	check("the web warp waits for the streamed extras so Dude is cast", entry.find("while Ep2Extras.state() == \"loading\"") > 0 and entry.find("while Ep2Extras.state() == \"loading\"") < entry.find("_root.start_playtest()"))
	GameManager.token_purse["btc"] = 0
	GameManager.personal_armory = {}
	# 1. the warp
	var s := _session()
	s.start_playtest()
	var town := _town(s)
	check("the preset opens the gold town", town != null)
	if town == null:
		get_tree().quit(1)
		return
	check("on the STABLES beat (the Minister's referral)", town.get_beat_name() == "STABLES", town.get_beat_name())
	var dude: Vector3 = town._stable_yard.dude_position()
	var at: Vector3 = town.get_player_position()
	check("standing at Dude's (within his talk radius)", at.distance_to(dude) <= Ep2StableYard.TALK_RADIUS, "%.2f m" % at.distance_to(dude))
	check("talk to Dude is open", town._stable_interaction_allowed() and town._stable_yard.can_talk(at))
	var st: Ep2ArmoryState = s.armory
	var owned: int = 0
	var low: int = 1 << 30
	for id in Ep2ArmoryState.IDS:
		if st.owns(id): owned += 1
		var gun: Ep2Winchester = st.firearm(id)
		low = mini(low, gun.rounds if id == Ep2ArmoryState.BOW else gun.reserve)
	check("every Episode 2 gun owned (%d)" % Ep2ArmoryState.IDS.size(), owned == Ep2ArmoryState.IDS.size(), str(owned))
	check("every gun's ammunition >= 999", low >= 999, str(low))
	check("every gun loaded and unlocked", Ep2ArmoryState.IDS.all(func(id: String) -> bool: return st.firearm(id).rounds > 0 and not st.firearm(id).locked))
	check("the Shipment and the Sharps are bought, nothing held by the Sheriff", st.river_gear and st.sniper_owned and not st.firearms_confiscated)
	check("BTC purse >= 50", GameManager.purse_balance("btc") >= 50, str(GameManager.purse_balance("btc")))
	check("the armory is persisted for the save", (GameManager.personal_armory.get("weapons", {}) as Dictionary).size() == Ep2ArmoryState.IDS.size())
	# 2. horse bought -> GEARED -> mountable at the departure horse
	var btc_before: int = GameManager.purse_balance("btc")
	check("Dude's real horse negotiation starts", town.start_rig())
	for i in 1800:
		town.step(0.1)
		if town.get_beat_name() == "GEARED": break
	check("Dude sells the horse for the normal price", town.horse_bought() and GameManager.purse_balance("btc") == btc_before - Ep2StableYard.HORSE_PRICE)
	check("after Dude's horse the town is GEARED (no trip back to the counter)", town.get_beat_name() == "GEARED", town.get_beat_name())
	check("the bought horse is reachable on foot", _walk_to(town, GoldTownChamber.DEPART_HORSE + Vector3(1, 0, 0), 20.0, 1.5))
	check("the horse is mountable", town.can_mount_departure())
	# 3. Save -> Continue lands at Dude's again
	town._player_pos = at
	town._advance_to(town.Beat.STABLES)
	s.capture_section_checkpoint()
	var rec: Dictionary = s.section_checkpoint.duplicate(true)
	rec["offset"] = 0
	check("the save is a valid Episode 2 checkpoint", GameManager.valid_resume(rec))
	check("the save is the gold town, flagged playtest", str(rec.section.room) == "gold_town" and rec.section.get("playtest") == "dude")
	_forward(s, town)
	s.queue_free()
	await get_tree().process_frame
	GameManager.personal_armory = rec.state.personal_armory
	var c := _session()
	check("Continue restores the save", c.restore_section(rec))
	var back := _town(c)
	check("Continue opens at Dude's on STABLES", back != null and back.get_beat_name() == "STABLES" and back.get_player_position().distance_to(back._stable_yard.dude_position()) <= Ep2StableYard.TALK_RADIUS)
	check("Continue keeps every gun", Ep2ArmoryState.IDS.all(func(id: String) -> bool: return c.armory.owns(id) and c.armory.firearm(id).reserve >= 999 or id == Ep2ArmoryState.BOW))
	c.queue_free()
	await get_tree().process_frame
	# 4. a normal town save (no playtest flag) is unchanged: the STREET beat
	var plain: Dictionary = rec.duplicate(true)
	plain.section.erase("playtest")
	var n := _session()
	n.restore_section(plain)
	var street := _town(n)
	check("a normal town save still opens on STREET", street != null and street.get_beat_name() == "STREET", street.get_beat_name() if street else "none")
	n.queue_free()
	await get_tree().process_frame
	print("EP2_PLAYTEST_DUDE: %d checks, %d failed" % [checks, failed])
	get_tree().quit(failed)


# One production session, real room resolutions and the existing armory. Position/time are
# accelerated; combat rules remain covered by ep2_river_cover_test.
func _advance(room: Node, seconds: float) -> void:
	for i in int(seconds * 30.0):
		if room._resolved: break
		room.step(1.0 / 30.0)


func _built(s: Ep2SessionRoot) -> void:
	if is_instance_valid(s._pb_node): s._pb_node.prebuild_finish()


func _forward(s: Ep2SessionRoot, town: GoldTownChamber) -> void:
	town._after_story()
	town._player_pos = GoldTownChamber.DEPART_HORSE + Vector3(1.0, 0, 0)
	_built(s)
	check("mount starts the forward handoff", town.start_rig())
	_advance(town, 2.0)
	var trail := s.get_active() as LakeTrailChamber
	check("mount reaches the real lake trail", trail != null and trail.is_mounted())
	if trail == null: return
	trail.set_physics_process(false)
	trail.debug_invulnerable = true
	_built(s)
	var left_yard: bool = true
	for point in [Vector3(10,0,-9), Vector3(21,0,-9), Vector3(33,0,-10), Vector3(49,0,-48), Vector3(70,0,-82), Vector3(102,0,-119)]:
		left_yard = _walk_to(trail, point, 20.0, 4.0) and left_yard
	check("the horse can ride out of the ranch onto the trail", left_yard and not trail._in_departure_area)
	trail._place_at_distance(trail.get_route_length() - 1.0)
	# Exercise the slow-machine path: the lake wasn't prebuilt. Held W must survive
	# this handoff too; the root only forwards movement when its value changes.
	if is_instance_valid(s._pb_vp): s._pb_vp.free()
	s._pb_node = null
	s._pb_vp = null
	s._pb_id = ""
	trail.set_move_input(Vector2(0, 1))
	trail._begin_shore()
	_advance(trail, 5.0)
	var lake := s.get_active() as LogansLakeChamber
	check("the trail reaches Logan's first visit, no day-88 skip", lake != null and not lake.after_day88 and lake.get_beat_name() == "ARRIVE")
	if lake == null: return
	check("cold lake handoff keeps his shore position and held forward", lake.get_player_position().distance_to(trail.get_handoff().lake_player) < 0.01 and lake._move_input == Vector2(0, 1))
	lake.set_move_input(Vector2.ZERO)
	lake.set_physics_process(false)
	check("Logan is reachable from the trail arrival", _walk_to(lake, LogansLakeChamber.LOGAN_MARK + Vector3(-1.0, 0, 0), 20.0, 1.5))
	check("Logan's investigation starts", lake.start_rig())
	_advance(lake, 60.0)
	check("the staging marker is reachable", _walk_to(lake, LogansLakeChamber.STAGING_MARK, 20.0, 2.0))
	check("cargo can be checked once", lake.start_rig() and lake._stage_calls == 1)
	_built(s)
	_walk_to(lake, Vector3(-8, 0, 64), 30.0, 0.1)
	var ridge := s.get_active() as RiverCoverChamber
	check("checked cargo reaches the real day-88 ridge with its gear", ridge != null and ridge._blocked_reason == "" and not ridge.is_launched())
	if ridge == null: return
	ridge.set_physics_process(false)
	ridge.debug_no_ranged = true
	ridge._player_pos = RiverCoverChamber.MARKER + Vector3(0, 0, 1)
	_advance(ridge, 0.2)
	ridge._player_pos = RiverCoverChamber.OVERLOOKS[0]
	var d: Vector3 = ridge.river_point(ridge.river_s_of(RiverCoverChamber.LAUNCH_POINT)) - (ridge._player_pos + Vector3(0, ridge.eye_height, 0))
	ridge._look_yaw = atan2(d.x, d.z)
	ridge._look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	_advance(ridge, 1.0)
	check("the founder must launch the shipment at the overlook", ridge.is_launched())
	for gate in 3:
		ridge._player_pos = RiverCoverChamber.OVERLOOKS[gate]
		ridge._ground_y = ridge._player_pos.y
		for i in 3600:
			if ridge._resolved: break
			for bear in ridge.get_bears(): ridge.damage_bear(bear, 99)
			for man in ridge.get_raiders(): ridge.damage_raider(man)
			ridge.step(1.0 / 30.0)
			if ridge.get_gate() == gate and ridge._gate_cleared and gate < 2 and ridge.crate_s() >= ridge.river_s_of(RiverCoverChamber.EDDY_1 if gate == 0 else RiverCoverChamber.EDDY_2) - 0.2: break
	lake = s.get_active() as LogansLakeChamber
	check("only day-88 success returns to the lake with the auction sign", lake != null and lake.after_day88 and lake.get_beat_name() == "ROAD" and lake._auction_sign.visible)
	if lake == null: return
	lake.set_physics_process(false)
	_built(s)
	check("the drinking horse is reachable from the bank", _walk_to(lake, Vector3(-4.1, 0, 5), 20.0, 0.15))
	check("the returned horse can be mounted", lake.start_rig() and lake.is_riding_horse())
	_advance(lake, 1.0)
	lake._player_pos = LogansLakeChamber.AUCTION_SIGN
	check("the auction sign opens the road", lake.start_rig())
	check("the real auction road and house are reachable", s.get_active() is AuctionRoadChamber and s._chain_id == "auction_road")


func _walk_to(room: Node, target: Vector3, seconds: float, reach: float) -> bool:
	for i in int(seconds * 30.0):
		if room._resolved: return true
		var d: Vector3 = target - room.get_player_position()
		if Vector2(d.x, d.z).length() <= reach:
			room.set_move_input(Vector2.ZERO)
			return true
		room._look_yaw = atan2(d.x, d.z)
		room.set_move_input(Vector2(0, 1))
		room.step(1.0 / 30.0)
	room.set_move_input(Vector2.ZERO)
	print("  WALK STOP target=", target, " at=", room.get_player_position())
	return false
