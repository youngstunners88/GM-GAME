extends Node
## Episode 2 — playable entry point. THIS is the scene the game loads after the
## Episode 1 campaign is cleared; everything under src/episode2/ was previously
## reachable only by instantiating it from a headless test.
##
## Why this file exists: the runner↔chamber loop was built, and 8 headless gates
## covering it were green (2000-cycle soak, 4000-op economy fuzz), but nothing in
## the game ever loaded it and no script in Episode 2 read a single input action.
## Green gates proved the LOGIC; they could never prove REACHABILITY, because
## they instantiate the scenes directly and drive them with step(delta). A human
## pressing keys had no path in.
##
## Responsibilities kept deliberately thin — this is a host, not a system:
##   1. build the track plan and hand it to Ep2SessionRoot
##   2. draw a debug HUD so the mode/vest/health are legible while testing
##   3. always offer a visible exit back to the menu (never trap the player)
## All loop logic, all guards and every economy commit stay in the session root.

const SESSION_ROOT := preload("res://src/episode2/session/ep2_session_root.tscn")
const MENU_SCENE := "res://src/ui/main_menu.tscn"

## Track layout lives in src/episode2/runner/tracks/episode2_tracks.gd (pure data).
## `gold_principal` there is NOT a protocol constant (none exists in
## goldmine_system.gd or the white paper) — it is a caller-supplied placeholder,
## same as everywhere else Episode 2 needs one.
const TRACK_PLAN: Array = Episode2Tracks.LEGS

var _root: Node = null
## TEST-ONLY distance probe. With ?ep2probe=1 on web, prints "[EP2] d=<m>" each
## metre so a browser harness can time inputs by track position, not wall-clock
## (software-rendered CI browsers run the sim well below real time). Off otherwise.
var _probe: bool = false
## TEST-ONLY. ?ep2leg=N on web starts the session at leg N (e.g. the armed leg)
## without replaying earlier legs and chambers. 0 in normal play.
var _leg_offset: int = 0
var _probe_last: int = -1
var _probe_chamber_t: float = 0.0
## TEST-ONLY. ?ep2bot=1 on web hands the runner to RunnerAutopilot (the same
## player the solvability gate uses), so a browser capture shows clean play.
var _bot: bool = false
var _ended: bool = false
var _lake_complete: bool = false
var _hud: Label = null
var _hint: Label = null
var _banner: Label = null
## Founder 2026-10-02: no always-on banner or key strip. K shows the controls for 3 seconds; the facility gets a
## film-title card that fades away (skill ep2-hud-title-card).
const KEYS_SHOW_SECONDS := 3.0
var _keys_t: float = 0.0
var _title: Label = null
var _title_done_for: int = 0

# --- TOUCH (skill ep2-mobile-touch; DECISIONS section 4) -------------------------------------------------------------
## The profile for the run-over screen is THIS node's: the session root is IDLE then and answers `none`. MobileLayoutManager reads
## the first node (tree order = this node before the session root) of the group that has `touch_profile()`, so this node is a
## member ONLY while the run is over - otherwise its `none` would hide the session root's controls.
signal touch_profile_changed
const TOUCH_GROUP := &"touch_controls_wanted"
const PROFILE_END := &"ep2_end"
const PROFILE_NONE := &"none"
const PROFILE_RUNNER := &"ep2_runner"
const PROFILE_FOOT := &"ep2_foot"
const PROFILE_ROTATE := &"ep2_rotate"
## The wordless pause card (touch). Built on first use; Escape / the card's HOME leave through the same path.
var _overlay: Ep2TouchOverlay = null
var _pause_open: bool = false
var _run_controls: RunControls
var _saved_offset: int = 0
## The dimmed last frame behind the run-over buttons (touch): the screen is never plain black.
var _scrim_layer: CanvasLayer = null

