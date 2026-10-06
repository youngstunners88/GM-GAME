extends Node
## Gate for CHAMBER 0 - the Smelting Facility (Inferno Bull, the Winchester, the first-person exit).
##
## Rewritten 2026-10-02 for the founder's new story (skill ep2-bull-handoff-walk): Inferno Bull is seated with his
## whiskey, introduces himself (Blaze protocol), names the price (ONE Bitcoin for the rifle and the helmet), stands,
## WALKS to the gun wall, takes the Winchester off the rack, walks to Lil Blunt and hands it over, does the same with
## the helmet, tells him the bears have taken the Gold Mine and asks him to hunt them together; from the verb teach on
## the game is a first-person shooter/RPG and they leave together.
##
## What it locks (and why):
##  * THE BEAT SHEET RUNS TO COMPLETION driven only by the verbs a player has. A story chamber that cannot be finished
##    is a soft-lock in the middle of the episode.
##  * A LINE CANNOT BE CUT OFF, and the Bull speaks at a natural pace (voice speed >= 1.0: 0.8 was "he speaks way too slowly").
##  * THE STORY IS LOCKED: Blaze/Inferno intro, one Bitcoin, bears in the Gold Mine, Fort Knox stake - and no Diamonds.
##  * THE RIFLE AND THE HELMET ARE REALLY HANDED OVER by an actor that walks, not teleported.
##  * IT MINTS NOTHING: gold_awarded / gold_forfeited are a hard 0 (btc_paid is a narrative ledger line).
##  * FREE ROAM: Up/W fwd, Down/S back, Left/A + Right/D strafe, Space jump (double), mouse look (skill ep2-free-roam-controls).
##
## Run: godot --headless res://tests/ep2_smelting_facility_test.tscn

const SMELT := preload("res://src/episode2/chamber/smelting_facility.tscn")
const ROOT := preload("res://src/episode2/session/ep2_session_root.tscn")

var _fail: int = 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])


func _run(c: Node, seconds: float) -> void:
	var step := 1.0 / 60.0
	for i in int(seconds / step):
		c.step(step)


## Step until `pred` is true or `limit` seconds pass. Returns whether it became true.
func _until(c: Node, limit: float, pred: Callable) -> bool:
	var step := 1.0 / 60.0
	for i in int(limit / step):
		if pred.call():
			return true
		c.step(step)
	return pred.call()


func _manifest_text(id: String) -> String:
	var f := FileAccess.open("res://assets/audio-manifest.json", FileAccess.READ)
	if f == null:
		return ""
	var d: Variant = JSON.parse_string(f.get_as_text())
	for v in (d as Dictionary).get("voice", []):
		if str(v.get("id", "")) == id:
			return str(v.get("text", ""))
	return ""


func _manifest_speed(id: String) -> float:
	var f := FileAccess.open("res://assets/audio-manifest.json", FileAccess.READ)
	var d: Variant = JSON.parse_string(f.get_as_text())
	for v in (d as Dictionary).get("voice", []):
		if str(v.get("id", "")) == id:
			return float((v.get("voice_settings", {}) as Dictionary).get("speed", 1.0))
	return 0.0


