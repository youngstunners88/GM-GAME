extends Node
## Consequences gate: real chamber, real eye camera, shoot() and deterministic
## chamber steps. Run: godot --headless res://tests/ep2_town_law_test.tscn

const TOWN := preload("res://src/episode2/chamber/gold_town.tscn")

var _fail: int = 0


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


func _fresh() -> GoldTownChamber:
	var c: GoldTownChamber = TOWN.instantiate()
	add_child(c)
	c.setup(0, [], 0)
	c.step(1.0 / 60.0)
	return c


func _retire(c: GoldTownChamber) -> void:
	c.set_move_input(Vector2.ZERO)
	c.queue_free()


## Aim only through the chamber's public mouse-look verb, then let its real FPS
## camera update. The shot path below never supplies a synthetic impact point.
func _aim_at(c: GoldTownChamber, target: Vector3) -> void:
	c.set_aim(false)
	for i in 14:
		var eye: Vector3 = c.get_camera().global_position
		var d: Vector3 = target - eye
		if d.length() < 0.01:
			return
		var yaw: float = atan2(d.x, d.z)
		var pitch: float = atan2(d.y, Vector2(d.x, d.z).length())
		var dy: float = wrapf(yaw - c._look_yaw, -PI, PI)
		var dp: float = pitch - c._look_pitch
		if absf(dy) < 0.0002 and absf(dp) < 0.0002:
			break
		var k: float = Ep2Interlude.LOOK_SENSITIVITY
		c.look(Vector2(-dy / k, -dp / k))
		c.step(1.0 / 60.0)
	c.step(1.0 / 60.0)


func _fire_at(c: GoldTownChamber, target: Vector3) -> bool:
	_aim_at(c, target)
	return c.shoot()


func _nearest_person(c: GoldTownChamber) -> Ep2TownPeople.Person:
	var best: Ep2TownPeople.Person = null
	var distance: float = INF
	for p in c.get_people().people:
		if p.folk.dead:
			continue
		var d: float = p.folk.position.distance_to(c.get_player_position())
		if d < distance:
			distance = d
			best = p
	return best