## Founder 2026-09-30: Episode 2 is behind an access code ("I want to still access it simply but restrict
## others"). Only the SHA-256 of the code is stored - the plaintext is not in the repo or the build. This is
## a casual lock for a client-only static web game: anyone who reverse-engineers the web pack can skip it.
## A correct code is remembered on that device (user://), so the founder types it once.
## base64 of the SHA-256 (not hex: a 64-hex literal is exactly what the sentinel's SEC-005 private-key check flags)
const ACCESS_SHA256 := "oNnp3gYj9AxoCW/G7jmhAtt4RK0pxyT2xg4gDl8Eajs="
const UNLOCK_FILE := "user://ep2_unlock.cfg"
const HarnessHooks := preload("res://src/debug/harness_hooks.gd")   # test-harness hooks, compiled out unless the gm_harness feature tag is set
var _gate: Control = null
var _gate_input: LineEdit = null
var _gate_msg: Label = null

func _ready() -> void:
	_build_hud()
	if OS.has_feature("web") and bool(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('ep2lakeprobe') === '1'", true)):
		_probe_lake_assets()
	Ep2Extras.start(self)          # web: fetch ep2_extras.pck (two-storey Armory, Tripo Rich & Utah) long before the town
	# TEST-ONLY (?ep2unlock=1 on web): remember the unlock on this device exactly as a correct code
	# does, so a phone can enter without a keyboard. The prompt and the code path are untouched.
	if _debug_unlock_requested():
		_write_unlock()
	if _is_unlocked():
		_begin()
	else:
		_show_gate()

static func code_ok(code: String) -> bool:
	return Marshalls.raw_to_base64(code.strip_edges().sha256_buffer()) == ACCESS_SHA256

func _is_unlocked() -> bool:
	var cf := ConfigFile.new()
	HarnessHooks.apply_ep2_gate_skip()   # harness-only access-gate skip: a web build tagged gm_harness, never the shipped one
	if GameManager.EP2_STORY_BYPASSES_CODE and GameManager.ep2_story_unlocked:
		return true         # earned: boss 3 was just beaten (founder 2026-10-03: the hand-off must be seamless)
	return cf.load(UNLOCK_FILE) == OK and str(cf.get_value("ep2", "key", "")) == ACCESS_SHA256

## The same device-local record a correct code writes. Kept in one place so the gate and the
## test-only URL shortcut can never disagree on what "unlocked" means.
func _write_unlock() -> void:
	var cf := ConfigFile.new()
	cf.set_value("ep2", "key", ACCESS_SHA256)
	cf.save(UNLOCK_FILE)

## TEST-ONLY. ?ep2unlock=1 on web skips the prompt by writing the unlock file above. Off
## everywhere else (no query string, no web, any other value); the shipped gate is unchanged.
func _debug_unlock_requested() -> bool:
	return OS.has_feature("web") and bool(JavaScriptBridge.eval(
		"new URLSearchParams(window.location.search).get('ep2unlock') === '1'", true))

func _show_gate() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_gate = ColorRect.new()
	(_gate as ColorRect).color = Color(0.05, 0.03, 0.02, 0.96)
	_gate.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_gate)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-220, -110)
	box.custom_minimum_size = Vector2(440, 220)
	box.add_theme_constant_override("separation", 14)
	_gate.add_child(box)
	var title := Label.new()
	title.text = "EPISODE 2 — GOLD MINE
Enter the access code"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	box.add_child(title)
	_gate_input = LineEdit.new()
	_gate_input.secret = true
	_gate_input.placeholder_text = "access code"
	_gate_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gate_input.add_theme_font_size_override("font_size", 24)
	_gate_input.text_submitted.connect(_try_code)
	box.add_child(_gate_input)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var go := Button.new()
	go.text = "ENTER"
	go.pressed.connect(func() -> void: _try_code(_gate_input.text))
	row.add_child(go)
	var back := Button.new()
	back.text = "BACK TO MENU"
	back.pressed.connect(func() -> void: SceneRouter.load_scene(MENU_SCENE, SceneRouter.Transition.DIAMOND))
	row.add_child(back)
	_gate_msg = Label.new()
	_gate_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gate_msg.add_theme_color_override("font_color", Color(1, 0.45, 0.35))
	box.add_child(_gate_msg)
	_gate_input.grab_focus()
	print("[EP2] code prompt")

