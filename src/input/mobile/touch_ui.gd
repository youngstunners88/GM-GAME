class_name TouchUi
extends RefCounted
## One question, one answer: "is this a touch player, and what does the screen look like?"
##
## Game scripts (HUDs, hint labels, films, banners) call THIS instead of re-deriving
## "touch" from `OS.get_name()` or poking `MobileLayoutManager` privates. Every
## function is static and null-safe: the autoload may be absent (a unit test that
## instantiates one script) and the answers then fall back to the platform report.
##
## The founder's rule behind it (2026-10-13, angry): mobile games do not have the
## keys written on them. Anything that names a key ("SPACE", "[E]", "R - reload",
## "HOLD Tab") must be gated on `TouchUi.keys_shown()` and replaced by a vector icon
## or a pulse when it is false.

const MANAGER_NODE := "MobileLayoutManager"

## The layout manager autoload, or null (not in the tree yet / unit test).
static func _manager() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(MANAGER_NODE)
	return null

## True on a device that has (or has proven) a touchscreen, or when touch is forced
## (`--touch-ui`, GM_TOUCH_UI=1, tests). It does NOT mean "no keyboard".
static func is_touch() -> bool:
	var m: Node = _manager()
	if m != null:
		return bool(m.get(&"is_touch_device"))
	return TouchMetrics.is_touch_capable() or "--touch-ui" in OS.get_cmdline_args() \
			or "--touch-ui" in OS.get_cmdline_user_args() or OS.get_environment("GM_TOUCH_UI") == "1"

## True while a hybrid device (touch laptop, iPad with a keyboard) is being driven
## by real key presses. A finger on the screen flips it back.
static func is_keyboard_mode() -> bool:
	var m: Node = _manager()
	if m != null and m.has_method(&"is_keyboard_mode"):
		return bool(m.call(&"is_keyboard_mode"))
	return false

## Show key names / keyboard instructions? `not (touch device and not keyboard mode)`:
## a pure phone never sees keys, a hybrid laptop driven with a keyboard still does.
static func keys_shown() -> bool:
	return not (is_touch() and not is_keyboard_mode())

## Live metrics (the manager's own, kept current on resize) or a fresh read.
static func metrics() -> TouchMetrics:
	var m: Node = _manager()
	if m != null and m.has_method(&"metrics"):
		var live: Variant = m.call(&"metrics")
		if live is TouchMetrics:
			return live as TouchMetrics
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return TouchMetrics.from_environment((loop as SceneTree).root, is_touch())
	return TouchMetrics.new()

## Window taller than wide (the Episode 2 runner cannot be framed in it).
static func is_portrait() -> bool:
	return metrics().orientation == TouchMetrics.PORTRAIT

## The touch profile in force (`platformer`, `blaze`, `ep2_runner`, ...), or
## `platformer` when there is no manager. Debug overlays and tests read this.
static func profile() -> StringName:
	var m: Node = _manager()
	if m != null and m.has_method(&"current_profile"):
		return StringName(m.call(&"current_profile"))
	return &"platformer"

## Wordless context cue: light the on-screen button bound to `action` while a verb is in range.
## Null-safe: a missing manager or layout is a no-op (desktop, unit tests).
static func cue(action: StringName, on: bool) -> void:
	var m: Node = _manager()
	if m != null and m.has_method(&"cue_action"):
		m.call(&"cue_action", action, on)
