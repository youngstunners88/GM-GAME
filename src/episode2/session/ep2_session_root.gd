class_name Ep2SessionRoot
extends Node
## Episode 2 — persistent session root. Owns the runner↔chamber loop.
##
## This is the "persistent session root + separate scenes + explicit transition
## states" from architecture rail #5
## (.claude/skills/gm-game-episode2-gold-mine-runner/SKILL.md). The runner and
## runners are disposable; visited story chambers are isolated and retained for backtracking; everything that must survive a mode swap
## — health, cumulative track distance, GOLD totals, which chambers are done —
## lives here, above both of them.
##
## Rail #5 names five specific guards. Each is implemented and each has a
## headless assertion in tests/ep2_session_root_test.gd:
##
##   1. Double-triggered rewards → `_rewarded_chambers`.
##   2. Stale input → `_mode`. Input verbs are routed by mode and are hard
##      no-ops during TRANSITION.
##   3. Duplicate player → `_teardown_active()` frees and NULLS the outgoing
##      scene before the incoming one is instantiated.
##   4. Wrong resume position → `_completed_distance` accumulates the runner's
##      distance at the moment the chamber was entered.
##   5. Visited worlds use disabled isolated viewports; configure clears them for a new run.
##
## ECONOMY: the chamber computes its outcome and emits it; THIS is where it is
## committed to GoldMineSystem (mine_gold / auction pool credit).

signal mode_changed(mode: int)
signal chamber_committed(index: int, result: Dictionary)
signal session_complete
signal session_failed
## The touch profile or the suspended flag may have changed. MobileLayoutManager connects to it the first time it reads
## this node and refreshes at once (it also polls 5x a second, which is all a PAUSED tree can rely on).
signal touch_profile_changed

enum Mode { IDLE, RUNNER, CHAMBER, TRANSITION }

# --- TOUCH (skill ep2-mobile-touch; DECISIONS section 4) -----------------------------------------------------------
# This node IS the profile source for the on-screen controls. MobileLayoutManager reads `touch_profile()` from the first
# node in the group below that has it; the profile names are the manager's. Joined in `_ready` (so there is no gap at the
# hand-off reveal) and only AFTER the scene swap, so it never coexists with the Stage 3 film's legacy group node.
const TOUCH_GROUP := &"touch_controls_wanted"
const PROFILE_RUNNER := &"ep2_runner"
const PROFILE_FOOT := &"ep2_foot"
const PROFILE_FILM := &"ep2_film"
const PROFILE_ROTATE := &"ep2_rotate"
const PROFILE_NONE := &"none"
## Touch-only verbs (no key event, so they can never collide with W = jump + move_up). The layout buttons register them too;
## registering here as well keeps a test without a layout, or a router without a touch layer, working.
const TOUCH_SWIPE := &"ep2_touch_swipe"
const TOUCH_RELOAD := &"ep2_touch_reload"
const TOUCH_AIM := &"ep2_touch_aim"
const TOUCH_JUMP := &"ep2_touch_jump"
const TOUCH_ACTIONS: Array[StringName] = [TOUCH_SWIPE, TOUCH_RELOAD, TOUCH_AIM, TOUCH_JUMP]

const RUNNER_SCENE := preload("res://src/episode2/runner/runner_graybox.tscn")
const CHAMBER_SCENES := {
	"smelting_facility": preload("res://src/episode2/chamber/smelting_facility.tscn"),
	"miner_shaft": preload("res://src/episode2/chamber/miner_shaft.tscn"),
	# The INTERLUDE chain (founder 2026-10-09): after the hideout the runner is paused - a mine lift, then the bear woods.
	"mine_lift": preload("res://src/episode2/chamber/mine_lift.tscn"),
	"woods_quad": preload("res://src/episode2/chamber/woods_quad.tscn"),
	# Out of the woods (founder 2026-10-14): Bull drops Lil Blunt in the GoldMine town - the sheriff, the saloon, the draw.
	"gold_town": preload("res://src/episode2/chamber/gold_town.tscn"),
	"lake_trail": preload("res://src/episode2/chamber/lake_trail.tscn"),
	"logans_lake": preload("res://src/episode2/chamber/logans_lake.tscn"),
}
const DEFAULT_CHAMBER := "miner_shaft"

const DEFAULT_GOLD_PRINCIPAL := 1000

var armory: Ep2ArmoryState = Ep2ArmoryState.new()
var _armory_save_due: float = -1.0
var _runner_armory_checkpoint: Dictionary = {}
var _town_save_due: float = 20.0
var section_checkpoint: Dictionary = {}
var _mode: int = Mode.IDLE
var _active: Node = null
var _plan: Array = []
var _segment: int = 0
var _completed_distance: float = 0.0
var _rewarded_chambers: Dictionary = {}   # index -> true, guard #1
## The segment index the CURRENTLY-LOADED chamber belongs to (guard #1 key).
var _chamber_segment: int = -1
## Which chamber of the current segment is loaded ("" = the segment's own). Interlude chambers chain: a chamber's result
## may carry `next_chamber` (load that one next, in the same segment) or `end_session` (the playable slice ends here).
var _chain_id: String = ""
var _chain_n: int = 0
var _commit_to_economy: bool = true
var _totals: Dictionary = {"gold_awarded": 0, "gold_forfeited": 0, "diamonds_burned": 0, "btc_paid": 0}
## The last profile / suspended flag announced through `touch_profile_changed`.
var _touch_last_profile: StringName = &""
var _touch_last_suspended: bool = false
## True while THIS node holds the tree paused because a touch device is held upright (the 3D runner / hideout cannot be
## framed in portrait: a drawn "turn your phone" cue is up instead). Only this node ever clears it.
var _rotate_paused: bool = false
## A held verb that began as an input EVENT and must end as one: a pause (the touch card, the armory, the rotate cue) freezes
## this node, so the release event of a duck / an aim made DURING it never arrives. `_resync_held_verbs` ends them when polled
## input says the finger or key is already up.
var _duck_by_event: bool = false
var _aim_by_touch: bool = false

