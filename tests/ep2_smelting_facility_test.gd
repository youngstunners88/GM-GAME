extends Node
## Gate for CHAMBER 0 — the Smelting Facility (Inferno Bull + Winchester).
##
## Spec: artifacts/episode2-gold-mine/chambers/00_SMELTING_FACILITY.md
##
## What it locks, and why each one is here rather than being obvious:
##
##  * THE BEAT SHEET RUNS TO COMPLETION from arrival to exit, driven only by
##    the verbs a player actually has. A story chamber that cannot be finished
##    is a soft-lock in the middle of the episode.
##  * A LINE CANNOT BE CUT OFF. Hammering interact must not skip the Bull's
##    dialogue — the hold timers are the measured clip durations, and a beat
##    that advances early means the player never hears the character.
##  * THE RIFLE IS A REAL UNLOCK. shoot() must refuse before the hand-off and
##    work after it. This is the mechanical point of the whole scene.
##  * IT MINTS NOTHING. Chamber 0 carries no white-paper mechanic; the economy
##    starts at Fort Knox. `gold_awarded` and `gold_forfeited` must be hard 0,
##    and `early_claim()` must refuse — otherwise a habitual dash could route a
##    payout through a chamber that has no principal behind it.
##  * IT IS A DROP-IN SIBLING of the Miner Shaft, answering the exact interface
##    ep2_session_root calls, so the session root's guards and commit boundary
##    keep working with no special case.
##  * THE SESSION ROOT REALLY ROUTES TO IT. Same class of assertion as the
##    reachability gate: a chamber nothing loads is a chamber nobody plays.
##
## FAILING-FIRST: every assertion below was false before 2026-09-12 — the scene
## did not exist and the session root had a single hardcoded CHAMBER_SCENE.
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless \
##        res://tests/ep2_smelting_facility_test.tscn

const SMELT := preload("res://src/episode2/chamber/smelting_facility.tscn")
const ROOT := preload("res://src/episode2/session/ep2_session_root.tscn")

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])


## Drive `seconds` of simulated time at a fixed step. Deterministic — no frame
## clock involved, same pattern as every other Episode 2 gate.
func _run(c: Node, seconds: float) -> void:
	var step := 1.0 / 60.0
	var n := int(seconds / step)
	for i in n:
		c.step(step)


