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
	# Chamber handoffs save the armory. Keep this fixture's completed shipment out of later CI tests.
	var prior_session: Dictionary = GameManager.session_data().duplicate(true)
	GameManager.personal_armory = {}
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
	check("registered on the Episode 2 surface chain", Ep2SessionRoot.CHAMBER_SCENES.has("logans_lake"))
	check("first person, firearm and 3-heart contract", c.is_fps() and c.get_viewmodel() != null and c.get_health() == 3)
	check("founder's supplied Logan has a real skin and clips", c._logan.has_clips() and c._logan.model.find_children("*", "Skeleton3D", true, false).size() == 1)
	check("no remote interaction from the arrival trail", not c.start_rig())
	check("walk to Logan through ordinary movement", walk(c, Vector3(-5.5, 0, 8)))
	advance(c, 0.1)                                # he sees Lil Blunt on the shore: the talk starts by itself (founder 2026-11-15, no [E])
	check("meeting starts investigation", c.get_beat() == LogansLakeChamber.Beat.INVESTIGATE)
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
	# The three lines are Logan's own takes since 2026-11-22 (P1-0): the talk lasts as long as the takes, never cut short, then one staging action.
	var talk_budget: float = 0.0
	for line in LogansLakeChamber.LINES:
		var take: AudioStream = Ep2TownVoiceBank.stream(Ep2TownVoiceBank.id_for("logan", str(line).split(": ", true, 1)[1]))
		talk_budget += (take.get_length() + Ep2Speech.GAP) if take != null else 6.5
	var talked: float = 0.0
	while talked < talk_budget + 1.0 and c.get_beat() != LogansLakeChamber.Beat.STAGE:
		advance(c, 0.25)
		talked += 0.25
	print("  logan talk %.1f s of a %.1f s take budget" % [talked, talk_budget])
	check("short dialogue leads to one staging action", c.get_beat() == LogansLakeChamber.Beat.STAGE and talked <= talk_budget + 1.0)
	check("staging cannot be activated beside Logan", not c.start_rig())
	check("walk to the staging crate", walk(c, Vector3(-6, 0, 17)))
	check("without the Armory purchase, cargo interaction can’t launch a crate", not c.start_rig() and c._cargo == null)
	GameManager.purse_add("btc", 2)
	check("purchase records the shipment in the same Armory used at the lake", town.buy("river_gear", 2, "btc") and c.armory.river_gear)
	var initial: Dictionary = c.armory.snapshot()
	var balance: int = GameManager.purse_balance("btc")
	c._hud.search_requested.emit()
	check("touch interaction frames the owned crate, then locks out repeat interactions", c._cargo != null and not c.start_rig() and c.staging_count() == 1)
	var shipment: Node3D = c._cargo
	var start: Vector3 = shipment.position
	advance(c, 3.0)
	check("the framed crate moves in the water with a wake before the ridge is armed",
		shipment.position.z > start.z + 2.0 and c._cargo_wake != null and c._cam_goal_active and not c.armory.day88_outflow_started)
	advance(c, LogansLakeChamber.CARGO_SHOT_SECONDS - 3.0 + 0.1)
	check("the crate reaches the outflow and player control returns", c.staging_complete() and c.has_player_control()
		and is_equal_approx(shipment.position.z, LogansLakeChamber.CARGO_END_Z))
	initial["day88_outflow_started"] = true
	check("staging is saved once without spending or modifying any inventory", c.armory.snapshot() == initial
		and GameManager.purse_balance("btc") == balance and session.section_checkpoint.state.personal_armory == initial)
	var saved_state := Ep2ArmoryState.new()
	saved_state.restore(session.section_checkpoint.state.personal_armory)
	check("the outflow checkpoint retains the owned and staged shipment", saved_state.river_gear and saved_state.day88_outflow_started)
	check("walk up the shore to the river overlook", walk(c, LogansLakeChamber.OVERLOOK))
	advance(c, 0.2)
	check("lake hands off to visible day-88 outflow", c.river_ready() and c._visuals.get_node_or_null("Day88Outflow") != null)
	check("overlook stands above the water", c.get_player_position().y > 5.5)
	check("water remains outside walkable bounds", c._collide(Vector3(25, 0, 20)).x <= -4)
	check("arrival/overview cannot walk off the world", c._collide(Vector3(-200, 0, 500)).z <= 64)
	# founder 2026-11-07 ("no pause climbing the hill from the cargo check"): finishing never waits for the overlook line to end
	check("the ridge is being built behind the lake since Logan's first line", session._pb_id == "river_cover")
	check("the overlook line is still running when he may walk on", c._talk_t > 0.0)
	session._drive_prebuild(1.0e9)                 # the test is the frame clock: the background build, done
	# audit 2026-11-17: the ridge needs the Sharps and has no way back, so the lake holds him here until he owns it
	c._player_pos = Vector3(-8.0, 6.0, LogansLakeChamber.WALK_ON_Z)
	advance(c, 0.1)
	check("without the Sharps the overlook turns him round instead of ending the run on the ridge", results.is_empty() and c.has_player_control() and "sharps" in c._hud.objective.to_lower())
	c.armory.sniper_owned = true
	c._player_pos = Vector3(-8.0, 6.0, LogansLakeChamber.WALK_ON_Z)   # walking on IS finishing (founder 2026-11-15: no [E] arrivals)
	advance(c, 0.1)
	advance(c, 0.1)
	check("finish touch action resolves the lake exactly once (the session carries on to the ridge)", completions.is_empty() and results.size() == 1)
	# founder lock 2026-11-04: the lake hands on to the day-88 ridge (never a vault, never the runner)
	check("lake result hands on to the day-88 ridge, no vault", results.size() == 1 and not results[0].get("end_session", false) and results[0].get("lake_complete", false) and str(results[0].get("next_chamber", "")) == "river_cover")
	var ridge := session.get_active() as RiverCoverChamber
	check("the ridge adopts the same shipment node launched at the lake", ridge != null and ridge.get_crate() == shipment
		and ridge.armory.river_gear and ridge.armory.day88_outflow_started and ridge.blocked_reason() == "")
	check("finish input cannot duplicate the hand-off", not c.start_rig() and results.size() == 1)
	session.free()
	GameManager.restore_session_data(prior_session)
	check("fixture restores the prior save for later gameplay tests", GameManager.save_session())
	print("LOGANS_LAKE: %s" % ("ALL PASS" if failures == 0 else "%d FAIL" % failures))
	get_tree().quit(1 if failures else 0)