func _ready() -> void:
	for action: StringName in TOUCH_ACTIONS:
		TouchActions.ensure_action(action)
	add_to_group(TOUCH_GROUP)
	mode_changed.connect(_on_mode_changed_touch)
	# a window event, not a frame: it still arrives while the tree is paused (the rotate pause)
	get_tree().root.size_changed.connect(_on_window_resized)

func configure(plan: Array, commit_to_economy: bool = true) -> void:
	_persist_town()
	farmer_trip.clear()
	Ep2DrawMusic.finish_lake(self)
	Ep2DrawMusic.finish(self)
	world_routes.clear()
	Ep2ArmoryState.install_actions()
	var manager: Node = get_node_or_null("/root/GameManager")
	armory = Ep2ArmoryState.new()
	if manager != null:
		armory.restore(manager.personal_armory, manager.highest_unlocked_level >= 3 or manager.current_level >= 3)
	armory.changed.connect(_persist_armory)
	_plan = plan.duplicate(true)
	_commit_to_economy = commit_to_economy
	_segment = 0
	_completed_distance = 0.0
	_rewarded_chambers.clear()
	_chamber_segment = -1
	_chain_id = ""
	_chain_n = 0
	_totals = {"gold_awarded": 0, "gold_forfeited": 0, "diamonds_burned": 0, "btc_paid": 0}
	_runner_armory_checkpoint.clear()
	_teardown_active()
	_mode = Mode.IDLE

func capture_section_checkpoint() -> void:
	var manager: Node = get_node_or_null("/root/GameManager")
	if manager == null: return
	var room: String = _chain_id
	if _mode == Mode.CHAMBER and room == "": room = str(_plan[_segment].get("chamber", DEFAULT_CHAMBER))
	var state: Dictionary = manager.session_data().duplicate(true)
	state["personal_armory"] = armory.snapshot()
	section_checkpoint = {"version": 1, "episode": 2, "label": "Episode 2 — " + (room.replace("_", " ").capitalize() if room != "" else "mine run %d" % (_segment + 1)), "state": state,
		"section": {"segment": _segment, "mode": _mode, "room": room, "chain_n": _chain_n,
		"distance": _completed_distance, "rewarded": _rewarded_chambers.keys(), "totals": _totals.duplicate(true)}}

func restore_section(record: Dictionary) -> bool:
	if not GameManager.valid_resume(record) or int(record.episode) != 2: return false
	var section: Dictionary = record.section
	var segment: int = SaveSafe.to_int(section.get("segment"), -1)
	if segment < 0 or segment >= _plan.size(): return false
	_segment = segment
	_completed_distance = clampf(SaveSafe.to_float(section.get("distance"), 0), 0, 1000000)
	_chain_n = clampi(SaveSafe.to_int(section.get("chain_n"), 0), 0, 64)
	_rewarded_chambers.clear()
	var rewarded: Variant = section.get("rewarded", [])
	if not rewarded is Array: return false
	for key in rewarded:
		var n: int = SaveSafe.to_int(key, -1)
		if n >= 0 and n < 6500: _rewarded_chambers[n] = true
	for key in _totals:
		_totals[key] = maxi(0, SaveSafe.to_int(SaveSafe.to_dict(section.get("totals", {})).get(key), 0))
	if int(section.mode) == Mode.RUNNER:
		_enter_runner()
	else:
		_chain_id = str(section.room)
		if not CHAMBER_SCENES.has(_chain_id): return false
		_enter_chamber()
	return true

func start() -> void:
	if _plan.is_empty():
		return
	_enter_runner()

# --- Mode entry ---------------------------------------------------------------

func _enter_runner() -> void:
	_mode = Mode.TRANSITION
	_teardown_active()
	# A fresh leg gets a fresh completion marker. Coins stay in the runner's
	# `_gold` until the leg actually finishes; a retry or a failed leg therefore
	# cannot spend an earlier attempt's tunnel BTC at Rich's.
	var manager: Node = get_node_or_null("/root/GameManager")
	if manager != null:
		manager.runner_btc_credited = 0
	var seg: Dictionary = _plan[_segment]
	if bool(seg.get("armed", false)):
		armory.acquire(Ep2ArmoryState.REM)
		armory.select(Ep2ArmoryState.REM)
	armory.firearm(Ep2ArmoryState.REM).cancel_reload()  # runner owns its timed cylinder reload
	_runner_armory_checkpoint = armory.snapshot()
	var r: Node = RUNNER_SCENE.instantiate()
	add_child(r)
	_active = r
	r.setup(
		float(seg.get("chamber_z", 200.0)),
		seg.get("obstacles", []),
		seg.get("zip_segments", []),
		seg.get("archers", []),
		bool(seg.get("armed", false)),
		{
			"rail_events": seg.get("rail_events", []),
			"carts_start": seg.get("carts_start", [true, true, true]),
			"start_lane": int(seg.get("start_lane", 1)),
			"speed": seg.get("speed", {}),
			"ends_at_cliff": bool(seg.get("ends_at_cliff", false)),
		}
	)
	r.bind_armory(armory)
	r.chamber_reached.connect(_on_chamber_reached, CONNECT_ONE_SHOT)
	r.archer_down.connect(_on_runner_archer_down)
	r.shovel_bear_down.connect(_on_runner_shovel_bear_down)
	if r.has_signal("cliff_panic"):
		r.cliff_panic.connect(_warm_chamber_assets, CONNECT_ONE_SHOT)
		_runner_music_faded = false
		r.cliff_panic.connect(_on_cliff_panic_music)
	r.run_failed.connect(_on_run_failed, CONNECT_ONE_SHOT)
	_mode = Mode.RUNNER
	_sync_mouse_mode()
	capture_section_checkpoint()
	mode_changed.emit(_mode)

