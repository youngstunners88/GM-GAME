extends Node
## MobileLayoutManager (autoload) - the touch controls' single owner.
##
## It decides WHETHER the on-screen controls exist right now, WHICH layout they
## use, and keeps them laid out for the current screen. Gameplay never talks to
## it: virtual controls press ordinary InputMap actions (TouchActions), so
## player.gd / combat / forges read `Input.*` exactly as they do for a keyboard.
##
## Visible only when ALL hold:
##   * the device has a touchscreen (or was forced: `--touch-ui` / GM_TOUCH_UI=1)
##   * the player is not driving with a keyboard right now (hybrid laptops/iPads)
##   * the game is PLAYING (not menu / transition / victory). A death (GAME_OVER) or a
##     pause keeps visible controls up SUSPENDED (dimmed, nothing injected, fingers
##     still tracked, direction/run restored on resume). A scene that opted in via
##     the group below may also keep them through LEVEL_COMPLETE (the skippable
##     Stage 3 defeat film)
##   * the scene holds a platformer `Player`, or opted in via the
##     `touch_controls_wanted` group (the extension point for new chambers)
##   * nothing has locked it (`set_locked`, e.g. a modal panel or a cutscene)
## Whenever it hides it releases every held action, so a vanished finger can
## never leave Lil Blunt running.
##
## (No `class_name`: a class_name equal to the autoload name is a parse error.)

signal controls_visibility_changed(shown: bool)
signal layout_changed(layout_key: StringName)

## Below the vault/oracle/companion panels (20-30) and the how-to-play (80), so a
## modal's buttons win the touch; above the HUD (<=12) and gameplay.
const LAYER := 18
const GROUP_WANTED := &"touch_controls_wanted"
const REFRESH_SECONDS := 0.2
const HINT_SECONDS := 4.5
## Layout opacity while visible but suspended (dead / paused).
const SUSPENDED_ALPHA := 0.4
const CONFIG_PATH := "user://touch_controls.cfg"
const DEFAULT_THEME := preload("res://src/input/mobile/themes/smoke_realm_touch_theme.tres")
const LAYOUT_SCENES := {
	&"phone_landscape": preload("res://src/input/mobile/layouts/phone_landscape.tscn"),
	&"tablet_landscape": preload("res://src/input/mobile/layouts/tablet_landscape.tscn"),
	&"phone_portrait": preload("res://src/input/mobile/layouts/phone_portrait.tscn"),
}

## Master switch. Set false to disable the whole touch system (desktop builds).
var enabled: bool = true
## Show the controls on a non-touch machine (desktop emulation, tests).
var force_touch_ui: bool = false
var is_touch_device: bool = false
var device_class: StringName = TouchMetrics.CLASS_DESKTOP
var orientation: StringName = TouchMetrics.LANDSCAPE
var controls_visible: bool = false
## Visible but not injecting: the hero is dead (GAME_OVER) or the game is paused.
var controls_suspended: bool = false
## Player preferences (persisted in user://touch_controls.cfg).
var button_scale: float = 1.0
var haptics_enabled: bool = true

var _layer: CanvasLayer
var _layout: TouchLayout
var _layout_key: StringName = &""
var _metrics: TouchMetrics
var _theme: TouchTheme = DEFAULT_THEME
var _keyboard_mode: bool = false
var _locks: Dictionary = {}
var _refresh_left: float = 0.0
var _hint_timer: Timer
var _hint_seen: bool = false
var _fade: Tween

