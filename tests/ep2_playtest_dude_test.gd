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
	check("the URL entry takes only a known preset name", "PLAYTEST_ROW.any(func(row: Array) -> bool: return row[0] == asked)" in overlay)
	check("the preset keys only work with the F3 overlay on", "k.pressed and not k.echo and _on:" in overlay and "KEY_F8" in overlay)
	var entry: String = FileAccess.get_file_as_string("res://src/episode2/ep2_entry.gd")
	check("the web warp waits for the streamed extras so Dude is cast", entry.find("while Ep2Extras.state() == \"loading\"") > 0 and entry.find("while Ep2Extras.state() == \"loading\"") < entry.find("_root.start_playtest(playtest)"))
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
	town._on_stable_horse_bought(1, 0)
	for i in 10: town.step(1.0 / 30.0)
	check("after Dude's horse the town is GEARED (no trip back to the counter)", town.get_beat_name() == "GEARED", town.get_beat_name())
	town._player_pos = GoldTownChamber.DEPART_HORSE + Vector3(1.0, 0.0, 0.0)
	check("the horse is mountable", town.can_mount_departure())
	# 3. Save -> Continue lands at Dude's again
	town._player_pos = at
	town._advance_to(town.Beat.STABLES)
	s.capture_section_checkpoint()
	var rec: Dictionary = s.section_checkpoint.duplicate(true)
	rec["offset"] = 0
	check("the save is a valid Episode 2 checkpoint", GameManager.valid_resume(rec))
	check("the save is the gold town, flagged playtest", str(rec.section.room) == "gold_town" and rec.section.get("playtest") == "dude")
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
	await _test_auction_preset()
	await _test_ridge_preset()
	await _test_overlay_row()
	print("EP2_PLAYTEST_DUDE: %d checks, %d failed" % [checks, failed])
	get_tree().quit(failed)


## Preset "auction" (founder brief 2026-11-11: "cannot reach the auction on live itch"): the lake AFTER day-88 through the session's own
## room entry - signpost up, horse at the water and mountable, and the lake's own hand-over at the sign lands on the auction road, mounted.
func _test_auction_preset() -> void:
	print("-- preset auction")
	# Arrange
	GameManager.token_purse["btc"] = 0
	GameManager.personal_armory = {}
	check("an unknown preset name is ignored (no warp pending)", Ep2Playtest.room("nope") == "gold_town" and not Ep2Playtest.PRESETS.has("nope"))
	var s := _session()
	# Act
	s.start_playtest(Ep2Playtest.AUCTION)
	var lake: LogansLakeChamber = s.get_active() as LogansLakeChamber
	check("the preset opens Logan's Lake", lake != null)
	if lake == null:
		s.queue_free()
		return
	lake.set_physics_process(false)
	# Assert: the after-day-88 lake, as a save of that moment would open it
	check("...after day-88, on the ROAD beat", lake.after_day88 and lake.get_beat_name() == "ROAD", lake.get_beat_name())
	check("the AUCTION GROUNDS signpost is up", lake._auction_sign != null and lake._auction_sign.visible)
	check("the horse is at the water, sound", lake.get_horse_node().visible and lake.get_horse_state() == "drink" and s.armory.horse_is_sound(), lake.get_horse_state())
	check("every gun, the Shipment, the Sharps and the purse come with it", Ep2ArmoryState.IDS.all(func(id: String) -> bool: return s.armory.owns(id))
		and s.armory.river_gear and s.armory.sniper_owned and GameManager.purse_balance("btc") >= 50)
	check("he starts within a short walk of the signpost (%.1f m)" % lake.get_player_position().distance_to(LogansLakeChamber.AUCTION_SIGN),
		lake.get_player_position().distance_to(LogansLakeChamber.AUCTION_SIGN) < 12.0)
	# the ride: mount at the water, ride to the sign, the lake's own hand-over
	for i in 30: lake.step(1.0 / 30.0)
	lake._player_pos = lake.get_horse_node().position + Vector3(-1.2, 0, 0)
	check("the horse is mountable", lake.can_mount_horse())
	check("interact mounts it", lake.start_rig() and lake.is_riding_horse())
	for i in 90: lake.step(1.0 / 30.0)
	lake._player_pos = LogansLakeChamber.AUCTION_SIGN + Vector3(0.6, 0, 0.6)
	s._drive_prebuild(1.0e9)
	check("the road to the auction is built behind the lake", s.is_prebuilt("auction_road"))
	check("at the signpost the lake lets him leave for the auction", lake._near_auction_sign() and lake._can_leave_for_auction() and lake.start_rig())
	var road: AuctionRoadChamber = s.get_active() as AuctionRoadChamber
	check("...and he is on the auction road, still in the saddle", road != null and road.is_mounted(), str(s.get_active()))
	# a save at the warped lake is an ordinary after-day-88 lake checkpoint: Continue opens there again, signpost and all
	s.queue_free()
	await get_tree().process_frame
	var again := _session()
	again.start_playtest(Ep2Playtest.AUCTION)
	again.capture_section_checkpoint()
	var rec: Dictionary = again.section_checkpoint.duplicate(true)
	rec["offset"] = 0
	check("a save there is a valid lake checkpoint flagged after day-88", GameManager.valid_resume(rec) and str(rec.section.room) == "logans_lake"
		and bool(rec.section.get("after_day88", false)) and not rec.section.has("playtest"))
	again.queue_free()
	await get_tree().process_frame
	GameManager.personal_armory = rec.state.personal_armory
	var c := _session()
	var resumed: bool = c.restore_section(rec)
	var back: LogansLakeChamber = c.get_active() as LogansLakeChamber
	check("Continue opens the lake after day-88 again", resumed and back != null and back.after_day88 and back._auction_sign.visible)
	c.queue_free()
	await get_tree().process_frame