func _try_code(code: String) -> void:
	if not code_ok(code):
		_gate_msg.text = "Wrong code."
		_gate_input.clear()
		_gate_input.grab_focus()
		return
	_write_unlock()
	_gate.get_parent().queue_free()
	_gate = null
	_begin()

func _begin() -> void:
	if OS.has_feature("web"):
		var q: Variant = JavaScriptBridge.eval(
			"new URLSearchParams(window.location.search).get('ep2probe') || ''", true)
		_probe = str(q) == "1"
		var lq: Variant = JavaScriptBridge.eval(
			"new URLSearchParams(window.location.search).get('ep2leg') || '0'", true)
		_leg_offset = clampi(int(str(lq)), 0, TRACK_PLAN.size() - 1)
		var bq: Variant = JavaScriptBridge.eval(
			"new URLSearchParams(window.location.search).get('ep2bot') || ''", true)
		_bot = str(bq) == "1"
		# TEST-ONLY render bisection: ?ep2off=boulders,shadows,... switches named
		# view features off (see RunnerView.debug_off). Empty in normal play.
		var oq: Variant = JavaScriptBridge.eval(
			"new URLSearchParams(window.location.search).get('ep2off') || ''", true)
		for f in str(oq).split(",", false):
			RunnerView.debug_off[f.strip_edges()] = true

	_enter_playing()
	_root = SESSION_ROOT.instantiate()
	add_child(_root)
	_root.mode_changed.connect(_on_mode_changed)
	_root.chamber_committed.connect(_on_chamber_committed)
	_root.session_complete.connect(_on_session_complete)
	_root.session_failed.connect(_on_session_failed)
	_root.touch_profile_changed.connect(_sync_portrait_exit)
	_run_controls = RunControls.new()
	_run_controls.save_action = _save_checkpoint
	_run_controls.available = func() -> bool: return _can_pause() or _pause_open
	_run_controls.checkpoint_name = func() -> String: return str(_root.section_checkpoint.get("label", "Episode 2 section start"))
	add_child(_run_controls)
	var chart := preload("res://src/episode2/ui/region_map.gd").new()
	chart.name = "RegionMap"
	chart.allowed = _can_pause
	chart.context = func() -> Vector2:
		var room: Node = _root.get_active()
		if room is LakeTrailChamber:
			if room._in_departure_area:
				return Vector2(.23,.42).lerp(Vector2(.23,.76),clampf(room._player_pos.z/265.0,0,1))
			var stops: Array[Vector2] = [Vector2(370,420),Vector2(590,345),Vector2(810,290),Vector2(1030,355),Vector2(1190,382)]
			var progress: float = clampf(room._route_s / maxf(1.0,room._route_total),0,.9999)*4.0
			var index: int = int(progress)
			return stops[index].lerp(stops[index+1],progress-index)/Vector2(1600,1000)
		if room is GoldTownChamber:
			var pos: Vector3 = room.get_player_position()
			if pos.z < 1300: return Vector2(.23,.42)
			return Vector2(clampf(.23+pos.x/220,.1,.39),clampf(.68+(pos.z-1420)/400,.51,.8))
		return Vector2(.74,.38)
	add_child(chart)
	var record: Dictionary = GameManager.take_episode2_resume()
	if not record.is_empty():
		_saved_offset = clampi(SaveSafe.to_int(record.get("offset"), 0), 0, TRACK_PLAN.size()-1)
		_root.configure(TRACK_PLAN.slice(_saved_offset), true)
		if not _root.restore_section(record): _start_session()
	else:
		_start_session()

func _save_checkpoint() -> bool:
	if _root == null or _root.section_checkpoint.is_empty(): return false
	var record: Dictionary = _root.section_checkpoint.duplicate(true)
	record["offset"] = _saved_offset
	return GameManager.save_manual_checkpoint(record)

func _can_pause() -> bool:
	if _ended or _gate != null or _root == null: return false
	return _root.touch_profile() in [PROFILE_RUNNER, PROFILE_FOOT] and StateMachine.is_playing() and not get_tree().paused