## Rare-transition log (show / hide / suspend / layout / release). Shows up in the browser
## console and the touch playtest, so "why did my thumb stop steering" is answerable.
func _log(msg: String) -> void:
	print("[Touch] %s (state %s)" % [msg, StateMachine.get_current_state()])

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	force_touch_ui = "--touch-ui" in OS.get_cmdline_args() or "--touch-ui" in OS.get_cmdline_user_args() \
			or OS.get_environment("GM_TOUCH_UI") == "1"
	is_touch_device = force_touch_ui or TouchMetrics.is_touch_capable()

	_layer = CanvasLayer.new()
	_layer.name = "TouchLayer"
	_layer.layer = LAYER
	_layer.visible = false
	add_child(_layer)

	_hint_timer = Timer.new()
	_hint_timer.one_shot = true
	_hint_timer.timeout.connect(_end_hint)
	add_child(_hint_timer)

	_load_prefs()
	get_tree().root.size_changed.connect(_on_size_changed)
	StateMachine.state_changed.connect(_on_state_changed)
	_relayout()
	refresh()

func _process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = REFRESH_SECONDS
		refresh()

# --- public API --------------------------------------------------------------

## Re-evaluate visibility now (it also runs 5x a second and on state changes).
func refresh() -> void:
	_set_shown(_wants_controls())
	_set_suspended(controls_visible and _wants_suspended())

## Hide the controls (and release everything) while `key` is locked: a modal
## panel, a dialogue, a cutscene. Re-enable with `set_locked(key, false)`.
func set_locked(key: StringName, locked: bool) -> void:
	if locked:
		_locks[key] = true
	else:
		_locks.erase(key)
	refresh()

func is_locked() -> bool:
	return not _locks.is_empty()

## Re-skin every control (per-biome themes later).
func apply_theme(theme: TouchTheme) -> void:
	_theme = theme if theme != null else DEFAULT_THEME
	if _layout != null:
		_layout.apply_theme(_theme)

## Briefly raise every control's opacity (a wordless pulse showing where they are).
func flash_hints(seconds: float = HINT_SECONDS) -> void:
	if _layout == null:
		return
	_layout.set_hint(true)
	_hint_timer.start(seconds)

func set_button_scale(value: float) -> void:
	button_scale = clampf(value, 0.7, 1.5)
	_save_prefs()
	_relayout()

func set_haptics(on: bool) -> void:
	haptics_enabled = on
	TouchActions.haptics_enabled = on
	_save_prefs()

## The layout key in use ("phone_landscape", ...), or &"" before the first build.
func current_layout_key() -> StringName:
	return _layout_key

## The live layout node (tests, tools). Null until built.
func layout() -> TouchLayout:
	return _layout

func metrics() -> TouchMetrics:
	return _metrics

# --- visibility --------------------------------------------------------------

func _wants_controls() -> bool:
	if not enabled or not is_touch_device or _keyboard_mode or not _locks.is_empty():
		return false
	var opted_in: bool = not get_tree().get_nodes_in_group(GROUP_WANTED).is_empty()
	var state: int = StateMachine.get_state_enum()
	if state == StateMachine.State.PLAYING:
		return opted_in or _platformer_player_present()
	# LEVEL_COMPLETE is the boss-defeat film: it is skipped by HOLDING jump, which
	# the old always-on overlay allowed. Only a scene that explicitly opted in keeps
	# the controls through it; the victory / menu screens never opt in, so their
	# buttons are never covered by the stick region.
	if state == StateMachine.State.LEVEL_COMPLETE:
		return opted_in
	# A death (GAME_OVER) or a pause keeps already-visible controls up, SUSPENDED:
	# they stop pressing actions but keep tracking the fingers. Hiding them instead
	# made them flicker out and back on every death and ignored a thumb that touched
	# during the ~1 s death animation until it was lifted and re-placed.
	if controls_visible and _wants_suspended():
		return opted_in or _platformer_player_present()
	return false

func _wants_suspended() -> bool:
	var state: int = StateMachine.get_state_enum()
	return state == StateMachine.State.GAME_OVER or state == StateMachine.State.PAUSED

## A platformer Player is on stage.
func _platformer_player_present() -> bool:
	for node in get_tree().get_nodes_in_group(&"player"):
		if node is Player:
			return true
	return false

