extends Node
## Founder fix pack 2026-11-15 (New Fixes.md): three licenses, Rich's hands-free reveal, Dude's horses and manners, Logan's three sentences, no [E] arrivals,
## Rich collecting the shipment, the auctioneer's voice id, GM OG Smoke on the road. Each check fails on the code as it was before this pack.
var failures := 0

func check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["PASS" if ok else "FAIL", label])
	if not ok: failures += 1

func _src(path: String) -> String:
	return FileAccess.get_file_as_string(path)

func _ready() -> void:
	await get_tree().process_frame
	# 1. three licenses
	# Captain lock (touch-ups 2026-11-16): Prospector's -> Miner's -> Goldsmith's. Never Foreman's, never Mine Owner's.
	check("the license wall has three tiers: Prospector's, Miner's, Goldsmith's", GoldTownChamber.LICENSE_TIERS.size() == 3
		and GoldTownChamber.LICENSE_TIERS.map(func(t: Array) -> String: return str(t[0])) == ["PROSPECTOR'S LICENSE", "MINER'S LICENSE", "GOLDSMITH'S LICENSE"])
	check("each tier's print is its own texture (the Goldsmith print exists, the Foreman and Mine Owner prints are gone)",
		str(GoldTownChamber.LICENSE_TIERS[2][2]).ends_with("tex_license_goldsmith.jpg") and FileAccess.file_exists("res://src/episode2/extras/town/licenses/tex_license_goldsmith.jpg")
		and not FileAccess.file_exists("res://src/episode2/extras/town/licenses/tex_license_foreman.jpg") and not FileAccess.file_exists("res://src/episode2/extras/town/licenses/tex_license_mine-owner.jpg"))
	var all_copy: String = (_src("res://src/episode2/chamber/gold_town.gd") + _src("res://assets/town-audio.json") + _src("res://src/episode2/audio/town_voice_bank.gd")).to_lower()
	check("no Foreman's or Mine Owner's anywhere in the town's code, dialogue or voice lines", not "foreman" in all_copy and not "mine owner" in all_copy)
	check("no line says four licenses or four papers", not "four licenses" in all_copy and not "four papers" in all_copy)
	check("the miners' certificate talk is recorded with three licenses (no 'four' left in the takes)", Ep2TownVoiceBank.LINES["miners_certs_1"]["ready"]
		and "three licenses" in str(Ep2TownVoiceBank.LINES["miners_certs_1"]["text"]) and Ep2TownVoiceBank.LINES["miners_certs_2"]["ready"]
		and str(Ep2TownVoiceBank.LINES["miners_certs_2"]["text"]).begins_with("Three papers"))
	var first: String = " ".join(GoldTownChamber.MINISTER1_LINES.map(func(l: Array) -> String: return str(l[1]))).to_lower()
	check("Mike Dean says three licenses, never four, and never names a fourth", "three licenses" in first and not "four" in first and not "mine owner" in first)
	# 2. Rich's hands-free reveal
	check("the hand-over has a SETDOWN stage before the reach", Ep2ArmoryIntro.Stage.has("SHARPS_SETDOWN") and Ep2ArmoryIntro.Stage.SHARPS_SETDOWN < Ep2ArmoryIntro.Stage.SHARPS_REACH)
	var intro_src: String = _src("res://src/episode2/actors/ep2_armory_intro.gd")
	check("...and the beat really plays it: his walk ends in SETDOWN (not straight into the reach) and the slow turn rate is applied",
		intro_src.contains("stage = Stage.SHARPS_SETDOWN") and intro_src.contains("rich.folk.turn_rate = TURN_RATE"))
	check("gold is set down, then the hands are free, then he turns - in that order, slowly", Ep2ArmoryIntro.SETDOWN_RELEASE_AT < Ep2ArmoryIntro.SETDOWN_TURN_AT
		and Ep2ArmoryIntro.SETDOWN_TURN_AT < Ep2ArmoryIntro.SETDOWN_S and Ep2ArmoryIntro.TURN_RATE < 4.0)
	var folk := Ep2TownFolk.new()
	check("a folk has the standing turn rate unless a beat overrides it", folk.turn_rate < 0.0)
	folk.free()
	check("opening the trade no longer pauses the tree while the introduction runs", _src("res://src/episode2/chamber/gold_town.gd").contains("get_tree().paused = not (_intro != null and _intro.is_busy())"))
	# 3. Dude's yard
	var c: GoldTownChamber = load("res://src/episode2/chamber/gold_town.tscn").instantiate()
	add_child(c)
	c.setup(0, [], 0)
	c.set_physics_process(false)
	var yard: Ep2StableYard = c._stable_yard
	var coats: Array = yard.horses.map(func(h: Node3D) -> String: return Ep2HorseCoat.coat_of(h))
	check("the yard's horses are not all brown: white, black and brown all stand there", "white" in coats and "black" in coats and "brown" in coats)
	var overrides := {}
	for h in yard.horses:
		for mi in h.find_children("*", "MeshInstance3D", true, false):
			var m: Material = (mi as MeshInstance3D).get_surface_override_material(0)
			if m != null: overrides[m] = true
	check("each recoloured horse owns its own material (they are not one shared brown)", overrides.size() >= 2)
	var white: int = coats.find("white")
	var chosen: bool = yard.try_choose(yard.horses[white].global_position + Vector3(1.0, 0.0, 0.0))
	check("[E] beside a horse chooses it, and the ride takes its coat", chosen and yard.chosen_index() == white and yard.chosen_coat() == "white")
	var dude_at: Vector3 = yard.dude_position()
	check("Dude greets by himself when Lil Blunt comes into sight (no [E])", yard.try_auto_greet(dude_at + Vector3(4.0, 0.0, 0.0)) and yard.conversation_active())
	yard.step(0.1, dude_at + Vector3(Ep2StableYard.LEAVE_RADIUS + 2.0, 0.0, 0.0))
	check("walking off mid-sentence before the horse is paid for gets the rude goodbye", str(yard._conv_current.get("id", "")) == "dude_ranch_17" and yard._conv_queue.is_empty())
	check("the horse talk is short (the haggle and the reminder are gone)", not _src("res://src/episode2/chamber/ep2_stable_yard.gd").contains("dude_ranch_09\"))") )
	check("paying for the horse sends him on to the ride without waiting for Dude to finish",
		not _src("res://src/episode2/chamber/gold_town.gd").contains("(_stable_yard == null or not _stable_yard.conversation_active()):\n\t\t\t\t_after_story()"))
	# 4. Logan
	check("Logan's lesson is exactly three sentences", LogansLakeChamber.LINES.size() == 3 and LogansLakeChamber.LINES.all(func(l: String) -> bool: return l.begins_with("LOGAN:") and l.count(". ") == 0 and l.ends_with(".")))
	check("...and it explains the pool, the still deep water, and the fee", "liquidity pool" in LogansLakeChamber.LINES[0] and "still" in LogansLakeChamber.LINES[1] and "fee" in LogansLakeChamber.LINES[2])
	var lake_src: String = _src("res://src/episode2/chamber/logans_lake.gd")
	check("Logan begins talking when he sees Lil Blunt (the [E] prompt is gone)", lake_src.contains("_advance_to(Beat.INVESTIGATE)                    # he sees him") and not lake_src.contains("Meet Logan [E]"))
	# 5. one world: no [E] arrivals
	check("the ridge and the auction road carry on by walking: no 'Finish lake visit [E]' / 'Ride to the auction [E]'", not lake_src.contains("Finish lake visit [E]")
		and not lake_src.contains("Ride to the auction [E]") and lake_src.contains("riding (or walking, when the horse is gone) past the signpost IS leaving"))
	# 6. Rich collects the shipment
	var river_src: String = _src("res://src/episode2/chamber/river_cover.gd")
	check("Rich is built at the dock, comes for gate 3, lifts the crate and carries it off", river_src.contains("func _build_rich") and river_src.contains("_rich_to_dock()")
		and river_src.contains("\"lift\"") and river_src.contains("\"carry\"") and not river_src.contains("Rich never comes"))
	check("the beat waits for him to finish collecting before it hands on", river_src.contains("rich_done"))
	check("the crate keeps the dock prop's size in his arms (no shrink on the lift)", not river_src.contains("RICH_CARRY_SCALE") and not river_src.contains("_crate.scale =")
		and river_src.contains("_carry_reach = _crate_carry_reach()"))
	check("Rich walks on the dock's deck, not 1.2 m under it (the crate he carries is above the boards)", river_src.contains("_rich.use_height = true")
		and river_src.contains("_rich.place(DOCK_DECK + RICH_START)"))
	check("Rich's dock line is recorded", Ep2TownVoiceBank.LINES.has("river_rich_dock") and Ep2TownVoiceBank.LINES["river_rich_dock"]["ready"])
	# 7. the auctioneer's voice id
	var cfg: Dictionary = JSON.parse_string(_src("res://assets/town-audio.json"))
	check("the auctioneer's voice is X0KF3ROqwE8cLCsWuhs6 in the town voice config", str(cfg["voices"]["renegade"]["voice_id"]) == "X0KF3ROqwE8cLCsWuhs6")
	check("every CALL of the auctioneer is recorded in his voice (touch-ups 2026-11-16)", Ep2AuctionHouse.CALLS.all(func(l: String) -> bool:
		var id: String = Ep2TownVoiceBank.id_for("renegade", l.trim_prefix("RENEGADE: "))
		return id != "" and bool(Ep2TownVoiceBank.LINES[id]["ready"]) and ResourceLoader.exists(str(Ep2TownVoiceBank.LINES[id]["path"]))))
	check("the auction house plays recorded takes for RENEGADE lines", _src("res://src/episode2/chamber/ep2_auction_house.gd").contains("Ep2TownVoiceBank.id_for(\"renegade\""))
	# 8. GM OG Smoke
	check("GM OG Smoke is packaged for the road and the road starts, ducks and fades it", ResourceLoader.exists(AuctionRoadChamber.ROAD_SONG)
		and _src("res://src/episode2/chamber/auction_road.gd").contains("AudioManager.crossfade_music(ROAD_SONG") and _src("res://src/episode2/chamber/auction_road.gd").contains("AudioManager.fade_out_music(SONG_FADE_OUT)")
		and _src("res://src/episode2/chamber/auction_road.gd").contains("AudioManager.duck_for_speech(seconds)"))
	print("EP2_FIX_PACK_1115: %s" % ("ALL PASS" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)