func _ready() -> void:
	await get_tree().process_frame
	print("EP2 SMELTING FACILITY:")

	var c = SMELT.instantiate()
	add_child(c)
	c.intro_film = false          # the conversation on its own; the film has tests/ep2_cinematic_test.gd
	c.setup(0, [], 0)
	await get_tree().process_frame

	# --- 1. arrival hands over control ---------------------------------------
	_check("starts on ARRIVAL", c.get_beat() == c.Beat.ARRIVAL, c.get_beat_name())
	_check("no rifle at the start", not c.has_winchester())
	_check("shoot() refuses before the hand-off", c.shoot() == false)
	_run(c, 1.2)
	_check("arrival hands over to walking (-> APPROACH)", c.get_beat() == c.Beat.APPROACH,
		c.get_beat_name())

	# --- 2. approach: you have to actually cross the floor --------------------
	var start_z: float = c.get_player_z()
	_run(c, 1.0)
	_check("standing still does NOT advance the meeting", c.get_beat() == c.Beat.APPROACH,
		c.get_beat_name())
	c.walk(1.0)
	_run(c, 6.0)
	c.walk_stop()
	_check("walking moved the player toward the Bull", c.get_player_z() > start_z + 3.0,
		"(%.1f -> %.1f)" % [start_z, c.get_player_z()])
	_check("reaching the Bull starts the meeting (-> DRINK)", c.get_beat() == c.Beat.DRINK,
		c.get_beat_name())

	# --- 3. the Bull cannot be talked over ------------------------------------
	# vo_bull_made_it measures 3.58s. Mashing interact inside that window must
	# do nothing, or the player never hears the character beat.
	var beat_before: int = c.get_beat()
	var spammed_ok := true
	for i in 20:
		if c.start_rig():
			spammed_ok = false
		c.step(1.0 / 60.0)
	_check("mashing interact cannot cut off a line", spammed_ok and c.get_beat() == beat_before,
		"(beat %s, hold %.2f)" % [c.get_beat_name(), c.get_line_hold()])
	_run(c, 4.0)
	_check("interact advances once the line has finished", c.start_rig())
	_check("-> SIZING", c.get_beat() == c.Beat.SIZING, c.get_beat_name())

	# --- 4. the Winchester hand-off -------------------------------------------
	var granted: Array = []
	c.weapon_granted.connect(func(w): granted.append(w))
	_check("interact -> HANDOFF", c.start_rig() and c.get_beat() == c.Beat.HANDOFF,
		c.get_beat_name())
	_check("the rifle is granted", c.has_winchester())
	_check("weapon_granted fired with the Winchester", granted == ["winchester_1886"], str(granted))
	_run(c, 6.0)
	# Founder 2026-09-30: "this is where Lil Blunt now gets his Gun and helmet".
	var gear: Array = []
	c.gear_granted.connect(func(g): gear.append(g))
	_check("interact -> HELMET", c.start_rig() and c.get_beat() == c.Beat.HELMET, c.get_beat_name())
	_check("the miner's helmet is granted", c.has_helmet() and gear == ["miner_helmet"], str(gear))
	_run(c, 7.0)
	_check("interact -> VERB_TEACH", c.start_rig() and c.get_beat() == c.Beat.VERB_TEACH,
		c.get_beat_name())

	# --- 5. the verb teach: the rifle now works -------------------------------
	_check("three molds to break", c.get_molds_left() == MOLDS_EXPECTED,
		str(c.get_molds_left()))
	var hits := 0
	for i in 5:
		if c.shoot():
			hits += 1
		c.step(1.0 / 60.0)
	_check("shooting breaks exactly the molds that exist (no infinite target)",
		hits == MOLDS_EXPECTED, "(%d hits)" % hits)
	_run(c, 0.2)
	_check("clearing the rack advances (-> TERMS)", c.get_beat() == c.Beat.TERMS,
		c.get_beat_name())

	# --- 6. terms, promise, exit ----------------------------------------------
	_run(c, 4.2)
	_check("interact -> PROMISE", c.start_rig() and c.get_beat() == c.Beat.PROMISE,
		c.get_beat_name())
	_run(c, 5.2)
	_check("interact -> EXIT", c.start_rig() and c.get_beat() == c.Beat.EXIT,
		c.get_beat_name())

	var results: Array = []
	c.chamber_cleared.connect(func(r): results.append(r))
	# The parting line runs 7.76s. Walking out before it ends must not resolve.
	c.walk(1.0)
	_run(c, 3.0)
	_check("cannot leave before the parting line finishes", results.is_empty(),
		"(hold %.2f)" % c.get_line_hold())
	_run(c, 12.0)
	c.walk_stop()
	_check("walking out resolves the chamber", results.size() == 1, str(results.size()))

	# --- 7. it mints NOTHING ---------------------------------------------------
	if results.size() == 1:
		var r: Dictionary = results[0]
		_check("gold_awarded is a hard 0", int(r.get("gold_awarded", -1)) == 0, str(r.get("gold_awarded")))
		_check("gold_forfeited is a hard 0", int(r.get("gold_forfeited", -1)) == 0, str(r.get("gold_forfeited")))
		_check("result flags the story chamber", bool(r.get("story", false)))
		_check("result carries the companion", str(r.get("companion", "")) == "inferno_bull")
		_check("result carries the weapon unlock", str(r.get("weapon", "")) == "winchester_1886")
	_check("early_claim() always refuses — nothing here to claim", c.early_claim() == false)
	_check("resolving twice is impossible", c.is_resolved() and not c.is_running())
	c.queue_free()

	# --- 8. drop-in sibling of the Miner Shaft ---------------------------------
	# The session root calls all of these unconditionally. A missing method is a
	# runtime crash the moment a player walks into the room.
	var c2 = SMELT.instantiate()
	add_child(c2)
	var missing: Array = []
	for m in ["setup", "step", "start_rig", "shoot", "take_cover", "leave_cover",
			"early_claim", "get_health", "get_ammo", "get_live_bear_count",
			"get_vest", "is_rig_started", "is_resolved"]:
		if not c2.has_method(m):
			missing.append(m)
	_check("answers the full session-root chamber interface", missing.is_empty(), str(missing))
	_check("declares chamber_cleared", c2.has_signal("chamber_cleared"))
	_check("declares chamber_failed (session root connects it unconditionally)",
		c2.has_signal("chamber_failed"))
	c2.queue_free()

	# --- 9. the session root actually routes here ------------------------------
	# The reachability lesson: logic that nothing loads is logic nobody plays.
	var root = ROOT.instantiate()
	root.input_enabled = false
	add_child(root)
	root.configure([
		{"chamber_z": 6.0, "obstacles": [], "zip_segments": [], "chamber": "smelting_facility"},
	], false)
	root.start()
	for i in 400:
		root.step(1.0 / 60.0)
		if root.get_mode() == Ep2SessionRoot.Mode.CHAMBER:
			break
	var active: Node = root.get_active()
	_check("session root loads the Smelting Facility for that segment",
		active != null and active.get_script() == SMELT.instantiate().get_script(),
		str(active))
	_check("...and it is the smelting scene, not the Miner Shaft",
		active != null and active.has_method("has_winchester"))
	root.queue_free()

	# --- 10. the real game order (founder 2026-09-30): cliff-jump film -> wake at the Bull's boots with the
	# whiskey line -> the meeting.
	var f = SMELT.instantiate()
	add_child(f)
	var said: Array = []
	f.line_spoken.connect(func(id): said.append(id))
	f.setup(0, [], 0)
	_check("the facility opens on the cliff-jump film", f.get_beat() == f.Beat.CINEMATIC and f.get_film() != null, f.get_beat_name())
	_run(f, 13.0)
	_check("after the film he wakes up (-> WAKE)", f.get_beat() == f.Beat.WAKE, f.get_beat_name())
	_check("...at the Bull's boots", f.get_distance_to_bull() <= f.TALK_RANGE, "%.2f" % f.get_distance_to_bull())
	_run(f, 16.0)
	_check("Lil Blunt groans, then the Bull nurses him with whiskey", said.slice(0, 2) == ["vo_lb_wake", "vo_bull_wake"], str(said))
	_check("...and the meeting follows (-> DRINK)", f.get_beat() == f.Beat.DRINK, f.get_beat_name())
	f.queue_free()

	# --- 11. the hangout (founder target 2026-10-01): dressed room + acted hand-overs ------------------------
	var h = SMELT.instantiate()
	add_child(h)
	h.intro_film = false
	h.setup(0, [], 0)
	await get_tree().process_frame
	_check("the hangout is dressed: poster, Gatling and flame lights exist",
		h._dressing.get("poster") != null and h._dressing.get("gatling") != null and (h._dressing.get("flames") as Array).size() >= 3)
	_check("the armory + trophies are in the scene tree", h.find_child("ColtGatling", true, false) != null)
	for tex in ["tex_pinup_poster.jpg", "tex_cowhide.png"]:
		_check("hideout texture on disk: " + tex, ResourceLoader.exists("res://src/episode2/assets/textures/" + tex))
	for glb in ["hideout/gatling.glb", "hideout/bear_standing.glb", "hideout/bear_head.glb", "hideout/ore_cart.glb",
			"hideout/cauldron.glb", "winchester_1886.glb", "inferno_bull_rigged.glb", "lil_blunt_walking_clip.glb",
			"lil_blunt_running_clip.glb"]:
		_check("hideout model on disk: " + glb, ResourceLoader.exists("res://src/episode2/assets/" + glb))
	# The Bull is RIGGED (Meshy) and acts by beat; Lil Blunt has a real walk cycle.
	_check("the Bull is the rigged model with his clips", h._bull_anim != null and h._bull_anim.has_animation(h.BULL_DRINK)
		and h._bull_anim.has_animation(h.BULL_TALK) and h._bull_anim.has_animation(h.BULL_GUN))
	_check("his offering hand is a real bone (hand-overs follow his arm)", h._bull_hand != null
		and h._bull_hand.bone_name == "RightHand" and h._glass_node.get_parent() == h._bull_left_hand)
	# He sits on his crate drinking (the target image), and stands up when he takes your measure.
	_check("the Bull starts seated on his crate", h.is_bull_seated() and h.find_child("BullSeat", true, false) != null)
	h._beat = h.Beat.DRINK
	_run(h, 0.1)
	_check("...drinking while seated", h._bull_clip == h.BULL_SIT, h._bull_clip)
	h._beat = h.Beat.SIZING
	_run(h, 0.2)
	_check("SIZING: he stands up", not h.is_bull_seated() and h._bull_clip == h.BULL_STAND_UP, h._bull_clip)
	_run(h, 4.0)
	_check("...and is standing when the hand-over comes", h._bull_clip != h.BULL_STAND_UP and h._stand_t >= 99.0,
		h._bull_clip)
	_check("Lil Blunt carries a walk + run cycle", h._hero_anim != null and h._hero_anim.has_animation("walk")
		and h._hero_anim.has_animation("run"))
	# the helmet is HANDED OVER: it travels via the Bull's hand, it does not teleport onto his head
	h._beat = h.Beat.HELMET
	h._has_helmet = true
	h._helmet_t = 0.0
	_run(h, 0.3)
	_check("helmet is not on his head the instant it is granted", not h._helmet_on_head)
	var near_hand := false
	for i in 140:
		h.step(1.0 / 60.0)
		var hand: Vector3 = h.get_bull_hand()
		if h._helmet_node.position.distance_to(hand) < 0.35:
			near_hand = true
	_check("the helmet passes through the Bull's outstretched hand", near_hand)
	_run(h, 2.0)
	_check("then it lands on Lil Blunt's head", h._helmet_on_head)
	_check("...and he hops for joy", h._hop_y > 0.0 or h._hop_v != 0.0 or h._anim_t > 0.0)
	# the rifle too
	h._beat = h.Beat.HANDOFF
	h._has_winchester = true
	h._rifle_t = 0.0
	var rifle_near_hand := false
	for i in 200:
		h.step(1.0 / 60.0)
		if h._rifle_node.position.distance_to(h.get_bull_hand()) < 0.35:
			rifle_near_hand = true
	_check("the Winchester passes through the Bull's hand", rifle_near_hand)
	_check("...and ends in Lil Blunt's hands", h._rifle_in_hands)
	# the Bull leans in while handing over, and breathes otherwise
	h._beat = h.Beat.HANDOFF
	h._rifle_t = 1.0
	_run(h, 0.8)
	_check("the Bull leans toward Lil Blunt during a hand-over", h._lean > 0.05, "%.3f" % h._lean)
	_check("...and plays his open-hands offer clip for it", h._bull_clip == h.BULL_TALK, h._bull_clip)
	h._beat = h.Beat.TERMS
	h._hold = 2.0
	_run(h, 0.1)
	_check("his terms come with the hand-on-gun gesture", h._bull_clip == h.BULL_GUN, h._bull_clip)
	h._beat = h.Beat.DRINK
	h._hold = 2.0
	_run(h, 0.1)
	_check("the drink beat plays Stand_and_Drink", h._bull_clip == h.BULL_DRINK, h._bull_clip)
	h.queue_free()

	# --- 12. free roam (founder 2026-10-01): Up fwd, Down back, Left/Right strafe, Space jump, mouse look ------
	var g = SMELT.instantiate()
	add_child(g)
	g.intro_film = false
	g.setup(0, [], 0)
	await get_tree().process_frame
	_run(g, 1.2)                                   # ARRIVAL -> APPROACH: control handed over
	_check("the player has control after arrival", g.has_player_control())
	var p0: Vector3 = g.get_player_position()
	g.set_move_input(Vector2(0.0, 1.0))           # Up arrow / W
	_run(g, 0.5)
	_check("walking plays his walk cycle (legs from the clip)", g._hero_clip == "walk" and g._player_pose.legs_free, g._hero_clip)
	g.set_move_input(Vector2.ZERO)
	var p1: Vector3 = g.get_player_position()
	_check("Up moves Lil Blunt forward (+Z, toward the Bull)", p1.z > p0.z + 1.0 and absf(p1.x - p0.x) < 0.05, str(p1))
	g.set_move_input(Vector2(0.0, -1.0))          # Down arrow / S
	_run(g, 0.3)
	g.set_move_input(Vector2.ZERO)
	_check("Down moves him back", g.get_player_position().z < p1.z - 0.5)
	var p2: Vector3 = g.get_player_position()
	g.set_move_input(Vector2(1.0, 0.0))           # Right arrow / D: screen-right is world -X here
	_run(g, 0.3)
	g.set_move_input(Vector2.ZERO)
	_check("Right strafes him to screen-right", g.get_player_position().x < p2.x - 0.5, str(g.get_player_position()))
	g.set_move_input(Vector2(-1.0, 0.0))          # Left arrow / A
	_run(g, 0.6)
	g.set_move_input(Vector2.ZERO)
	_check("Left strafes him to screen-left", g.get_player_position().x > p2.x + 0.3, str(g.get_player_position()))
	# mouse look turns the view; forward follows the view
	g.look(Vector2(-490.0, 0.0))                  # mouse left ~90 degrees
	_check("mouse look turns the view", absf(g.get_look_yaw()) > 1.3, "%.2f" % g.get_look_yaw())
	var p3: Vector3 = g.get_player_position()
	g.set_move_input(Vector2(0.0, 1.0))
	_run(g, 0.4)
	g.set_move_input(Vector2.ZERO)
	var d3: Vector3 = g.get_player_position() - p3
	_check("Up walks where he is looking", absf(d3.x) > absf(d3.z) and absf(d3.x) > 0.5, str(d3))
	g.look(Vector2(490.0, 0.0))
	# Space: jump, double jump, no triple
	_check("Space jumps", g.jump())
	_run(g, 0.15)
	_check("...he leaves the floor", g.get_player_position().y > 0.3, "%.2f" % g.get_player_position().y)
	_check("Space again = double jump", g.jump())
	_check("no triple jump", not g.jump())
	_run(g, 1.5)
	_check("...and lands", g.get_player_position().y == 0.0)
	# walls, the Bull and the molten channel block him
	g.set_move_input(Vector2(-1.0, 0.0))
	_run(g, 6.0)
	g.set_move_input(Vector2.ZERO)
	_check("the alcove wall stops him", g.get_player_position().x <= g.ROOM_X + 0.001, str(g.get_player_position()))
	g._player_pos = Vector3(g.BULL_POSITION.x, 0.0, g.BULL_POSITION.z - 3.0)
	g.set_move_input(Vector2(0.0, 1.0))
	_run(g, 2.0)
	g.set_move_input(Vector2.ZERO)
	_check("he cannot walk through the Bull", g.get_player_position().distance_to(g.BULL_POSITION) > 0.8,
		str(g.get_player_position()))
	g._player_pos = Vector3(4.0, 0.0, g.CHANNEL_Z - 2.0)
	g.set_move_input(Vector2(0.0, 1.0))
	_run(g, 2.0)
	g.set_move_input(Vector2.ZERO)
	_check("the molten channel is only crossable on the bridge", g.get_player_position().z < g.CHANNEL_Z - 1.0,
		str(g.get_player_position()))
	# the scripted hand-over owns control, then gives it back
	g._beat = g.Beat.SIZING
	g._hold = 0.0
	g.start_rig()
	_check("hand-over: the camera/script owns control", not g.has_player_control())
	var mark: Vector3 = g.get_player_position()
	g.set_move_input(Vector2(0.0, 1.0))
	_run(g, 1.0)
	_check("...movement is ignored during it", g.get_player_position().distance_to(mark) < 0.01)
	_run(g, 3.0)
	_check("...and control returns when the rifle is in his hands", g.has_player_control())
	g.set_move_input(Vector2.ZERO)
	# the session root routes the real keys
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
	_check("session root: the Up arrow / W walks him forward", g.get_player_position().z > before.z + 0.5,
		str(g.get_player_position()))
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	_check("session root: Space is jump", root2._route_free_roam(space) and g.get_player_position().y >= 0.0 and g._vel_y > 0.0)
	var mm := InputEventMouseMotion.new()
	mm.relative = Vector2(120.0, 0.0)
	var yaw0: float = g.get_look_yaw()
	root2._route_free_roam(mm)
	_check("session root: mouse motion turns the view", g.get_look_yaw() < yaw0 - 0.2)
	root2._active = null
	root2.queue_free()
	g.queue_free()

	await get_tree().process_frame
	if _fail == 0:
		print("EP2_SMELTING_FACILITY: ALL PASS")
		get_tree().quit(0)
	else:
		print("EP2_SMELTING_FACILITY: %d FAILED" % _fail)
		get_tree().quit(1)

const MOLDS_EXPECTED := 3