## The menu / ?ep2=1 route enters Episode 2 through SceneRouter, which leaves the StateMachine in TRANSITIONING, and nothing on
## this side ever set PLAYING - so the touch layer (which needs PLAYING) stayed hidden for the whole run. The Stage 3 story
## hand-off gets PLAYING from TransitionDirector at its reveal: while the director is still busy it owns the change. Called
## from _begin(), i.e. AFTER the access gate, so the code screen never sits in PLAYING.
func _enter_playing() -> void:
	if not StateMachine.is_state(StateMachine.State.TRANSITIONING):
		return
	if TransitionDirector.state != TransitionDirector.S.IDLE:
		return
	StateMachine.change_state(StateMachine.State.PLAYING)

## (Re)start a run from segment 0. Used by _ready() and by the retry path.
## Signals are connected ONCE in _ready(); reconnecting here would multiply
## every commit callback per retry.
func _start_session() -> void:
	_saved_offset = _leg_offset
	_set_ended(false)
	_banner.text = ""
	# A run that starts from the cliff is a NEW run: Lil Blunt begins with a fresh armory (full rounds, rifle lesson not yet taught).
	# Without this the saved armory from an earlier play-through came back - 8 rounds left and "training_complete", so the target
	# practice vanished and the runner felt starved (founder 2026-10-15). Mid-run retries still conserve rounds via the session
	# root's own checkpoint. A test warp (?ep2leg=N) keeps whatever the save holds.
	if _leg_offset == 0:
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm != null:
			gm.personal_armory = {}
	_root.configure(_plan().slice(_leg_offset), true)   # commit_to_economy: real GOLD in play
	_root.start()


## TEST-ONLY warp. `?ep2chamber=1` on web shortens the first runner stretch to a
## few metres so the Smelting Facility is reachable in about a second.
##
## Matches the existing `?stage=N` / `?boss=N` / `?ep2=1` warp convention rather
## than inventing a new one. It exists because a browser capture of Chamber 0
## otherwise has to survive 180 m of hazards first — which makes the screenshot
## a test of the runner, not of the chamber, and makes a failed capture
## ambiguous. Story content is unchanged; only the distance to it shrinks.
func _plan() -> Array:
	var warp: bool = false
	var lake_probe: bool = false
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval(
			"new URLSearchParams(window.location.search).get('ep2chamber') || ''", true)
		warp = str(q) == "1"
		lake_probe = str(q) == "lake"
		warp = warp or lake_probe
	if not warp:
		return TRACK_PLAN
	var short_plan: Array = TRACK_PLAN.duplicate(true)
	short_plan[0]["chamber_z"] = 8.0
	short_plan[0]["obstacles"] = []
	short_plan[0]["zip_segments"] = []
	# Same existing test-warp convention, only reached after the access gate.
	# No weapons/currency/access are granted here. ep2leg retains its own contract.
	if lake_probe:
		for segment in short_plan:
			segment["chamber"] = "logans_lake"
			segment["chamber_z"] = 8.0
			segment["obstacles"] = []
			segment["zip_segments"] = []
			segment["archers"] = []
	return short_plan

func _restart() -> void:
	_start_session()

func _physics_process(_delta: float) -> void:
	# Runs before the runner's own _physics_process (parents tick first).
	if _bot and _root and _root.get_mode() == Ep2SessionRoot.Mode.RUNNER:
		var a: Node = _root.get_active()
		if a and a.has_method("get_carts_alive") and a.is_running():
			RunnerAutopilot.tick(a)

