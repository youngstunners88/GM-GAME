extends Node
## Mobile input SHIM.
##
## As of 2026-08-01 the on-screen touch overlay (src/ui/mobile_controls.gd)
## drives gameplay entirely through the existing InputMap actions via
## TouchScreenButton — the same actions the keyboard uses. So this autoload no
## longer needs its own touch parsing, invisible tap-zones, or keyboard mirror.
## Those were the source of the double-fire / dead-signal / stuck-movement bugs
## the Kimi K3 audit (docs/model-responses/2026-08-01-kimi-mobile-input-audit.md,
## findings F2/F3/F5/F6/F9/F13) flagged.
##
## What remains is a thin compatibility surface:
##   - `is_mobile` — touch-capability flag other systems read.
##   - `get_movement_input()` / `is_sprint_active()` — now read the InputMap
##     directly, so they work identically on desktop (keyboard) and mobile
##     (TouchScreenButton pressing the same actions). player.gd reads
##     get_movement_input() every frame; returning the action axis keeps that
##     call correct on both platforms.
##   - the `touch_*` signals stay DECLARED (players/combat/forge connect to
##     them) but are intentionally no longer emitted here; the action path
##     supersedes them. Kept only so existing `.connect(...)` calls don't error.

# (no class_name: this script IS the MobileInputHandler autoload; a class_name
# matching an autoload name is a parse error in Godot 4.)

# Declared for backward-compatible .connect() calls; not emitted anymore.
signal touch_move(direction: float)
signal touch_jump
signal touch_sprint
signal touch_sprint_released
signal touch_dash
signal touch_interact
signal touch_attack
signal touch_attack_released

# Native mobile OR any touchscreen device — the Web export reports
# OS.get_name() as "Web" even in a phone browser, so is_touchscreen_available()
# is the only reliable signal.
var is_mobile: bool = OS.get_name() in ["Android", "iOS"] or DisplayServer.is_touchscreen_available()

## Movement axis, read from the InputMap so keyboard and the touch overlay
## (which presses move_left/move_right) resolve through one path. Analog-safe:
## get_axis returns 0 when both or neither are held.
func get_movement_input() -> float:
	return Input.get_axis("move_left", "move_right")

## Sprint is now the plain `sprint` action (the touch RUN button presses it).
func is_sprint_active() -> bool:
	return Input.is_action_pressed("sprint")
