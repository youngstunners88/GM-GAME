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

	await get_tree().process_frame
	if _fail == 0:
		print("EP2_SMELTING_FACILITY: ALL PASS")
		get_tree().quit(0)
	else:
		print("EP2_SMELTING_FACILITY: %d FAILED" % _fail)
		get_tree().quit(1)

const MOLDS_EXPECTED := 3