func _civilian_and_cell() -> void:
	print("-- CIVILIAN, WALKING ARREST, BAM, PICKAXE")
	GameManager.set_town_standing("warm")
	var c: GoldTownChamber = _fresh()
	var captions: Array = []
	c.captioned.connect(func(w: String, t: String) -> void: captions.append([w, t]))
	c.armory.acquire(Ep2ArmoryState.REM)
	c.armory.acquire(Ep2ArmoryState.BOW)
	var person: Ep2TownPeople.Person = _nearest_person(c)
	_check("the real streamed town roster is present", person != null)
	if person == null:
		_retire(c)
		return
	c._player_pos = person.folk.position + Vector3(0.0, 0.0, 4.0)
	c.step(1.0 / 60.0)
	var fired: bool = _fire_at(c, person.folk.position + Vector3(0.0, 1.05, 0.0))
	var law: Ep2TownLaw = c.get_town_law()
	_check("a camera-ray shot on a townsperson kills and immediately starts arrest",
		fired and person.folk.dead and law.is_arrest_active(), str(law.last_shot))
	_check("the arrest caption is the Sheriff's", captions.any(func(l: Array) -> bool:
		return l[0] == "SHERIFF" and str(l[1]) == Ep2TownLaw.ARREST_LINE))
	var sheriff: Ep2TownFolk = c.get_sheriff()
	var previous_distance: float = sheriff.position.distance_to(c.get_player_position())
	var shrink_checks: int = 0
	for i in 4:
		if law.law_state != "approach":
			break
		_run(c, 1.0)
		var now_distance: float = sheriff.position.distance_to(c.get_player_position())
		_check("the Sheriff walks closer during arrest second %d" % (i + 1), now_distance < previous_distance - 0.05,
			"%.2f -> %.2f" % [previous_distance, now_distance])
		previous_distance = now_distance
		shrink_checks += 1
	_check("the approach really used walking time", shrink_checks >= 2)
	_until(c, 100.0, func(): return law.is_in_cell())
	_check("Lil Blunt is auto-walked with the Sheriff into the cell", law.is_in_cell() and law.player_in_cell(),
		"%s %s" % [law.law_state, str(c.get_player_position())])
	_check("Bam Bankman Free is alive in the cell, with the original prisoner untouched",
		law.get_bam() != null and law.get_bam().visible and not law.get_bam().dead
			and (c.get_accomplice() == null or not c.get_accomplice().dead))
	_check("the guns were taken at the jail and the pickaxe is the equipped mode",
		c.armory.firearms_confiscated and c.armory.equipped == Ep2ArmoryState.PICK)
	_run(c, 55.0)
	_check("the cell is still shut well before two minutes", law.cell_locked() and law.cell_seconds_left() > 50.0)
	var gate_target: Vector3 = Ep2GoldTown.local_to_world("Bldg_Jail", Ep2TownLaw.CELL_GATE_LOCAL)
	_aim_at(c, gate_target + Vector3(0.0, 1.4, 0.0))
	c.set_move_input(Vector2(0.0, 1.0), true)
	_run(c, 2.0)
	c.set_move_input(Vector2.ZERO)
	_check("looking and walking cannot get him out before the time is up", law.cell_locked() and law.player_in_cell(),
		str(c.get_player_position()))
	_run(c, 55.0)
	_check("the lock holds through 112 seconds, not a shorter cosmetic wait", law.cell_locked() and law.cell_elapsed() >= 112.0,
		"%.2f" % law.cell_elapsed())
	_until(c, 35.0, func(): return law.law_state == "idle")
	_check("release happens only after the full 120 seconds and walks him back out",
		law.law_state == "idle" and law.release_count == 1 and law.cell_elapsed() >= Ep2TownLaw.CELL_SECONDS,
		"%s %.2f" % [law.law_state, law.cell_elapsed()])
	var ordered: bool = law.cell_captioned.size() == Ep2TownLaw.CELL_LINES.size()
	for i in mini(law.cell_captioned.size(), Ep2TownLaw.CELL_LINES.size()):
		var want: Array = Ep2TownLaw.CELL_LINES[i]
		var got: Array = law.cell_captioned[i]
		ordered = ordered and got[0] == want[0] and got[1] == want[1]
	_check("all ten Bam/Lil Blunt lines are captioned once, in order", ordered, str(law.cell_captioned))
	_check("their conversation is spread across the stay", law.cell_line_times.size() == 10
		and law.cell_line_times[0] >= 3.9 and law.cell_line_times[9] >= 111.9 and law.cell_line_times[9] < 120.0,
		str(law.cell_line_times))
	_check("release uses the Sheriff's pickaxe line", captions.any(func(l: Array) -> bool:
		return l[0] == "SHERIFF" and str(l[1]) == Ep2TownLaw.RELEASE_LINE))
	_check("the town relationship is cold", GameManager.town_standing == "cold")
	var selector := Ep2WeaponSelector.new()
	selector.state = c.armory
	add_child(selector)
	var held: bool = true
	for id in Ep2ArmoryState.IDS:
		held = held and selector.card_status(id) == "HELD BY THE SHERIFF" and not c.armory.select(id)
	_check("Tabs shows all three irons HELD BY THE SHERIFF and none can be selected", held)
	selector.queue_free()
	var swings: int = c.get_viewmodel().pickaxe_swings
	var rounds: int = c.armory.firearm(Ep2ArmoryState.WIN).rounds
	_check("click swings the pickaxe with no ammunition and no shot/offence",
		c.shoot() and c.get_viewmodel().pickaxe_swings == swings + 1
			and c.armory.firearm(Ep2ArmoryState.WIN).rounds == rounds and law.person_hits == 1)
	var snap: Dictionary = c.armory.snapshot()
	var restored := Ep2ArmoryState.new()
	restored.restore(snap)
	_check("confiscation survives the armory snapshot/restore round-trip",
		restored.firearms_confiscated and restored.equipped == Ep2ArmoryState.PICK)
	var returned: Array = []
	c.armory.firearms_returned.connect(func() -> void: returned.append(true))
	c.return_firearms()
	var usable: bool = not c.armory.firearms_confiscated and returned.size() == 1
	for id in Ep2ArmoryState.IDS:
		# select() is false for the iron already in his hands (no-op switch), so that one counts as usable when it is equipped.
		usable = usable and c.armory.owns(id) and (c.armory.equipped == id or c.armory.select(id))
	_check("return_firearms() gives every previously owned iron back and emits once", usable,
		"equipped %s, confiscated %s, emitted %d" % [c.armory.equipped, str(c.armory.firearms_confiscated), returned.size()])
	_retire(c)


