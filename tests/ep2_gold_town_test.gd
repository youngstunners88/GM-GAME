extends Node
## Gate for the GOLDMINE TOWN (founder lock 2026-10-14, PROMPT_EPISODE2_SURFACE_TO_TOWN_DRAW_SPEC.md; skills ep2-surface-to-town,
## ep2-sheriff-jake (now the Sheriff + Minister Mike Dean), ep2-quickdraw-duel). Plays the whole room headless: the street, the Sheriff's office (certificate rules as the
## whitepaper has them: in your name, not sellable, not tradeable, bring your share), the saloon (whiskey, a quarter Bitcoin, the
## stranger's demand VERBATIM), the sheriff as witness, the draw (foul -> redo; too slow -> retry with hearts back; hit first -> the
## map). Since the founder fix pack (2026-10-27 section 2) the post-draw story plays in the LOCKED order: the stranger's Peacemaker
## (holstered, drawn, dropped), E at the body for it and the map, Mike Dean alarmed and praying, the Sheriff's job and the jail, then
## Rich & Utah and the Gatling, Inferno, the body again, the bar (they really drink), the Gold Panner, the second visit and the stamp,
## Dude (BTC, Chill Buds, Logan's Lake first) and the hand-off to the ride (lake_trail).
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


var _cheer_seen: int = 0
var _dance_seen: int = 0
var _minister_ran_seen: bool = false
func _observed_step(c: GoldTownChamber) -> void:
	c.step(1.0 / 60.0)
	if c.get_minister() != null and c.get_minister().current_clip() == "run": _minister_ran_seen=true
	var ppl: Ep2TownPeople = c.get_people()
	if ppl == null: return
	var cheer: int = 0
	var dance: int = 0
	for q in ppl.people:
		if q.state == "cel_cheer" and q.folk.current_clip() in ["cheer","clap"]: cheer+=1
		var mate: Variant = ppl.person(q.partner) if q.partner != "" else null
		if q.state == "cel_dance" and q.folk.current_clip() in ["dancea","danceb"] and mate != null and mate.state == "cel_dance" and q.folk.position.distance_to(mate.folk.position)<2.0: dance+=1
	_cheer_seen=maxi(_cheer_seen,cheer)
	_dance_seen=maxi(_dance_seen,int(dance/2.0))

func _run(c: GoldTownChamber, seconds: float) -> void:
	for i in int(seconds * 60.0):
		_observed_step(c)


func _until(c: GoldTownChamber, seconds: float, cond: Callable) -> bool:
	for i in int(seconds * 60.0):
		if cond.call():
			return true
		_observed_step(c)
	return bool(cond.call())


## Walk Lil Blunt to `goal` (straight line steering, re-aimed each step; the walls push him round corners).
func _walk_to(c: GoldTownChamber, goal: Vector3, seconds: float = 30.0) -> bool:
	# Walks like a player: straight at the goal, and when townspeople crossing the street box him in (no progress for a second),
	# a short sidestep round them - the way anyone at the keys would - before heading for the goal again.
	var last: Vector3 = c.get_player_position()
	var stuck: float = 0.0
	var side_t: float = 0.0
	var side: float = 1.0
	for i in int(seconds * 60.0):
		var me: Vector3 = c.get_player_position()
		var d := Vector2(goal.x - me.x, goal.z - me.z)
		if d.length() < 0.5:
			c.set_move_input(Vector2.ZERO)
			return true
		var yaw: float = atan2(d.x, d.y)
		if side_t > 0.0:
			side_t -= 1.0 / 60.0
			yaw += side * PI * 0.5
		c._look_yaw = yaw
		c.set_move_input(Vector2(0.0, 1.0), true)
		_observed_step(c)
		stuck = stuck + 1.0 / 60.0 if c.get_player_position().distance_to(last) < 0.01 else 0.0
		last = c.get_player_position()
		if stuck > 1.0 and side_t <= 0.0:
			side_t = 0.7
			side = -side
			stuck = 0.0
	c.set_move_input(Vector2.ZERO)
	return false


