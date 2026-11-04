extends Node
## Founder 2026-11-04: "if you try to shoot Logan. He pulls out a golden revolver ... shoots you dead and you start all over from Dude on the horse. Also If
## the horse gets shot that must carry through so that Lil Blunt is unable to water it ... if they have shot Lil Blunt's horse they should acknowledge that
## and not say 'if you cant shoot the man shoot the horse anymore'." The rule, the carry-through across rooms and saves, and the world's awareness of it.
const LAKE := preload("res://src/episode2/chamber/logans_lake.tscn")
const TRAIL := preload("res://src/episode2/chamber/lake_trail.tscn")
var failures: int = 0


func check(label: String, ok: bool, detail: String = "") -> void:
	print("  [%s] %s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures += 1


func _lake(st: Ep2ArmoryState, mounted: bool = true) -> LogansLakeChamber:
	var c: LogansLakeChamber = LAKE.instantiate() as LogansLakeChamber
	c.handoff = {"arrived_mounted": mounted}
	add_child(c)
	c.set_physics_process(false)
	c.bind_armory(st)
	c.setup(0, [], 0)
	return c


func _advance(c: Node, seconds: float) -> void:
	for i in int(seconds * 30.0):
		c.step(1.0 / 30.0)


func _aim_at_logan(c: LogansLakeChamber) -> void:
	var eye: Vector3 = c._player_pos + Vector3(0, c.eye_height, 0)
	var d: Vector3 = c._logan.global_position + Vector3(0, 1.1, 0) - eye
	c._look_yaw = atan2(d.x, d.z)
	c._look_pitch = atan2(d.y, Vector2(d.x, d.z).length())


func _ready() -> void:
	print("-- EP2 HORSE WOUNDS AND LOGAN")
	_test_state()
	_test_barks()
	_test_trail()
	_test_lake_water()
	_test_logan_rule()
	await _test_session_respawn()
	print("HORSE_LOGAN: %s" % ("ALL PASS" if failures == 0 else "%d FAIL" % failures))
	get_tree().quit(1 if failures else 0)


func _test_state() -> void:
	var st := Ep2ArmoryState.post_hideout()
	check("a new game's horse is sound", st.horse_is_sound())
	st.wound_horse()
	var copy := Ep2ArmoryState.post_hideout()
	copy.restore(JSON.parse_string(JSON.stringify(st.snapshot())))
	check("a wound survives a save and load (snapshot through JSON)", copy.horse_wounds == 1 and not copy.horse_is_sound(), str(copy.horse_wounds))
	st.wound_horse()
	st.wound_horse()
	st.wound_horse()
	check("three wounds is down, and it stops there", st.horse_is_down() and st.horse_wounds == Ep2ArmoryState.HORSE_WOUNDS_MAX)
	st.treat_horse()
	check("Dude's care clears it", st.horse_is_sound())
	var old := Ep2ArmoryState.post_hideout()
	var saved: Dictionary = old.snapshot()
	saved.erase("horse_wounds")
	old.restore(saved)
	check("a save from before this rule loads with a sound horse", old.horse_is_sound())


func _test_barks() -> void:
	var st := Ep2ArmoryState.post_hideout()
	var barks: Array = LakeTrailChamber.BANDIT_BARKS
	check("before it is shot, Hammer's men may call to shoot the horse", "jh_bandit_3" in Ep2WorldFacts.fitting(barks, Ep2WorldFacts.now(st, true)))
	st.wound_horse()
	var after: Array = Ep2WorldFacts.fitting(barks, Ep2WorldFacts.now(st, true))
	check("once shot, nobody says 'shoot the horse' again", not ("jh_bandit_3" in after), str(after))
	check("...and they still have something true to shout", not after.is_empty())
	var on_foot: Array = Ep2WorldFacts.fitting(barks, Ep2WorldFacts.now(st, false))
	check("unhorsed, nobody calls to get him off that horse", not ("jh_bandit_1" in on_foot) and not on_foot.is_empty(), str(on_foot))
	check("Lil Blunt's 'the horse is down' only fits when it is", not Ep2WorldFacts.allows("trail_lb_unhorse", Ep2WorldFacts.now(st, true)))
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.rotation_degrees = Vector3(-40, 0, 0)
	check("a sun up in the sky is day", not Ep2WorldFacts.now(st, true, sun)["night"])
	sun.rotation_degrees = Vector3(30, 0, 0)
	check("a sun under the horizon is night", Ep2WorldFacts.now(st, true, sun)["night"])
	sun.free()


func _test_trail() -> void:
	var st := Ep2ArmoryState.post_hideout()
	var t: LakeTrailChamber = TRAIL.instantiate() as LakeTrailChamber
	add_child(t)
	t.set_physics_process(false)
	t.bind_armory(st)
	t.setup(0, [], 0)
	t._invuln = 0.0
	t._hurt_horse()
	check("a shot on the trail wounds the horse in the state that travels", st.horse_wounds == 1 and t.get_horse_hp() == 2, "%d %d" % [st.horse_wounds, t.get_horse_hp()])
	t._retry_trail()
	check("a retry from the trail start is at Dude's: the horse is patched up", st.horse_is_sound() and t.get_horse_hp() == 3)
	t.free()
	var hurt := Ep2ArmoryState.post_hideout()
	hurt.wound_horse()
	var t2: LakeTrailChamber = TRAIL.instantiate() as LakeTrailChamber
	add_child(t2)
	t2.set_physics_process(false)
	t2.bind_armory(hurt)
	t2.setup(0, [], 0)
	check("a loaded run starts the trail with the horse as it was", t2.get_horse_hp() == 2, str(t2.get_horse_hp()))
	t2.free()


func _test_lake_water() -> void:
	var sound := _lake(Ep2ArmoryState.post_hideout(), false)
	check("a sound horse is at the water, drinking", sound._horse_state == "drink")
	sound.free()
	var st := Ep2ArmoryState.post_hideout()
	st.wound_horse()
	var hurt := _lake(st)
	_advance(hurt, 1.0)
	check("a shot horse does not walk to the water or drink", hurt._horse_state == "hurt" and hurt._horse_clip != "horse_graze", hurt._horse_state)
	hurt._player_pos = hurt._horse.position + Vector3(1.0, 0, 0)
	check("...and cannot be mounted", not hurt.can_mount_horse())
	hurt._advance_to(LogansLakeChamber.Beat.STAGE)
	check("Logan sees it and says so", hurt._dialogue.text == LogansLakeChamber.HORSE_SHOT_LINE, hurt._dialogue.text)
	hurt.free()
	var down := Ep2ArmoryState.post_hideout()
	for i in Ep2ArmoryState.HORSE_WOUNDS_MAX:
		down.wound_horse()
	var gone := _lake(down, false)
	check("a horse shot out from under him is not at the lake at all", gone._horse_state == "gone" and not gone._horse.visible)
	gone._advance_to(LogansLakeChamber.Beat.STAGE)
	check("Logan knows he walked in", gone._dialogue.text == LogansLakeChamber.HORSE_GONE_LINE, gone._dialogue.text)
	gone.free()


func _test_logan_rule() -> void:
	var c := _lake(Ep2ArmoryState.post_hideout(), false)
	var res: Array = []
	c.chamber_cleared.connect(func(r: Dictionary) -> void: res.append(r))
	check("Logan is in the build", c._logan != null)
	if c._logan == null:
		c.free()
		return
	c._player_pos = Vector3(-6, 0, 6)
	c._look_yaw = c._look_yaw + PI
	c._look_pitch = 0.6
	c._on_player_shot()
	check("a shot that misses him is only a warning", not c.logan_is_drawing())
	_aim_at_logan(c)
	c._on_player_shot()
	check("shoot at Logan and he draws", c.logan_is_drawing())
	check("...the golden Remington, the same gun Rich sells", c._logan.find_child("GoldenRemington", true, false) != null)
	check("...and the player has no say in it", not c.has_player_control())
	_advance(c, 0.3)
	check("he is not dead yet: the gold is seen first", res.is_empty() and not c._logan_fired)
	_advance(c, 2.2)
	check("one shot: the room resolves to a respawn at Dude's", res.size() == 1 and bool(res[0].get("respawn_at_dude", false)), str(res))
	c.free()


func _test_session_respawn() -> void:
	var session = load("res://src/episode2/session/ep2_session_root.tscn").instantiate()
	add_child(session)
	session.set_process(false)
	session.armory = Ep2ArmoryState.post_hideout()
	session.armory.wound_horse()
	var lake := _lake(session.armory)
	lake.get_parent().remove_child(lake)
	session.add_child(lake)
	session._active = lake
	session._mode = session.Mode.CHAMBER
	session._chain_id = "logans_lake"
	session._chamber_segment = 0
	session._wire_chamber(lake)
	lake.chamber_cleared.connect(session._on_chamber_cleared, CONNECT_ONE_SHOT)
	check("(test wiring) Logan is in the session's lake", lake._logan != null)
	if lake._logan == null:
		session.queue_free()
		return
	_aim_at_logan(lake)
	lake._on_player_shot()
	_advance(lake, 2.6)
	print("  session: drawing %s resolved %s mode %s segment %s" % [lake.logan_is_drawing(), lake._resolved, session._mode, session._chamber_segment])
	await get_tree().process_frame
	var room: Node = session.get_active()
	check("the session goes back to the trail", room is LakeTrailChamber, str(room))
	if room is LakeTrailChamber:
		var t: LakeTrailChamber = room
		check("...at Dude's end: the very start of the ride", t._route_s < 1.0, str(t._route_s))
		check("...on the horse", t.is_mounted() and t.is_riding())
		check("...which Dude has patched up", session.armory.horse_is_sound() and t.get_horse_hp() == 3)
		check("...hearts full", t.get_health() == t.HEALTH_MAX)
		check("...with the controls back", t.has_player_control())
		check("...and a save taken here keeps the sound horse", int(session.section_checkpoint["state"]["personal_armory"]["horse_wounds"]) == 0)
		# the ride goes round again: the lake he left is parked, Logan's gun is away, and its story can still finish
		var back: bool = session.world_routes.travel(session, "logans_lake", LogansLakeChamber.SPAWN)
		check("riding in again reaches the same lake", back and session.get_active() == lake)
		check("...Logan has put the gun away and is no danger", not lake.logan_is_drawing() and lake._logan.find_child("GoldenRemington", true, false) == null)
		check("...the view is back up, off the ground", lake.has_player_control() and lake.eye_height >= lake.FPS_EYE_HEIGHT, "%s %.2f" % [lake.has_player_control(), lake.eye_height])
		lake._beat = LogansLakeChamber.Beat.OVERLOOK
		lake._staged = true
		lake._talk_t = 0.0
		lake._player_pos = Vector3(-8.0, 6.0, 60.0)
		check("...and his visit can finish: [E] goes on to the ridge", lake.start_rig() and session.get_active() is RiverCoverChamber, str(session.get_active()))
	session.queue_free()
	await get_tree().process_frame
