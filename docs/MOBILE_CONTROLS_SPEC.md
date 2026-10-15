# Mobile Controls + Onboarding — Spec

**Rewritten 2026-10-13** for the analog-stick touch system in `src/input/mobile/`
(skill `gm-game-mobile-touch-experience`, ADR `docs/architecture/adr-mobile-touch-controls.md`,
founder prompt `PROMPT_MOBILE_TABLET_TOUCH_EXPERIENCE_2026-10-13.md`).
The 2026-08-01 design (nine fixed `TouchScreenButton`s in `src/ui/mobile_controls.gd`, drafted by DeepSeek V4 Flash
from the Grok 4.5 scheme and the Kimi K3 audit, `docs/model-responses/2026-08-01-*`) is **gone**; its DO-NOT list
below is still binding because each line was a real bug.

## Architecture: one path — Control -> TouchActions -> InputMap action

`MobileLayoutManager` (autoload) owns a CanvasLayer (layer 18) holding one layout scene. Its `VirtualJoystick` and
`VirtualButton` controls press the existing InputMap actions through `TouchActions`:
- **press** -> `Input.action_press(action, strength)` + one `InputEventAction` on the edge
- **release** -> `Input.action_release(action)` + the up event

So desktop parity is by construction: keyboard, gamepad and touch all reach `player.gd` through `Input.*`, and the
touch layer is simply hidden (and inert) on a machine without a touchscreen. Controls are real `Control` nodes:
Godot's GUI routes touch/drag/release per finger index, which is true multi-touch (stick + JUMP + ATK together).

`MobileInputHandler` (autoload) stays a thin shim: `get_movement_input()` returns `Input.get_axis("move_left",
"move_right")` (now genuinely analog on touch), `is_sprint_active()` returns the `sprint` action. Its `touch_*`
signals are declared only so old `.connect()` calls do not error; they are never emitted.

## Detection rule

```gdscript
is_touch = OS.get_name() in ["Android","iOS"] or DisplayServer.is_touchscreen_available()
```
The Web export always reports `OS.get_name() == "Web"`, so `has_feature("mobile")` is always false in a browser.
A real finger also proves a touchscreen (`MobileLayoutManager` learns it on the first `InputEventScreenTouch`).
Phone vs tablet is decided by the smallest window side in dp (< 600 = phone), never by an OS name.

## Layout map (dp; centre measured inward from the safe-area corner; JUMP etc. are anchored bottom-right)

| Hand | Control | action | phone landscape | tablet landscape (x1.2) |
|------|---------|--------|-----------------|--------------------------|
| Left  | analog stick (appears under the thumb) | move_left/right (analog), move_up/down (digital) | region x 0-47 %, y 24-100 %, base r58 | region 0-46 %, base r58 |
| Right | JUMP (hold) | jump | (96, 84) r40 | (112, 104) |
| Right | ATK (hold) | attack | (200, 62) r36 | (222, 82) |
| Right | DASH | dash | (62, 186) r30 | (78, 206) |
| Right | RUN (toggle) | sprint | (172, 162) r28 | (194, 182) |
| Right | GRAB | interact | (276, 140) r28 | (324, 66) |

`phone_portrait.tscn` stacks the right-hand buttons in one column up the edge. Idle opacity 0.30, pressed 0.78.
Layout recomputes on `size_changed` (rotate / resize safe) and releases every held action when it swaps. A death or pause keeps the controls up, dimmed and SUSPENDED (nothing pressed, fingers still tracked, direction/run restored on resume); a scene transition or lock hides them and releases everything.

## No written words (founder, 2026-10-13)

Mobile players use finger movements, not key names. The touch UI carries NO text at all: buttons are vector icons
(double-chevron jump, starburst attack, chevron dash, bolt run, diamond grab), the stick is a bare ring/thumb, there
is no "?" button and no hint line. The first-run cue is a wordless opacity pulse.

## First-run onboarding

`src/ui/how_to_play_panel.gd` — dismissible "HOW YOU ROLL" panel with keyboard AND touch columns, shown once on
first run (`user://how_to_play_shown.txt`), re-openable from the main menu's HOW TO PLAY button. In addition the
touch controls pulse (no words) for ~4.5 s the first time they appear (`user://touch_controls.cfg`).

## DO NOT (distilled from the Kimi K3 audit; still true)

- **DO NOT** detect mobile with `has_feature("mobile")` — always false on Web.
- **DO NOT** add a second touch-parsing path, `TouchScreenButton`s, or invisible tap-zones next to the new one.
- **DO NOT** put ANY written word or key name on the touch UI (founder rule).
- **DO NOT** rely on `emulate_mouse_from_touch` for game controls (single pointer, double-fires) — and do not switch it
  off either: menus need it.
- **DO NOT** compute control layout only in `_ready()` — it must follow `size_changed`.
- **DO NOT** name an enum `Anchor` or `Corner` in a `Control` subclass (Godot built-ins; the script silently fails).
- **DO NOT** leave a held action behind when controls hide — every hide path goes through `TouchActions.release_all()`.

## Test checklist (run after any input/UI change)

Automated: `tests/mobile_touch_controls_test.tscn` (headless, real fingers -> real player), `script_compile_test`,
`scripts/touch-playtest.mjs` (Chromium multi-touch against a local export, screenshots with the F3 overlay).

Touch (real device, hard refresh first):
- Stick: light push walks, firm push runs, push up/down on a ladder climbs.
- Hold the stick, tap the jump icon (twice = double jump) and ATK together.
- RUN tap stays on, second tap stops. DASH in the air.
- Keep the thumb down through a death/respawn: the stick resumes without lifting.
- Rotate / resize: controls re-lay out, nothing sticks. Pause / resume: nothing keeps running while paused.
- Tablet: bigger buttons set further in from the edge; nothing covers the hero.

Desktop parity: keyboard (WASD/arrows, Space, J, K, Shift, E) plays exactly as before; no touch layer drawn.
