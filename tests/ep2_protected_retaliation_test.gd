extends Node
var checks := 0
var failures := 0

func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: failures += 1
	print("[PASS] " + label if ok else "[FAIL] " + label)

func aim(c: GoldTownChamber, point: Vector3) -> void:
	var d: Vector3 = point - (c._player_pos + Vector3(0, c.eye_height, 0))
	c._look_yaw = atan2(d.x, d.z)
	c._look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	c._update_camera(0)

func _ready() -> void:
	await get_tree().process_frame
	GameManager.reset_session()
	var session := Ep2SessionRoot.new()
	add_child(session)
	session.set_process(false)
	session.configure([{"chamber": "gold_town"}], false)
	session._enter_chamber()
	var c: GoldTownChamber = session._active
	c.set_physics_process(false)
	c._beat = c.Beat.GEARED
	c._show_active = false
	c._show_blocks_control = false
	c._hold = 0
	var entry: Vector3 = c._player_pos
	var old_purse: int = GameManager.purse_balance("btc")
	var crowd := c.get_people()
	var original_people: int = crowd.people.size()
	for id in ["dude", "minister", "bartender", "sheriff", "rich", "utah", "store_clerk", "stable_assistant"]:
		var cast: Dictionary = {"dude": c._stable_yard.actors[0], "minister": c._minister, "bartender": c._bartender, "sheriff": c._sheriff, "rich": c._rich, "utah": c._utah, "store_clerk": c._shopkeepers[0][1], "stable_assistant": c._stable_yard.actors[1]}
		var f: Ep2TownFolk = cast[id]
		for encounter in 2:
			print("ENCOUNTER ", id, " ", encounter)
			c._player_pos = f.global_position + Vector3(0, 0, 2)
			aim(c, c._player_pos + Vector3(0, 10, 0))
			c._on_player_shot()
			check(id + " missed shot does not retaliate", not c._law.retaliation.active)
			aim(c, f.global_position + Vector3(0, 1.3, 0))
			c._on_player_shot()
			check(id + " registered hit starts immediately " + str(c._law.last_shot), c._law.retaliation.active and c._law.last_shot.get("id") == id)
			if not c._law.retaliation.active: continue
			check(id + " survives initial hit", not f.dead and not f.has_meta("law_wounded"))
			var before: int = c._law.retaliation.shots
			for i in 10: c._on_player_shot()
			check(id + " burst owns one held weapon", f.held_prop("Sharps" if id == "rich" else "GoldenRemington") != null)
			check(id + " controls blocked during draw", not c.has_player_control())
			for i in 30: c.step(1.0 / 60.0)
			check(id + " draw precedes firing", not c._law.retaliation.fired)
			for i in 70: c.step(1.0 / 60.0)
			check(id + " one decisive shot", c._law.retaliation.shots == before + 1)
			await get_tree().process_frame
			check(id + " restarts at recorded entry", c._player_pos.is_equal_approx(entry) and not c._resolved)
			check(id + " state resets for next encounter", not c._law.retaliation.active and c.has_player_control())
			check(id + " narrative and purchases survive", c._beat == c.Beat.GEARED and GameManager.purse_balance("btc") == old_purse)
	check("ordinary population is preserved", c.get_people() == crowd and crowd.people.size() == original_people)
	check("story protection does not start arrest", c._law.law_state == "idle" and c._law.person_hits == 0)
	session.queue_free()
	await get_tree().process_frame
	print("EP2_PROTECTED_RETALIATION: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
