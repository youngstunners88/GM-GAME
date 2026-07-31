# Kimi K3 audit — mobile/touch input path (findings-first, be exhaustive)

Godot 4.3 project (Lil Blunt Adventure), HTML5 web export played on desktop
AND mobile browsers. Audit the touch/mobile input path below. I have already
found some issues; confirm/deny them and find what I missed. **Findings
first**, each as: SEVERITY (critical/high/med/low) — file:line — what fires
or fails to fire — concrete fix. No preamble.

## Critical facts about the runtime environment
- On the **Web export**, `OS.get_name()` returns `"Web"` and
  `OS.has_feature("android"/"ios"/"mobile")` are ALL **false**, even in a
  phone browser. The ONLY reliable mobile-web signal is
  `DisplayServer.is_touchscreen_available()`.
- `MobileInputHandler` is an autoload (singleton). `mobile_controls.gd`
  (class_name MobileControls) is the VISUAL overlay, instanced in every level
  via `touch_controls.tscn`.

## Specific things I need you to check
1. Which script does `touch_controls.tscn` actually run, and is
   `touch_controls.gd` dead code as a result? (See the .tscn contents in the
   file dump — the ext_resource path.)
2. Does the visual overlay's mobile detection MATCH the autoload's? If one
   uses `OS.has_feature("mobile")` and the other uses
   `DisplayServer.is_touchscreen_available()`, mobile-web players get a
   mismatch (logic without visuals, or visuals without logic).
3. Can a single tap **double-fire** an action? The autoload's `_input()`
   detects taps in an "action zone" AND the visual Buttons emit the same
   signals via `.pressed` / `button_down`. Do both fire for one tap, or does
   the Button consume the event first? State which, with reasoning.
4. Is there any touch control for **up/down** (needed for ladders/climbing
   and the interact-with-forge flow)? If not, say so — it's a playability gap.
5. Movement quality: the "joystick" — is it analog or just sign(x)? Does the
   visual knob (`joystick_stick`) ever move to follow the finger?
6. Attack on touch: trace `touch_attack` from emit to the combat handler.
   Does press-and-hold (fire-breath channel) actually work on touch?
7. What breaks on **resize / orientation change**? Zones and button
   positions are computed once in `_ready()` from viewport size — what
   happens if the browser viewport changes after load?
8. Desktop parity: does anything here risk breaking keyboard/mouse on
   desktop (e.g. `_physics_process` overwriting movement, `is_mobile` false
   paths)?

## Files

@include src/ui/touch_controls.tscn
@include src/autoload/mobile_input_handler.gd
@include src/ui/mobile_controls.gd
@include src/ui/touch_controls.gd
@include src/player/input_handler.gd
@include src/player/combat_handler.gd
