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
	print("EP2_PLAYTEST_DUDE: %d checks, %d failed" % [checks, failed])
	get_tree().quit(failed)