func _enter_chamber() -> void:
	_mode = Mode.TRANSITION
	_sync_mouse_mode()
	if _active and _active.has_method("get_distance"):
		_completed_distance += float(_active.get_distance())
	_teardown_active()
	var seg: Dictionary = _plan[_segment]
	var chamber_id: String = _chain_id if _chain_id != "" else str(seg.get("chamber", DEFAULT_CHAMBER))
	if not CHAMBER_SCENES.has(chamber_id):
		push_error("Ep2SessionRoot: unknown chamber id \"%s\"; falling back to %s" % [chamber_id, DEFAULT_CHAMBER])
		chamber_id = DEFAULT_CHAMBER
	var c: Node = CHAMBER_SCENES[chamber_id].instantiate()
	add_child(c)
	_active = c
	_wire_chamber(c)
	c.setup(
		int(seg.get("gold_principal", DEFAULT_GOLD_PRINCIPAL)),
		seg.get("bears", []),
		int(seg.get("diamonds_paid", 0))
	)
	_restore_town(c)
	c.chamber_cleared.connect(_on_chamber_cleared, CONNECT_ONE_SHOT)
	c.chamber_failed.connect(_on_chamber_failed, CONNECT_ONE_SHOT)
	_chamber_segment = _segment
	_mode = Mode.CHAMBER
	capture_section_checkpoint()
	mode_changed.emit(_mode)

## Load the next chamber of a chain in the same segment (no runner in between). If it was built in the background
## (`_on_prebuild_requested`), the hand-over is ONE cut in the same frame: the player keeps his gaze and his held keys, there is no
## freeze, no blackout, no title card (founder 2026-10-11: "one motion").
func _enter_chamber_chained(segment: int) -> void:
	_mode = Mode.TRANSITION
	var gaze: Dictionary = {}
	if _active != null and _active.has_method("get_handoff"):
		gaze = _active.get_handoff()
	var c: Node = null
	var seamless: bool = false
	# The viewport the next room was built in. Held in a local, not `_pb_vp`: activating the room runs its setup(), and the lift's
	# setup asks for the woods at once (a NEW `_pb_vp`). Freeing `_pb_vp` after activate used to free that new viewport and the woods
	# being built inside it, so the woods were built from scratch at the lift's exit (a long freeze) and set up without the hand-over
	# (back at their own entrance, Inferno's opening line again: founder 2026-10-25 "long painful delay ... the scene rewinds").
	var built_vp: SubViewport = _pb_vp
	_pb_vp = null
	if _pb_node != null and is_instance_valid(_pb_node) and _pb_id == _chain_id:
		c = _pb_node
		seamless = true
	else:
		if _pb_node != null and is_instance_valid(_pb_node):
			_pb_node.queue_free()
		if built_vp != null and is_instance_valid(built_vp):
			built_vp.queue_free()
		built_vp = null
		c = CHAMBER_SCENES[_chain_id].instantiate()
	_pb_node = null
	_pb_id = ""
	_portal_on = false
	var old: Node = _active
	if old != null:
		if old.has_method("portal_detach"):old.portal_detach()
		_persist_town()
		if old.get_parent() == self:
			world_routes.park(self,old)
			# Isolated viewport retains the visited world without leaking its camera, sky or lights.
	_active = c
	_wire_chamber(c)
	if seamless:
		c.call("activate", self, gaze)
		if built_vp != null and is_instance_valid(built_vp):
			built_vp.queue_free()
	else:
		add_child(c)
		c.setup(0, [], 0)
	if c is LakeTrailChamber and old is GoldTownChamber:
		var woods: Node3D = world_routes.rooms.get("woods_quad",{}).get("node",null)
		c.adopt_departure(old,woods)
	_restore_town(c)
	c.chamber_cleared.connect(_on_chamber_cleared, CONNECT_ONE_SHOT)
	c.chamber_failed.connect(_on_chamber_failed, CONNECT_ONE_SHOT)
	_chamber_segment = segment
	_mode = Mode.CHAMBER
	capture_section_checkpoint()
	mode_changed.emit(_mode)


# --- background build of the next chamber (skill ep2-interlude-chain: "no blackouts") -------------------------------------------

## Millisecond budget per frame for the background build; raised while the player is already waiting at the hand-over door.
const PREBUILD_MS := 7.0
const PREBUILD_MS_WAITING := 40.0
var world_routes := Ep2WorldRoutes.new()
var farmer_trip := Ep2FarmerTrip.new()
var _pb_node: Node = null
var _pb_id: String = ""
var _pb_vp: SubViewport = null


## A chamber asked for the next one to be built behind it: instantiate it hidden and let `_process` build it a few ms per frame.
func _on_prebuild_requested(chamber_id: String) -> void:
	if not CHAMBER_SCENES.has(chamber_id) or (_pb_node != null and is_instance_valid(_pb_node)):
		return
	var n: Node = CHAMBER_SCENES[chamber_id].instantiate()
	if n.has_method("bind_armory"):
		n.bind_armory(armory.detached_copy())
	if n.has_method("prebuild_begin"):
		# An off-screen viewport with its OWN world: the chamber is built, lit and drawn there (so the GPU compiles its shaders and
		# uploads its meshes now, a few ms per frame) without touching the camera / environment of the chamber being played.
		_pb_vp = SubViewport.new()
		_pb_vp.name = "PrebuildViewport"
		_pb_vp.size = Vector2i(320, 180)
		_pb_vp.own_world_3d = true
		_pb_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_pb_vp)
		_pb_vp.add_child(n)
		n.call("prebuild_begin")
	else:
		add_child(n)
	_pb_node = n
	_pb_id = chamber_id


## THE OPEN DOOR (founder 2026-10-24: no transition at the hideout's elevator door - "the door should be open and we should be able to
## see the elevator from within the smelting facility"). A chamber that wants to show the next room through a doorway answers
## `portal_view_wanted()` with the view in the next room's frame (or {}). Once that room is fully built behind it, its off-screen
## viewport is raised to screen size, its camera follows that view every frame, and its image is handed to the doorway
## (`portal_attach`). The hand-over itself is unchanged: the same instance is activated in the same frame.
var _portal_on: bool = false


