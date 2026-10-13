# ADR: Touch controls = Control nodes -> InputMap, owned by one autoload

Date: 2026-10-13 · Status: Accepted · Prompt: `PROMPT_MOBILE_TABLET_TOUCH_EXPERIENCE_2026-10-13.md`
Skill (how to use/extend): `.claude/skills/gm-game-mobile-touch-experience/SKILL.md`

## ADR Dependencies
Builds on the 2026-08-01 collapse to a single InputMap path (`docs/MOBILE_CONTROLS_SPEC.md`, Kimi K3 audit) and
`adr-gameplay-feel.md` (player accel/decel is what makes analog speeds feel right). No dependency on Episode 2 ADRs.

## Engine Compatibility
Godot 4.3.stable only. Uses `Control._gui_input` with `InputEventScreenTouch/Drag`, `Control._has_point`,
`Input.action_press(action, strength)`, `Window.push_input`, `DisplayServer.get_display_safe_area()` and
`screen_get_scale()`. The built-in `VirtualJoystick` of later versions is intentionally not used; on upgrade the
`VirtualJoystick` class here can be swapped without touching layouts or gameplay.

## GDD Requirements Addressed
Founder prompt `PROMPT_MOBILE_TABLET_TOUCH_EXPERIENCE_2026-10-13.md` goals 1-7: non-obstructive, touch-native
(analog stick, multi-touch buttons), phone/tablet adaptive layouts, desktop parity, DPI/safe-area/orientation safe,
Smoke Realm themed, modular. No design-doc requirement IDs exist for input yet (`tr-registry.yaml` untouched).

## Context
The 2026-08-01 overlay (`src/ui/mobile_controls.gd`) was nine fixed-rectangle `TouchScreenButton`s with text
labels. It fixed real double-fire bugs, but on a phone it read as UI tabs on the art: binary left/right, a fixed
layout in viewport fractions (thumb size varied with the screen), no tablet treatment, no safe area, and it was
instanced only in Stages 1-3, so the Smoke Lounge and vault realms (which also use `Player`) had no controls.

## Decision
1. **InputMap stays the only contract.** `TouchActions` presses/releases the existing actions (polled
   `Input.action_press` with strength + an `InputEventAction` on press/release edges). Gameplay is untouched.
2. **Controls are `Control` nodes handled by the GUI**, not `TouchScreenButton` or a custom `_input` router.
   Measured on 4.3: the GUI routes touch/drag/release per finger to the control the finger started on, even after
   it leaves it, so multi-touch and z-order against modal panels come free. (`tests/mobile_touch_controls_test.gd`)
3. **One autoload, `MobileLayoutManager`**, decides visibility (touch device, PLAYING, platformer `Player` or the
   `touch_controls_wanted` group, not locked, not keyboard-driven), picks the layout, relayouts on resize and
   releases every action whenever it hides. Level scenes no longer instance anything.
4. **Layouts are pure scenes in dp**, classified by smallest side in dp (<600 phone), so thumb size is constant
   across devices and tablets get a 1.2x tier with wider spacing.
5. **Movement is analog**: `move_left/right` pressed with strength. `player.gd` already multiplies the axis by
   `walk_speed`. Up/down stay digital with hysteresis and a vertical cone.
6. One gameplay edit: air dash uses `signf(axis)` so an analog light tilt cannot weaken a dash.

## Consequences
+ Precise movement, simultaneous stick/jump/attack, round 10-13 mm targets, see-through when idle (0.30).
+ Stages, Smoke Lounge and vault realms all get controls; desktop keyboard path is byte-for-byte unchanged.
+ New buttons/layouts are scene edits; new scenes opt in with one group.
- The old overlay is deleted (history is in git); `MobileInputHandler` remains a thin shim for old `.connect()` calls.
- Only validated headless + in desktop Chromium touch emulation until the founder confirms on real hardware.

## Rejected
- Keep `TouchScreenButton`s: no analog, rectangular, no per-device sizing.
- Custom `_input` router: cannot tell that a modal panel is above a control, must reimplement finger ownership.
- Swipe/tap gesture zones: forbidden by the 2026-08-01 DO-NOT list (invisible zones) and less reliable than buttons.
- Godot 4.7 built-in `VirtualJoystick`: not available on the pinned 4.3.

## Addendum 2026-10-13: the pause menu and a touch pause button
`src/ui/pause_menu.gd` had never worked: it called `event.is_action_just_pressed("ui_cancel")` (an `Input` method; `InputEvent`
only has `is_action_pressed`), so every event threw and `StateMachine` could never enter PAUSED. Fixing that one line switches
on a menu nobody had played, so the surrounding assumptions were checked and several were wrong:
- `GameManager` is `PROCESS_MODE_ALWAYS`, so Blaze / the Diamond shield / the big axe kept draining while paused. `_process` now stops
  while `get_tree().paused`.
- Other panels (oracle, lore, onboarding) pause the tree but leave the state PLAYING; the menu refuses to open on top of them, and
  while the Talk panel is up (menu hidden, state PAUSED) Escape belongs to that panel. The companion panel now closes on Escape.
- The menu wires its own buttons (the Lounge forgot Talk), sits on layer 40 (above the touch layer 18 and the 20-30 panels, below
  how-to-play 80), hides Restart in the Smoke Lounge (it would wipe the run inside a side room), and credits paused time back to the
  level clock that feeds the adaptive-difficulty pacing metric.
- Touch: a `pause` InputMap action (gamepad Start only, `P` is taken) + a Pause `VirtualButton` in every layout. Godot only emulates a
  mouse click for the first finger down, so a thumb still on the stick made Resume untappable by the other thumb; the menu's buttons
  now also act on the raw finger event with a same-frame dedupe (trap 11 in the skill). Rejected: cancelling the stick's finger on
  pause (breaks "the thumb never has to lift") and a second parser next to the touch layer.
Open for the founder: whether pausing should exist at all, and what Restart should mean inside the Lounge.
