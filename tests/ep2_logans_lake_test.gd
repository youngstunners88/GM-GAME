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
	var c: LogansLakeChamber = load("res://src/episode2/chamber/logans_lake.tscn").instantiate()
	add_child(c)
	c.setup()
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
	print("LOGANS_LAKE: %s" % ("ALL PASS" if failures == 0 else "%d FAIL" % failures))
	get_tree().quit(1 if failures else 0)