func _drive_portal() -> void:
	var portal_node: Node = _pb_node
	var portal_vp: SubViewport = _pb_vp
	var portal_ready: bool = _pb_id != "" and is_prebuilt(_pb_id)
	if _active is SmeltingFacilityChamber and _active._world_revisit and world_routes.rooms.has("mine_lift"):
		portal_node=world_routes.rooms.mine_lift.node
		portal_vp=world_routes.rooms.mine_lift.viewport
		portal_ready=true
	var want: Dictionary = {}
	if _active != null and is_instance_valid(_active) and _active.has_method("portal_view_wanted"):
		want = _active.call("portal_view_wanted")
	var ok: bool = not want.is_empty() and portal_vp != null and is_instance_valid(portal_vp) and portal_ready \
		and portal_node.has_method("portal_view")
	if not ok:
		if _portal_on and _active != null and is_instance_valid(_active) and _active.has_method("portal_detach"):
			_active.call("portal_detach")
		if portal_vp != null and is_instance_valid(portal_vp) and (_portal_on or portal_ready):
			# nothing to show: stop drawing the next room. Once its warm-up views have been rendered, a built room behind a lift
			# ride or a long scene is not drawn again every frame (the whole woods cost a second world's draw calls).
			portal_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_portal_on = false
		return
	if not _portal_on:
		portal_vp.size = Vector2i(get_viewport().get_visible_rect().size)
		portal_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		portal_node.call("portal_begin")
		_active.call("portal_attach", portal_vp.get_texture())
		_portal_on = true
	elif portal_vp.size != Vector2i(get_viewport().get_visible_rect().size):
		portal_vp.size = Vector2i(get_viewport().get_visible_rect().size)
	portal_node.call("portal_view", want)


## True once the chamber named `chamber_id` is fully built in the background (the active chamber holds its exit until then).
func is_prebuilt(chamber_id: String) -> bool:
	return _pb_node != null and is_instance_valid(_pb_node) and _pb_id == chamber_id and bool(_pb_node.call("is_prebuilt"))


## Advance the background build. `step()` (the deterministic tests) finishes it; `_process` spends a few ms per frame.
func _drive_prebuild(budget_ms: float) -> void:
	if _pb_node == null or not is_instance_valid(_pb_node):
		return
	if budget_ms >= 1.0e8 and _pb_node.has_method("prebuild_finish"):
		_pb_node.call("prebuild_finish")
	elif _pb_node.has_method("prebuild_step"):
		_pb_node.call("prebuild_step", budget_ms)


func _wire_chamber(c: Node) -> void:
	if c.has_method("bind_armory"):
		c.bind_armory(armory)
	if c.has_signal("weapon_granted"):
		c.weapon_granted.connect(func(id: String) -> void: armory.acquire(id, c.get_gun()))
	if c.has_signal("prebuild_requested") and not c.prebuild_requested.is_connected(_on_prebuild_requested):
		c.prebuild_requested.connect(_on_prebuild_requested)
	if "handoff_ready" in c:
		c.set("handoff_ready", func() -> bool: return _pb_node == null or not is_instance_valid(_pb_node) or bool(_pb_node.call("is_prebuilt")))

## The next scene's models are requested on a worker thread while Lil Blunt is still panicking on the cart, so
## the cut to the film and the hideout never stalls on a disk read (the "ridiculously delayed" film).
const WARM_DIRS := ["res://src/episode2/assets/", "res://src/episode2/assets/hideout/"]

func _warm_chamber_assets(_level: int = 0) -> void:
	# The Seedance transition film first: it is what the very next cut shows, and it must start the frame it is asked to.
	if ResourceLoader.exists(SmeltingFacilityChamber.FILM_VIDEO):
		ResourceLoader.load_threaded_request(SmeltingFacilityChamber.FILM_VIDEO)
	for d in WARM_DIRS:
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".glb"):
				ResourceLoader.load_threaded_request(d + f)

## Founder 2026-10-04: the mine music must phase out BEFORE Lil Blunt goes into the film (the film brings the stage
## theme in itself). Panic level 2 is ~90 m before the mouth (~3.5 s at speed): a 3 s fade ends right at the cut.
const RUNNER_MUSIC_FADE_LEVEL := 2
const RUNNER_MUSIC_FADE_SECONDS := 3.0
var _runner_music_faded: bool = false
func _on_cliff_panic_music(level: int) -> void:
	if level >= RUNNER_MUSIC_FADE_LEVEL and not _runner_music_faded and has_node("/root/AudioManager"):
		_runner_music_faded = true
		get_node("/root/AudioManager").fade_out_music(RUNNER_MUSIC_FADE_SECONDS)

func _teardown_active() -> void:
	if _active:
		_persist_town()
		_active.queue_free()
		_active = null
	if _pb_node != null and is_instance_valid(_pb_node) and _chain_id == "":
		_pb_node.queue_free()
		_pb_node = null
		_pb_id = ""
		if _pb_vp != null:
			_pb_vp.queue_free()
			_pb_vp = null

# --- Signal handlers ----------------------------------------------------------

func _on_chamber_reached() -> void:
	if _mode != Mode.RUNNER:
		return
	# Tunnel BTC becomes purse BTC only when the leg FINISHES. Mark the amount
	# before purse_add emits: even a re-entrant listener cannot pay this leg a
	# second time. setup()/retry keeps the coins in the runner and reaches no
	# handler, so failed attempts credit nothing.
	var manager: Node = get_node_or_null("/root/GameManager")
	if manager != null and _active != null and _active.has_method("get_gold"):
		var run_btc: int = int(_active.get_gold())
		if run_btc > 0 and int(manager.runner_btc_credited) == 0:
			manager.runner_btc_credited = run_btc
			manager.purse_add("btc", run_btc)
	_enter_chamber()

func _on_runner_archer_down(_archer_id: String) -> void:
	GameManager.tally_bear("archer")

func _on_runner_shovel_bear_down(_obstacle_index: int) -> void:
	GameManager.tally_bear("shovel")