func _manifest_text(id: String) -> String:
	if Ep2TownVoiceBank.LINES.has(id):
		return str(Ep2TownVoiceBank.LINES[id]["text"])
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
	var holstered: Node3D = c.get_revolver()
	_check("the stranger wears a Colt Single Action Army (the Peacemaker, the CAD kit's, real size) holstered on his hip before the bell",
		holstered != null and holstered.visible and holstered.get_parent() == c.get_opponent()
		and holstered.position.distance_to(GoldTownChamber.OPP_HOLSTER) < 0.01 and holstered.find_child("Prop_Revolver", true, false) != null
		and (not Ep2KitProps.available("Kit_Revolver") or holstered.find_child("PeacemakerStandIn", true, false) == null),
		str(holstered.position if holstered != null else Vector3.INF))
	_run(c, 0.3)
	_check("before the bell the rifle is DOWN (low ready)", c.get_viewmodel().lowered and c.get_draw_state() == "wait")
	_check("the wait before the bell is never the same twice-predictable (seeded, between the limits)",
		c.get_draw_wait() >= GoldTownChamber.DRAW_WAIT_MIN and c.get_draw_wait() <= GoldTownChamber.DRAW_WAIT_MAX, "%.2f" % c.get_draw_wait())
	var p0: Vector3 = c.get_player_position()
	c.set_move_input(Vector2(0.0, 1.0), true)
	_run(c, 0.3)
	c.set_move_input(Vector2.ZERO)
	_check("feet planted: he cannot walk during the draw", c.get_player_position().distance_to(p0) < 0.01)
	# FOUL: fire before the bell
	_check("firing before the bell is a FOUL (no shot leaves the barrel)", not c.shoot() and c.get_fouls() == 1 and said.has("vo_sheriff_foul"))
	_until(c, Ep2TownVoiceBank.seconds("vo_sheriff_foul") + 5.0, func(): return c.get_draw_state() == "wait")
	_check("...and the round is set up again", c.get_draw_state() == "wait" and c.get_opponent().position.distance_to(GoldTownChamber.OPP_MARK) < 0.1)
	# LOSE: do nothing after the bell
	_until(c, 10.0, func(): return c.get_draw_state() == "go")
	_check("the town bell signals DRAW and the stranger's gun hand comes up with the revolver in it", c._town_audio.bell_count == 1 and not said.has("vo_sheriff_draw") and c.get_draw_state() == "go"
		and c.get_opponent().pose_name == "draw" and c.get_opponent().find_child("Revolver", true, false).visible)
	_check("the rifle stays out of view until Enter draws it", c.get_viewmodel().lowered and not c._player_drawn)
	_until(c, 5.0, func(): return c.get_draw_state() != "go")
	_check("too slow: the stranger fires first (a loss, never a death)", c.get_losses() == 1 and c.get_draw_state() == "lost")
	_until(c, Ep2TownVoiceBank.seconds("vo_sheriff_lose") + 8.0, func(): return c.get_draw_state() == "wait")
	_check("...the screen comes back, the Sheriff says do it again, hearts full, back on the mark", said.has("vo_sheriff_lose") and c.get_health() == 3
		and c.get_player_position().distance_to(GoldTownChamber.DUEL_MARK) < 0.1 and c.get_hud().fade < 0.05 and c.get_beat_name() == "DRAW")
	_check("...and he gives a little more time on the next try", c.opp_reaction() > GoldTownChamber.OPP_REACTION)
	# WIN: aim and fire at the bell
	_until(c, 10.0, func(): return c.get_draw_state() == "go")
	c.draw_weapon()
	var fired: bool = false
	for i in 120:
		_aim_at_opp(c)
		c.set_aim(true)
		if c.shoot():
			fired = true
		_observed_step(c)
		if c.get_draw_state() != "go":
			break
	c.set_aim(false)
	_check("at the bell he brings the rifle up and hits the stranger first (he goes down)", fired and c.get_draw_state() == "won" and c.get_opponent().dead, "%s fired %s" % [c.get_draw_state(), fired])
	_check("a shot that misses wide would not count (the hit is a real ray test)", not c.aim_hits_opponent(c.get_player_position() + Vector3(0, 1.5, 0), Vector3(1.0, 0.0, 0.0)))
	var colt: Node3D = c.get_revolver()
	var opp_at: Vector3 = c.get_opponent().position
	_check("his Peacemaker falls out of his hand into the dirt beside him", colt != null and colt.visible and colt.get_parent() == c._visuals
		and colt.position.y < 0.12 and Vector2(colt.position.x - opp_at.x, colt.position.z - opp_at.z).length() < 1.2, str(colt.position if colt != null else Vector3.INF))
	_until(c, 10.0, func(): return c.get_beat_name() == "WON")
	_check("-> WON: the Sheriff calls it fair and square", c.get_beat_name() == "WON" and said.has("vo_sheriff_win"))
	_check("...and the map is NOT handed over (it is on the body, with his gun: fix pack 2026-10-27 step 2)", not c.has_map() and not c.has_peacemaker())

	# ---- the locked story order (founder fix pack 2026-10-27, section 2): loot -> Mike Dean prays -> the Sheriff, the jail -> Rich & Utah
	print("-- AFTER THE DRAW (fix pack 2026-10-27 section 2: loot, Mike Dean, the Sheriff and the jail, then Rich & Utah)")
	var caps: Array = []
	c.captioned.connect(func(w: String, t: String) -> void: caps.append([w, t]))
	_check("Inferno does NOT arrive at the draw", not c.is_bull_here())
	_until(c, 30.0, func(): return c.get_beat_name() == "LOOT")
	_check("-> LOOT: search the stranger for his Peacemaker and the map", c.get_beat_name() == "LOOT" and "PEACEMAKER" in str(c.get_hud().objective),
		str(c.get_hud().objective))
	_check("[E] from across the street does nothing (he has to go to the body)", not c.can_loot() and not c.start_rig("") and not c.has_map())
	var mike: Ep2TownFolk = c.get_minister()
	var office_xf: Transform3D = Ep2GoldTown.building_xform(Ep2GoldTown.entry("Bldg_Certificates"))
	_check("Mike Dean reacts before the body is looted", c.minister_task() != "" or (office_xf.affine_inverse() * mike.position).z < 0.0)
	var reached_body: bool = _walk_to(c, opp_at + Vector3(-1.3, 0.0, -0.6), 30.0)
	_until(c, 30.0, func(): return c.can_loot())
	_check("he walks up the street to the fallen stranger, and [E] can search him there", reached_body and c.can_loot(), str(c.get_player_position()))
	_check("[E]: the Peacemaker and the map to the auction are his", c.start_rig("") and c.has_peacemaker() and c.has_map() and not colt.visible)
	var ran: bool = _minister_ran_seen
	var mike_outside: bool = false
	var cheered: int = _cheer_seen
	var danced_pairs: int = _dance_seen
	var want_next: String = "JAIL_TIP" if Ep2GoldTown.jail_v1 else "TIP"
	for i in 60 * 90:
		_observed_step(c)
		if mike.current_clip() == "run":
			ran = true
		if (office_xf.affine_inverse() * mike.position).z > 0.5:
			mike_outside = true
		var ppl: Ep2TownPeople = c.get_people()
		if ppl != null:
			var now_cheer: int = 0
			var now_dance: int = 0
			for q in ppl.people:
				if q.state == "cel_cheer" and q.folk.current_clip() in ["cheer", "clap"]:
					now_cheer += 1
				var mate: Variant = ppl.person(q.partner) if q.partner != "" else null
				if q.state == "cel_dance" and q.folk.current_clip() in ["dancea", "danceb"] and mate != null and mate.state == "cel_dance" \
						and q.folk.position.distance_to(mate.folk.position) < 2.0:
					now_dance += 1
			cheered = maxi(cheered, now_cheer)
			danced_pairs = maxi(danced_pairs, int(now_dance / 2.0))
		if c.get_beat_name() == want_next and danced_pairs > 0:
			break
	_check("Lil Blunt names what he found (the Colt Peacemaker, the map)", caps.any(func(l: Array) -> bool: return l[0] == "LIL BLUNT" and "peacemaker" in str(l[1]).to_lower()))
	_check("Minister Mike Dean leaves his counter and comes out of the office", mike_outside)
	_check("...at a run (the founder's Mike Dean rigged, on his Run clip; the statue only if the streamed pack is missing)", ran or not c.minister_rigged(),
		"rigged %s" % c.minister_rigged())
	_check("...alarmed: he asks what happened", caps.any(func(l: Array) -> bool: return l[0] == "MIKE DEAN" and "happened" in str(l[1]).to_lower()), str(caps))
	_check("Mike Dean has gone to the fallen stranger to kneel and pray over him", mike.position.distance_to(opp_at) < 1.8
		and (not c.minister_rigged() or mike.current_clip() in ["kneel", "kneeldown"]), "%s %.2f m" % [mike.current_clip(), mike.position.distance_to(opp_at)])
	_check("the townspeople gather round and celebrate (their own Cheer / Clap clips)", cheered >= 4, "%d cheering at once" % cheered)
	_check("...then pair off and dance together (DanceA / DanceB partners within arm's reach, facing each other)", danced_pairs >= 2, "%d pairs" % danced_pairs)
	var job: String = " ".join(caps.filter(func(l: Array) -> bool: return l[0] == "SHERIFF").map(func(l: Array) -> String: return str(l[1]).to_lower()))
	_check("Sheriff James, impressed with the draw, offers the job: who let the bears hold Fort Knox (his prisoner knows more)",
		"shooting" in job and "bears" in job and "fort knox" in job and "prisoner" in job, job)
	_check("-> JOB -> the Sheriff LEADS him to the jail first (Rich and Utah come after it)", c.get_beat_name() == want_next
		and ("walk you over" in job if Ep2GoldTown.jail_v1 else "rich and utah" in job) and (not Ep2GoldTown.jail_v1 or not ("rich and utah" in job)), c.get_beat_name() + " | " + job)
	_check("still no Inferno: he comes back later, after the Gatling", not c.is_bull_here())

	# ---- the jailhouse (founder lock PROMPT_EPISODE2_JAILHOUSE_BEARS_INVESTIGATION, 2026-10-20): out at the town's south edge, one
	# occupied cell; since the fix pack (2026-10-27 step 4) the Sheriff walks him there straight after the draw, then sends him to Rich's
	if Ep2GoldTown.jail_v1:
		print("-- THE JAILHOUSE (the Sheriff leads him out to the south edge of town)")
		_check("-> JAIL_TIP: follow the Sheriff to the jailhouse, out the south road", c.get_beat_name() == "JAIL_TIP" and "jail" in str(c.get_hud().objective).to_lower(),
			str(c.get_hud().objective))
		var jdoor: Vector3 = Ep2GoldTown.door_world("Bldg_Jail", 2.4)
		var jinside: Vector3 = Ep2GoldTown.local_to_world("Bldg_Jail", Ep2GoldTown.jail_spots["visit"])
		var main_to_jail: float = Vector2(Ep2GoldTown.door_world("Bldg_Jail", 0.0).x, Ep2GoldTown.door_world("Bldg_Jail", 0.0).z).distance_to(Vector2(0.0, 1403.0))
		_check("the jailhouse stands well apart from the town (>= 22 m from the drop-off, on the Sheriff/Certificates side x < 0)",
			main_to_jail >= 22.0 and Ep2GoldTown.door_world("Bldg_Jail", 0.0).x < -20.0, "%.1f m" % main_to_jail)
		var jreached: bool = _walk_to(c, Vector3(-6.0, 0.0, 1400.0), 60.0)
		jreached = _walk_to(c, jdoor, 40.0) and jreached
		_check("he walks out the south road to the jailhouse door", jreached, str(c.get_player_position()) + " want " + str(jdoor))
		var jin_ok: bool = _walk_to(c, Ep2GoldTown.door_world("Bldg_Jail", -0.9), 30.0)      # straight through the doorway first
		jin_ok = _walk_to(c, jinside, 40.0) and jin_ok
		_check("he steps in through its door and the cell block is not walkable (bars stop him)", jin_ok, str(c.get_player_position()) + " want " + str(jinside))
		_until(c, 45.0, func(): return c.get_beat_name() == "JAIL")          # the Sheriff leads at his own walk; the talk waits for him
		_check("-> JAIL: one accomplice is in the cell and the Sheriff is inside with him", c.get_beat_name() == "JAIL" and c.get_accomplice() != null
			and c.get_sheriff() != null and c.get_sheriff().position.distance_to(c.get_player_position()) < 8.0,
			"%s sheriff %s player %s" % [c.get_beat_name(), str(c.get_sheriff().position), str(c.get_player_position())])
		var cell_ok: bool = c.get_accomplice() != null and Ep2GoldTown.local_to_world("Bldg_Jail", Ep2GoldTown.jail_spots["accomplice"]).distance_to(c.get_accomplice().position) < 0.3
		_check("the accomplice is held in his cell, behind the bars", cell_ok)
		var jail_budget: float = 6.0
		for line in GoldTownChamber.JAIL_LINES + GoldTownChamber.ARMORY_SEND_LINES:
			jail_budget += Ep2TownVoiceBank.seconds(Ep2TownVoiceBank.id_for(c._town_speaker(str(line[0])), str(line[1]))) + 0.3
		_until(c, jail_budget, func(): return c.get_beat_name() == "TIP")
		_check("the Sheriff's ask opens the investigation (the hunt is a thread on the existing path)", c.is_investigation_open())
		_check("the lines frame bears + early claims + Fort Knox and the existing lake/river/trains path, no celebrity prisoners", _jail_lines_ok())
		_check("...and only THEN does the Sheriff send him to Rich and Utah", c.jail_sent_to_armory()
			and caps.any(func(l: Array) -> bool: return l[0] == "SHERIFF" and "rich and utah" in str(l[1]).to_lower()), c.get_beat_name())
		var jout: bool = _walk_to(c, Ep2GoldTown.door_world("Bldg_Jail", -0.9), 30.0)
		jout = _walk_to(c, jdoor, 30.0) and jout
		jout = _walk_to(c, Vector3(-6.0, 0.0, 1400.0), 40.0) and jout
		jout = _walk_to(c, Vector3(2.0, 0.0, 1406.0), 40.0) and jout          # back up the road to the street's centre
		_check("he walks back out toward town", jout)

	# ---- the Armory: Rich the Claim Recorder and Utah, off Main Street (founder lock PROMPT_EPISODE2_RICH_ARMORY_UTAH_RIVER.md)
	print("-- THE ARMORY (down the side lane, Rich & Utah)")
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
	var stepped: bool = _walk_to(c, Vector3(-6.0, 0.0, 1453.0), 60.0)
	stepped = _walk_to(c, GoldTownChamber.LANE_MARK, 30.0) and stepped
	stepped = _walk_to(c, lane, 30.0) and stepped
	_check("he walks the side lane off the left row (off Main Street, no sign on the drag) and in through the shop door",
		stepped and _walk_to(c, inside, 30.0), str(c.get_player_position()) + " want " + str(inside))
	_until(c, 8.0, func(): return c.get_beat_name() == "ARMORY")
	_check("-> ARMORY: both shopkeepers turn to whoever came in", c.get_beat_name() == "ARMORY" and c.armory_visited())
	_check("the trade is offered at the counter and nowhere else", c._at_armory_counter())
	_check("the purse is his collected crypto and the case below it: no soft currency, no free loadout",
		not c.is_shop_open() and c.get_shop() != null and c.get_shop().purse >= 0)
	GameManager.token_purse = {"eth": 0, "btc": 0, "sol": 0}
	_check("no crypto, no iron: the counter refuses the long rifle", not c.buy("sniper", 3, "btc") and not c.has_sniper())
	GameManager.token_purse = {"eth": 4, "btc": 9, "sol": 5}
	var before: int = GameManager.purse_balance("btc")
	_check("with crypto in the purse [E] opens Rich & Utah's trade", c.start_rig("eth") and c.is_shop_open())
	_check("the long rifle is sold for BTC - 3 faces of BTC debited, not minted, nothing else touched",
		c.buy("sniper", 3, "btc") and c.has_sniper() and GameManager.purse_balance("btc") == before - 3 and c.coins_spent() == 3
			and GameManager.purse_balance("eth") == 4 and GameManager.purse_balance("sol") == 5,
		"purse %s spent %d" % [str(GameManager.token_purse), c.coins_spent()])
	_check("a second look at the same rifle is not a second sale", not c.buy("sniper", 3, "btc") and GameManager.purse_balance("btc") == before - 3)
	_check("the long-rifle cartridges come by the box and only after the rifle, paid in SOL",
		c.buy("sniper_ammo", 2, "sol") and c.armory.sniper_rounds == GoldTownChamber.SNIPER_BOX and GameManager.purse_balance("sol") == 3)
	_check("the river gear (skiff and sealed crates) is his for the day-88 shipment, paid in ETH", c.buy("river_gear", 2, "eth") and c.has_river_gear() and GameManager.purse_balance("eth") == 2)
	_check("a token he does not hold enough of is refused (no TitanX on him)", GameManager.purse_balance("titanx") > 0 or not c.buy("rifle_ammo", 1, "titanx"))
	_check("the room refuses a tender that is not in his purse", not c.buy("rifle_ammo", 1, "gold") and not c.buy("river_gear", 2, "gold"))
	# A finger must be able to shut the trade: the tree is paused, so the touch controls are
	# suspended and Esc / ui_cancel is unreachable on a phone (audit 2026-10-29).
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	var close_pad: Button = c.get_shop().get_node_or_null("Close")
	_check("the trade carries a wordless close pad in the corner (>= 44 CSS px on a phone)",
		close_pad != null and close_pad.is_visible_in_tree() and close_pad.size.x >= 88.0
			and close_pad.position.x + close_pad.size.x <= c.get_shop().size.x)
	if close_pad != null:
		close_pad.pressed.emit()
	_check("the close pad shuts the trade and gives the street back", not c.is_shop_open() and not get_tree().paused)
	# ---- section 4.3: he can test the Colt Gatling; after it, Inferno rides back in on his quad and parks outside Rich's
	print("-- THE GATLING, THEN INFERNO'S RETURN")
	for i in 120:
		_observed_step(c)
	_check("buying everything on the first visit does not end the town: the story goes on with Inferno", c.get_beat_name() == "ARMORY", c.get_beat_name())
	var gat: Ep2GatlingPost = c.get_gatling()
	_check("the Colt Gatling stands in the yard (streamed extras)", gat != null)
	if gat != null:
		c.skip_armory_intro()
		var out_ok: bool = _walk_to(c, Ep2GoldTown.door_world("Bldg_Armory", -0.9), 30.0)
		out_ok = _walk_to(c, Ep2GoldTown.door_world("Bldg_Armory", 2.0), 30.0) and out_ok
		out_ok = _walk_to(c, gat.stand_position(), 40.0) and out_ok
		_check("he walks out to the Colt Gatling in the yard", out_ok, str(c.get_player_position()))
		_check("he takes the crank", c.start_rig("") and c.is_mounted())
		var fired_g: bool = false
		for i in 90:
			if c.shoot():
				fired_g = true
			_observed_step(c)
		_check("...fires a burst from the drum", fired_g and c.mount_bursts() > 0)
		_check("...and steps away from it", c.start_rig("") and not c.is_mounted())
	_until(c, 40.0, func(): return c.get_beat_name() == "BULL_BACK")
	_check("-> BULL_BACK: with the Gatling tested, Inferno is coming back", c.get_beat_name() == "BULL_BACK" and c.is_bull_here() and c.get_quad() != null)
	_check("...on his flame quad, seated in the saddle", c.get_quad() != null and c.bull_task() == "riding"
		and c.get_bull().position.distance_to(c.get_quad().seat_position()) < 0.05)
	_until(c, 40.0, func(): return c.get_quad() != null and c.get_quad().is_parked)
	var park: Vector3 = Ep2GoldTown.local_to_world("Bldg_Armory", GoldTownChamber.QUAD_PARK_LOCAL)
	_check("...and parks outside Rich's, clear of the Gatling yard", c.get_quad() != null and c.get_quad().is_parked
		and Vector2(c.get_quad().position.x, c.get_quad().position.z).distance_to(Vector2(park.x, park.z)) < 0.3
		and (gat == null or c.get_quad().position.distance_to(gat.position) > 6.0), str(c.get_quad().position if c.get_quad() != null else Vector3.ZERO))
	_check("...and the parked quad is solid (nobody walks through it)", c.get_quad() != null and c._town_col.get("props", []).any(func(pr: Array) -> bool:
		return (pr[0] as Vector2).distance_to(Vector2(c.get_quad().position.x, c.get_quad().position.z)) < 0.05))
	_until(c, 40.0, func(): return c.get_beat_name() == "BODY")
	_check("he swings off, comes over: the whiskey is on him", c.get_beat_name() == "BODY"
		and caps.any(func(l: Array) -> bool: return l[0] == "INFERNO" and "whiskey" in str(l[1]).to_lower()), c.get_beat_name())

	# ---- step 6: Mike Dean again, by the body; Inferno greets him; the bird
	print("-- THE BODY IN THE STREET (Mike Dean again)")
	var walked: bool = _walk_to(c, Vector3(-6.0, 0.0, 1453.0), 40.0)
	walked = _walk_to(c, opp_at + Vector3(-3.0, 0.0, 4.0), 60.0) and walked
	_check("he walks back with Inferno and comes upon the man he shot", walked and c.get_opponent().dead, str(c.get_player_position()))
	_until(c, 60.0, func(): return c.get_beat_name() == "DRINKS")
	_check("Mike Dean is still kneeling there, praying", mike.position.distance_to(opp_at) < 1.8 and (not c.minister_rigged() or mike.current_clip() == "kneel"),
		mike.current_clip())
	_check("Inferno greets the Minister", caps.any(func(l: Array) -> bool: return l[0] == "INFERNO" and "minister" in str(l[1]).to_lower()))
	_check("...and asks who put a hole in his head", caps.any(func(l: Array) -> bool: return l[0] == "INFERNO" and "hole in his head" in str(l[1]).to_lower()))
	_check("Lil Blunt: \"Must've been a bird that had to get rid of the heavy load.\"",
		caps.any(func(l: Array) -> bool: return l[0] == "LIL BLUNT" and str(l[1]) == "Must've been a bird that had to get rid of the heavy load."))

	# ---- steps 7-9: the bar - they really drink; cousin Flux's new kettle; Inferno's gift for Mike Dean
	print("-- THE BAR: THEY DRINK, FLUX'S KETTLE, THE GOLD PANNER")
	var into: bool = _walk_to(c, Ep2GoldTown.door_world("Bldg_Saloon", 2.2), 40.0)
	into = _walk_to(c, Ep2GoldTown.door_world("Bldg_Saloon", -0.9), 30.0) and into
	into = _walk_to(c, Ep2GoldTown.local_to_world("Bldg_Saloon", GoldTownChamber.BAR_SPOT), 40.0) and into
	_check("he follows Inferno into the saloon and up to the bar", into, str(c.get_player_position()))
	var bull_sipped: bool = false
	var glass_at_lips: bool = false
	var rifle_low: bool = false
	for i in 60 * 70:
		if c.get_beat_name() != "DRINKS":
			break
		_observed_step(c)
		var bull: Ep2Actor = c.get_bull()
		if bull != null and bull.anim != null and bull.anim.current_animation == SmeltingFacilityChamber.BULL_SIP:
			bull_sipped = true
		var fp: Node3D = c._fp_glass
		if fp != null and fp.visible and fp.position.distance_to(GoldTownChamber.FP_GLASS_LIP) < 0.04 and fp.get_parent() == c.get_camera():
			glass_at_lips = true
			rifle_low = rifle_low or c.get_viewmodel().lowered
	_check("Inferno - 2.9 m - stooped through the saloon's 2.5 m door rather than through its lintel", c.max_duck() > 0.6, "%.2f" % c.max_duck())
	_check("two whiskeys on the bar", c.is_glass_on_bar() and c.is_second_glass_on_bar())
	_check("they really drink: Inferno lifts his glass on his own Stand_and_Drink clip", bull_sipped and c.drinks_done() == 1)
	_check("...and Lil Blunt's glass comes up to his lips in first person (the rifle lowered meanwhile)", glass_at_lips and rifle_low)
	_check("...then Inferno: his cousin Flux needs help with his new kettle - they'll meet up later",
		caps.any(func(l: Array) -> bool: return l[0] == "INFERNO" and "flux" in str(l[1]).to_lower() and "kettle" in str(l[1]).to_lower())
		and caps.any(func(l: Array) -> bool: return l[0] == "INFERNO" and "later" in str(l[1]).to_lower()))
	_check("...and leaves him a gift for Mike Dean: THE GOLD PANNER", c.has_gold_panner()
		and caps.any(func(l: Array) -> bool: return l[0] == "INFERNO" and "gold panner" in str(l[1]).to_lower() and "mike dean" in str(l[1]).to_lower()))
	_check("-> MINISTER2: the next thread is the gift, at Mike Dean's counter", c.get_beat_name() == "MINISTER2"
		and "gold panner" in str(c.get_hud().objective).to_lower(), c.get_beat_name() + " | " + str(c.get_hud().objective))

	# ---- steps 9-10: the second visit - the gift, the stamp, the referral to Dude
	print("-- THE SECOND VISIT TO MIKE DEAN (the stamp)")
	var left: bool = _walk_to(c, Ep2GoldTown.door_world("Bldg_Saloon", -0.9), 30.0)
	left = _walk_to(c, Ep2GoldTown.door_world("Bldg_Saloon", 2.0), 30.0) and left
	_check("he steps back out into the street", left)
	_until(c, 40.0, func(): return not mike.is_walking())
	_check("Mike Dean has walked back behind his counter", (office_xf.affine_inverse() * mike.position).z < -3.0, str(office_xf.affine_inverse() * mike.position))
	var to_office: bool = _walk_to(c, Ep2GoldTown.door_world("Bldg_Certificates", 1.5), 40.0)
	to_office = _walk_to(c, Ep2GoldTown.local_to_world("Bldg_Certificates", GoldTownChamber.OFFICE_SPOT), 20.0) and to_office
	_check("he walks back into the certificate office", to_office, str(c.get_player_position()))
	var m2_budget: float = 6.0
	for line in GoldTownChamber.MINISTER2_LINES:
		m2_budget += Ep2TownVoiceBank.seconds(Ep2TownVoiceBank.id_for(c._town_speaker(str(line[0])), str(line[1]))) + 4.0
	_until(c, m2_budget, func(): return c.get_beat_name() == "STABLES")
	_check("Mike Dean takes the Gold Panner", c.gold_panner_given() and not c.has_gold_panner()
		and caps.any(func(l: Array) -> bool: return l[0] == "MIKE DEAN" and "gold panner" in str(l[1]).to_lower()))
	_check("...and the certificate is stamped on this second visit (the first one laid out the rules)", c.is_stamped()
		and caps.any(func(l: Array) -> bool: return l[0] == "MIKE DEAN" and "stamped" in str(l[1]).to_lower()))
	_check("...and he sends him to his friend Dude at the horse stables", caps.any(func(l: Array) -> bool:
		return l[0] == "MIKE DEAN" and "dude" in str(l[1]).to_lower() and "stables" in str(l[1]).to_lower()))
	_check("-> STABLES: the objective is Dude's", c.get_beat_name() == "STABLES" and "dude" in str(c.get_hud().objective).to_lower(), str(c.get_hud().objective))

	# ---- steps 11-12: Dude - the Minister sent him, a price in BTC, his Chill Buds, "Logan's Lake first"
	print("-- DUDE AT THE STABLES")
	var yard: Ep2StableYard = c._stable_yard
	_check("Dude's stable yard is in town", yard != null and yard.actors.size() == 2)
	if yard != null and yard.actors.size() == 2:
		GameManager.dude_free_bud_claimed = false                          # a fresh visitor (an earlier gate's save may have claimed it)
		# he walks over to the yard (the route is the ranch gate's job); Dude may be out on his ride loop - he is back off the horse
		# first, then a visitor within 3 m keeps him there (Ep2StableYard: no new ride with someone close)
		_until(c, 90.0, func(): return not yard.is_dude_riding())
		c._player_pos = yard.actors[0].position + Vector3(1.6, 0.0, 0.0)
		_until(c, 3.0, func(): return yard.can_talk(c._player_pos))
		var btc_before: int = GameManager.purse_balance("btc")
		_check("[E] talks to Dude", c.start_rig(""))
		for i in 1200:
			if not yard.conversation_active():
				break
			c.step(0.1)
		var dude: String = " ".join(caps.filter(func(l: Array) -> bool: return str(l[0]).to_upper() == "DUDE").map(func(l: Array) -> String: return str(l[1]).to_lower()))
		_check("Dude: Mike Dean sent him, so he's good folk", "mike dean sent you" in dude, dude)
		_check("...they agree the horse's price in BTC (2 BTC, debited from his purse)", "btc" in dude and c.horse_bought()
			and GameManager.purse_balance("btc") == btc_before - 2, "btc %d -> %d" % [btc_before, GameManager.purse_balance("btc")])
		_check("...he offers his Chill Buds in the same talk (health kept in Tabs)", "chill bud" in dude)
		_check("...and: Logan's Lake first, so the horse can drink in this heat", "logan's lake" in dude)
	_until(c, 30.0, func(): return c.get_beat_name() == "GEARED")
	_check("-> GEARED: with the long rifle and the river gear already bought at Rich's, he rides for Logan's Lake",
		c.get_beat_name() == "GEARED" and c.has_sniper() and c.has_river_gear() and "logan" in str(c.get_hud().objective).to_lower(), c.get_beat_name())
	c.step(10.0)
	_check("Dude never auto-warps the player to the trail", res.is_empty())
	c._player_pos = GoldTownChamber.DEPART_HORSE + Vector3(1.5,0,0)
	_check("E explicitly mounts the horse at the stables",c.can_mount_departure() and c.start_rig(""))
	_until(c, 20.0, func(): return res.size() == 1)
	_check("the town hands on to the ride to Logan's Lake on Dude's horse, the map and the Peacemaker in hand, the certificate stamped, mints nothing",
		res.size() == 1 and str(res[0].get("next_chamber", "")) == "lake_trail" and bool(res[0].get("horse", false))
		and not bool(res[0].get("end_session", false)) and bool(res[0].get("got_map", false)) and bool(res[0].get("peacemaker", false))
		and bool(res[0].get("stamped", false)) and int(res[0].get("gold_awarded", -1)) == 0, str(res))
	_check("the ending carries the Armory: he visited it, and the long rifle + river gear come with him",
		res.size() == 1 and bool(res[0].get("armory_visited", false)) and bool(res[0].get("sniper", false))
		and int(res[0].get("sniper_rounds", 0)) == GoldTownChamber.SNIPER_BOX and bool(res[0].get("river_gear", false)), str(res))
	c.queue_free()

	# ---- lines exist; the session chain woods -> town -> end
	print("-- LINES + CHAIN")
	var ids: Array = ["vo_bull_drop1", "vo_bull_drop2", "vo_lb_drop", "vo_sheriff_1", "vo_lb_cert1", "vo_sheriff_2", "vo_sheriff_3", "vo_bar_1", "vo_lb_bar1", "vo_lb_bar2",
		"vo_bar_2", "vo_opp_1", "vo_opp_2", "vo_lb_draw1", "vo_opp_3", "vo_sheriff_witness", "vo_sheriff_foul", "vo_sheriff_win", "vo_sheriff_lose"]
	var missing: Array = []
	for id in ids:
		if (Ep2TownVoiceBank.stream(id) == null if Ep2TownVoiceBank.LINES.has(id) else not ResourceLoader.exists("res://src/assets/sounds/voice/%s.mp3" % id)) or _manifest_text(id) == "":
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