func _story_wounds_and_bull() -> void:
	print("-- STORY CAST WOUNDS; INFERNO IS NEVER A TARGET")
	for who in ["sheriff", "minister"]:
		var c: GoldTownChamber = _fresh()
		# Past the office meeting: walking up to the Sheriff at STREET starts the office show, and a show holds the controls
		# (no shot leaves the barrel then), so the shot is taken when Lil Blunt is free to act.
		c._advance_to(GoldTownChamber.Beat.TO_BAR)
		_until(c, 8.0, func(): return c.has_player_control())
		var folk: Ep2TownFolk = c.get_sheriff() if who == "sheriff" else c.get_minister()
		var meeting: Vector3 = Ep2GoldTown.local_to_world("Bldg_Certificates", GoldTownChamber.OFFICE_SPOT)
		var toward: Vector3 = meeting - folk.position
		toward.y = 0.0
		if toward.length() < 0.5:
			toward = Vector3(0.0, 0.0, -1.0)
		c._player_pos = folk.position + toward.normalized() * 2.6
		c.step(1.0 / 60.0)
		_until(c, 4.0, func(): return c.has_player_control())
		var fired: bool = _fire_at(c, folk.position + Vector3(0.0, 1.10, 0.0))
		_check("a shot on %s wounds but never kills, and still arrests" % who,
			fired and not folk.dead and bool(folk.get_meta("law_wounded", false)) and c.get_town_law().is_arrest_active(),
			"fired %s control %s beat %s last %s" % [str(fired), str(c.has_player_control()), c.get_beat_name(), str(c.get_town_law().last_shot)])
		_retire(c)
	var c: GoldTownChamber = _fresh()
	var bull: Ep2Actor = c.get_bull()
	bull.position = Vector3(0.0, 0.0, 1420.0)
	bull.visible = true
	c._player_pos = Vector3(0.0, 0.0, 1426.0)
	c.step(1.0 / 60.0)
	_fire_at(c, bull.position + Vector3(0.0, 1.35, 0.0))
	_check("a ray aimed through Inferno Bull never wounds him and never arrests",
		not c.get_town_law().is_arrest_active() and c.get_town_law().person_hits == 0
			and str(c.get_town_law().last_shot.get("protected", "")) == "inferno", str(c.get_town_law().last_shot))
	_retire(c)