func _on_chamber_cleared(result: Dictionary) -> void:
	armory.active_gun().cancel_reload()
	_persist_armory()
	var manager: Node = get_node_or_null("/root/GameManager")
	if manager != null:
		manager.save_session()
	var owner_segment: int = _chamber_segment
	# Guard #1 is keyed per chamber: a chained interlude gets its own key (segment * 100 + its place in the chain), so the
	# first chamber's payout can never be paid twice and a chained one is never swallowed by it.
	var key: int = owner_segment + _chain_n * 100
	if owner_segment < 0 or _rewarded_chambers.has(key):
		return
	_rewarded_chambers[key] = true

	var awarded: int = int(result.get("gold_awarded", 0))
	var forfeited: int = int(result.get("gold_forfeited", 0))
	var burned: int = int(result.get("diamonds_burned", 0))
	_totals["gold_awarded"] = int(_totals["gold_awarded"]) + awarded
	_totals["gold_forfeited"] = int(_totals["gold_forfeited"]) + forfeited
	_totals["diamonds_burned"] = int(_totals["diamonds_burned"]) + burned
	# The narrative price of the gear (ONE Bitcoin, Inferno Bull). A ledger line only: GoldMine is not touched.
	_totals["btc_paid"] = int(_totals.get("btc_paid", 0)) + int(result.get("btc_paid", 0))

	if _commit_to_economy:
		var gm: Node = get_node_or_null("/root/GoldMineSystem")
		if gm:
			if awarded > 0 and gm.has_method("mine_gold"):
				gm.mine_gold(awarded)
			# Deliberately NOT gm.forfeit_to_auction() — that debits the player
			# (tests/ep2_session_root_test.gd test 15). The unvested remainder
			# was never in the balance, so it is a plain pool credit.
			if forfeited > 0:
				gm.auction_gold_pool += forfeited

	chamber_committed.emit(owner_segment, result)
	var next_chamber: String = str(result.get("next_chamber", ""))
	if bool(result.get("end_session", false)):
		_chain_id = ""
		_chain_n = 0
		_chamber_segment = -1
		_mode = Mode.IDLE
		_teardown_active()
		_sync_mouse_mode()
		session_complete.emit()
		return
	if next_chamber != "" and CHAMBER_SCENES.has(next_chamber):
		_chain_id = next_chamber
		_chain_n += 1
		_chamber_segment = -1
		_enter_chamber_chained(owner_segment)
		return
	_chain_id = ""
	_chain_n = 0
	_chamber_segment = -1
	_advance_segment()

func _on_chamber_failed() -> void:
	_chamber_segment = -1
	_mode = Mode.IDLE
	_teardown_active()
	_sync_mouse_mode()
	session_failed.emit()

func _on_run_failed() -> void:
	if _mode != Mode.RUNNER:
		return
	if not _runner_armory_checkpoint.is_empty():
		armory.restore(_runner_armory_checkpoint)
	_mode = Mode.IDLE
	_teardown_active()
	_sync_mouse_mode()
	session_failed.emit()

func _advance_segment() -> void:
	_segment += 1
	if _segment >= _plan.size():
		_mode = Mode.IDLE
		_teardown_active()
		_sync_mouse_mode()
		session_complete.emit()
		return
	_enter_runner()

# --- Input routing (guard #2) -------------------------------------------------

func runner_switch_lane_left() -> void:
	if _mode == Mode.RUNNER and _active:
		_active.switch_lane_left()

func runner_switch_lane_right() -> void:
	if _mode == Mode.RUNNER and _active:
		_active.switch_lane_right()

func runner_jump() -> void:
	if _mode == Mode.RUNNER and _active:
		_active.jump()

func runner_duck_start() -> void:
	if _mode == Mode.RUNNER and _active:
		_active.duck_start()

func runner_duck_end() -> void:
	if _mode == Mode.RUNNER and _active:
		_active.duck_end()

## Keyboard auto-aim shot at the nearest archer ahead (no-op on unarmed legs).
func runner_shoot() -> void:
	if _mode == Mode.RUNNER and _active:
		_active.shoot()

## Mouse-aimed revolver shot through the given screen position.
func runner_fire_at_screen(pos: Vector2) -> void:
	if _mode != Mode.RUNNER or _active == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam:
		_active.fire_ray(cam.project_ray_origin(pos), cam.project_ray_normal(pos))

func runner_reload() -> void:
	if _mode == Mode.RUNNER and _active:
		_active.reload()

## Pickaxe swipe — knocks a boarding bear off the cart.
func runner_swipe() -> void:
	if _mode == Mode.RUNNER and _active:
		_active.swipe()

func chamber_start_rig(payment: String = "eth") -> bool:
	if _mode == Mode.CHAMBER and _active:
		return _active.start_rig(payment)
	return false

func chamber_shoot() -> bool:
	if _mode == Mode.CHAMBER and _active:
		if _free_roam() and _active.wants_mouse_capture() and not TouchUi.is_touch():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return _active.shoot()
	return false

func chamber_early_claim() -> bool:
	if _mode == Mode.CHAMBER and _active:
		return _active.early_claim()
	return false

func chamber_walk(direction: float) -> void:
	if _mode == Mode.CHAMBER and _active and _active.has_method("walk"):
		_active.walk(direction)


func chamber_walk_stop() -> void:
	if _mode == Mode.CHAMBER and _active and _active.has_method("walk_stop"):
		_active.walk_stop()


func chamber_take_cover() -> void:
	if _mode == Mode.CHAMBER and _active:
		_active.take_cover()

func chamber_leave_cover() -> void:
	if _mode == Mode.CHAMBER and _active:
		_active.leave_cover()

func step(delta: float) -> void:
	_drive_prebuild(1.0e9)      # deterministic callers have no frame clock: the background build simply completes
	if _active and (_mode == Mode.RUNNER or _mode == Mode.CHAMBER):
		_active.step(delta)

# --- Getters ------------------------------------------------------------------
func get_mode() -> int: return _mode
func get_segment() -> int: return _segment
func get_active() -> Node: return _active
func get_totals() -> Dictionary: return _totals.duplicate()

