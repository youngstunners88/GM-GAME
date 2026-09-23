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
var _ended: bool = false
var _hud: Label = null
var _hint: Label = null
var _banner: Label = null

func _ready() -> void:
	_build_hud()
	if OS.has_feature("web"):
		var q: Variant = JavaScriptBridge.eval(
			"new URLSearchParams(window.location.search).get('ep2probe') || ''", true)
		_probe = str(q) == "1"
		var lq: Variant = JavaScriptBridge.eval(
			"new URLSearchParams(window.location.search).get('ep2leg') || '0'", true)
		_leg_offset = clampi(int(str(lq)), 0, TRACK_PLAN.size() - 1)

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
	_root.configure(TRACK_PLAN.slice(_leg_offset), true)   # commit_to_economy: real GOLD in play
	_root.start()

func _restart() -> void:
	_start_session()

func _process(_delta: float) -> void:
	_refresh_hud()
	if _probe and _root and _root.get_mode() == Ep2SessionRoot.Mode.RUNNER:
		var a: Node = _root.get_active()
		if a and a.has_method("get_distance"):
			var d: int = int(a.get_distance())
			if d != _probe_last:
				_probe_last = d
				print("[EP2] d=%d hp=%d" % [d, a.get_health()])

func _unhandled_input(event: InputEvent) -> void:
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
			_hint.text = ("A / D  hop carts     SPACE  jump / grab zipline     S  duck (hold)\n"
				+ ("J / ENTER  shoot bears     " if a and a.can_shoot() else "")
				+ "ESC  back to menu")
		Ep2SessionRoot.Mode.CHAMBER:
			if a:
				lines += "MINER SHAFT\n"
				lines += "health %d   ammo %d   bears %d\n" % [a.get_health(), a.get_ammo(), a.get_live_bear_count()]
				if a.is_rig_started():
					lines += "vest %s %d%%%s" % [_bar(a.get_vest()), int(a.get_vest() * 100.0),
						"   IN COVER" if a.is_in_cover() else ""]
				else:
					lines += "rig idle — press E to start a Miner"
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
