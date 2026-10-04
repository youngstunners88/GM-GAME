extends Node
## Gate for Inferno Bull's TARGET PRACTICE lesson and the Modern-Warfare-style Winchester (founder 2026-10-04):
##   "Inferno must lead you there, conduct a demo and then have the player play. The rifle doesn't fire until
##    Inferno teaches Lil Blunt to load it, aim and fire."  (skills ep2-range-lesson, ep2-fps-shooter-feel)
## It plays the lesson end to end with only the verbs a player has: follow, watch, R, hold RMB, LMB.
## Run: godot --headless res://tests/ep2_range_lesson_test.tscn

const SMELT := preload("res://src/episode2/chamber/smelting_facility.tscn")
var _fail: int = 0
var said: Array = []


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])


func _run(c: Node, seconds: float) -> void:
	for i in int(seconds * 60.0):
		c.step(1.0 / 60.0)


func _until(c: Node, limit: float, pred: Callable) -> bool:
	for i in int(limit * 60.0):
		if pred.call():
			return true
		c.step(1.0 / 60.0)
	return pred.call()


func _ready() -> void:
	print("EP2 RANGE LESSON:")
	_gun_logic()
	await _lesson()
	print("EP2_RANGE_LESSON: %s" % ("ALL PASS" if _fail == 0 else "FAIL (%d)" % _fail))
	get_tree().quit(_fail)


## The Ep2Winchester rules on their own (no nodes).
func _gun_logic() -> void:
	var g := Ep2Winchester.new()
	_check("a new rifle is unloaded and locked", g.rounds == 0 and g.locked and g.reload_locked)
	_check("locked: the trigger does nothing", g.trigger() == Ep2Winchester.Shot.LOCKED and g.shots_fired == 0)
	_check("locked: it cannot be loaded either", g.start_reload() == false)
	g.locked = false
	g.reload_locked = false
	_check("unlocked but empty: a dry click, not a shot", g.trigger() == Ep2Winchester.Shot.EMPTY and g.dry_fires == 1)
	_check("reload starts", g.start_reload() and g.reloading)
	for i in 29:
		g.step(1.0 / 60.0)
	_check("one shell per ~0.5 s (not instant): %d after 0.48 s" % g.rounds, g.rounds == 0)
	g.step(1.0 / 60.0 * 2)
	_check("the first shell goes in", g.rounds == 1)
	for i in 130:
		g.step(1.0 / 60.0)
	_check("it fills to the tube's %d rounds and stops" % Ep2Winchester.MAG, g.rounds == Ep2Winchester.MAG and not g.reloading)
	_check("a full rifle will not start another reload", g.start_reload() == false)
	_check("the first shot fires", g.trigger() == Ep2Winchester.Shot.OK and g.rounds == 3)
	_check("the lever must be cycled: an instant second shot is refused", g.trigger() == Ep2Winchester.Shot.CYCLING and g.rounds == 3)
	for i in 45:
		g.step(1.0 / 60.0)
	_check("after the 0.65 s cycle it fires again", g.trigger() == Ep2Winchester.Shot.OK and g.rounds == 2)
	for i in 45:
		g.step(1.0 / 60.0)
	g.start_reload()
	g.step(0.2)
	_check("firing interrupts a reload (Modern Warfare)", g.trigger() == Ep2Winchester.Shot.OK and not g.reloading)
	# aim and spread
	var hip: float = g.spread_deg(false, false)
	g.wants_ads = true
	for i in 30:
		g.step(1.0 / 60.0)
	var aimed: float = g.spread_deg(false, false)
	_check("ADS takes ~0.24 s and is not instant", g.ads >= 0.99)
	_check("aimed is much tighter than hip (%.2f vs %.2f deg)" % [aimed, hip], aimed < hip * 0.35)
	_check("moving widens the spread", g.spread_deg(true, false) > aimed * 1.1)
	_check("jumping widens it more", g.spread_deg(false, true) > g.spread_deg(true, false))
	_check("the kick is smaller aimed", g.kick_rad() < deg_to_rad(Ep2Winchester.KICK_DEG))
	g.sprinting = true
	for i in 30:
		g.step(1.0 / 60.0)
	_check("sprinting drops the aim", g.ads < 0.05)


