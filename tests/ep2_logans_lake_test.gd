extends Node
var failures := 0
func check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["PASS" if ok else "FAIL", label])
	if not ok: failures += 1
func advance(c: LogansLakeChamber, seconds: float) -> void:
	for i in int(seconds * 60): c.step(1.0 / 60.0)
func walk(c: LogansLakeChamber, target: Vector3) -> bool:
	for i in 3600:
		var d: Vector3 = target - c.get_player_position()
		if Vector2(d.x, d.z).length() < 0.35:
			c.set_move_input(Vector2.ZERO)
			return true
		c._look_yaw = atan2(d.x, d.z)
		c.set_move_input(Vector2(0, 1))
		c.step(1.0 / 60.0)
	return false
func _ready() -> void:
	var session: Ep2SessionRoot = load("res://src/episode2/session/ep2_session_root.tscn").instantiate()
	add_child(session)
	session.configure([{"chamber": "gold_town"}, {"chamber": "miner_shaft"}], false)
	session._enter_chamber()
	var town: Node = session.get_active()
	check("town contains both jail investigation beats", town.Beat.has("JAIL_TIP") and town.Beat.has("JAIL"))
	town._horse_bought = true                      # Dude sold him the horse (the town's Beat.STABLES)
	town._advance_to(town.Beat.DONE)
	# fix pack 2026-10-27 (the locked order): the town hands on to the ride on Dude's horse; the trail's shore hands on to the lake
	var trail: LakeTrailChamber = session.get_active() as LakeTrailChamber
	check("real town DONE dispatch rides the lake trail first (Dude's horse, the bandits)", trail != null and session.get_mode() == Ep2SessionRoot.Mode.CHAMBER)
	if trail != null:
		trail._resolve({"next_chamber": "logans_lake", "arrived_mounted": true, "trail_seconds": 60.0, "bandits_down": 0, "companion": ""})
	var c: LogansLakeChamber = session.get_active() as LogansLakeChamber
	check("real town DONE dispatch loads Logan lake in same session", c != null and session.get_mode() == Ep2SessionRoot.Mode.CHAMBER)
	if c == null:
		get_tree().quit(1)
		return
	var completions: Array = []
	session.session_complete.connect(func() -> void: completions.append(true))
	var results: Array = []
	c.chamber_cleared.connect(func(result: Dictionary) -> void: results.append(result))
	check("live asset probe verifies supplied 65-bone skin and four clips", LogansLakeChamber.probe_assets())
	c.set_physics_process(false)
	var initial: Dictionary = c.armory.snapshot().duplicate(true)
	check("registered on the Episode 2 surface chain", Ep2SessionRoot.CHAMBER_SCENES.has("logans_lake"))
	check("first person, firearm and 3-heart contract", c.is_fps() and c.get_viewmodel() != null and c.get_health() == 3)
	check("founder's supplied Logan has a real skin and clips", c._logan.has_clips() and c._logan.model.find_children("*", "Skeleton3D", true, false).size() == 1)
	check("no remote interaction from the arrival trail", not c.start_rig())
	check("walk to Logan through ordinary movement", walk(c, Vector3(-5.5, 0, 8)))
	check("meeting starts investigation", c.start_rig() and c.get_beat() == LogansLakeChamber.Beat.INVESTIGATE)
	check("cannot skip dialogue by spamming interact", not c.start_rig())
	# Exercise the live scene clock, not deterministic manual stepping, while paused.
	c.set_physics_process(true)
	c.toggle_armory()
	var talk_before: float = c._talk_t
	await get_tree().create_timer(0.15, true).timeout
	check("armory freezes the conversation and world", get_tree().paused and c._talk_t == talk_before)
	c.toggle_armory()
	c.set_physics_process(false)
	check("closing armory resumes the scene", not get_tree().paused)
	advance(c, 20)
	check("short dialogue leads to one staging action", c.get_beat() == LogansLakeChamber.Beat.STAGE)
	check("staging cannot be activated beside Logan", not c.start_rig())
	check("walk to the staging crate", walk(c, Vector3(-6, 0, 17)))
	c._hud.search_requested.emit()
	check("touch interaction confirms cargo once", c.staging_complete() and c.staging_count() == 1)
	check("repeat input never rewards or stages twice", not c.start_rig() and c.staging_count() == 1)
	check("all weapons, finite ammunition and currency unaffected", c.armory.snapshot() == initial)
	check("walk up the shore to the river overlook", walk(c, LogansLakeChamber.OVERLOOK))
	advance(c, 0.2)
	check("lake hands off to visible day-88 outflow", c.river_ready() and c._visuals.get_node_or_null("Day88Outflow") != null)
	check("overlook stands above the water", c.get_player_position().y > 5.5)
	check("water remains outside walkable bounds", c._collide(Vector3(25, 0, 20)).x <= -4)
	check("arrival/overview cannot walk off the world", c._collide(Vector3(-200, 0, 500)).z <= 64)
	check("cannot finish before overlook closing dialogue", not c.start_rig())
	advance(c, 8.1)
	c._hud.search_requested.emit()
	check("finish touch action completes session exactly once", completions.size() == 1 and results.size() == 1)
	check("lake result ends slice without next chamber or vault", results.size() == 1 and results[0].get("end_session", false) and results[0].get("lake_complete", false) and not results[0].has("next_chamber"))
	check("session stops without entering next runner or vault", session.get_mode() == Ep2SessionRoot.Mode.IDLE and session.get_active() == null)
	check("finish input cannot duplicate completion", not c.start_rig() and completions.size() == 1)
	print("LOGANS_LAKE: %s" % ("ALL PASS" if failures == 0 else "%d FAIL" % failures))
	get_tree().quit(1 if failures else 0)