## Preset "day88_ridge": the overlook with the Shipment bought and the Sharps owned, so the river run is not refused.
func _test_ridge_preset() -> void:
	print("-- preset day88_ridge")
	# Arrange
	GameManager.personal_armory = {}
	var s := _session()
	# Act
	s.start_playtest(Ep2Playtest.RIDGE)
	var ridge: RiverCoverChamber = s.get_active() as RiverCoverChamber
	# Assert
	check("the preset opens the day-88 ridge", ridge != null)
	if ridge != null:
		ridge.set_physics_process(false)
		check("...with nothing missing: the Shipment is bought and the Sharps is his", ridge.blocked_reason() == "" and s.armory.river_gear and s.armory.sniper_owned, ridge.blocked_reason())
		check("...on its opening beat with control his", ridge.get_beat_name() == "APPROACH" and ridge.has_player_control(), ridge.get_beat_name())
	s.queue_free()
	await get_tree().process_frame


## The overlay's preset row: hidden in normal play and under ?debug=1, shown by F3 or five corner taps, one button per preset.
func _test_overlay_row() -> void:
	print("-- overlay preset row")
	var row: HBoxContainer = DebugOverlay._row
	check("the row exists with one button per preset, hidden by default", row != null and row.get_child_count() == Ep2Playtest.PRESETS.size() and not row.visible)
	if row == null:
		return
	var names: Array = DebugOverlay.PLAYTEST_ROW.map(func(r: Array) -> String: return str(r[0]))
	check("its presets are exactly the ones Ep2Playtest knows", names.all(func(n: String) -> bool: return Ep2Playtest.PRESETS.has(n)) and names.size() == Ep2Playtest.PRESETS.size(), str(names))
	var size: Vector2 = get_viewport().get_visible_rect().size
	for i in DebugOverlay.CORNER_TAPS - 1:
		var t := InputEventScreenTouch.new()
		t.pressed = true
		t.position = Vector2(size.x * 0.05, size.y * 0.08)
		DebugOverlay._input(t)
	check("four corner taps are not enough", not row.visible)
	var last := InputEventScreenTouch.new()
	last.pressed = true
	last.position = Vector2(size.x * 0.05, size.y * 0.08)
	DebugOverlay._input(last)
	check("the fifth brings the row up (a phone's F3)", row.visible)
	var away := InputEventScreenTouch.new()
	away.pressed = true
	away.position = size * 0.5
	for i in DebugOverlay.CORNER_TAPS: DebugOverlay._input(away)
	check("taps anywhere else never toggle it", row.visible)
	row.visible = false
