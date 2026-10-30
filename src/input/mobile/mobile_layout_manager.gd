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
##   * the scene's profile is not `none`
## Whenever it hides it releases every held action, so a vanished finger can
## never leave Lil Blunt running.
##
## PROFILES. A node in group `touch_controls_wanted` that has a method
## `touch_profile() -> StringName` picks WHICH control set is up (the FIRST such node
## wins; nodes in the group without the method keep the legacy platformer behaviour, which
## is what the Stage 3 film and the study rooms rely on):
##   platformer  stick + jump/attack/dash/run/grab + pause (the default)
##   blaze       full-screen tap field + pause (Blaze Rush, one verb)
##   ep2_runner  swipe pad + attack + pickaxe + pause (Episode 2 mine runner)
##   ep2_foot    analog stick + look pad + fire/jump/aim/reload/interact/run + pause
##   ep2_film    one SKIP button with a hold ring (the cliff film, the fallback film)
##   ep2_end     retry + home (the run-over screen), armed after a beat
##   ep2_rotate  a drawn "turn your phone" cue; swallows touches (portrait Episode 2)
##   none        hide + release (a modal, a transition)
## The same node may also define `touch_suspended() -> bool` (keep the controls up but
## inert, e.g. the armory is open and the walking thumb must not be orphaned) and a signal
## `touch_profile_changed` (the manager refreshes at once instead of at the next 5 Hz poll).
## Layout scenes live in LAYOUT_SCENES (platformer) and PROFILE_SCENES (every other
## profile), keyed `<profile>_<phone_landscape|tablet_landscape|phone_portrait>`; a missing
## key falls back to that profile's landscape scene, then to the platformer layout.
##
## The layout for a changed profile / orientation is BUILT BEFORE the layer is shown (no
## one-frame flash of the wrong layout) and a profile change releases everything once.
##
## (No `class_name`: a class_name equal to the autoload name is a parse error.)

signal controls_visibility_changed(shown: bool)
signal layout_changed(layout_key: StringName)
## The profile in force changed (after the new layout was built).
signal profile_changed(profile: StringName)

## Below the vault/oracle/companion panels (20-30) and the how-to-play (80), so a
## modal's buttons win the touch; above the HUD (<=12) and gameplay.
const LAYER := 18
## The Episode 2 film / weapon selector layers sit at 40; the profiles that must stay
## usable over them (skip a film, retry, the rotate cue) and Blaze's tap field go above.
const LAYER_OVER_FILMS := 60
const GROUP_WANTED := &"touch_controls_wanted"
const REFRESH_SECONDS := 0.2
const HINT_SECONDS := 4.5
## Layout opacity while visible but suspended (dead / paused).
const SUSPENDED_ALPHA := 0.4
const CONFIG_PATH := "user://touch_controls.cfg"
const DEFAULT_THEME := preload("res://src/input/mobile/themes/smoke_realm_touch_theme.tres")

const PROFILE_PLATFORMER := &"platformer"
const PROFILE_BLAZE := &"blaze"
const PROFILE_EP2_RUNNER := &"ep2_runner"
const PROFILE_EP2_FOOT := &"ep2_foot"
const PROFILE_EP2_FILM := &"ep2_film"
const PROFILE_EP2_END := &"ep2_end"
const PROFILE_EP2_ROTATE := &"ep2_rotate"
const PROFILE_NONE := &"none"
const KNOWN_PROFILES: Array[StringName] = [&"platformer", &"blaze", &"ep2_runner", &"ep2_foot",
		&"ep2_film", &"ep2_end", &"ep2_rotate", &"none"]
## Profiles whose layer is raised to LAYER_OVER_FILMS.
const PROFILES_OVER_FILMS: Array[StringName] = [&"blaze", &"ep2_film", &"ep2_end", &"ep2_rotate"]
## Profiles that get the one-time wordless pulse the first time they appear (each has its
## own flag: the global "seen" flag is long since true after Episode 1).
const PROFILES_WITH_HINT: Array[StringName] = [&"platformer", &"blaze", &"ep2_runner", &"ep2_foot"]
## The scoped Blaze-entry hide fade (see request_fade_hide) and how long a request stays valid.
const HIDE_FADE_SECONDS := 0.12
const HIDE_FADE_REQUEST_MS := 1500