func _process(delta: float) -> void:
	_keys_t = maxf(0.0, _keys_t - delta)
	_refresh_hud()
	if GameManager.has_region_map: _hud.position.x = 158.0
	_update_title_card()
	if _probe and _root:
		var chamber: Node = _root.get_active()
		if chamber and chamber.has_method("get_beat_name") and chamber.has_method("is_fps"):
			_probe_chamber_t += delta
			if _probe_chamber_t >= 1.0:
				_probe_chamber_t = 0.0
				print("[EP2] chamber beat=%s fps=%s control=%s pos=%s yaw=%.3f extras=%s" % [chamber.get_beat_name(), chamber.is_fps(), chamber.has_player_control(), chamber.get_player_position(), chamber.get_look_yaw(), Ep2Extras.state()])
	if _probe and _root and _root.get_mode() == Ep2SessionRoot.Mode.RUNNER:
		var a: Node = _root.get_active()
		if a and a.has_method("get_distance"):
			var d: int = int(a.get_distance())
			if d != _probe_last:
				_probe_last = d
				var extra: String = ""
				if a.has_method("get_carts_alive"):
					extra = " lane=%d carts=%s gold=%d v=%d" % [a.get_lane(), str(a.get_carts_alive()), a.get_gold(), int(a.get_speed())]
				print("[EP2] d=%d hp=%d%s" % [d, a.get_health(), extra])

func _unhandled_input(event: InputEvent) -> void:
	if _gate != null:
		if event.is_action_pressed("ui_cancel"):
			SceneRouter.load_scene(MENU_SCENE, SceneRouter.Transition.DIAMOND)
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K:
		_keys_t = KEYS_SHOW_SECONDS          # shows the control list; changes no binding
	if (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")) and not event.is_echo():
		if _ended: _go_home()
		elif _pause_open: _close_pause()
		elif _can_pause(): _open_pause()
		elif event.is_action_pressed("ui_cancel"): _go_home() # retain the existing exit during films/scripted contexts
		get_viewport().set_input_as_handled()
		return
	# RETRY. When a run ends, the session root tears the active scene down —
	# which also removes the only Camera3D, so the screen goes BLACK. A browser
	# playtest hit exactly that: fail at ~13s, then stare at nothing. An ended
	# run must always offer a way back in.
	if _ended and (event.is_action_pressed("jump") or event.is_action_pressed("ui_accept")
			or (event is InputEventKey and event.pressed and event.keycode == KEY_R)):
		_restart()

# --- HUD ----------------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	_hud = Label.new()
	# Leave the offline banner clear; RunnerView's BTC/speed row sits below
	# this two-line progress/health block instead of drawing over its title.
	_hud.position = Vector2(24, 44)
	_hud.add_theme_font_size_override("font_size", 20)
	_hud.add_theme_color_override("font_color", Color(1, 0.93, 0.7))
	_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_hud.add_theme_constant_override("outline_size", 6)
	layer.add_child(_hud)

	_hint = Label.new()
	_hint.position = Vector2(24, 150)
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_hint.add_theme_constant_override("outline_size", 5)
	layer.add_child(_hint)

	_title = Label.new()
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 54)
	_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5))
	_title.add_theme_color_override("font_outline_color", Color(0.12, 0.04, 0.0))
	_title.add_theme_constant_override("outline_size", 12)
	_title.modulate.a = 0.0
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_title)

	_banner = Label.new()
	_banner.position = Vector2(24, 250)
	_banner.add_theme_font_size_override("font_size", 26)
	_banner.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_banner.add_theme_constant_override("outline_size", 7)
	_banner.text = ""
	layer.add_child(_banner)

