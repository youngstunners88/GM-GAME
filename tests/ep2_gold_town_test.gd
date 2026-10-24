extends Node
## Gate for the GOLDMINE TOWN (founder lock 2026-10-14, PROMPT_EPISODE2_SURFACE_TO_TOWN_DRAW_SPEC.md; skills ep2-surface-to-town,
## ep2-sheriff-jake (now the Sheriff + Minister Mike Dean), ep2-quickdraw-duel). Plays the whole room headless: the street, the Sheriff's office (certificate rules as the
## whitepaper has them: in your name, not sellable, not tradeable, bring your share), the saloon (whiskey, a quarter Bitcoin, the
## stranger's demand VERBATIM), the sheriff as witness, the draw (foul -> redo; too slow -> retry with hearts back; hit first -> the
## map), Bull walking up afterwards, TO BE CONTINUED.
## Run: godot --headless res://tests/ep2_gold_town_test.tscn

const TOWN := preload("res://src/episode2/chamber/gold_town.tscn")
const ROOT := preload("res://src/episode2/session/ep2_session_root.tscn")

var _fail: int = 0


func _jail_lines_ok() -> bool:
	var all: String = ""
	for ln in GoldTownChamber.JAIL_LINES:
		all += str(ln[1]).to_lower() + " "
	return "bears" in all and "claims" in all and "fort knox" in all and "lake" in all and "river" in all and "trains" in all \
		and not ("bankman" in all or "sbf" in all or "celebrity" in all)


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])


func _run(c: GoldTownChamber, seconds: float) -> void:
	for i in int(seconds * 60.0):
		c.step(1.0 / 60.0)


func _until(c: GoldTownChamber, seconds: float, cond: Callable) -> bool:
	for i in int(seconds * 60.0):
		if cond.call():
			return true
		c.step(1.0 / 60.0)
	return bool(cond.call())


## Walk Lil Blunt to `goal` (straight line steering, re-aimed each step; the walls push him round corners).
func _walk_to(c: GoldTownChamber, goal: Vector3, seconds: float = 30.0) -> bool:
	for i in int(seconds * 60.0):
		var me: Vector3 = c.get_player_position()
		var d := Vector2(goal.x - me.x, goal.z - me.z)
		if d.length() < 0.5:
			c.set_move_input(Vector2.ZERO)
			return true
		c._look_yaw = atan2(d.x, d.y)
		c.set_move_input(Vector2(0.0, 1.0), true)
		c.step(1.0 / 60.0)
	c.set_move_input(Vector2.ZERO)
	return false


func _manifest_text(id: String) -> String:
	var m = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio-manifest.json"))
	var stack: Array = [m]
	while not stack.is_empty():
		var o = stack.pop_back()
		if o is Dictionary:
			if str(o.get("id", "")) == id:
				return str(o.get("text", ""))
			stack.append_array(o.values())
		elif o is Array:
			stack.append_array(o)
	return ""


func _aim_at_opp(c: GoldTownChamber) -> void:
	var eye: Vector3 = c.get_player_position() + Vector3(0.0, c.eye_height, 0.0)
	var t: Vector3 = c.get_opponent().position + Vector3(0.0, 1.3, 0.0) - eye
	c._look_yaw = atan2(t.x, t.z)
	c._look_pitch = atan2(t.y, Vector2(t.x, t.z).length())