func _lesson() -> void:
	var c: SmeltingFacilityChamber = SMELT.instantiate()
	c.intro_film = false
	add_child(c)
	c.setup(0, [], 0)
	c.set_physics_process(false)
	c.line_spoken.connect(func(id: String) -> void: said.append(id))
	await get_tree().process_frame
	c._on_video_film_finished()                    # the founder's film ends here: the real hand-off into the lesson
	_run(c, 0.5)
	_check("after the film the lesson begins", c.get_beat_name() == "VERB_TEACH" and c.get_lesson_name() == "LEAD", c.get_lesson_name())
	_check("first person, with the Winchester in hand", c.is_fps() and c.has_winchester())
	var gun: Ep2Winchester = c.get_gun()
	_check("the rifle is unloaded and LOCKED", gun.rounds == 0 and gun.locked and gun.reload_locked)
	_check("he says follow me", said.has("vo_bull_range_follow"), str(said))
	_check("the player is free to walk (he leads, you follow)", c.has_player_control())
	_check("clicking does nothing yet", c.shoot() == false and gun.shots_fired == 0)
	_check("neither does R", c.reload() == false and gun.rounds == 0)
	var bull: Ep2Actor = c.get_bull()
	_until(c, 25.0, func(): return c._lead_done)
	_check("Inferno LEADS: he walked to the range (no teleport)",
		bull.position.distance_to(c.BULL_DEMO) < 0.6 and c._lead_done, str(bull.position))
	_run(c, 3.0)
	_check("he waits for you: no demo while you are far from the line", c.get_lesson_name() == "LEAD")
	_run(c, 12.0)
	_check("...and nags if you dawdle", said.has("vo_bull_range_nag"))
	c.spread_scale = 0.0
	# --- DEMO ------------------------------------------------------------------------------------------------
	c._player_pos = Vector3(RangeDressing.LINE.x, 0.0, RangeDressing.LINE.z + 0.4)      # the player reaches the firing line
	_run(c, 0.3)
	_check("reaching the line starts the DEMO", c.get_lesson_name() == "DEMO", c.get_lesson_name())
	_check("...the player is held still and watches", not c.has_player_control())
	_check("the rifle is still locked during the demo", c.shoot() == false and gun.shots_fired == 0)
	var shots0: int = c.winchester_shots_played
	var saw_plate_down: bool = false
	var t: float = 0.0
	while c.get_lesson_name() == "DEMO" and t < 90.0:
		c.step(1.0 / 60.0)
		t += 1.0 / 60.0
		if c._mold_broken[1]:
			saw_plate_down = true
	_check("the demonstration plays out (%.0f s)" % t, c.get_lesson_name() == "LOAD" and t > 15.0, c.get_lesson_name())
	var order: Array = said.filter(func(x): return str(x).begins_with("vo_bull_range_") and x not in ["vo_bull_range_follow", "vo_bull_range_nag", "vo_bull_range_hold"])
	_check("he teaches in order: intro, load, aim, fire, your turn",
		order == ["vo_bull_range_intro", "vo_bull_range_load", "vo_bull_range_aim", "vo_bull_range_fire", "vo_bull_range_your_turn"], str(order))
	_check("he FIRES the Winchester in the demo (the report plays)", c.winchester_shots_played == shots0 + 1)
	_check("...and his shot knocks a plate down", saw_plate_down)
	_check("the targets are reset for the player", c.get_molds_left() == 5 and not c._mold_broken[1])
	_check("your gun is still empty and locked after watching", gun.rounds == 0 and gun.locked)
	# --- LOAD ------------------------------------------------------------------------------------------------
	_check("LOAD: the player has control again", c.has_player_control())
	_check("LOAD: the prompt names the key", "R" in c._lesson_objective() and "LOAD" in c._lesson_objective())
	_check("LOAD: still no shooting", c.shoot() == false and gun.shots_fired == 0)
	_check("LOAD: R starts loading", c.reload() and gun.reloading)
	_until(c, 6.0, func(): return gun.rounds >= Ep2Winchester.MAG)
	_run(c, 0.1)
	_check("shells go in one at a time until the tube is full (%d)" % gun.rounds, gun.rounds == Ep2Winchester.MAG)
	_check("loading takes the reserve: %d left" % gun.reserve, gun.reserve == Ep2Winchester.RESERVE_START - Ep2Winchester.MAG)
	_check("full tube -> AIM, and he says so", c.get_lesson_name() == "AIM" and said.has("vo_bull_range_good_load"), c.get_lesson_name())
	# --- AIM -------------------------------------------------------------------------------------------------
	_check("AIM: loaded but STILL locked until you aim", c.shoot() == false and gun.shots_fired == 0 and gun.locked)
	_check("AIM: the prompt names RIGHT MOUSE", "RIGHT MOUSE" in c._lesson_objective())
	c.set_aim(true)
	_run(c, 0.3)
	_check("holding aim narrows the view (fov %.1f)" % c._camera.fov, c._camera.fov < c.FPS_FOV - 8.0)
	_check("a split-second aim is not enough yet", c.get_lesson_name() == "AIM")
	_until(c, 3.0, func(): return c.get_lesson_name() == "FIRE")
	_check("holding aim steady -> FIRE, the rifle unlocks", c.get_lesson_name() == "FIRE" and not gun.locked and said.has("vo_bull_range_good_aim"))
	# --- FIRE ------------------------------------------------------------------------------------------------
	_check("FIRE: the prompt names LEFT CLICK", "LEFT CLICK" in c._lesson_objective())
	c.aim_at(c.get_mold_position(0))
	_run(c, 0.05)
	_check("the first shot hits the plate", c.shoot() == true and c._mold_broken[0])
	_check("the trigger cannot be mashed (lever cycle): second click refused", c.shoot() == false and gun.rounds == 3)
	_run(c, 0.3)
	_check("-> PRACTICE after the first hit, with his praise", c.get_lesson_name() == "PRACTICE" and said.has("vo_bull_range_first_hit"))
	# --- PRACTICE: empty gun, dry fire, reload, finish ----------------------------------------------------------
	c.aim_at(c.get_mold_position(0) + Vector3(5.0, 2.0, 0.0))
	for i in 3:
		_run(c, 0.8)
		c.shoot()
	_check("three misses empty the tube", gun.rounds == 0)
	_run(c, 0.8)
	_check("an empty rifle only clicks", c.shoot() == false and gun.dry_fires >= 1)
	_check("...and he reminds you to reload", said.has("vo_bull_range_empty"))
	_check("reload refills it", c.reload())
	_until(c, 6.0, func(): return gun.rounds >= Ep2Winchester.MAG)
	# break the remaining four targets (1..4), reloading when the tube runs dry
	for i in [1, 2, 3, 4]:
		if gun.rounds == 0:
			c.reload()
			_until(c, 6.0, func(): return gun.rounds >= Ep2Winchester.MAG)
		c.aim_at(c.get_mold_position(i))
		_check("target %d goes down" % i, c.shoot() == true and c._mold_broken[i])
		_run(c, 0.8)
	_check("all five targets down", c.get_molds_left() == 0)
	_until(c, 8.0, func(): return c.get_beat_name() != "VERB_TEACH")
	_check("his closing line, then on to the story (-> TERMS)", said.has("vo_bull_range_done") and c.get_beat_name() == "TERMS", c.get_beat_name())
	c.queue_free()
