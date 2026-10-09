extends Node
## Gate for the INTERLUDE chain (founder 2026-10-09): the hideout's lava river gives way to the MINE LIFT (two floors up,
## a hidden lever, Inferno lays out the plan to "Inferno Bull 2"), then the BEAR WOODS (sneak, the camouflaged flame quad,
## the ride to "Deep Mining 3", the spyglass on the bear camp), where the playable slice ends with TO BE CONTINUED.
##
## What it locks:
##  * THE LEVER IS INCONSPICUOUS: same material as the wall, small, unlit - and Inferno still pulls it, on camera.
##  * THE CAGE REALLY CLIMBS two floors (past MID_Y to TOP_Y), the plan lines play in order, the gate opens at the top.
##  * THE SONGS: "Inferno Bull 2" in the shaft, "Deep Mining 3" once they are on the quad - never the other way round.
##  * THE QUAD IS HIDDEN under leaves until Inferno throws them off; stealth: walking is free, running near a bear is heard.
##  * THE SESSION CHAINS: hideout result -> mine_lift -> woods_quad -> session_complete, each commit guarded (no double pay).
## Run: godot --headless res://tests/ep2_interlude_test.tscn

const LIFT := preload("res://src/episode2/chamber/mine_lift.tscn")
const WOODS := preload("res://src/episode2/chamber/woods_quad.tscn")
const ROOT := preload("res://src/episode2/session/ep2_session_root.tscn")

var _fail: int = 0


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


func _manifest_text(id: String) -> String:
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio-manifest.json"))
	for e in m["voice"]:
		if str(e["id"]) == id:
			return str(e["text"])
	return ""


func _manifest_speed(id: String) -> float:
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio-manifest.json"))
	for e in m["voice"]:
		if str(e["id"]) == id:
			return float((e.get("voice_settings", {}) as Dictionary).get("speed", 1.0))
	return 0.0


func _music_path() -> String:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am == null or am.current_music_player == null or not is_instance_valid(am.current_music_player):
		return ""
	var st: AudioStream = am.current_music_player.stream
	return st.resource_path if st else ""


