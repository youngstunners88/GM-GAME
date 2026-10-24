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

## Amendment 2026-10-13 — no written words

Founder rule: a phone UI is icons and finger movement, never key names. The "?" hint button, per-button `label`
exports and the hint labels were removed; the first-run cue is a wordless pulse. See the skill's "NO WRITTEN WORDS".

## Amendment 2026-10-23 - profiles, finger-movement controls, and the refined zone rule

Founder (angry, 2026-10-13 and again 2026-10-22): "mobile games do not have the keys written on them; players use finger movements." Blaze Rush (one verb: tap) and the Episode 2 mine runner
(hop / jump / duck) and hideout (look) cannot be played with the Episode 1 stick-and-buttons cluster. Status of this amendment: Accepted. Skills: `gm-game-mobile-touch-experience` (contract),
`gm-game-blaze-rush-mobile`, `ep2-mobile-touch`. Blaze decision record: `adr-blaze-rush-mobile.md`.

Decisions (the original Decision items 1-6 stand; "InputMap is the only contract" gained two documented verbs):
1. **Profiles.** The scene says which control set it wants: the manager reads `touch_profile() -> StringName` from the FIRST node in group `touch_controls_wanted` that has it (optional `touch_suspended()` and signal `touch_profile_changed`).
   Names: `platformer` (default), `blaze`, `ep2_runner`, `ep2_foot`, `ep2_film`, `ep2_end`, `ep2_rotate`, `none`. Group nodes without the method keep the legacy platformer behaviour. Registries: `LAYOUT_SCENES` (platformer only) and `PROFILE_SCENES` (18 scenes keyed `<profile>_<variant>`).
   The layout is built BEFORE the layer is shown; a profile change releases everything once. `blaze`, `ep2_film`, `ep2_end`, `ep2_rotate` sit on layer `LAYER_OVER_FILMS = 60` and go inert while suspended so a lower-layer overlay of the game's own receives the touch.
2. **New controls** (all `Control`s, vector-drawn, no text): `VirtualTapField` (tap anywhere = fresh `jump` edge), `VirtualSwipePad` (hop / jump / duck from finger travel; thresholds in dp), `VirtualLookPad` (drag = look via `TouchActions.add_look` / `take_look`),
   `VirtualRotateCue`; `VirtualButton` glyphs SKIP / PICKAXE / CYLINDER / SCOPE / RETRY / HOME / PLAY / EXIT / EYE, a hold ring, an arming delay and `touch_only`; `VirtualJoystick.analog_vertical` for first-person rooms.
   `TouchActions` gained `pulse`, `tap`, `add_look/take_look/look_pending`, `ensure_action` (touch-only verbs are registered EMPTY actions, so they can never collide with a key).
3. **The zone rule is refined, not repealed.** The earlier "no invisible tap zones / no gesture detector" rule (Rejected list above, DO-NOT list in `docs/MOBILE_CONTROLS_SPEC.md`) existed because the 2026-08-01 overlay's hidden zones double-fired and stuck inputs.
   The founder's "players use finger movements" supersedes it for exactly one shape: swipe, look and tap zones are allowed **as real, VISIBLE `Control`s inside a layout scene** (a faint ring and chevrons, corner brackets, a tap ring, a first-run pulse),
   with per-finger ownership, release-on-hide and rotation, and the orphan rule (never adopt a finger the control did not press), placed FIRST so buttons win their own touches. Still forbidden: `TouchScreenButton`, a second parser, hidden hit areas, gesture detection in game code.
4. **`TouchUi` (static, null-safe) is the one question "is this a touch player?"**: `keys_shown() = not (is_touch() and not is_keyboard_mode())`. Every key name or keyboard instruction in game UI is gated on it and replaced by an icon or a pulse
   (the "no written words" amendment above, made enforceable). `VirtualControl._draw_label` was removed and a source-level test fails on any text API in `src/input/mobile` or any text in a layout scene.
5. **Scoped fade.** `request_fade_hide()` lets exactly one hide (the Blaze portal dive) fade over 0.12 s with the controls inert; every other hide stays instant (the vault lock test depends on it).
6. Router/edge fixes that touch needs and desktop does not see: Episode 2 F5 (hoisted `move_*` swallow), F6 (`ep2_touch_jump`), F8 (`DEVICE_ID_EMULATION` mouse ignored on foot).

Consequences: + the three phone flows (Blaze, Episode 2 runner/hideout, the hand-off) are playable with fingers only, desktop is byte-identical; - more surface to keep honest (profile registry, layer 60 inert rule, group-order trap), and every threshold
(swipe 22/20/24 dp, look gain, 24 dp edge inset, retry arm 0.8 s) is a paper number until the founder's device pass. Pack impact: none (no binary assets; the web pack is at its 190 MiB gate).