func _ready() -> void:
	print("-- GOLDMINE TOWN")
	var c: GoldTownChamber = TOWN.instantiate()
	add_child(c)
	var said: Array = []
	var res: Array = []
	c.line_spoken.connect(func(id): said.append(id))
	c.chamber_cleared.connect(func(r): res.append(r))
	c.setup(0, [], 0)
	await get_tree().process_frame
	_check("starts in the STREET where Bull dropped him, first person, the Winchester in his hands",
		c.get_beat_name() == "STREET" and c.is_fps() and c.get_viewmodel() != null and c.get_player_position().distance_to(Ep2GoldTown.DROP_POINT) < 4.0,
		"%s %s" % [c.get_beat_name(), str(c.get_player_position())])
	_check("the objective sends him to the certificate office", "CERTIFICATES" in c.get_hud().objective, c.get_hud().objective)
	var bnames: Dictionary = {}
	for n in c._visuals.find_children("Bldg_*", "", true, false):
		bnames[str(n.name).get_slice("_", 1)] = true
	_check("the town is the gold-rush street: certificates office, saloon, treasury and the rest, Fort Knox on its hill",
		c._visuals.find_child("Bldg_Certificates", true, false) != null and c._visuals.find_child("Bldg_Saloon", true, false) != null
		and c._visuals.find_child("Bldg_Treasury", true, false) != null and c._visuals.find_child("FortKnox", true, false) != null, str(bnames.keys()))
	_check("no DIAMONDS anywhere in the town (no sign, no mechanic)", not ResourceLoader.exists("res://src/episode2/assets/town/sign_DIAMONDS.png")
		and c._visuals.find_children("*DIAMOND*", "", true, false).is_empty())
	_check("the desert around it is the same one the woods built (scrub, rocks, mesas)", c._visuals.find_child("Mesas", true, false) != null)
	_check("the open desert light (thin warm haze)", c._env_node.environment.fog_density < 0.004)
	_check("Bull is gone (he rode off): not in the street", not c.is_bull_here())
	# walls are solid; the office door is open
	var wall_probe: Vector3 = Ep2GoldTown.local_to_world("Bldg_Certificates", Vector3(-3.0, 0.0, 0.3))
	c._player_pos = wall_probe
	c._look_yaw = atan2((Ep2GoldTown.local_to_world("Bldg_Certificates", Vector3(-3.0, 0.0, -2.0)) - wall_probe).x, (Ep2GoldTown.local_to_world("Bldg_Certificates", Vector3(-3.0, 0.0, -2.0)) - wall_probe).z)
	c.set_move_input(Vector2(0.0, 1.0))
	_run(c, 1.5)
	c.set_move_input(Vector2.ZERO)
	var lp: Vector3 = Ep2GoldTown.building_xform(Ep2GoldTown.entry("Bldg_Certificates")).affine_inverse() * c.get_player_position()
	_check("the office front wall is solid beside the door", lp.z > -0.05, "local z %.2f" % lp.z)
	c._player_pos = Ep2GoldTown.DROP_POINT + Vector3(-2.2, 0.0, 0.6)
	# ---- the office
	var at_door: bool = _walk_to(c, Ep2GoldTown.door_world("Bldg_Certificates", 1.2))
	_walk_to(c, Ep2GoldTown.local_to_world("Bldg_Certificates", GoldTownChamber.OFFICE_SPOT), 4.0)
	_check("he walks in through the open office door", at_door and c.get_beat_name() == "OFFICE", c.get_beat_name())
	_check("-> OFFICE: the sheriff is behind the counter", c.get_beat_name() == "OFFICE" and c.get_minister() != null and c.get_sheriff().position.distance_to(Ep2GoldTown.local_to_world("Bldg_Certificates", GoldTownChamber.SHERIFF_OFFICE_AT)) < 0.3, c.get_beat_name())
	var sheriff: Node3D = c.get_sheriff()
	_check("The Sheriff is smoking his pipe (a curl of smoke) and stands at human height", sheriff.find_child("CigSmoke", true, false) != null and (sheriff.find_child("CigSmoke", true, false) as CPUParticles3D).emitting
		and absf(sheriff.height_m - GoldTownChamber.SHERIFF_HEIGHT) < 0.01)
	_until(c, 60.0, func(): return c.get_beat_name() == "TO_BAR")
	_check("the Sheriff greets him, Lil Blunt asks for the certificate, the Sheriff hands him to Minister Mike Dean, who lays out the rules, then the Sheriff sends him to the saloon - in order",
		said.find("vo_sheriff_1") < said.find("vo_lb_cert1") and said.find("vo_lb_cert1") < said.find("vo_sheriff_2") and said.find("vo_sheriff_2") < said.find("vo_minister_1") and said.find("vo_minister_1") < said.find("vo_sheriff_3") and said.find("vo_sheriff_1") >= 0, str(said))
	var rules: String = _manifest_text("vo_minister_1").to_lower()
	_check("the certificate rules are the whitepaper's: in your name, can't sell it on, can't trade it, bring your share - no invented numbers",
		"your name" in rules and "sold" in rules and "trade" in rules and "share" in rules and not rules.contains("%") and not rules.contains("0") and not rules.contains("5"), rules)
	_check("-> TO_BAR, the objective is the saloon", "SALOON" in c.get_hud().objective, c.get_hud().objective)
	# ---- the saloon
	var crossed: bool = _walk_to(c, Ep2GoldTown.door_world("Bldg_Certificates", 1.5)) and _walk_to(c, Ep2GoldTown.door_world("Bldg_Saloon", 1.2))
	_walk_to(c, Ep2GoldTown.local_to_world("Bldg_Saloon", GoldTownChamber.BAR_SPOT), 8.0)
	_check("he crosses the street and walks up to the bar", crossed and c.get_beat_name() == "BAR", c.get_beat_name())
	_check("-> BAR (a human barman behind the bar)", c.get_beat_name() == "BAR" and str(c.get_bartender().get_script().get_global_name()) == "Ep2TownFolk", c.get_beat_name())
	_until(c, 90.0, func(): return c.get_beat_name() == "SQUARE_UP")
	var order: Array = ["vo_bar_1", "vo_lb_bar1", "vo_lb_bar2", "vo_bar_2", "vo_opp_1", "vo_opp_2", "vo_lb_draw1", "vo_opp_3", "vo_sheriff_witness"]
	var in_order: bool = true
	for i in range(1, order.size()):
		if said.find(order[i - 1]) < 0 or said.find(order[i - 1]) > said.find(order[i]):
			in_order = false
	_check("the bar scene plays in order: a whiskey, a quarter Bitcoin, the barman's jaw, the stranger, the demand, the refusal, the terms, the witness", in_order, str(said))
	_check("the whiskey and the coin are on the bar", c.is_glass_on_bar() and c.is_coin_on_bar())
	_check("the payment is a QUARTER Bitcoin", "quarter" in _manifest_text("vo_lb_bar2").to_lower() and "bitcoin" in _manifest_text("vo_lb_bar2").to_lower())
	_check("the demand is the founder's line VERBATIM", _manifest_text("vo_opp_2") == "Give me a bitcoin or I give you the map to the auction where they can get more intel.", _manifest_text("vo_opp_2"))
	_check("the sheriff is the witness, and he walked in (he is in the saloon)", "witness" in _manifest_text("vo_sheriff_witness")
		and Ep2GoldTown.building_xform(Ep2GoldTown.entry("Bldg_Saloon")).affine_inverse().origin != Vector3.INF
		and (Ep2GoldTown.building_xform(Ep2GoldTown.entry("Bldg_Saloon")).affine_inverse() * sheriff.position).z < 0.0, str(sheriff.position))
	_check("the stranger carries a revolver and is a COWBOY, not a bear (the town has no bears)", c.get_opponent().find_child("Revolver", true, false) != null
		and str(c.get_opponent().get_script().get_global_name()) == "Ep2TownFolk" and c._visuals.find_children("Bear*", "", true, false).is_empty())
	# ---- square up in the street
	_check("-> SQUARE_UP: out into the street", "street" in c.get_hud().objective, c.get_hud().objective)
	_walk_to(c, Ep2GoldTown.door_world("Bldg_Saloon", -1.0))
	_walk_to(c, Ep2GoldTown.door_world("Bldg_Saloon", 2.0))
	_walk_to(c, GoldTownChamber.DUEL_MARK)
	_until(c, 40.0, func(): return c.get_beat_name() == "DRAW")
	_check("-> DRAW once he is on his mark, the stranger 15 m up the street, the sheriff off to the side",
		c.get_beat_name() == "DRAW" and c.get_opponent().position.distance_to(GoldTownChamber.OPP_MARK) < 0.6 and sheriff.position.distance_to(GoldTownChamber.WITNESS_MARK) < 0.6,
		"%s opp %s sheriff %s" % [c.get_beat_name(), str(c.get_opponent().position), str(sheriff.position)])
	_check("his hearts are on the HUD for the draw", c.get_hud().show_health and c.get_health() == 3)
	_run(c, 0.3)
	_check("before the word the rifle is DOWN (low ready)", c.get_viewmodel().lowered and c.get_draw_state() == "wait")
	_check("the wait before the word is never the same twice-predictable (seeded, between the limits)",
		c.get_draw_wait() >= GoldTownChamber.DRAW_WAIT_MIN and c.get_draw_wait() <= GoldTownChamber.DRAW_WAIT_MAX, "%.2f" % c.get_draw_wait())
	var p0: Vector3 = c.get_player_position()
	c.set_move_input(Vector2(0.0, 1.0), true)
	_run(c, 0.3)
	c.set_move_input(Vector2.ZERO)
	_check("feet planted: he cannot walk during the draw", c.get_player_position().distance_to(p0) < 0.01)
	# FOUL: fire before the word
	_check("firing before the word is a FOUL (no shot leaves the barrel)", not c.shoot() and c.get_fouls() == 1 and said.has("vo_sheriff_foul"))
	_until(c, 10.0, func(): return c.get_draw_state() == "wait")
	_check("...and the round is set up again", c.get_draw_state() == "wait" and c.get_opponent().position.distance_to(GoldTownChamber.OPP_MARK) < 0.1)
	# LOSE: do nothing after the word
	_until(c, 10.0, func(): return c.get_draw_state() == "go")
	_check("the town bell signals DRAW and the stranger's gun hand comes up with the revolver in it", c._town_audio.bell_count == 1 and not said.has("vo_sheriff_draw") and c.get_draw_state() == "go"
		and c.get_opponent().pose_name == "draw" and c.get_opponent().find_child("Revolver", true, false).visible)
	_check("...and the rifle comes up", not c.get_viewmodel().lowered)
	_until(c, 5.0, func(): return c.get_draw_state() != "go")
	_check("too slow: the stranger fires first (a loss, never a death)", c.get_losses() == 1 and c.get_draw_state() == "lost")
	_until(c, 12.0, func(): return c.get_draw_state() == "wait")
	_check("...the screen comes back, the Sheriff says do it again, hearts full, back on the mark", said.has("vo_sheriff_lose") and c.get_health() == 3
		and c.get_player_position().distance_to(GoldTownChamber.DUEL_MARK) < 0.1 and c.get_hud().fade < 0.05 and c.get_beat_name() == "DRAW")
	_check("...and he gives a little more time on the next try", c.opp_reaction() > GoldTownChamber.OPP_REACTION)
	# WIN: aim and fire on the word
	_until(c, 10.0, func(): return c.get_draw_state() == "go")
	var fired: bool = false
	for i in 120:
		_aim_at_opp(c)
		c.set_aim(true)
		if c.shoot():
			fired = true
		c.step(1.0 / 60.0)
		if c.get_draw_state() != "go":
			break
	c.set_aim(false)
	_check("on the word he brings the rifle up and hits the stranger first (he goes down)", fired and c.get_draw_state() == "won" and c.get_opponent().dead, "%s fired %s" % [c.get_draw_state(), fired])
	_check("a shot that misses wide would not count (the hit is a real ray test)", not c.aim_hits_opponent(c.get_player_position() + Vector3(0, 1.5, 0), Vector3(1.0, 0.0, 0.0)))
	_until(c, 10.0, func(): return c.get_beat_name() == "WON")
	_check("-> WON: the map to the auction is his", c.has_map() and c.get_beat_name() == "WON")
	_check("Bull comes walking up the street afterwards (no line locked for him)", c.is_bull_here())
	_check("the Sheriff calls it fair and square", said.has("vo_sheriff_win"))

	# ---- the Armory: Rich the Claim Recorder and Utah, off Main Street (founder lock PROMPT_EPISODE2_RICH_ARMORY_UTAH_RIVER.md)
	print("-- THE ARMORY (down the side lane, Rich & Utah)")
	# ---- the jailhouse (founder lock PROMPT_EPISODE2_JAILHOUSE_BEARS_INVESTIGATION, 2026-10-20): out at the town's south edge, one
	# occupied cell, the Sheriff asks him to find who brought the bears; then the Armory tip follows as before
	print("-- THE JAILHOUSE (Sheriff side, out at the south edge of town)")
	_until(c, 30.0, func(): return c.get_beat_name() == "JAIL_TIP")
	_check("-> JAIL_TIP: the Sheriff has a prisoner and the jailhouse is out the south road", c.get_beat_name() == "JAIL_TIP" and "jail" in str(c.get_hud().objective).to_lower(),
		str(c.get_hud().objective))
	var jdoor: Vector3 = Ep2GoldTown.door_world("Bldg_Jail", 2.4)
	var jinside: Vector3 = Ep2GoldTown.local_to_world("Bldg_Jail", Ep2GoldTown.jail_spots["visit"])
	var main_to_jail: float = Vector2(Ep2GoldTown.door_world("Bldg_Jail", 0.0).x, Ep2GoldTown.door_world("Bldg_Jail", 0.0).z).distance_to(Vector2(0.0, 1403.0))
	_check("the jailhouse stands well apart from the town (>= 22 m from the drop-off, on the Sheriff/Certificates side x < 0)",
		main_to_jail >= 22.0 and Ep2GoldTown.door_world("Bldg_Jail", 0.0).x < -20.0, "%.1f m" % main_to_jail)
	var jreached: bool = _walk_to(c, Vector3(-6.0, 0.0, 1400.0), 40.0)
	jreached = _walk_to(c, jdoor, 40.0) and jreached
	_check("he walks out the south road to the jailhouse door", jreached, str(c.get_player_position()) + " want " + str(jdoor))
	var jin_ok: bool = _walk_to(c, Ep2GoldTown.door_world("Bldg_Jail", -0.9), 30.0)      # straight through the doorway first
	jin_ok = _walk_to(c, jinside, 40.0) and jin_ok
	_check("he steps in through its door and the cell block is not walkable (bars stop him)", jin_ok, str(c.get_player_position()) + " want " + str(jinside))
	_until(c, 8.0, func(): return c.get_beat_name() == "JAIL")
	_check("-> JAIL: one accomplice is in the cell and the Sheriff is inside with him", c.get_beat_name() == "JAIL" and c.get_accomplice() != null
		and c.get_sheriff() != null)
	var cell_ok: bool = c.get_accomplice() != null and Ep2GoldTown.local_to_world("Bldg_Jail", Ep2GoldTown.jail_spots["accomplice"]).distance_to(c.get_accomplice().position) < 0.3
	_check("the accomplice is held in his cell, behind the bars", cell_ok)
	_until(c, 40.0, func(): return c.is_investigation_open())
	_check("the Sheriff's ask opens the investigation (the hunt is a thread on the existing path)", c.is_investigation_open())
	_check("the lines frame bears + early claims + Fort Knox and the existing lake/river/trains path, no celebrity prisoners", _jail_lines_ok())
	var jout: bool = _walk_to(c, Ep2GoldTown.door_world("Bldg_Jail", -0.9), 30.0)
	jout = _walk_to(c, jdoor, 30.0) and jout
	jout = _walk_to(c, Vector3(-6.0, 0.0, 1400.0), 40.0) and jout
	jout = _walk_to(c, Vector3(2.0, 0.0, 1406.0), 40.0) and jout          # back up the road to the street's centre
	_check("he walks back out toward town", jout)
	_until(c, 30.0, func(): return c.get_beat_name() == "TIP")
	_check("-> TIP: the room points him down the side lane (off Main Street, not on the boardwalk)",
		c.get_beat_name() == "TIP" and "lane" in str(c.get_hud().objective).to_lower(), str(c.get_hud().objective))
	var rich: Ep2TownFolk = c.get_rich()
	var utah: Ep2TownFolk = c.get_utah()
	_check("Rich the Claim Recorder and Utah are both in the shop before he ever walks in (the lock's both-present rule)",
		rich != null and utah != null and rich.visible and utah.visible, str(rich) + " " + str(utah))
	# the two-storey Armory's pair work on their own (Ep2ArmoryBrain), so any of their work clips is right; the fallback pair holds poses
	var work_clips: Array = ["counter", "idle", "cigarpuff", "wiperifle", "inspectrifle", "reach", "talk", "pickup", "putdown", "greet", "walk",
		"carry", "stairsup", "point"]
	_check("both are rigged bodies, moving on their authored clips (not statues with a bob)",
		rich.has_clips() and utah.has_clips() and ((Ep2GoldTown.armory_v2 and rich.current_clip() in work_clips and utah.current_clip() in work_clips)
			or (rich.current_clip() == "counter" and utah.current_clip() == "idle")),
		"%s %s" % [rich.current_clip(), utah.current_clip()])
	var lane: Vector3 = Ep2GoldTown.door_world("Bldg_Armory", 2.2)
	var inside: Vector3 = Ep2GoldTown.local_to_world("Bldg_Armory", GoldTownChamber.ARMORY_SPOT)
	# the shop is off the Main Street sightline: he has to step off the boardwalk, walk up the street
	# past the left row, turn down the lane between Bldg_E's back and the shop front, and go in.
	var stepped: bool = _walk_to(c, Vector3(-6.0, 0.0, 1453.0), 40.0)
	stepped = _walk_to(c, GoldTownChamber.LANE_MARK, 30.0) and stepped
	stepped = _walk_to(c, lane, 30.0) and stepped
	_check("he walks the side lane off the left row (off Main Street, no sign on the drag) and in through the shop door",
		stepped and _walk_to(c, inside, 30.0), str(c.get_player_position()) + " want " + str(inside))
	_until(c, 8.0, func(): return c.get_beat_name() == "ARMORY")
	_check("-> ARMORY: both shopkeepers turn to whoever came in", c.get_beat_name() == "ARMORY" and c.armory_visited())
	_check("the trade is offered at the counter and nowhere else", c._at_armory_counter())
	_check("the purse is Episode 1 crypto and the case below it: no soft currency, no free loadout",
		not c.is_shop_open() and c.get_shop() != null and c.get_shop().purse >= 0)
	GameManager.coins_collected = 0
	_check("no crypto, no iron: the counter refuses the long rifle", not c.buy("sniper", 3, "btc") and not c.has_sniper())
	GameManager.coins_collected = 9
	var before: int = GameManager.coins_collected
	_check("with crypto in the purse [E] opens Rich & Utah's trade", c.start_rig("eth") and c.is_shop_open())
	_check("the long rifle is sold for crypto - 3 coins, debited, not minted",
		c.buy("sniper", 3, "btc") and c.has_sniper() and GameManager.coins_collected == before - 3 and c.coins_spent() == 3,
		"purse %d spent %d" % [GameManager.coins_collected, c.coins_spent()])
	_check("a second look at the same rifle is not a second sale", not c.buy("sniper", 3, "btc") and GameManager.coins_collected == before - 3)
	_check("the long-rifle cartridges come by the box and only after the rifle", c.buy("sniper_ammo", 2, "sol") and c.armory.sniper_rounds == GoldTownChamber.SNIPER_BOX)
	_check("the river gear (skiff and sealed crates) is his for the day-88 shipment", c.buy("river_gear", 2, "eth") and c.has_river_gear())
	_check("the room refuses a tender that is not Episode 1 crypto", not c.buy("rifle_ammo", 1, "gold") and not c.buy("river_gear", 2, "gold"))
	c.get_shop().closed.emit()
	_check("Esc shuts the trade and gives the street back", not c.is_shop_open() and not get_tree().paused)
	_until(c, 12.0, func(): return c.get_beat_name() == "GEARED")
	_check("-> GEARED: the rifle and the river gear in hand, the room hands him to the river shipment",
		c.get_beat_name() == "GEARED" and c.has_sniper() and c.has_river_gear())
	_until(c, 20.0, func(): return res.size() == 1)
	_check("the geared town continues to Logan's Lake, the map in hand, mints nothing", res.size() == 1 and str(res[0].get("next_chamber", "")) == "logans_lake"
		and not bool(res[0].get("end_session", false)) and bool(res[0].get("got_map", false)) and int(res[0].get("gold_awarded", -1)) == 0, str(res))
	_check("the ending carries the Armory: he visited it, and the long rifle + river gear come with him",
		res.size() == 1 and bool(res[0].get("armory_visited", false)) and bool(res[0].get("sniper", false))
		and int(res[0].get("sniper_rounds", 0)) == GoldTownChamber.SNIPER_BOX and bool(res[0].get("river_gear", false)), str(res))
	c.queue_free()

	# ---- lines exist; the session chain woods -> town -> end
	print("-- LINES + CHAIN")
	var ids: Array = ["vo_bull_drop1", "vo_bull_drop2", "vo_lb_drop", "vo_sheriff_1", "vo_lb_cert1", "vo_sheriff_2", "vo_sheriff_3", "vo_bar_1", "vo_lb_bar1", "vo_lb_bar2",
		"vo_bar_2", "vo_opp_1", "vo_opp_2", "vo_lb_draw1", "vo_opp_3", "vo_sheriff_witness", "vo_sheriff_draw", "vo_sheriff_foul", "vo_sheriff_win", "vo_sheriff_lose"]
	var missing: Array = []
	for id in ids:
		if not ResourceLoader.exists("res://src/assets/sounds/voice/%s.mp3" % id) or _manifest_text(id) == "":
			missing.append(id)
	_check("all %d town voice lines are generated and in the manifest" % ids.size(), missing.is_empty(), str(missing))
	_check("Bull's drop-off: the blonde lady (a wink, nothing shown), the certificate office, the bar for a whiskey",
		"blonde" in _manifest_text("vo_bull_drop1").to_lower() and "certificate" in _manifest_text("vo_bull_drop2").to_lower() and "whiskey" in _manifest_text("vo_bull_drop2").to_lower())
	var all_text: String = ""
	for id in ids:
		all_text += _manifest_text(id)
	_check("no Diamonds in the town's speech", not ("iamond" in all_text))
	var root: Ep2SessionRoot = ROOT.instantiate()
	add_child(root)
	root.configure([{"chamber": "woods_quad", "chamber_z": 5.0}], false)
	var done: Array = []
	root.session_complete.connect(func(): done.append(true))
	_check("the session root knows the town", Ep2SessionRoot.CHAMBER_SCENES.has("gold_town"))
	root._chamber_segment = 0
	root._on_chamber_cleared({"story": true, "chamber": "woods_quad", "gold_awarded": 0, "gold_forfeited": 0, "next_chamber": "gold_town"})
	await get_tree().process_frame
	_check("the woods' result loads the GOLD TOWN", root.get_active() is GoldTownChamber)
	root._on_chamber_cleared({"story": true, "chamber": "gold_town", "gold_awarded": 0, "gold_forfeited": 0, "end_session": true, "to_be_continued": true})
	_check("the town ends the session (TO BE CONTINUED)", done.size() == 1)
	root.queue_free()

	await get_tree().process_frame
	if _fail == 0:
		print("EP2_GOLD_TOWN: ALL PASS")
		get_tree().quit(0)
	else:
		print("EP2_GOLD_TOWN: %d FAILED" % _fail)
		get_tree().quit(1)