## The platformer layouts. Every scene here has a Pause button (tests/pause_menu_test.gd
## walks this registry); the other profiles live in PROFILE_SCENES.
const LAYOUT_SCENES := {
	&"phone_landscape": preload("res://src/input/mobile/layouts/phone_landscape.tscn"),
	&"tablet_landscape": preload("res://src/input/mobile/layouts/tablet_landscape.tscn"),
	&"phone_portrait": preload("res://src/input/mobile/layouts/phone_portrait.tscn"),
}
## Every non-platformer profile x {phone_landscape, tablet_landscape, phone_portrait}.
const PROFILE_SCENES := {
	&"blaze_phone_landscape": preload("res://src/input/mobile/layouts/blaze_phone_landscape.tscn"),
	&"blaze_tablet_landscape": preload("res://src/input/mobile/layouts/blaze_tablet_landscape.tscn"),
	&"blaze_phone_portrait": preload("res://src/input/mobile/layouts/blaze_phone_portrait.tscn"),
	&"ep2_runner_phone_landscape": preload("res://src/input/mobile/layouts/ep2_runner_phone_landscape.tscn"),
	&"ep2_runner_tablet_landscape": preload("res://src/input/mobile/layouts/ep2_runner_tablet_landscape.tscn"),
	&"ep2_runner_phone_portrait": preload("res://src/input/mobile/layouts/ep2_runner_phone_portrait.tscn"),
	&"ep2_foot_phone_landscape": preload("res://src/input/mobile/layouts/ep2_foot_phone_landscape.tscn"),
	&"ep2_foot_tablet_landscape": preload("res://src/input/mobile/layouts/ep2_foot_tablet_landscape.tscn"),
	&"ep2_foot_phone_portrait": preload("res://src/input/mobile/layouts/ep2_foot_phone_portrait.tscn"),
	&"ep2_film_phone_landscape": preload("res://src/input/mobile/layouts/ep2_film_phone_landscape.tscn"),
	&"ep2_film_tablet_landscape": preload("res://src/input/mobile/layouts/ep2_film_tablet_landscape.tscn"),
	&"ep2_film_phone_portrait": preload("res://src/input/mobile/layouts/ep2_film_phone_portrait.tscn"),
	&"ep2_end_phone_landscape": preload("res://src/input/mobile/layouts/ep2_end_phone_landscape.tscn"),
	&"ep2_end_tablet_landscape": preload("res://src/input/mobile/layouts/ep2_end_tablet_landscape.tscn"),
	&"ep2_end_phone_portrait": preload("res://src/input/mobile/layouts/ep2_end_phone_portrait.tscn"),
	&"ep2_rotate_phone_landscape": preload("res://src/input/mobile/layouts/ep2_rotate_phone_landscape.tscn"),
	&"ep2_rotate_tablet_landscape": preload("res://src/input/mobile/layouts/ep2_rotate_tablet_landscape.tscn"),
	&"ep2_rotate_phone_portrait": preload("res://src/input/mobile/layouts/ep2_rotate_phone_portrait.tscn"),
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
var _hints_seen: Dictionary = {}          # profile -> true once its first-run pulse has played
var _fade: Tween
## The profile the scene asked for (can be `none`), and the last non-none one a layout was
## built for (what a rotation rebuilds).
var _profile: StringName = PROFILE_PLATFORMER
var _layout_profile: StringName = PROFILE_PLATFORMER
var _req_profile: StringName = PROFILE_PLATFORMER
var _req_suspended: bool = false
var _warned_profiles: Dictionary = {}
var _available_keys: Array = []
## A profile change that has not released yet (cleared by the first release that follows).
var _release_pending: bool = false
var _release_count: int = 0
## Scoped hide fade (request_fade_hide) and its state.
var _fade_hide_until_ms: int = 0
var _fade_hide_seconds: float = HIDE_FADE_SECONDS
var _hide_fading: bool = false

## Rare-transition log (show / hide / suspend / layout / release). Shows up in the browser
## console and the touch playtest, so "why did my thumb stop steering" is answerable.
func _log(msg: String) -> void:
	print("[Touch] %s (state %s)" % [msg, StateMachine.get_current_state()])

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	force_touch_ui = "--touch-ui" in OS.get_cmdline_args() or "--touch-ui" in OS.get_cmdline_user_args() \
			or OS.get_environment("GM_TOUCH_UI") == "1"
	is_touch_device = force_touch_ui or TouchMetrics.is_touch_capable()
	_available_keys = LAYOUT_SCENES.keys() + PROFILE_SCENES.keys()

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

## Re-evaluate visibility, profile and layout now (it also runs 5x a second, on state
## changes and when a profile node emits `touch_profile_changed`).
func refresh() -> void:
	_read_scene_request()
	var want: bool = _wants_controls(_req_profile)
	var was_visible: bool = controls_visible
	var changed: bool = _adopt_profile(_req_profile)
	if want:
		# BUILD BEFORE SHOW: the layout for this profile + orientation exists (and the old one
		# is gone) before the layer is made visible, so no frame ever draws the wrong one
		_ensure_layout()
		if changed and was_visible:
			_maybe_flash_hints()
	_set_shown(want)
	_set_suspended(controls_visible and (_wants_suspended() or _req_suspended))
	if _release_pending:
		_release_everything()

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

## Wordless context cue: light the button bound to `action` (INTERACT while a verb is in range).
## A no-op when no layout is up or this profile has no such button.
func cue_action(action: StringName, on: bool) -> void:
	if _layout == null:
		return
	_layout.set_cue(action, on)

func set_button_scale(value: float) -> void:
	button_scale = clampf(value, 0.7, 1.5)
	_save_prefs()
	_relayout()

func set_haptics(on: bool) -> void:
	haptics_enabled = on
	TouchActions.haptics_enabled = on
	_save_prefs()

## The layout key in use ("phone_landscape", "blaze_phone_portrait", ...), or &"" before the first build.
func current_layout_key() -> StringName:
	return _layout_key

## The profile the scene asked for ("platformer", "blaze", ..., or "none"). Valid whether or
## not the controls are visible; the debug overlay prints it.
func current_profile() -> StringName:
	return _profile

## The live layout node (tests, tools). Null until built.
func layout() -> TouchLayout:
	return _layout

func metrics() -> TouchMetrics:
	return _metrics

## True while a hybrid device is being driven by real key presses (a finger flips it back).
func is_keyboard_mode() -> bool:
	return _keyboard_mode

## How many times everything has been released (tests: "a profile change releases once").
func release_count() -> int:
	return _release_count

## One line for the debug overlay: shown / suspended / profile / layout / held actions.
func debug_line() -> String:
	return "touch shown=%d susp=%d profile=%s layout=%s held=%d" % [int(controls_visible), int(controls_suspended),
			_profile, _layout_key, TouchActions.held_count()]

## Ask for the NEXT hide to fade over `seconds` instead of snapping off (valid for 1.5 s).
## Only the Blaze portal uses it: the level's touch controls dissolve while the dive wipe
## starts. Every other hide stays instant (the vault's lock test depends on that). Held
## actions are released at once and the controls ignore touches for the whole fade.
func request_fade_hide(seconds: float = HIDE_FADE_SECONDS) -> void:
	_fade_hide_seconds = maxf(seconds, 0.02)
	_fade_hide_until_ms = Time.get_ticks_msec() + HIDE_FADE_REQUEST_MS

## True while a scoped hide fade is running (the layer is still drawn, inert).
func is_hide_fading() -> bool:
	return _hide_fading

# --- profile -------------------------------------------------------------------

## Read the profile (and the suspended flag) from the first group node that has
## `touch_profile()`. No such node: the legacy platformer behaviour.
func _read_scene_request() -> void:
	_req_profile = PROFILE_PLATFORMER
	_req_suspended = false
	for node: Node in get_tree().get_nodes_in_group(GROUP_WANTED):
		if node.is_queued_for_deletion() or not node.has_method(&"touch_profile"):
			continue
		if node.has_signal(&"touch_profile_changed") and not node.is_connected(&"touch_profile_changed", refresh):
			node.connect(&"touch_profile_changed", refresh)
		var raw: Variant = node.call(&"touch_profile")
		var named: StringName = StringName(str(raw))
		if KNOWN_PROFILES.has(named):
			_req_profile = named
		elif not _warned_profiles.has(named):
			_warned_profiles[named] = true
			push_warning("MobileLayoutManager: unknown touch profile '%s' (using platformer)" % named)
		if node.has_method(&"touch_suspended"):
			_req_suspended = bool(node.call(&"touch_suspended"))
		return

## Take `profile` as the one in force. Returns true if it changed. A change while the
## controls are up marks ONE release as owed (the layout build that follows pays it, or the
## hide, or refresh() at its end); it does not build anything by itself.
func _adopt_profile(profile: StringName) -> bool:
	if profile == _profile:
		return false
	var old: StringName = _profile
	_profile = profile
	_log("profile %s -> %s" % [old, profile])
	if profile != PROFILE_NONE:
		_layout_profile = profile
		_layer.layer = LAYER_OVER_FILMS if PROFILES_OVER_FILMS.has(profile) else LAYER
		if controls_visible:
			_release_pending = true
	profile_changed.emit(profile)
	return true

# --- visibility --------------------------------------------------------------

func _wants_controls(profile: StringName) -> bool:
	if not enabled or not is_touch_device or _keyboard_mode or not _locks.is_empty():
		return false
	if profile == PROFILE_NONE:
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
	_kill_fade()
	_log("controls %s" % ("SHOWN" if shown else "HIDDEN"))
	if shown:
		_layer.visible = true
		_apply_inert()
		if _layout != null:
			_layout.modulate.a = 0.0
			_fade = create_tween()
			_fade.tween_property(_layout, "modulate:a", 1.0, 0.22)
		_maybe_flash_hints()
	else:
		_release_everything()
		controls_suspended = false
		TouchActions.set_suspended(false)
		if _fade_hide_requested() and _layout != null:
			_begin_hide_fade()
		else:
			_layer.visible = false
		_end_hint()
	controls_visibility_changed.emit(shown)

## Dim + stop injecting (dead / paused) or undim + restore the held direction.
func _set_suspended(on: bool) -> void:
	if on == controls_suspended:
		return
	controls_suspended = on
	_log("controls %s" % ("SUSPENDED" if on else "RESUMED"))
	if on and _layout != null:
		# controls that hold an action of their own (the swipe pad's duck) drop it BEFORE
		# injection stops, so nothing of theirs is left "wanted" for the resume
		_layout.on_suspended(true)
	TouchActions.set_suspended(on)
	if not on and _layout != null:
		_layout.on_suspended(false)
	_apply_inert()
	if _layout != null:
		if _fade != null and _fade.is_valid():
			_fade.kill()
		_fade = create_tween()
		_fade.tween_property(_layout, "modulate:a", SUSPENDED_ALPHA if on else 1.0, 0.15)

func _release_everything() -> void:
	_release_pending = false
	_release_count += 1
	if _layout != null:
		_layout.release_all()
	TouchActions.release_all()

func _end_hint() -> void:
	if _layout != null:
		_layout.set_hint(false)

## The one-time wordless pulse for a profile's FIRST appearance (per-profile flag).
func _maybe_flash_hints() -> void:
	if not PROFILES_WITH_HINT.has(_layout_profile) or bool(_hints_seen.get(_layout_profile, false)):
		return
	_hints_seen[_layout_profile] = true
	_save_prefs()
	flash_hints()

# --- scoped hide fade ----------------------------------------------------------

func _fade_hide_requested() -> bool:
	var live: bool = _fade_hide_until_ms > 0 and Time.get_ticks_msec() <= _fade_hide_until_ms
	_fade_hide_until_ms = 0
	return live

## Fade the (already released) layer out, inert, then hide it.
func _begin_hide_fade() -> void:
	_hide_fading = true
	_apply_inert()
	_fade = create_tween()
	_fade.tween_property(_layout, "modulate:a", 0.0, _fade_hide_seconds)
	_fade.finished.connect(_finish_hide_fade)

func _finish_hide_fade() -> void:
	_hide_fading = false
	_layer.visible = controls_visible
	_apply_inert()

## Stop any fade; a hide fade still running ends NOW (layer hidden, controls listening again).
func _kill_fade() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if _hide_fading:
		_hide_fading = false
		_layer.visible = controls_visible
		_apply_inert()

## Controls ignore touches (mouse_filter IGNORE) while a scoped hide fade runs, and - for the
## profiles drawn ABOVE the film layers (blaze, ep2_film, ep2_end, ep2_rotate) - while
## suspended: an overlay of the game's own (the Blaze pause card, a dialogue) sits on a lower
## layer than 60 and must get every touch the dimmed controls would otherwise swallow.
func _inert_wanted() -> bool:
	return _hide_fading or (controls_suspended and PROFILES_OVER_FILMS.has(_layout_profile))

func _apply_inert() -> void:
	if _layout != null:
		_layout.set_inert(_inert_wanted())

# --- layout ------------------------------------------------------------------

func _on_size_changed() -> void:
	_relayout()

func _on_state_changed(_from: String, _to: String) -> void:
	refresh()

## Build the layout if the one in place is not the right one for the profile + screen.
func _ensure_layout() -> void:
	if _layout == null or _metrics == null:
		_relayout()
		return
	var key: StringName = TouchMetrics.profile_layout_key(_layout_profile, device_class, orientation, _available_keys)
	if key != _layout_key:
		_relayout()

func _relayout() -> void:
	if _layer == null:
		return
	_metrics = TouchMetrics.from_environment(get_viewport(), is_touch_device)
	device_class = _metrics.device_class
	orientation = _metrics.orientation
	var key: StringName = TouchMetrics.profile_layout_key(_layout_profile, device_class, orientation, _available_keys)
	if key != _layout_key or _layout == null:
		_build_layout(key)
	_layout.apply(_metrics, button_scale, _theme)

func _scene_for(key: StringName) -> PackedScene:
	if PROFILE_SCENES.has(key):
		return PROFILE_SCENES[key]
	return LAYOUT_SCENES.get(key, LAYOUT_SCENES[&"phone_landscape"])

func _build_layout(key: StringName) -> void:
	_log("layout build %s (releases all)" % key)
	_release_everything()
	_kill_fade()
	if _layout != null:
		# gone NOW (not at the end of the frame): the old layout can never be drawn or
		# hit-tested next to the new one
		_layer.remove_child(_layout)
		_layout.queue_free()
		_layout = null
	_layout = _scene_for(key).instantiate() as TouchLayout
	_layout_key = key
	_layer.add_child(_layout)
	_apply_inert()
	if controls_visible:
		# a swap while showing (rotation, profile change): fade the new layout in
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

## Config key of a profile's "first-run pulse played" flag. The platformer keeps the
## original key, so a player who has seen it is not shown it again.
func _hint_key(profile: StringName) -> String:
	return "hint_seen" if profile == PROFILE_PLATFORMER else "hint_seen_%s" % profile

func _load_prefs() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		button_scale = clampf(float(cfg.get_value("controls", "button_scale", 1.0)), 0.7, 1.5)
		haptics_enabled = bool(cfg.get_value("controls", "haptics", true))
		for profile: StringName in PROFILES_WITH_HINT:
			_hints_seen[profile] = bool(cfg.get_value("controls", _hint_key(profile), false))
	TouchActions.haptics_enabled = haptics_enabled

func _save_prefs() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "button_scale", button_scale)
	cfg.set_value("controls", "haptics", haptics_enabled)
	for profile: StringName in PROFILES_WITH_HINT:
		cfg.set_value("controls", _hint_key(profile), bool(_hints_seen.get(profile, false)))
	cfg.save(CONFIG_PATH)