## Which Episode 2 mode we are in (skill ep2-fps-exit): the cart RUNNER, the story HIDEOUT, or first-person FPS.
## Damage, input hints and the camera read this, so there is exactly one place that knows.
func get_episode_mode() -> int:
	if _mode == Mode.CHAMBER and _active != null and is_instance_valid(_active) and _active.has_method("get_episode_mode"):
		return int(_active.get_episode_mode())
	if _mode == Mode.CHAMBER:
		return Episode2Mode.Mode.HIDEOUT
	return Episode2Mode.Mode.RUNNER
func get_total_distance() -> float:
	var live: float = 0.0
	if _mode == Mode.RUNNER and _active and _active.has_method("get_distance"):
		live = float(_active.get_distance())
	return _completed_distance + live

# --- Touch profile (the controls the phone shows right now) -------------------------------------------------------------
#
#   RUNNER, running                          -> ep2_runner   (swipe pad + attack + pickaxe + pause)
#   CHAMBER, free roam, player in control    -> ep2_foot     (stick + look pad + fire/jump/aim/reload/interact/run + pause)
#   CHAMBER, armory open                     -> ep2_foot, SUSPENDED (the walking thumb is not orphaned)
#   CHAMBER, a skippable film is up          -> ep2_film     (one SKIP button; the film's own hold timer decides)
#   RUNNER / foot while the screen is upright on a touch device -> ep2_rotate (and the sim is paused until landscape)
#   TRANSITION, IDLE, a scripted beat, anything else -> none (the manager hides the controls and releases everything)
#
# The run-over screen (retry + home) is Ep2Entry's profile (`ep2_end`): this node is IDLE then.

## Which touch profile the scene asks for. Duck-typed: MobileLayoutManager reads it from the first group node that has it.
func touch_profile() -> StringName:
	if _active == null or not is_instance_valid(_active):
		return PROFILE_NONE
	match _mode:
		Mode.RUNNER:
			if _runner_live():
				return PROFILE_ROTATE if _rotate_wanted() else PROFILE_RUNNER
		Mode.CHAMBER:
			if _active.has_method("is_film_skippable") and bool(_active.call("is_film_skippable")):
				return PROFILE_FILM
			if _foot_ok():
				return PROFILE_ROTATE if _rotate_wanted() else PROFILE_FOOT
	return PROFILE_NONE

## Keep the controls up but inert: the armory is open (the weapon selector reads raw fingers and the holster hold must not
## fight a live stick). The walking thumb keeps its finger; nothing is injected until the armory closes.
func touch_suspended() -> bool:
	return _mode == Mode.CHAMBER and _armory_is_open()

func _runner_live() -> bool:
	return _active.has_method("is_running") and bool(_active.call("is_running"))

func _armory_is_open() -> bool:
	return _active != null and is_instance_valid(_active) and _active.has_method("armory_open") and bool(_active.call("armory_open"))

## On foot AND the player is the one driving (or the armory is open on top of a driven room).
func _foot_ok() -> bool:
	if not _free_roam():
		return false
	return (_active.has_method("has_player_control") and bool(_active.call("has_player_control"))) or _armory_is_open()

## The window is taller than wide (TouchMetrics' own rule, so the cue and the layouts always agree).
func _portrait_window() -> bool:
	var win: Window = get_window()
	var size_px: Vector2 = Vector2(win.size) if win != null else get_viewport().get_visible_rect().size
	return TouchMetrics.orientation_of(size_px) == TouchMetrics.PORTRAIT

## Upright on a touch device that is not being driven by a keyboard, in a mode the controls would be up for.
func _rotate_wanted() -> bool:
	if not TouchUi.is_touch() or TouchUi.is_keyboard_mode() or not _portrait_window():
		return false
	if _active == null or not is_instance_valid(_active):
		return false
	match _mode:
		Mode.RUNNER:
			return _runner_live()
		Mode.CHAMBER:
			return _foot_ok()
	return false

## Ends a duck / an ADS whose release event was dropped while the tree was paused (the polled input is the truth).
func _resync_held_verbs() -> void:
	if _duck_by_event and not Input.is_action_pressed(&"move_down"):
		_duck_by_event = false
		runner_duck_end()
	if _aim_by_touch and not Input.is_action_pressed(TOUCH_AIM):
		_aim_by_touch = false
		if _mode == Mode.CHAMBER and _active != null and is_instance_valid(_active) and _active.has_method("set_aim"):
			_active.set_aim(false)

## Announce a changed profile / suspended flag (the manager then refreshes at once instead of at its next 5 Hz poll).
func _touch_changed() -> void:
	var profile: StringName = touch_profile()
	var suspended: bool = touch_suspended()
	if profile == _touch_last_profile and suspended == _touch_last_suspended:
		return
	_touch_last_profile = profile
	_touch_last_suspended = suspended
	touch_profile_changed.emit()

## Portrait on a touch device: the sim waits (tree pause) until the screen is landscape again. The pause is taken only while
## the game is PLAYING (that is when the manager can show the cue), never over somebody else's pause (the armory, a pause
## overlay, the transition director's freeze), and only this node releases it.
func _update_rotate_pause() -> void:
	var want: bool = _rotate_wanted()
	if want:
		# also re-asserts the pause if a StateMachine change cleared it while the screen is still upright
		if StateMachine.is_playing() and not get_tree().paused:
			_rotate_paused = true
			get_tree().paused = true
	elif _rotate_paused:
		_rotate_paused = false
		if get_tree().paused and not StateMachine.is_paused():
			get_tree().paused = false

## True while this node is holding the tree paused for the rotate cue (tests, debug).
func is_rotate_paused() -> bool:
	return _rotate_paused

func _on_mode_changed_touch(_mode_now: int) -> void:
	_update_rotate_pause()
	_touch_changed()

func _on_window_resized() -> void:
	_update_rotate_pause()
	_touch_changed()

# --- Mouse cursor ---------------------------------------------------------------
# The runner view draws its own reticle, so the OS cursor is hidden in RUNNER
# mode and visible everywhere else (chambers, menus, after the session ends).

