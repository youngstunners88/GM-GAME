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

## Graybox track. `gold_principal` is NOT a protocol constant (none exists in
## goldmine_system.gd or the white paper) — it is a caller-supplied placeholder,
## same as everywhere else Episode 2 needs one.
const TRACK_PLAN: Array = [
	{
		"chamber_z": 180.0,
		# Spacing is deliberately generous for a FIRST run. Browser playtest of
		# the earlier, tighter track ended in RUN FAILED inside ~13 seconds:
		# hazards arrived every ~2s at RUN_SPEED 12, which is not learnable when
		# you are also discovering the controls. Each hazard now gets ~3s of
		# reaction time, and the first two are in side lanes so simply holding
		# the centre rail survives the opening.
		"obstacles": [
			{"z": 45.0, "lane": 0, "type": "box"},
			{"z": 80.0, "lane": 2, "type": "box"},
			{"z": 118.0, "lane": 1, "type": "boulder"},
			{"z": 155.0, "lane": 0, "type": "arrow"},
		],
		"zip_segments": [{"start_z": 100.0, "end_z": 120.0}],
		"gold_principal": 1000,
		"bears": [{"z": 4.0}, {"z": -6.0}],
	},
]

var _root: Node = null
var _ended: bool = false
var _hud: Label = null
var _hint: Label = null
var _banner: Label = null

func _ready() -> void:
	_build_hud()

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
	_root.configure(TRACK_PLAN, true)      # commit_to_economy: real GOLD in play
	_root.start()

func _restart() -> void:
	_start_session()

func _process(_delta: float) -> void:
	_refresh_hud()

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
	var lines := "EPISODE 2 — GOLD MINE  (graybox)\n"
	match _root.get_mode():
		Ep2SessionRoot.Mode.RUNNER:
			if a:
				lines += "MINECART RUN   dist %.0f m / %.0f\n" % [a.get_distance(), 180.0]
				lines += "health %d   lane %d%s" % [
					a.get_health(), a.get_lane(),
					"   ZIPLINE" if a.is_ziplining() else ("   DUCKING" if a.is_ducking() else ""),
				]
			_hint.text = "A / D  switch rail        SPACE  jump\nS  duck (hold)            ESC  back to menu"
		Ep2SessionRoot.Mode.CHAMBER:
			if a:
				lines += "MINER SHAFT\n"
				lines += "health %d   ammo %d   bears %d\n" % [a.get_health(), a.get_ammo(), a.get_live_bear_count()]
				if a.is_rig_started():
					lines += "vest %s %d%%%s" % [_bar(a.get_vest()), int(a.get_vest() * 100.0),
						"   IN COVER" if a.is_in_cover() else ""]
				else:
					lines += "rig idle — press E to start a Miner"
			_hint.text = "E  start Miner (hold SHIFT to pay ETH+Diamonds)\nLMB/CTRL  shoot     S  cover (hold)\nSHIFT+X / dash  EARLY CLAIM (take partial GOLD now)\nESC  back to menu"
		Ep2SessionRoot.Mode.TRANSITION:
			lines += "loading…"
		_:
			lines += "idle"
	_hud.text = lines

func _bar(f: float) -> String:
	var filled := int(clampf(f, 0.0, 1.0) * 20.0)
	return "[" + "=".repeat(filled) + " ".repeat(20 - filled) + "]"

# --- Session events -----------------------------------------------------------

func _on_mode_changed(_mode: int) -> void:
	_banner.text = ""

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