func _ready() -> void:
	await get_tree().process_frame
	print("EP2 SMELTING FACILITY:")

	var c = SMELT.instantiate()
	add_child(c)
	c.intro_film = false
	c.setup(0, [], 0)
	await get_tree().process_frame
	var said: Array = []
	c.line_spoken.connect(func(id): said.append(id))
	var granted: Array = []
	c.weapon_granted.connect(func(w): granted.append(w))
	var gear: Array = []
	c.gear_granted.connect(func(g): gear.append(g))
	var paid: Array = []
	c.payment_made.connect(func(n): paid.append(n))
	var results: Array = []
	c.chamber_cleared.connect(func(r): results.append(r))

	# --- 1. arrival hands over control --------------------------------------
	_check("starts on ARRIVAL", c.get_beat() == c.Beat.ARRIVAL, c.get_beat_name())
	_check("no rifle at the start", not c.has_winchester())
	# Regression (founder 2026-10-02 "a box follows Inferno Bull"): the seat crate was parented to the walking actor.
	var stray: Array = []
	for ch in c.get_bull().get_children():
		if ch is MeshInstance3D:
			stray.append(ch.name)
	_check("no mesh is parented directly to the Bull actor (nothing follows him)", stray.is_empty(), str(stray))
	_check("his seat is scenery in the room, not a child of the actor", c.get_bull().get_node_or_null("BullSeat") == null
		and c._visuals.get_node_or_null("BullSeat") != null)
	_check("shoot() refuses before the hand-off", c.shoot() == false)
	_check("the Bull is the rigged actor, seated on his crate", c.get_bull() != null and c.is_bull_seated()
		and c.find_child("BullSeat", true, false) != null)
	_run(c, 1.2)
	_check("arrival hands over to walking (-> APPROACH)", c.get_beat() == c.Beat.APPROACH, c.get_beat_name())
	_check("the player has control", c.has_player_control())

	# --- 2. FREE ROAM (founder 2026-10-01): Up fwd, Down back, Left/Right strafe, Space jump, mouse look ----------
	var p0: Vector3 = c.get_player_position()
	c.set_move_input(Vector2(0.0, 1.0))
	_run(c, 0.5)
	_check("walking plays his walk cycle (legs from the clip)", c._hero_clip == "walk" and c._player_pose.legs_free, c._hero_clip)
	c.set_move_input(Vector2.ZERO)
	var p1: Vector3 = c.get_player_position()
	_check("Up moves Lil Blunt forward (+Z)", p1.z > p0.z + 1.0 and absf(p1.x - p0.x) < 0.05, str(p1))
	c.set_move_input(Vector2(0.0, -1.0))
	_run(c, 0.3)
	c.set_move_input(Vector2.ZERO)
	_check("Down moves him back", c.get_player_position().z < p1.z - 0.5)
	var p2: Vector3 = c.get_player_position()
	c.set_move_input(Vector2(1.0, 0.0))
	_run(c, 0.3)
	c.set_move_input(Vector2.ZERO)
	_check("Right strafes him to screen-right (-X)", c.get_player_position().x < p2.x - 0.5, str(c.get_player_position()))
	c.set_move_input(Vector2(-1.0, 0.0))
	_run(c, 0.6)
	c.set_move_input(Vector2.ZERO)
	_check("Left strafes him to screen-left", c.get_player_position().x > p2.x + 0.3, str(c.get_player_position()))
	c.look(Vector2(-490.0, 0.0))
	_check("mouse look turns the view", absf(c.get_look_yaw()) > 1.3, "%.2f" % c.get_look_yaw())
	var p3: Vector3 = c.get_player_position()
	c.set_move_input(Vector2(0.0, 1.0))
	_run(c, 0.4)
	c.set_move_input(Vector2.ZERO)
	var d3: Vector3 = c.get_player_position() - p3
	_check("Up walks where he is looking", absf(d3.x) > absf(d3.z) and absf(d3.x) > 0.5, str(d3))
	c.look(Vector2(490.0, 0.0))
	_check("Space jumps", c.jump())
	_run(c, 0.15)
	_check("...he leaves the floor", c.get_player_position().y > 0.3, "%.2f" % c.get_player_position().y)
	_check("Space again = double jump", c.jump())
	_check("no triple jump", not c.jump())
	_run(c, 1.5)
	_check("...and lands", c.get_player_position().y == 0.0)
	c.set_move_input(Vector2(-1.0, 0.0))
	_run(c, 6.0)
	c.set_move_input(Vector2.ZERO)
	_check("the alcove wall stops him", c.get_player_position().x <= c.ROOM_X + 0.001, str(c.get_player_position()))
	c._player_pos = Vector3(4.0, 0.0, c.CHANNEL_Z - 2.0)
	c.set_move_input(Vector2(0.0, 1.0))
	_run(c, 2.0)
	c.set_move_input(Vector2.ZERO)
	_check("the molten channel is only crossable on the bridge", c.get_player_position().z < c.CHANNEL_Z - 1.0,
		str(c.get_player_position()))

	# --- 3. approach: you have to cross the floor ----------------------------------------------------------------
	c._player_pos = Vector3(0.0, 0.0, 0.0)
	c._look_yaw = atan2(c.BULL_POSITION.x, c.BULL_POSITION.z)
	_run(c, 1.0)
	_check("standing still does NOT start the meeting", c.get_beat() == c.Beat.APPROACH, c.get_beat_name())
	c.set_move_input(Vector2(0.0, 1.0))
	_until(c, 6.0, func(): return c.get_beat() != c.Beat.APPROACH)
	c.set_move_input(Vector2.ZERO)
	_check("reaching the Bull starts the meeting (-> DRINK)", c.get_beat() == c.Beat.DRINK, c.get_beat_name())

	# --- 4. DRINK: seated with his whiskey, he introduces himself ---------------------------------------------
	_check("he is still seated while he introduces himself", c.is_bull_seated())
	_check("a line is playing (hold > 0)", c.get_line_hold() > 0.0)
	var spam_ok := true
	for i in 20:
		if c.start_rig():
			spam_ok = false
		c.step(1.0 / 60.0)
	_check("mashing interact cannot cut off a line", spam_ok and c.get_beat() == c.Beat.DRINK)
	_until(c, 60.0, func(): return c.get_beat() != c.Beat.DRINK)
	var intro_ids: Array = said.filter(func(x): return str(x).begins_with("vo_bull_intro") or x == "vo_lb_intro_reply")
	_check("intro: Bull (x3) then Lil Blunt answers", intro_ids == ["vo_bull_intro1", "vo_bull_intro2", "vo_bull_intro3", "vo_lb_intro_reply"], str(intro_ids))
	_check("-> SIZING (the deal)", c.get_beat() == c.Beat.SIZING, c.get_beat_name())

	# --- 5. SIZING: the price, he stands, Lil Blunt pays ONE Bitcoin ---------------------------------------------------
	_check("the show owns Lil Blunt during the deal", not c.has_player_control())
	_until(c, 60.0, func(): return c.get_beat() != c.Beat.SIZING)
	_check("he named the price, Lil Blunt agreed", said.has("vo_bull_deal1") and said.has("vo_bull_deal2") and said.has("vo_lb_deal_ok"), str(said))
	_check("Lil Blunt paid exactly ONE Bitcoin (the coin left him)", paid == [1] and c.get_btc_paid() == 1, str(paid))
	_check("the Bull STOOD UP from his crate", not c.is_bull_seated())
	_check("-> HANDOFF", c.get_beat() == c.Beat.HANDOFF, c.get_beat_name())

	# --- 6. HANDOFF: the Bull WALKS to the wall, takes the Winchester, walks back, hands it over -------------------------
	var bull = c.get_bull()
	var start_pos: Vector3 = bull.position
	_until(c, 20.0, func(): return bull.position.distance_to(c.WALL_STAND) < 0.3)
	_check("he walks to the gun wall (no teleport: it took time and he is there)", bull.position.distance_to(c.WALL_STAND) < 0.3
		and start_pos.distance_to(c.WALL_STAND) > 5.0, str(bull.position))
	_check("while walking he plays the walk cycle (checked as he set off)", bull.walk_clip == "walk")
	_check("nobody has the rifle yet", not c.has_winchester())
	_until(c, 20.0, func(): return (c._rifle_node.get_parent() as Node).name == "Holder")
	_check("he takes the Winchester off the rack into his right hand (on the hand bone)",
		(c._rifle_node.get_parent() as Node).name == "Holder" and c._rifle_node.get_parent().get_parent().name == "Att_RightHand",
		str(c._rifle_node.get_parent().get_path()))
	_until(c, 40.0, func(): return c.has_winchester())
	_check("he hands it to Lil Blunt (weapon_granted)", granted == ["winchester_1886"], str(granted))
	_check("...walked to him: the Bull is next to Lil Blunt", bull.position.distance_to(Vector3(c.get_player_position().x, 0.0, c.get_player_position().z)) < 1.6)
	_check("the rifle line was spoken", said.has("vo_bull_rifle"))
	_until(c, 20.0, func(): return c.get_beat() != c.Beat.HANDOFF)
	_check("-> HELMET", c.get_beat() == c.Beat.HELMET, c.get_beat_name())

	# --- 7. HELMET: same again ---------------------------------------------------------------------------------------
	_until(c, 20.0, func(): return bull.position.distance_to(c.HELMET_STAND) < 0.3)
	_check("he walks to the helmet peg", bull.position.distance_to(c.HELMET_STAND) < 0.3, str(bull.position))
	_check("no helmet on Lil Blunt yet", not c.has_helmet() and not c._helmet_on_head)
	_until(c, 60.0, func(): return c.has_helmet())
	_check("he puts the miner's helmet on Lil Blunt (gear_granted)", gear == ["miner_helmet"] and c._helmet_on_head, str(gear))
	_check("weapon first, then helmet", granted.size() == 1 and gear.size() == 1)
	_until(c, 30.0, func(): return c.get_beat() != c.Beat.HELMET)
	_check("-> VERB_TEACH", c.get_beat() == c.Beat.VERB_TEACH, c.get_beat_name())

	# --- 8. FIRST PERSON: the shooter/RPG mode starts ------------------------------------------------------------------
	_check("first person: the camera is his eye", c.is_fps() and c.get_episode_mode() == Episode2Mode.Mode.FPS)
	_check("...the player has control again (WASD + mouse)", c.has_player_control())
	_check("...and the hero model is hidden (no body in first person)", not c._player_node.visible)
	_check("five wall targets to break", c.get_molds_left() == 5)
	# The rifle is LOCKED until Inferno has taught it (founder 2026-10-04); tests/ep2_range_lesson_test.gd plays the
	# whole lesson. Here the facility's skip hook stands in for it, with a perfectly steady hand.
	c.aim_at(c.get_mold_position(0))
	_check("the rifle does NOT fire before the lesson", c.shoot() == false and c.get_molds_left() == 5 and c.get_gun().shots_fired == 0)
	c.debug_skip_lesson()
	c.spread_scale = 0.0
	c.aim_at(c.get_mold_position(0) + Vector3(6.0, 3.0, 0.0))        # far off the targets
	_check("firing at nothing breaks nothing", c.shoot() == false and c.get_molds_left() == 5)
	_run(c, 0.8)                                                      # the lever cycles between shots
	for i in 5:
		c.aim_at(c.get_mold_position(i))
		_check("a shot on target %d breaks exactly that target" % i, c.shoot() == true and c._mold_broken[i])
		_run(c, 0.8)
	_check("shooting does not break more than exist", c.get_molds_left() == 0)
	_until(c, 8.0, func(): return c.get_beat() != c.Beat.VERB_TEACH)    # his closing line, then on
	_check("clearing the rack advances (-> TERMS)", c.get_beat() == c.Beat.TERMS, c.get_beat_name())

	# --- 9. TERMS + PROMISE: the bears, the partnership -----------------------------------------------------------------
	_until(c, 60.0, func(): return c.get_beat() == c.Beat.EXIT)
	_check("bears on the claims, then the partnership offer, then Lil Blunt agrees",
		said.has("vo_bull_bears") and said.has("vo_bull_partner") and said.has("vo_lb_partner_ok"))
	_check("the order is bears -> partner -> yes", said.find("vo_bull_bears") < said.find("vo_bull_partner")
		and said.find("vo_bull_partner") < said.find("vo_lb_partner_ok"))
	_check("-> EXIT, the Bull is the companion (beside you)", c.get_beat() == c.Beat.EXIT, c.get_beat_name())

	# --- 10. EXIT together ----------------------------------------------------------------------------------------------------
	c._player_pos = Vector3(c.EXIT_POSITION.x, 0.0, c.EXIT_POSITION.z - 4.0)
	c.aim_at(Vector3(c.EXIT_POSITION.x, 1.5, c.EXIT_POSITION.z + 5.0))
	c.set_move_input(Vector2(0.0, 1.0))
	_run(c, 1.0)
	_check("cannot leave before his parting line finishes", results.is_empty(), "(hold %.2f)" % c.get_line_hold())
	_until(c, 30.0, func(): return results.size() == 1)
	c.set_move_input(Vector2.ZERO)
	_check("walking out through the Fort Knox door resolves the chamber", results.size() == 1, str(results.size()))
	if results.size() == 1:
		var r: Dictionary = results[0]
		_check("gold_awarded is a hard 0", int(r.get("gold_awarded", -1)) == 0)
		_check("gold_forfeited is a hard 0", int(r.get("gold_forfeited", -1)) == 0)
		_check("the price is on the ledger: btc_paid = 1", int(r.get("btc_paid", -1)) == 1)
		_check("result flags the story chamber, the companion, the weapon", bool(r.get("story", false))
			and str(r.get("companion", "")) == "inferno_bull" and str(r.get("weapon", "")) == "winchester_1886")
		_check("result says the next mode is first person", str(r.get("next_mode", "")) == "fps")
	_check("early_claim() always refuses - nothing here to claim", c.early_claim() == false)
	_check("resolving twice is impossible", c.is_resolved() and not c.is_running())
	c.queue_free()

	# --- 11. THE STORY IS LOCKED (founder 2026-10-02) + natural pace --------------------------------------------------------
	var t1: String = _manifest_text("vo_bull_intro1")
	_check("he introduces himself as Inferno Bull from the Blaze protocol", "Inferno Bull" in t1 and "Blaze" in t1, t1)
	var t3: String = _manifest_text("vo_bull_intro3")
	_check("heat and debt: TitanX minted and bought-and-burned, not a whitepaper reading", "TitanX" in t3 and "burn" in t3.to_lower(), t3)
	_check("the price is ONE Bitcoin for the rifle and the helmet", "one Bitcoin" in _manifest_text("vo_bull_deal2")
		and "helmet" in _manifest_text("vo_bull_deal2"))
	var tb: String = _manifest_text("vo_bull_bears")
	_check("the bears have moved into the Gold Mine; time to hunt them together", "bears" in tb and "Gold Mine" in tb and "hunting" in tb, tb)
	var tp: String = _manifest_text("vo_bull_partner")
	_check("partnership: deeper into Fort Knox, clear the bears, haul out and stake the gold", "Fort Knox" in tp and "stake" in tp, tp)
	var no_diamonds := true
	for id in ["vo_bull_intro1", "vo_bull_intro2", "vo_bull_intro3", "vo_bull_deal1", "vo_bull_deal2", "vo_bull_rifle",
			"vo_bull_helmet2", "vo_bull_bears", "vo_bull_partner", "vo_bull_exit"]:
		if "iamond" in _manifest_text(id):
			no_diamonds = false
	_check("no Diamonds mechanic is stapled into his speech (Diamonds stay Episode 1)", no_diamonds)
	var natural := true
	for id in ["vo_bull_wake", "vo_bull_intro1", "vo_bull_intro2", "vo_bull_intro3", "vo_bull_deal1", "vo_bull_deal2",
			"vo_bull_rifle", "vo_bull_helmet2", "vo_bull_bears", "vo_bull_partner", "vo_bull_exit"]:
		if _manifest_speed(id) < 1.0:
			natural = false
	_check("the Bull speaks at a natural pace (voice speed >= 1.0; 0.8 was 'way too slowly')", natural)

	# --- 12. the Bull is a real rig: clips, IK, matte materials, a visible glass --------------------------------------
	var h = SMELT.instantiate()
	add_child(h)
	h.intro_film = false
	h.setup(0, [], 0)
	await get_tree().process_frame
	var hb = h.get_bull()
	_check("rig clips: idle, sit, stand-up, walk, run", hb.anim.has_animation("Idle_02") and hb.anim.has_animation("Sit_and_Drink")
		and hb.anim.has_animation("Sit_to_Stand_Transition_M") and hb.anim.has_animation("walk") and hb.anim.has_animation("run"))
	_check("two-bone arm IK on both arms", hb.reach_weight("Right") == 0.0 and hb.reach_weight("Left") == 0.0)
	hb.reach("Right", hb.global_position + Vector3(0.0, 2.2, 0.6), 0.2, 0.0)
	for i in 30:
		hb.step(1.0 / 60.0)
	_check("a reach eases the arm IK in", hb.reach_weight("Right") >= 0.97)
	hb.release("Right", 0.2)
	for i in 30:
		hb.step(1.0 / 60.0)
	_check("...and back out", hb.reach_weight("Right") <= 0.01)
	var matte := true
	var body_materials := 0
	for mi in hb.model.find_children("*", "MeshInstance3D", true, false):
		var sm: Material = (mi as MeshInstance3D).get_surface_override_material(0)
		if sm is StandardMaterial3D:
			var material := sm as StandardMaterial3D
			# Hand-attached rifle/glass meshes also live under this skeleton.
			# Their separate metal/glass materials are not the Bull skin atlas.
			if material.resource_name != "InfernoBullRestoredPBR":
				continue
			body_materials += 1
			# Mapped armor can be metal; fur/leather must not inherit glTF's
			# missing-map metallic=1 default that caused the original oil patch.
			matte = matte and material.metallic <= 0.651 and material.metallic_texture != null
			matte = matte and material.roughness_texture != null and material.normal_enabled
			if material.metallic_texture:
				# Headless Dummy rendering cannot read GPU texture pixels. Read
				# the authored map for this source-level material regression gate.
				var pixels: Image = Image.load_from_file("res://src/episode2/assets/textures/bull_metal_rough.png")
				if pixels.is_compressed():
					pixels.decompress()
				var nonmetal := 0
				for y in range(0, pixels.get_height(), 32):
					for x in range(0, pixels.get_width(), 32):
						if pixels.get_pixel(x, y).b < 0.1:
							nonmetal += 1
				matte = matte and nonmetal > 700
	_check("Bull PBR keeps fur/leather nonmetal with bounded armor highlights", matte and body_materials > 0)
	var gs: Vector3 = h._glass_node.global_transform.basis.get_scale()
	_check("his whiskey glass is real-sized (world scale ~1 in the hand-bone holder, not 2 mm)", absf(gs.x - 1.0) < 0.15, str(gs))
	_check("the glass rides his hand bone", h._glass_node.get_parent().get_parent().name == "Att_LeftHand")
	h.queue_free()

	# --- 13. the session root loads it and routes the REAL keys ---------------------------------------------------------------
	var root = ROOT.instantiate()
	add_child(root)
	root.input_enabled = false
	root.configure([
		{"chamber_z": 6.0, "obstacles": [], "zip_segments": [], "chamber": "smelting_facility"},
	], false)
	root.start()
	for i in 400:
		root.step(1.0 / 60.0)
		if root.get_mode() == Ep2SessionRoot.Mode.CHAMBER:
			break
	var active: Node = root.get_active()
	_check("session root loads the Smelting Facility for that segment", active != null and active.has_method("has_winchester"), str(active))
	_check("...and answers the Episode2Mode question (HIDEOUT before the exit, FPS after)",
		root.get_episode_mode() == Episode2Mode.Mode.HIDEOUT)
	root.queue_free()

	var g = SMELT.instantiate()
	add_child(g)
	g.intro_film = false
	g.setup(0, [], 0)
	await get_tree().process_frame
	_run(g, 1.2)
	var root2 = ROOT.instantiate()
	add_child(root2)
	root2._active = g
	root2._mode = Ep2SessionRoot.Mode.CHAMBER
	var before: Vector3 = g.get_player_position()
	Input.action_press("move_up")
	root2._poll_free_roam()
	_run(g, 0.5)
	Input.action_release("move_up")
	root2._poll_free_roam()
	_check("session root: the Up arrow / W walks him forward", g.get_player_position().z > before.z + 0.5, str(g.get_player_position()))
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	_check("session root: Space is jump", root2._route_free_roam(space) and g._vel_y > 0.0)
	var mm := InputEventMouseMotion.new()
	mm.relative = Vector2(120.0, 0.0)
	var yaw0: float = g.get_look_yaw()
	root2._route_free_roam(mm)
	_check("session root: mouse motion turns the view", g.get_look_yaw() < yaw0 - 0.2)
	root2._active = null
	root2.queue_free()
	g.queue_free()

	# --- 14. the film hands over to the wake-up -----------------------------------------------------------------------------
	var f = SMELT.instantiate()
	add_child(f)
	var said2: Array = []
	f.line_spoken.connect(func(id): said2.append(id))
	f.setup(0, [], 0)
	_check("the facility opens on a film", f.get_beat() == f.Beat.CINEMATIC and (f.get_video_film() != null or f.get_film() != null), f.get_beat_name())
	if f.get_video_film() != null:
		# The Seedance transition film: it starts on the same frame and the hideout is NOT built yet (no hitch).
		_check("the Seedance film is playing from frame 0 (no delay)", f.get_video_film().elapsed() == 0.0 and not f._room_built)
		_run(f, 0.5)
		_check("...the film's first second is not delayed by a build: still not built at 0.5 s", not f._room_built and f.get_beat() == f.Beat.CINEMATIC)
		_run(f, 8.0)
		var _guard: int = 0
		while not f._room_ready and _guard < 600:      # the pre-build is sliced over frames behind the film
			_guard += 1
			await get_tree().process_frame
		# Founder 2026-10-04: "a long period of blank screen that delays for no reason. Fix it." The hideout is now
		# built WHILE THE FILM PLAYS OVER IT (hidden behind the full-screen film), a few seconds in, so the cut to
		# target practice is instant instead of a frozen blank build after the film. tests/ep2_transition_prebuild_test
		# gates the whole behaviour; here we just confirm it happened behind the still-playing film.
		_check("...the hideout is pre-built behind the film (no blank-screen build at the cut)", f._room_ready and f.get_beat() == f.Beat.CINEMATIC)
		var got_btc: Array = []
		f.payment_made.connect(func(n): got_btc.append(n))
		var got_w: Array = []
		f.weapon_granted.connect(func(id): got_w.append(id))
		_until(f, SmeltingFacilityChamber.FILM_SECONDS + 5.0, func(): return f.get_beat() != f.Beat.CINEMATIC)
		_check("when the film ends the story it told is in the game: Winchester + helmet + 1 BTC",
			f.has_winchester() and f.has_helmet() and f.get_btc_paid() == 1 and got_btc == [1] and got_w == ["winchester_1886"], str(got_btc))
		_check("...and play resumes at target practice in first person", f.get_beat() == f.Beat.VERB_TEACH and f.is_fps() and f.has_player_control(), f.get_beat_name())
		_check("...with the Bull standing at his mark", f.get_bull().position.distance_to(f.BULL_REST) < 0.05)
		_check("...and the film node is gone", f.get_video_film() == null)
		_check("film resume: Bull holds his whiskey", f._glass_node.get_parent() == f.get_bull().holder("LeftHand"))
		_check("film resume: Bull's own rifle is separate from the sold reward", f._bull_guard_rifle != f._rifle_node and f._bull_guard_rifle.get_parent() == f.get_bull().holder("RightHand"))
		_check("film resume: player still owns the traded Winchester", f.has_winchester() and f._rifle_node.get_parent() == f._camera)
		_check("film resume: the rest arm is relaxed without IK", f._bull_rest_arm.resting and f.get_bull().reach_weight("Right") < 0.01)
		f.queue_free()
	else:
		_run(f, 13.0)
		_check("after the film he wakes up (-> WAKE)", f.get_beat() == f.Beat.WAKE, f.get_beat_name())
		_until(f, 40.0, func(): return f.get_beat() == f.Beat.ARRIVAL or f.get_beat() == f.Beat.APPROACH)
		_check("Lil Blunt groans, then the Bull nurses him with whiskey", said2.slice(0, 2) == ["vo_lb_wake", "vo_bull_wake"], str(said2))
		_check("...and control comes back to the player", _until(f, 5.0, func(): return f.has_player_control()))
		f.queue_free()

	await get_tree().process_frame
	if _fail == 0:
		print("EP2_SMELTING_FACILITY: ALL PASS")
		get_tree().quit(0)
	else:
		print("EP2_SMELTING_FACILITY: %d FAILED" % _fail)
		get_tree().quit(1)