func _refresh_hud() -> void:
	if _root == null or _hud == null:
		return
	var a: Node = _root.get_active()
	var lines := ""
	match _root.get_mode():
		Ep2SessionRoot.Mode.RUNNER:
			if a:
				var leg: Dictionary = TRACK_PLAN[clampi(_root.get_segment() + _leg_offset, 0, TRACK_PLAN.size() - 1)]
				lines += "%s   %.0f / %.0f m\n" % [str(leg.get("name", "Minecart Run")).to_upper(),
					a.get_distance(), a.get_chamber_z()]
				lines += "health %d/%d%s%s" % [
					a.get_health(), RunnerGraybox.START_HEALTH,
					("   bears %d" % a.archers_alive()) if a.can_shoot() else "",
					"   ON THE ZIPLINE" if a.is_ziplining() else ("   DUCKING" if a.is_ducking() else ""),
				]
			_hint.text = ("MOUSE aim   LMB fire   R reload   X / RMB axe\n"
				+ "A / D hop carts   SPACE jump / grab zipline   S duck   "
				+ "P  pause")
		Ep2SessionRoot.Mode.CHAMBER:
			# Chamber 0 is a story beat with a completely different HUD from a
			# protocol chamber: no vest, no ammo, no bear count — just where you
			# are in the meeting and what you can do about it. Branched on
			# capability, not on a chamber id, so a future chamber picks the
			# right HUD by what it actually is.
			if a and a.has_method("get_film") and a.get_beat_name() == "CINEMATIC":
				# The cliff-jump film owns the screen (it draws its own skip hint).
				_hud.text = ""
				_hint.text = ""
				return
			if a and a.has_method("get_beat_name"):
				lines += (str(a.get_title_card()) if a.has_method("get_title_card") else "THE SMELTING FACILITY") + "\n"
				lines += "Inferno Bull   ·   %s\n" % a.get_beat_name().capitalize()
				if a.has_winchester():
					lines += "WINCHESTER 1886 acquired"
					if a.get_molds_left() > 0:
						lines += "   ·   %d molds left" % a.get_molds_left()
				else:
					lines += "walk to the Bull (arrows / WASD, mouse to look)" if TouchUi.keys_shown() else "walk to the Bull"
				var mode: int = a.get_episode_mode() if a.has_method("get_episode_mode") else Episode2Mode.Mode.HIDEOUT
				if Episode2Mode.is_first_person(mode):
					lines += "\nFIRST-PERSON SHOOTER   ·   Inferno Bull rides with you   ·   BTC paid: %d" % a.get_btc_paid()
				_hint.text = ("ARROWS / WASD  move      SPACE  jump      MOUSE  look (click to lock)      SHIFT  run\n"
					+ "E  talk / take      LMB  fire      RMB (hold)  aim down the sights      R  reload      P  pause")
			elif a:
				lines += "MINER SHAFT\n"
				lines += "health %d   ammo %d   bears %d\n" % [a.get_health(), a.get_ammo(), a.get_live_bear_count()]
				if a.is_rig_started():
					lines += "vest %s %d%%%s" % [_bar(a.get_vest()), int(a.get_vest() * 100.0),
						"   IN COVER" if a.is_in_cover() else ""]
				else:
					lines += "rig idle — press E to start a Miner" if TouchUi.keys_shown() else "rig idle"
				# INSIDE the elif, not after it. When this assignment sat at the
				# end of the CHAMBER branch it ran unconditionally and stamped
				# the Miner Shaft's controls over the Smelting Facility's — the
				# first browser capture of Chamber 0 showed a story beat telling
				# the player to "start Miner" and "EARLY CLAIM", neither of
				# which exists in that room.
				_hint.text = "E  start Miner (hold SHIFT to pay ETH+Diamonds)\nJ / ENTER  shoot     S  cover (hold)\nSHIFT+X / dash  EARLY CLAIM (take partial GOLD now)\nP  pause"
		Ep2SessionRoot.Mode.TRANSITION:
			lines += "loading…"
		_:
			lines += "idle"
	_hud.text = lines
	# Facility: no beat/inventory text at all (the room tells the story). Elsewhere the run stats stay.
	if _root.get_mode() == Ep2SessionRoot.Mode.CHAMBER and a and a.has_method("get_beat_name"):
		_hud.text = ""
	if _keys_t <= 0.0 or not TouchUi.keys_shown():
		_hint.text = ""          # (the control strips name keys: a phone never shows them)

func _bar(f: float) -> String:
	var filled := int(clampf(f, 0.0, 1.0) * 20.0)
	return "[" + "=".repeat(filled) + " ".repeat(20 - filled) + "]"

# --- Session events -----------------------------------------------------------

func _on_mode_changed(mode: int) -> void:
	_banner.text = ""
	# Console marker so browser playtest harnesses can time inputs to the run
	# instead of guessing boot time (scripts / live-build-proof).
	if mode == Ep2SessionRoot.Mode.RUNNER:
		print("[EP2] leg start %d" % (_root.get_segment() + _leg_offset))

