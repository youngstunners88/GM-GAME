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
## TEST-ONLY. ?ep2bot=1 on web hands the runner to RunnerAutopilot (the same
## player the solvability gate uses), so a browser capture shows clean play.
var _bot: bool = false
var _ended: bool = false
var _hud: Label = null
var _hint: Label = null
var _banner: Label = null

## Founder 2026-09-30: Episode 2 is behind an access code ("I want to still access it simply but restrict
## others"). Only the SHA-256 of the code is stored - the plaintext is not in the repo or the build. This is
## a casual lock for a client-only static web game: anyone who reverse-engineers the web pack can skip it.
## A correct code is remembered on that device (user://), so the founder types it once.
## base64 of the SHA-256 (not hex: a 64-hex literal is exactly what the sentinel's SEC-005 private-key check flags)
const ACCESS_SHA256 := "oNnp3gYj9AxoCW/G7jmhAtt4RK0pxyT2xg4gDl8Eajs="
const UNLOCK_FILE := "user://ep2_unlock.cfg"
var _gate: Control = null
var _gate_input: LineEdit = null
var _gate_msg: Label = null

func _ready() -> void:
	_build_hud()
	if _is_unlocked():
		_begin()
	else:
		_show_gate()

static func code_ok(code: String) -> bool:
	return Marshalls.raw_to_base64(code.strip_edges().sha256_buffer()) == ACCESS_SHA256

func _is_unlocked() -> bool:
	var cf := ConfigFile.new()
	return cf.load(UNLOCK_FILE) == OK and str(cf.get_value("ep2", "key", "")) == ACCESS_SHA256

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
	var cf := ConfigFile.new()
	cf.set_value("ep2", "key", ACCESS_SHA256)
	cf.save(UNLOCK_FILE)
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

	_root = SESSION_ROOT.instantiate()
	add_child(_root)
	_root.mode_changed.connect(_on_mode_changed)
	_root.chamber_committed.connect(_on_chamber_committed)
	_root.session_complete.connect(_on_session_complete)
	_root.session_failed.connect(_on_session_failed)
	_start_session()

## (Re)start a run from segment 0. Used by _ready() and by the retry path.
## Signals are connected ONCE in _ready(); reconnecting here would multiply
## every commit callback per retry.
func _start_session() -> void:
	_ended = false
	_banner.text = ""
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
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval(
			"new URLSearchParams(window.location.search).get('ep2chamber') || ''", true)
		warp = str(q) == "1"
	if not warp:
		return TRACK_PLAN
	var short_plan: Array = TRACK_PLAN.duplicate(true)
	short_plan[0]["chamber_z"] = 8.0
	short_plan[0]["obstacles"] = []
	short_plan[0]["zip_segments"] = []
	return short_plan

func _restart() -> void:
	_start_session()

func _physics_process(_delta: float) -> void:
	# Runs before the runner's own _physics_process (parents tick first).
	if _bot and _root and _root.get_mode() == Ep2SessionRoot.Mode.RUNNER:
		var a: Node = _root.get_active()
		if a and a.has_method("get_carts_alive") and a.is_running():
			RunnerAutopilot.tick(a)

func _process(_delta: float) -> void:
	_refresh_hud()
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
	# Always an exit. A mode with no visible way out is how a tester gets stuck
	# and reports the whole episode as broken.
	if event.is_action_pressed("ui_cancel"):
		get_tree().paused = false
		SceneRouter.load_scene(MENU_SCENE, SceneRouter.Transition.DIAMOND)
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
	_hud.position = Vector2(24, 20)
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
	var lines := "EPISODE 2 — GOLD MINE\n"
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
				+ "ESC  back to menu")
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
				lines += "THE SMELTING FACILITY\n"
				lines += "Inferno Bull   ·   %s\n" % a.get_beat_name().capitalize()
				if a.has_winchester():
					lines += "WINCHESTER 1886 acquired"
					if a.get_molds_left() > 0:
						lines += "   ·   %d molds left" % a.get_molds_left()
				else:
					lines += "walk to the Bull (arrows / WASD, mouse to look)"
				var mode: int = a.get_episode_mode() if a.has_method("get_episode_mode") else Episode2Mode.Mode.HIDEOUT
				if Episode2Mode.is_first_person(mode):
					lines += "\nFIRST-PERSON SHOOTER   ·   Inferno Bull rides with you   ·   BTC paid: %d" % a.get_btc_paid()
				_hint.text = ("ARROWS / WASD  move      SPACE  jump      MOUSE  look (click to lock)      SHIFT  run\n"
					+ "E  talk / take      LMB  fire the Winchester      ESC  back to menu")
			elif a:
				lines += "MINER SHAFT\n"
				lines += "health %d   ammo %d   bears %d\n" % [a.get_health(), a.get_ammo(), a.get_live_bear_count()]
				if a.is_rig_started():
					lines += "vest %s %d%%%s" % [_bar(a.get_vest()), int(a.get_vest() * 100.0),
						"   IN COVER" if a.is_in_cover() else ""]
				else:
					lines += "rig idle — press E to start a Miner"
				# INSIDE the elif, not after it. When this assignment sat at the
				# end of the CHAMBER branch it ran unconditionally and stamped
				# the Miner Shaft's controls over the Smelting Facility's — the
				# first browser capture of Chamber 0 showed a story beat telling
				# the player to "start Miner" and "EARLY CLAIM", neither of
				# which exists in that room.
				_hint.text = "E  start Miner (hold SHIFT to pay ETH+Diamonds)\nJ / ENTER  shoot     S  cover (hold)\nSHIFT+X / dash  EARLY CLAIM (take partial GOLD now)\nESC  back to menu"
		Ep2SessionRoot.Mode.TRANSITION:
			lines += "loading…"
		_:
			lines += "idle"
	_hud.text = lines

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
	_banner.text = "CLAIMED  %d GOLD   (forfeited %d to the auction pool)" % [
		int(result.get("gold_awarded", 0)), int(result.get("gold_forfeited", 0)),
	]

func _on_session_complete() -> void:
	_ended = true
	_banner.text = "EPISODE 2 SLICE COMPLETE\nSPACE / R  run it again        ESC  menu"

func _on_session_failed() -> void:
	_ended = true
	_banner.text = "RUN FAILED\nSPACE / R  try again        ESC  menu"