func _process(_delta: float) -> void:
	world_routes.tick(self,_delta)
	if _mode==Mode.CHAMBER:farmer_trip.tick(self,_delta)
	_town_save_due -= _delta
	if _town_save_due <= 0:
		_town_save_due = 20.0
		_persist_town()
	if _armory_save_due >= 0.0:
		_armory_save_due -= _delta
		if _armory_save_due <= 0.0:
			_armory_save_due = -1.0
			var manager: Node = get_node_or_null("/root/GameManager")
			if manager != null:
				manager.personal_armory = armory.snapshot()
				manager.save_session()
	_sync_mouse_mode()
	_poll_free_roam()
	_resync_held_verbs()
	_update_rotate_pause()
	_touch_changed()
	var waiting: bool = _active != null and _active.has_method("is_waiting_for_handoff") and bool(_active.call("is_waiting_for_handoff"))
	_drive_prebuild(PREBUILD_MS_WAITING if waiting else PREBUILD_MS)
	_drive_portal()
	if _active is LakeTrailChamber and _pb_id=="logans_lake" and is_prebuilt("logans_lake"):
		_active.preview_lake(_pb_node)

func _restore_town(chamber: Node) -> void:
	if not chamber is GoldTownChamber: return
	var manager: Node = get_node_or_null("/root/GameManager")
	if manager != null and chamber.get_people() != null:
		chamber.get_people().restore(manager.town_people_state)
		var saved: Variant=manager.town_people_state.get("farmer_trip",{})
		farmer_trip.enter_town(chamber,world_routes.rooms.get("woods_quad",{}).get("node",null),saved if saved is Dictionary else {})
	_town_save_due = 20.0

func _persist_town() -> void:
	var town: GoldTownChamber=farmer_trip.town
	if is_instance_valid(_active) and _active is GoldTownChamber:town=_active as GoldTownChamber
	if not is_instance_valid(town): return
	var manager: Node = get_node_or_null("/root/GameManager")
	var crowd: Ep2TownPeople = town.get_people()
	if manager != null and crowd != null:
		manager.town_people_state = crowd.snapshot()
		if is_instance_valid(farmer_trip.cart):manager.town_people_state["farmer_trip"]=farmer_trip.snapshot()
		manager.save_session()

func _sync_mouse_mode() -> void:
	if _mode == Mode.CHAMBER and _free_roam() and _active.wants_mouse_capture():
		return      # the player captured it for mouse look (click); leave it, ESC/the browser releases it
	var want: Input.MouseMode = Input.MOUSE_MODE_HIDDEN if _mode == Mode.RUNNER else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != want:
		Input.mouse_mode = want

# --- Free roam (the Smelting Facility hideout) -------------------------------------------------------------
# Founder 2026-10-01: Up / W = forward, Down / S = back, Left / A = left, Right / D = right, Space = jump,
# mouse = look. Movement is polled (held keys), forwarded only when it changes so a test driving walk()
# directly is never overwritten by an idle keyboard.
var _last_move: Vector2 = Vector2.ZERO
var _last_run: bool = false

func _free_roam() -> bool:
	return _active != null and is_instance_valid(_active) and _active.has_method("set_move_input")

func _poll_free_roam() -> void:
	# The touch look pad banks a drag delta every event; the room drains it ONCE a frame, into the very verb the mouse
	# uses (so LOOK_SENSITIVITY and the ADS scale apply identically). Always drained so a stale drag never waits.
	var look_delta: Vector2 = TouchActions.take_look()
	if not input_enabled or _mode != Mode.CHAMBER or not _free_roam():
		_last_move = Vector2.ZERO
		_last_run = false
		return
	var v := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_down", "move_up"))
	var run: bool = InputMap.has_action("sprint") and Input.is_action_pressed("sprint")
	if _active.has_method("armory_open") and _active.armory_open():
		v = Vector2.ZERO
		run = false
		look_delta = Vector2.ZERO
	if v != _last_move or run != _last_run:
		_last_move = v
		_last_run = run
		_active.set_move_input(v, run)
	if look_delta != Vector2.ZERO and _active.has_method("look"):
		_active.look(look_delta)

## Mouse + Space + E/LMB for the hideout. Returns true when the event was used.
func _route_free_roam(event: InputEvent) -> bool:
	if _active.has_method("select_weapon"):
		if event.is_action_pressed("ep2_weapon_1"):
			_active.select_weapon(Ep2ArmoryState.WIN)
			return true
		if event.is_action_pressed("ep2_weapon_2"):
			_active.select_weapon(Ep2ArmoryState.REM)
			return true
		if event.is_action_pressed("ep2_weapon_3"):
			_active.select_weapon(Ep2ArmoryState.BOW)
			return true
		if event.is_action_pressed("ep2_weapon_previous"):
			_active.select_previous_weapon()
			return true
		if event.is_action_pressed("ep2_armory"):
			_active.toggle_armory()
			return true
		if _active.armory_open():
			return true
	# TOUCH (audit F8). A finger makes an emulated mouse event (device == DEVICE_ID_EMULATION) wherever no control covers it;
	# on foot that must never look, fire or capture the pointer: look comes from the look pad (TouchActions.take_look) and fire
	# from the FIRE button (the `attack` action). A real mouse (device 0) is untouched.
	if event is InputEventMouse and (event as InputEventMouse).device == InputEvent.DEVICE_ID_EMULATION:
		return false
	# Touch-only verbs (audit F6 / F7): jump, hold-to-aim, reload. W stays move_up, never jump.
	if event.is_action(TOUCH_AIM) and _active.has_method("set_aim"):
		_aim_by_touch = event.is_pressed()
		_active.set_aim(event.is_pressed())
		return true
	if event.is_action_pressed(TOUCH_JUMP):
		_active.jump()
		return true
	if event.is_action_pressed(TOUCH_RELOAD) and _active.has_method("reload"):
		_active.reload()
		return true
	if event is InputEventMouseMotion:
		_active.look((event as InputEventMouseMotion).relative)
		return true
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			# First click locks the pointer for mouse look (browsers need a click for that), and still fires.
			if _active.wants_mouse_capture() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			chamber_shoot()
			return true
		# RMB held = aim down the sights (Modern Warfare style); released = back to the hip.
		if mb.button_index == MOUSE_BUTTON_RIGHT and _active.has_method("set_aim"):
			if mb.pressed and _active.wants_mouse_capture(): Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_active.set_aim(mb.pressed)
			return true
		return false
	if event is InputEventKey:
		var k: InputEventKey = event
		# Keyboard movement/drawing is a real browser gesture too. Reacquire relative
		# mouse look after focus loss so the screen edge cannot fence in aiming.
		if k.pressed and not k.echo and not TouchUi.is_touch() and _active.wants_mouse_capture() and _active.has_player_control() 				and k.physical_keycode in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_ENTER,KEY_KP_ENTER]:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if k.pressed and k.physical_keycode == KEY_SPACE:
			_active.jump()
			return true
		if k.pressed and not k.echo and k.physical_keycode in [KEY_ENTER, KEY_KP_ENTER] and _active.has_method("draw_weapon"):
			if _active.draw_weapon():
				return true
		# R = load shells, one at a time (the Winchester's tube magazine).
		if k.pressed and k.physical_keycode == KEY_R and _active.has_method("reload"):
			_active.reload()
			return true
	# W / S / arrows are movement here, never "jump" or "take cover": swallow them so the shaft bindings
	# (move_down = cover, move_left/right = walk) cannot fire on top of free roam. Hoisted out of the key branch (audit F5):
	# the touch stick (and a gamepad D-pad) presses these as InputEventAction / joypad events, which are not keys, and used
	# to fall through to chamber_walk / take_cover (a horizontal push walked FORWARD). _poll_free_roam reads the same axes.
	if event.is_action("move_up") or event.is_action("move_down") or event.is_action("move_left") \
			or event.is_action("move_right"):
		return true
	return false