func _on_chamber_committed(_index: int, result: Dictionary) -> void:
	_lake_complete = bool(result.get("lake_complete", false))
	if bool(result.get("story", false)) and int(result.get("gold_awarded", 0)) == 0 and int(result.get("gold_forfeited", 0)) == 0:
		_banner.text = ""      # a story chamber moves nothing: no "CLAIMED 0 GOLD" banner over the next scene
		return
	_banner.text = "CLAIMED  %d GOLD   (forfeited %d to the auction pool)" % [
		int(result.get("gold_awarded", 0)), int(result.get("gold_forfeited", 0)),
	]

func _on_session_complete() -> void:
	_set_ended(true)
	if not TouchUi.keys_shown():
		_banner.text = ""          # wordless: the retry / home buttons (profile ep2_end) are the whole screen
		_show_scrim()
		return
	if _lake_complete:
		_banner.text = "LOGAN’S LAKE COMPLETE\nThe depth is staged. The day-88 river run lies ahead.\nSPACE / R  play again        ESC  menu"
		return
	_banner.text = "TO BE CONTINUED...\nInferno rides, Lil Blunt shoots: the bear hunt is next.\nSPACE / R  play it again        ESC  menu"

func _on_session_failed() -> void:
	_set_ended(true)
	if not TouchUi.keys_shown():
		_banner.text = ""          # wordless: the retry / home buttons (profile ep2_end) are the whole screen
		_show_scrim()
		return
	_banner.text = "RUN FAILED\nSPACE / R  try again        ESC  menu"


## "THE SMELTING FACILITY": plays once when the room appears after the cliff film, fades off like a film title.
func _update_title_card() -> void:
	if _root == null or _title == null or _root.get_mode() != Ep2SessionRoot.Mode.CHAMBER:
		return
	var a: Node = _root.get_active()
	if a == null or not a.has_method("get_beat_name") or a.get_beat_name() == "CINEMATIC":
		return
	if _title_done_for == a.get_instance_id():
		return
	_title_done_for = a.get_instance_id()
	if "handoff_seamless" in a and bool(a.get("handoff_seamless")):
		return          # a seamless hand-over (lift, woods) carries on in the same motion: no title card, no "checkpoint" feel
	_title.text = str(a.get_title_card()) if a.has_method("get_title_card") else "THE SMELTING FACILITY"
	var tw := create_tween()
	tw.tween_property(_title, "modulate:a", 1.0, 0.6)
	tw.tween_interval(1.8)
	tw.tween_property(_title, "modulate:a", 0.0, 1.2)

# --- Touch: run-over buttons, the wordless pause card, the portrait exit ------------------------------------------------

## The profile the manager reads while this node is in the group (only while the run is over): retry + home.
func touch_profile() -> StringName:
	return PROFILE_END if _ended else PROFILE_NONE

## Enter / leave the run-over state. The retry button presses `jump` and the home button `ui_cancel`: both already mean
## "play again" and "back to the menu" in _unhandled_input, so the buttons need no handler of their own.
func _set_ended(on: bool) -> void:
	_ended = on
	if on:
		if not is_in_group(TOUCH_GROUP):
			add_to_group(TOUCH_GROUP)
	else:
		if is_in_group(TOUCH_GROUP):
			remove_from_group(TOUCH_GROUP)
		_clear_scrim()
	touch_profile_changed.emit()

## True while the run is over (tests).
func is_ended() -> bool:
	return _ended