func _set_shown(shown: bool) -> void:
	if shown == controls_visible:
		return
	controls_visible = shown
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_log("controls %s" % ("SHOWN" if shown else "HIDDEN"))
	if shown:
		_layer.visible = true
		if _layout != null:
			_layout.modulate.a = 0.0
			_fade = create_tween()
			_fade.tween_property(_layout, "modulate:a", 1.0, 0.22)
		if not _hint_seen:
			_hint_seen = true
			_save_prefs()
			flash_hints()
	else:
		_release_everything()
		controls_suspended = false
		TouchActions.set_suspended(false)
		_layer.visible = false
		_end_hint()
	controls_visibility_changed.emit(shown)

## Dim + stop injecting (dead / paused) or undim + restore the held direction.
func _set_suspended(on: bool) -> void:
	if on == controls_suspended:
		return
	controls_suspended = on
	_log("controls %s" % ("SUSPENDED" if on else "RESUMED"))
	TouchActions.set_suspended(on)
	if _layout != null:
		if _fade != null and _fade.is_valid():
			_fade.kill()
		_fade = create_tween()
		_fade.tween_property(_layout, "modulate:a", SUSPENDED_ALPHA if on else 1.0, 0.15)

func _release_everything() -> void:
	if _layout != null:
		_layout.release_all()
	TouchActions.release_all()

func _end_hint() -> void:
	if _layout != null:
		_layout.set_hint(false)

# --- layout ------------------------------------------------------------------

func _on_size_changed() -> void:
	_relayout()

func _on_state_changed(_from: String, _to: String) -> void:
	refresh()

func _relayout() -> void:
	if _layer == null:
		return
	_metrics = TouchMetrics.from_environment(get_viewport(), is_touch_device)
	device_class = _metrics.device_class
	orientation = _metrics.orientation
	var key: StringName = TouchMetrics.layout_key(device_class, orientation)
	if key != _layout_key or _layout == null:
		_build_layout(key)
	_layout.apply(_metrics, button_scale, _theme)

func _build_layout(key: StringName) -> void:
	_log("layout build %s (releases all)" % key)
	_release_everything()
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if _layout != null:
		_layout.queue_free()
		_layout = null
	var scene: PackedScene = LAYOUT_SCENES.get(key, LAYOUT_SCENES[&"phone_landscape"])
	_layout = scene.instantiate() as TouchLayout
	_layout_key = key
	_layer.add_child(_layout)
	if controls_visible:
		# a swap while showing (rotation): fade the new layout in
		_layout.modulate.a = 0.0
		_fade = create_tween()
		_fade.tween_property(_layout, "modulate:a", SUSPENDED_ALPHA if controls_suspended else 1.0, 0.22)
	layout_changed.emit(key)

# --- input mode + safety -----------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and DebugOverlay.is_on():
		var finger := event as InputEventScreenTouch
		_log("finger %d %s%s" % [finger.index, "DOWN" if finger.pressed else "UP", " CANCELED" if finger.canceled else ""])
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		# A real finger proves a touchscreen even if the platform did not say so
		# (some touch laptops, a desktop browser in device-emulation mode).
		if not is_touch_device:
			is_touch_device = true
			_relayout()
		if _keyboard_mode:
			_keyboard_mode = false
			refresh()
	elif event is InputEventKey and not force_touch_ui:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and not _keyboard_mode:
			_keyboard_mode = true
			refresh()

func _notification(what: int) -> void:
	# Tab hidden / app backgrounded: fingers can vanish without a release event.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_log("focus lost (releases all)")
		_release_everything()

# --- preferences -------------------------------------------------------------

func _load_prefs() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		button_scale = clampf(float(cfg.get_value("controls", "button_scale", 1.0)), 0.7, 1.5)
		haptics_enabled = bool(cfg.get_value("controls", "haptics", true))
		_hint_seen = bool(cfg.get_value("controls", "hint_seen", false))
	TouchActions.haptics_enabled = haptics_enabled

func _save_prefs() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "button_scale", button_scale)
	cfg.set_value("controls", "haptics", haptics_enabled)
	cfg.set_value("controls", "hint_seen", _hint_seen)
	cfg.save(CONFIG_PATH)