func _exit_tree() -> void:
	Ep2DrawMusic.finish_lake(self)
	Ep2DrawMusic.finish(self)
	_persist_town()
	farmer_trip.clear()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# never leave the tree frozen behind us because the screen was upright when this node went away
	var tree: SceneTree = get_tree()
	if _rotate_paused:
		_rotate_paused = false
		if tree != null and tree.paused and StateMachine.is_playing():
			tree.paused = false
	if tree != null and tree.root.size_changed.is_connected(_on_window_resized):
		tree.root.size_changed.disconnect(_on_window_resized)

# --- Live player input (guard #2 still applies) --------------------------------
#
#   Runner   move_left/move_right = switch rail · jump = jump · move_down = duck (hold)
#            LMB = fire revolver at the reticle · RMB / X = pickaxe swipe (F toggled the browser's fullscreen/resized the screen)
#            R = reload · attack (J/Enter) = auto-aim shot
#   Hideout  Up/W forward · Down/S back · Left/A + Right/D strafe · Space jump (double) · Shift run
#            mouse = look (click locks the pointer) · E talk / take · LMB fire
#   Chamber  attack = shoot · interact = start the Miner Rig
#            move_down = take cover (hold) · dash = pull the Early Claim lever
#
# The revolver/pickaxe/reload bindings read raw mouse buttons and physical keys
# so no project.godot input-map edits are needed.

@export var input_enabled: bool = true

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or event.is_echo():
		return
	match _mode:
		Mode.RUNNER:
			if event is InputEventMouseButton:
				var mb: InputEventMouseButton = event
				if mb.pressed:
					if mb.button_index == MOUSE_BUTTON_LEFT:
						runner_fire_at_screen(mb.position)
					elif mb.button_index == MOUSE_BUTTON_RIGHT:
						runner_swipe()
				# Mouse buttons never fall through to actions (an "attack" mapped
				# to LMB would otherwise fire twice).
				return
			if event is InputEventKey:
				var k: InputEventKey = event
				if k.pressed:
					if k.physical_keycode == KEY_R:
						runner_reload()
						return
					if k.physical_keycode == KEY_X:
						runner_swipe()
						return
					if k.physical_keycode == KEY_UP:
						# Founder 2026-10-03: Up arrow jumps in the cart, same as Space (lanes stay on A/D / Left/Right).
						runner_jump()
						return
			if event.is_action_pressed("move_left"):
				runner_switch_lane_left()
			elif event.is_action_pressed("move_right"):
				runner_switch_lane_right()
			elif event.is_action_pressed("jump"):
				runner_jump()
			elif event.is_action_pressed("move_down"):
				_duck_by_event = true
				runner_duck_start()
			elif event.is_action_released("move_down"):
				_duck_by_event = false
				runner_duck_end()
			elif event.is_action_pressed("attack"):
				runner_shoot()
			# touch-only verbs (the pickaxe button; the runner has no reload button - it reloads itself - but the verb exists)
			elif event.is_action_pressed(TOUCH_SWIPE):
				runner_swipe()
			elif event.is_action_pressed(TOUCH_RELOAD):
				runner_reload()
		Mode.CHAMBER:
			if _free_roam() and _route_free_roam(event):
				get_viewport().set_input_as_handled()
				return
			if event.is_action_pressed("attack"):
				chamber_shoot()
			elif event.is_action_pressed("interact"):
				# (the touch RUN button is a persistent toggle: on a phone it must never pick the Diamond-burn payment - audit F13)
				chamber_start_rig("eth_diamonds" if Input.is_action_pressed("sprint") and TouchUi.keys_shown() else "eth")
			elif event.is_action_pressed("dash"):
				chamber_early_claim()
			elif event.is_action_pressed("move_down"):
				chamber_take_cover()
			elif event.is_action_released("move_down"):
				chamber_leave_cover()
			elif event.is_action_pressed("move_right"):
				chamber_walk(1.0)
			elif event.is_action_pressed("move_left"):
				chamber_walk(-1.0)
			elif event.is_action_released("move_right") or event.is_action_released("move_left"):
				chamber_walk_stop()


func _persist_armory() -> void:
	var manager: Node = get_node_or_null("/root/GameManager")
	if manager != null:
		manager.personal_armory = armory.snapshot()
		_armory_save_due = 0.75


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_persist_armory()
		var manager: Node = get_node_or_null("/root/GameManager")
		if manager != null:
			manager.save_session()