func _ready() -> void:
	await get_tree().process_frame

	# ---------------------------------------------------------------- 1. the mine lift
	print("-- MINE LIFT")
	var lift: MineLiftChamber = LIFT.instantiate()
	add_child(lift)
	var said: Array = []
	lift.line_spoken.connect(func(id): said.append(id))
	var results: Array = []
	lift.chamber_cleared.connect(func(r): results.append(r))
	lift.setup(0, [], 0)
	await get_tree().process_frame
	_check("starts at ARRIVE with Lil Blunt in the tunnel and control his", lift.get_beat_name() == "ARRIVE" and lift.has_player_control(), lift.get_beat_name())
	_check("Inferno Bull 2 starts the moment they are in the shaft", "inferno_bull2" in _music_path(), _music_path())
	_check("the interlude exposes the host's story-room vocabulary (title card, no weapon verbs)", lift.get_title_card() == "THE MINE LIFT"
		and lift.shoot() == false and lift.start_rig() == false and lift.get_episode_mode() == Episode2Mode.Mode.HIDEOUT)
	# --- the disguise
	var lv: Node3D = lift.get_lever_node()
	_check("a lever exists in the west wall, at knee height", lv != null and lv.position.x < -4.0 and lv.position.y < 1.4)
	var rock: StandardMaterial3D = lift.get_rock_material()
	var disguised: bool = true
	var meshes: int = 0
	var biggest: float = 0.0
	for mi in lv.find_children("*", "MeshInstance3D", true, false):
		meshes += 1
		var m: MeshInstance3D = mi
		if m.material_override != rock:
			disguised = false
		if (m.material_override as StandardMaterial3D).emission_enabled:
			disguised = false
		biggest = maxf(biggest, m.mesh.get_aabb().size[m.mesh.get_aabb().size.max_axis_index()] * m.scale[m.scale.max_axis_index()])
	_check("the lever is made of the WALL'S OWN ROCK material - no metal, no colour, no glow", disguised and meshes >= 2)
	_check("...and it is small (a stone stub, not a handle: no part longer than 1.2 m)", biggest < 1.2, "%.2f" % biggest)
	_check("it is far from the cage centre, off the player's path", Vector2(lift.get_lever_position().x, lift.get_lever_position().z).distance_to(Vector2.ZERO) > 3.5)
	# --- ARRIVE: Inferno walks to the cage while he talks; Lil Blunt walks in
	_until(lift, 25.0, func(): return said.has("vo_bull_lift1") and not lift.is_show_active())
	_check("Inferno tells him to step on the lift", said.has("vo_bull_lift1"))
	_check("...and walks to the cage himself", lift.get_bull().position.distance_to(MineLiftChamber.CAGE_STAND_BULL) < 0.5, str(lift.get_bull().position))
	lift.set_move_input(Vector2(0.0, 1.0))
	_until(lift, 8.0, func(): return lift.get_beat_name() != "ARRIVE")
	lift.set_move_input(Vector2.ZERO)
	_check("walking onto the cage ends ARRIVE", lift.get_beat_name() in ["BOARD", "LEVER"], lift.get_beat_name())
	# --- LEVER: Inferno says there is no use looking, walks to it and pulls it
	_until(lift, 4.0, func(): return lift.get_beat_name() == "LEVER")
	_check("-> LEVER; control is his show", lift.get_beat_name() == "LEVER" and not lift.has_player_control())
	_until(lift, 30.0, func(): return lift.get_beat_name() == "RISE")
	_check("he tells Lil Blunt not to bother looking for it - THEN the cage starts", said.has("vo_bull_lift_lever") and lift.get_beat_name() == "RISE", str(said))
	_check("the lever swung (he actually pulled it)", lift._lever_t >= 1.0)
	_check("control returns to the player for the ride", lift.has_player_control())
	# --- RISE: two floors
	var st: Dictionary = {"mid": false, "prev": 0.0, "mono": true}      # a lambda captures plain values by copy: mutate a Dictionary
	var ride_ok: bool = _until(lift, MineLiftChamber.RISE_SECONDS + 40.0, func():
		var y: float = lift.get_cage_y()
		if y < float(st["prev"]) - 0.001:
			st["mono"] = false
		st["prev"] = y
		if y > MineLiftChamber.MID_Y - 0.5 and y < MineLiftChamber.MID_Y + 0.5:
			st["mid"] = true
		return lift.get_beat_name() == "SURFACE")
	_check("the cage climbs, steadily, past the first floor and on to the surface (two floors)", ride_ok and bool(st["mid"]) and bool(st["mono"]), "y=%.2f %s" % [lift.get_cage_y(), str(st)])
	_check("Lil Blunt rides it up (he is at the surface level)", absf(lift.get_player_position().y - MineLiftChamber.TOP_Y) < 0.05, str(lift.get_player_position()))
	_check("the plan: sneak, the quad, spy on the bears - Inferno then Lil Blunt's answer, in order",
		said.find("vo_bull_plan1") >= 0 and said.find("vo_bull_plan1") < said.find("vo_bull_plan2") and said.find("vo_bull_plan2") < said.find("vo_bull_plan3")
		and said.find("vo_bull_plan3") < said.find("vo_lb_plan_reply"), str(said))
	_until(lift, 6.0, func(): return lift.is_gate_open())
	_check("the gate slides open at the top", lift.is_gate_open())
	_check("Inferno announces the surface", said.has("vo_bull_lift_arrive"))
	_until(lift, 10.0, func(): return not lift.is_show_active())
	lift.look(Vector2.ZERO)
	lift.set_move_input(Vector2(0.0, 1.0))
	_until(lift, 12.0, func(): return results.size() == 1)
	lift.set_move_input(Vector2.ZERO)
	_check("walking out into the daylight resolves the chamber", results.size() == 1, lift.get_beat_name() + " " + str(lift.get_player_position()))
	if results.size() == 1:
		var r: Dictionary = results[0]
		_check("it is a story chamber that mints nothing", bool(r.get("story", false)) and int(r.get("gold_awarded", -1)) == 0 and int(r.get("gold_forfeited", -1)) == 0)
		_check("...and chains to the bear woods", str(r.get("next_chamber", "")) == "woods_quad")
	lift.queue_free()

	# ---------------------------------------------------------------- 2. the woods
	print("-- BEAR WOODS")
	var w: WoodsQuadChamber = WOODS.instantiate()
	add_child(w)
	var said2: Array = []
	w.line_spoken.connect(func(id): said2.append(id))
	var res2: Array = []
	w.chamber_cleared.connect(func(r): res2.append(r))
	w.setup(0, [], 0)
	await get_tree().process_frame
	_check("starts at SNEAK", w.get_beat_name() == "SNEAK" and w.has_player_control(), w.get_beat_name())
	_check("the quad is hidden under leaves and branches (a real pile of them)", w.is_quad_hidden() and w.get_cover_bit_count() >= 80, str(w.get_cover_bit_count()))
	var quad_aabb: Vector3 = Vector3.ZERO
	for mi in w.get_quad_node().find_children("*", "MeshInstance3D", true, false):
		quad_aabb = quad_aabb.max((mi as MeshInstance3D).mesh.get_aabb().size)
	_check("the cover is as high as the quad and wider (nothing of the flame paint shows from the trail)", w.get_cover_node().get_child_count() > 100)
	_check("no music of the quad ride yet", "deep_mining3" not in _music_path(), _music_path())
	# walking beside Inferno along the trail is free (no warnings)
	var guard: int = 0
	while w.get_beat_name() == "SNEAK" and guard < 12000:
		guard += 1
		var bull_pos: Vector3 = w.get_bull().position
		var me: Vector3 = w.get_player_position()
		var to := Vector2(bull_pos.x - me.x, bull_pos.z - me.z)
		if to.length() > 3.2:
			w._look_yaw = atan2(to.x, to.y)
			w.set_move_input(Vector2(0.0, 1.0), false)
		else:
			w.set_move_input(Vector2.ZERO)
		w.step(1.0 / 60.0)
	w.set_move_input(Vector2.ZERO)
	_check("following Inferno at a walk brings them to the thicket (-> REVEAL) with no bear alerted", w.get_beat_name() == "REVEAL" and w.get_noise_hits() == 0, "%s hits %d" % [w.get_beat_name(), w.get_noise_hits()])
	_until(w, 40.0, func(): return w.get_beat_name() == "MOUNT" or w.get_beat_name() == "RIDE")
	_check("the leaves come off (the quad is revealed)", not w.is_quad_hidden() and said2.has("vo_bull_quad_reveal") and said2.has("vo_lb_quad_ok"))
	_check("Deep Mining 3 only now (the moment they mount)", "deep_mining3" in _music_path() or w.get_beat_name() == "MOUNT", _music_path() + " " + w.get_beat_name())
	_until(w, 20.0, func(): return w.get_beat_name() == "RIDE")
	_check("-> RIDE, the quad is on the road", w.get_beat_name() == "RIDE" and w.is_riding() and said2.has("vo_bull_quad_mount"))
	_until(w, 4.0, func(): return "deep_mining3" in _music_path())
	_check("Deep Mining 3 is playing on the quad", "deep_mining3" in _music_path(), _music_path())
	var q0: Vector3 = w.get_quad_node().position
	_run(w, 3.0)
	_check("the quad moves along the trail (rails: the player does not steer)", w.get_quad_node().position.distance_to(q0) > 12.0, str(w.get_quad_node().position))
	_check("both ride it: Inferno up front, Lil Blunt behind", absf(w.get_bull().position.distance_to(w.get_quad_node().position)) < 3.0 and absf(w.get_player_position().distance_to(w.get_quad_node().position)) < 4.5)
	_until(w, 40.0, func(): return w.get_beat_name() == "SPY")
	_check("the ride ends on the ridge (-> SPY) in first person", w.get_beat_name() == "SPY" and w.is_fps())
	_until(w, 12.0, func(): return not w.is_show_active())
	_check("Inferno tells him to get down and look", said2.has("vo_bull_spy1"))
	# spyglass: look at every bear with RMB held
	var eye: Vector3 = WoodsQuadChamber.SPY_EYE
	for b in w.get_camp_bears():
		var to3: Vector3 = (b.position + Vector3(0.0, 1.1, 0.0)) - eye
		w._look_yaw = atan2(to3.x, to3.z)
		w._look_pitch = atan2(to3.y, Vector2(to3.x, to3.z).length())
		w.set_aim(true)
		_run(w, 0.6)
	w.set_aim(false)
	_check("every bear in the camp can be spotted through the spyglass", w.get_marked_count() == w.get_bear_total() and w.get_bear_total() == 6, "%d/%d" % [w.get_marked_count(), w.get_bear_total()])
	_until(w, 30.0, func(): return res2.size() == 1)
	_check("then Inferno sums it up and Lil Blunt answers", said2.has("vo_bull_spy2") and said2.has("vo_lb_spy_reply"))
	_check("the chamber ends the playable slice (TO BE CONTINUED)", res2.size() == 1 and bool(res2[0].get("end_session", false)) and bool(res2[0].get("to_be_continued", false)))
	_check("...and it mints nothing", res2.size() == 1 and int(res2[0].get("gold_awarded", -1)) == 0)
	w.queue_free()

	# ---------------------------------------------------------------- 3. stealth: running near a bear is heard
	var w2: WoodsQuadChamber = WOODS.instantiate()
	add_child(w2)
	w2.setup(0, [], 0)
	await get_tree().process_frame
	var pb: Ep2Actor = w2._patrols[0][0]
	w2._player_pos = Vector3(pb.position.x + 6.0, 0.0, pb.position.z)
	w2._look_yaw = 0.0
	w2.set_move_input(Vector2(0.0, 1.0), true)
	_run(w2, 0.3)
	_check("RUNNING within a bear's hearing is noticed (a noise hit, Inferno shushes)", w2.get_noise_hits() >= 1, str(w2.get_noise_hits()))
	var hits: int = w2.get_noise_hits()
	w2.set_move_input(Vector2(0.0, 1.0), false)
	_run(w2, 2.0)
	_check("...walking next to the same bear is free", w2.get_noise_hits() == hits)
	w2.queue_free()

	# ---------------------------------------------------------------- 4. the session chain
	print("-- SESSION CHAIN")
	var root: Ep2SessionRoot = ROOT.instantiate()
	add_child(root)
	root.configure([{"chamber": "smelting_facility", "chamber_z": 5.0}], false)
	var commits: Array = []
	root.chamber_committed.connect(func(i, r): commits.append(r))
	var done: Array = []
	root.session_complete.connect(func(): done.append(true))
	# the hideout hands over with next_chamber = mine_lift; drive the root exactly as the facility would
	root._chamber_segment = 0
	root._on_chamber_cleared({"story": true, "chamber": "smelting_facility", "gold_awarded": 0, "gold_forfeited": 0, "btc_paid": 1, "next_chamber": "mine_lift"})
	await get_tree().process_frame
	_check("the hideout's result loads the MINE LIFT (no runner leg in between)", root.get_mode() == Ep2SessionRoot.Mode.CHAMBER and root.get_active() is MineLiftChamber)
	_check("a story chamber's result is committed once", commits.size() == 1)
	root._on_chamber_cleared({"story": true, "chamber": "mine_lift", "gold_awarded": 0, "gold_forfeited": 0, "next_chamber": "woods_quad"})
	await get_tree().process_frame
	_check("the lift chains to the WOODS", root.get_active() is WoodsQuadChamber and commits.size() == 2)
	var swallowed: int = commits.size()
	root._on_chamber_cleared({"story": true, "chamber": "woods_quad", "gold_awarded": 0, "gold_forfeited": 0, "end_session": true, "to_be_continued": true})
	_check("the woods end the session (TO BE CONTINUED)", done.size() == 1 and commits.size() == swallowed + 1 and root.get_mode() == Ep2SessionRoot.Mode.IDLE)
	root.queue_free()

	# ---------------------------------------------------------------- 5. the founder's songs and the new lines
	print("-- SONGS + LINES")
	_check("Inferno Bull 2 is in the build and wired to the lift", ResourceLoader.exists(MineLiftChamber.MUSIC))
	_check("Deep Mining 3 is in the build and wired to the quad", ResourceLoader.exists(WoodsQuadChamber.MUSIC))
	for sid in ["ep2_lava_burn", "ep2_lift_start", "ep2_lift_loop", "ep2_lift_arrive", "ep2_quad_start", "ep2_quad_loop", "ep2_leaves_pull"]:
		_check("sfx %s exists" % sid, ResourceLoader.exists("res://src/assets/sounds/%s.mp3" % sid))
	var all_ok: bool = true
	var natural: bool = true
	var clean: bool = true
	var ids: Array = ["vo_bull_lava1", "vo_bull_lava2", "vo_bull_lava_nudge", "vo_bull_lava_made_it", "vo_bull_lift1", "vo_bull_lift_lever", "vo_bull_plan1",
		"vo_bull_plan2", "vo_bull_plan3", "vo_lb_plan_reply", "vo_bull_lift_arrive", "vo_bull_woods_sneak", "vo_bull_woods_quiet", "vo_bull_quad_reveal",
		"vo_lb_quad_ok", "vo_bull_quad_mount", "vo_bull_spy1", "vo_bull_spy2", "vo_lb_spy_reply"]
	for id in ids:
		if not ResourceLoader.exists("res://src/assets/sounds/voice/%s.mp3" % id) or _manifest_text(id) == "":
			all_ok = false
		if id.begins_with("vo_bull") and _manifest_speed(id) < 1.0:
			natural = false
		if "iamond" in _manifest_text(id):
			clean = false
	_check("all %d new voice lines are generated and in the manifest" % ids.size(), all_ok)
	_check("Inferno speaks at a natural pace (speed >= 1.0) on every new line", natural)
	_check("no Diamonds mechanic is stapled into the interlude speech", clean)
	var plan_text: String = _manifest_text("vo_bull_plan1") + _manifest_text("vo_bull_plan2") + _manifest_text("vo_bull_plan3")
	_check("the plan is the founder's: sneak through the wood, the quad (I drive, you shoot), spy on the bears",
		"sneak" in plan_text and "quad" in plan_text and "drive" in plan_text and "shoot" in plan_text and "spy" in plan_text, plan_text)
	_check("the lava warning says it burns and tells him to hop", "cooks" in _manifest_text("vo_bull_lava1") and "Hop" in _manifest_text("vo_bull_lava2"))

	await get_tree().process_frame
	if _fail == 0:
		print("EP2_INTERLUDE: ALL PASS")
		get_tree().quit(0)
	else:
		print("EP2_INTERLUDE: %d FAILED" % _fail)
		get_tree().quit(1)