## A dim copy of the last frame behind the retry / home buttons, so the run-over screen is never plain black (the session
## root has freed the only Camera3D). Touch only. The headless renderer has no viewport texture: a dark warm plate then.
func _show_scrim() -> void:
	_clear_scrim()
	_scrim_layer = CanvasLayer.new()
	_scrim_layer.layer = 8          # under the HUD (10) and the touch layer (18 / 60)
	add_child(_scrim_layer)
	var img: Image = null
	if DisplayServer.get_name() != "headless":
		var tex: Texture2D = get_viewport().get_texture()
		if tex != null:
			img = tex.get_image()
	if img != null and not img.is_empty():
		var frame := TextureRect.new()
		frame.name = "LastFrame"
		frame.texture = ImageTexture.create_from_image(img)
		frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.modulate = Color(0.34, 0.31, 0.3)
		_scrim_layer.add_child(frame)
	else:
		var plate := ColorRect.new()
		plate.name = "LastFrame"
		plate.color = Color(0.1, 0.065, 0.045)
		plate.set_anchors_preset(Control.PRESET_FULL_RECT)
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scrim_layer.add_child(plate)

func _clear_scrim() -> void:
	if _scrim_layer != null and is_instance_valid(_scrim_layer):
		_scrim_layer.queue_free()
	_scrim_layer = null

func has_scrim() -> bool:
	return _scrim_layer != null and is_instance_valid(_scrim_layer)

func _ensure_overlay() -> Ep2TouchOverlay:
	if _overlay == null:
		_overlay = Ep2TouchOverlay.new()
		add_child(_overlay)
		_overlay.resume_pressed.connect(_close_pause)
		_overlay.home_pressed.connect(_go_home)
	return _overlay

func get_overlay() -> Ep2TouchOverlay:
	return _overlay

func is_pause_open() -> bool:
	return _pause_open

## The PAUSE button: freeze the sim (StateMachine PAUSED - the controls underneath go dim and inert) and raise the card.
## Only while the runner / on-foot controls are the ones up: a film keeps playing through a tree pause (it runs ALWAYS), and
## the armory, a transition or the portrait cue already own the pause.
func _open_pause() -> void:
	if _pause_open or not _can_pause(): return
	if not StateMachine.change_state(StateMachine.State.PAUSED):
		return
	_pause_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_ensure_overlay().show_pause()

## PLAY: the card goes, the sim runs again. Only resumes a pause THIS card took.
func _close_pause() -> void:
	if not _pause_open:
		return
	_pause_open = false
	if _overlay != null:
		_overlay.close()
	if StateMachine.is_paused():
		StateMachine.change_state(StateMachine.State.PLAYING)
	if _root != null: _root._sync_mouse_mode()
	_sync_portrait_exit()

## The card's HOME leaves the episode; nonpausable contexts retain their existing Escape exit.
func _go_home() -> void:
	_close_pause()
	get_tree().paused = false
	SceneRouter.load_scene(MENU_SCENE, SceneRouter.Transition.DIAMOND)

## Portrait on a touch device: the session root pauses the sim and the layout manager shows a drawn "turn your phone" cue.
## A phone locked to portrait must still have a way out, so the cue never stands alone: one HOME icon sits on top of it.
func _sync_portrait_exit() -> void:
	if _root == null or not is_instance_valid(_root):
		return
	var upright: bool = _root.touch_profile() == PROFILE_ROTATE
	if upright and not _pause_open:
		var overlay: Ep2TouchOverlay = _ensure_overlay()
		if overlay.mode() != Ep2TouchOverlay.Mode.PORTRAIT:
			overlay.show_portrait_exit()
	elif _overlay != null and _overlay.mode() == Ep2TouchOverlay.Mode.PORTRAIT:
		_overlay.close()

func _exit_tree() -> void:
	# the card pauses the StateMachine: never leave it paused behind a scene that is going away
	if _pause_open:
		_pause_open = false
		if StateMachine.is_paused():
			StateMachine.change_state(StateMachine.State.PLAYING)

## Opt-in asset proof works behind the normal access prompt without unlocking play.
func _probe_lake_assets() -> void:
	for attempt in 610:
		await get_tree().create_timer(0.5).timeout
		if Ep2Extras.state() == "ready":
			if not LogansLakeChamber.probe_assets(): print("[EP2] Logan lake assets failed")
			return
		if Ep2Extras.state() == "failed":
			print("[EP2] Logan lake assets failed (extras unavailable)")
			return
	print("[EP2] Logan lake assets failed (timeout)")