func _horse_and_property() -> void:
	print("-- HORSE, FACADES, WINDOWS, EXACT BTC FINES AND DEBT")
	GameManager.set_town_standing("warm")
	GameManager.town_debt_btc = 0
	var c: GoldTownChamber = _fresh()
	var law: Ep2TownLaw = c.get_town_law()
	var horse: Node3D = c._visuals.find_child("Horse0", true, false) as Node3D
	_check("the hitch-rail horse is a law target", horse != null)
	if horse != null:
		c._player_pos = horse.position + Vector3(0.0, 0.0, 4.0)
		GameManager.token_purse["btc"] = 5
		var before: int = GameManager.purse_balance("btc")
		_fire_at(c, horse.global_position + Vector3(0.0, 1.05, 0.0))
		_check("a horse bleeds/is wounded, costs a fine, and is not an arrest",
			law.horse_hits == 1 and not law.is_arrest_active() and law.pending_fine(), str(law.last_shot))
		_run(c, 3.3)
		_check("the horse's one-BTC fine settles after three quiet seconds",
			law.fines_charged == 1 and law.last_fine == 1 and GameManager.purse_balance("btc") == before - 1)
		if ResourceLoader.exists(Ep2TownLaw.BLOOD_SCRIPT):
			_check("the optional blood packet was used when present", law.blood_events >= 2)
	_retire(c)

	c = _fresh()
	law = c.get_town_law()
	GameManager.token_purse["btc"] = 10
	GameManager.town_debt_btc = 0
	var piece: String = "Bldg_Certificates"
	var normal: Vector3 = law.front_normal(piece)
	var facade: Vector3 = law.facade_target(piece)
	c._player_pos = Vector3(facade.x, 0.0, facade.z) + normal * 4.0
	c.step(1.0 / 60.0)
	_fire_at(c, facade)
	_check("a facade round leaves a real offset bullet mark", law.facade_holes == 1 and law.damage_marks == 1,
		str(law.last_shot))
	_run(c, 1.0)
	var window: Vector3 = law.window_target(piece, 0)
	_fire_at(c, window)
	_check("a round through a window shatters that pane", law.broken_windows == 1, str(law.last_shot))
	var purse_before: int = GameManager.purse_balance("btc")
	_run(c, 3.3)
	_check("one window plus one facade hole fines exactly two BTC once",
		law.fines_charged == 1 and law.last_fine == 2 and GameManager.purse_balance("btc") == purse_before - 2,
		"fine %d purse %d" % [law.last_fine, GameManager.purse_balance("btc")])
	_run(c, 3.5)
	_check("quiet time cannot debit the same damage twice", law.fines_charged == 1)

	GameManager.token_purse["btc"] = 1
	_run(c, 0.8)
	_fire_at(c, facade)
	_run(c, 1.0)
	_fire_at(c, law.window_target(piece, 1))
	_run(c, 3.3)
	_check("a short purse pays what exists and records the rest as debt",
		law.last_fine == 2 and GameManager.purse_balance("btc") == 0 and GameManager.town_debt_btc == 1
			and law.last_debt == 1, "purse %d debt %d" % [GameManager.purse_balance("btc"), GameManager.town_debt_btc])
	_check("the purse never goes negative", GameManager.purse_balance("btc") >= 0)
	GameManager.set_town_standing("cold")
	_check("standing and debt are written and loaded with the persistent session",
		GameManager.save_session())
	GameManager.town_standing = "warm"
	GameManager.town_debt_btc = 0
	GameManager.load_session()
	_check("save/load round-trips cold standing and BTC debt",
		GameManager.town_standing == "cold" and GameManager.town_debt_btc == 1)
	_retire(c)


func _draw_regression() -> void:
	print("-- THE DRAW IS UNCHANGED")
	var c: GoldTownChamber = _fresh()
	c._player_pos = GoldTownChamber.DUEL_MARK
	c._advance_to(GoldTownChamber.Beat.DRAW)
	_until(c, 10.0, func(): return c.get_draw_state() == "go")
	c.draw_weapon()
	_fire_at(c, c.get_opponent().position + Vector3(0.0, 1.30, 0.0))
	_check("in the draw the stranger is still the winning target, with no town arrest",
		c.get_draw_state() == "won" and c.get_opponent().dead and not c.get_town_law().is_arrest_active())
	_retire(c)
	c = _fresh()
	c._player_pos = GoldTownChamber.DUEL_MARK
	c._advance_to(GoldTownChamber.Beat.DRAW)
	_until(c, 10.0, func(): return c.get_draw_state() == "go")
	_until(c, 5.0, func(): return c.get_draw_state() == "lost")
	_check("doing nothing after the bell is still the same retryable loss",
		c.get_losses() == 1 and c.get_health() == 3 and not c.get_town_law().is_arrest_active())
	_until(c, 12.0, func(): return c.get_draw_state() == "wait")
	_check("the loss restages another draw exactly as before", c.get_draw_state() == "wait" and c.get_losses() == 1)
	_retire(c)


func _ready() -> void:
	print("-- EP2 TOWN LAW")
	_civilian_and_cell()
	await get_tree().process_frame
	_story_wounds_and_bull()
	await get_tree().process_frame
	_horse_and_property()
	await get_tree().process_frame
	_draw_regression()
	await get_tree().process_frame
	# Clean up the persistent session: this gate saves a COLD standing and a BTC debt on purpose, and the next gate in the
	# same CI run loads that save (ep2_town_people_test then saw no greetings at all).
	GameManager.town_standing = "warm"
	GameManager.town_debt_btc = 0
	GameManager.save_session()
	if _fail == 0:
		print("EP2_TOWN_LAW: ALL PASS")
		get_tree().quit(0)
	else:
		print("EP2_TOWN_LAW: %d FAILURE(S)" % _fail)
		get_tree().quit(_fail)
