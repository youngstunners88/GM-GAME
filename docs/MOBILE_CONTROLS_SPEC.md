# Mobile Controls + Onboarding — Spec

**Rewritten 2026-10-13** for the analog-stick touch system in `src/input/mobile/`
(skill `gm-game-mobile-touch-experience`, ADR `docs/architecture/adr-mobile-touch-controls.md`,
founder prompt `PROMPT_MOBILE_TABLET_TOUCH_EXPERIENCE_2026-10-13.md`).
The 2026-08-01 design (nine fixed `TouchScreenButton`s in `src/ui/mobile_controls.gd`, drafted by DeepSeek V4 Flash
from the Grok 4.5 scheme and the Kimi K3 audit, `docs/model-responses/2026-08-01-*`) is **gone**; its DO-NOT list
below is still binding because each line was a real bug.

## Architecture: one path — Control -> TouchActions -> InputMap action

`MobileLayoutManager` (autoload) owns a CanvasLayer (layer 18; layer 60 for the profiles that must stay usable over films and the Blaze card) holding one layout scene (chosen by the scene's touch PROFILE, see "Profiles" below). Its `VirtualJoystick` and
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

## Profiles (added 2026-10-23)

A scene asks for a control set by joining group `touch_controls_wanted` and answering `touch_profile() -> StringName` (see the skill and the ADR amendment). All layout numbers below are dp, centre measured inward from the named safe-area corner
(`BR` bottom-right, `BC` bottom-centre, `TR` top-right), read from `src/input/mobile/layouts/<profile>_<variant>.tscn`. Tablet scenes are the same scenes at tier 1.2 unless a number differs. Every control is a visible vector drawing; nothing is written.
Common HUD keep-outs (canvas units): bottom-right ammo/reload box 150 x 96, bottom-centre holster hold 140 x 80, top-right 0..62 dp x 0..96 dp (Blaze HUD) / the Pause button; hit areas >= 44 dp; >= 14 dp edge, 18 dp bottom.

### `blaze` (Blaze Rush, layer 60) - one verb: tap anywhere
| control | phone landscape | tablet landscape | phone portrait | action |
|---|---|---|---|---|
| `TapField` (whole viewport, first = lowest) | full screen | full screen | full screen | `jump` (a fresh edge per finger, haptic 8 ms) |
| `Pause` | TR (30, 64) r17, hit pad 12 | same, x1.2 | same | `pause` |

No EXIT button: the exit is the wordless pause card (dim, 80 dp PLAY triangle, small EXIT door; layer 40, opens from Pause, the `pause` action or app focus-out). The run is ARMED on touch: the cube waits for the reveal and the first tap (not a jump).

### `ep2_runner` (Episode 2 mine runner, layer 18)
| control | phone landscape | tablet landscape | phone portrait | action |
|---|---|---|---|---|
| `SwipePad` region (x, y, w, h of the safe rect) | 0, 0.12, 0.44, 0.88; rest ring (112, 92) | same | 0, 0.4, 0.55, 0.6 | `move_left/right` pulse (hop), `jump` pulse, `move_down` hold (duck) |
| `Attack` | BR (92, 96) r40 | BR (92, 118) r40 | BR (84, 110) r40 | `attack` (auto-aim shot) |
| `Pickaxe` | BR (188, 58) r34 | BR (190, 62) r34 | BR (84, 218) r34 | `ep2_touch_swipe` (touch-only) |
| `Pause` | TR (30, 64) r17 | same | same | `pause` |

Swipe thresholds (dp of finger travel, top of `virtual_swipe_pad.gd`): slop 8, hop 22 (sideways, x re-anchors), jump 20 (upward, 120 ms lockout, re-arm after 10 dp back down), duck 24 (release below 12, minimum hold 150 ms), dominant axis ratio 1.3, left edge >= 24 dp inboard. Portrait shows `ep2_rotate` instead (the sim waits behind the cue).

### `ep2_foot` (Smelting Facility on foot, layer 18)
| control | phone landscape | tablet landscape | phone portrait | action |
|---|---|---|---|---|
| `LookPad` region | 0.42, 0, 0.58, 0.8 | same | 0, 0, 1, 0.5 | `TouchActions.add_look` (gain 1.6, slop 4 dp) |
| `Stick` (DYNAMIC, `analog_vertical`) region | 0, 0.30, 0.40, 0.70; base r58 | same | 0, 0.5, 0.4, 0.4 | `move_left/right/up/down` analog |
| `Fire` | BR (92, 96) r44 | BR (92, 118) r44 | BR (84, 110) r44 | `attack` |
| `Jump` | BR (196, 62) r36 | same | BR (84, 222) | `ep2_touch_jump` |
| `Aim` (SCOPE, HOLD) | BR (84, 196) r30 | BR (84, 214) | BR (84, 320) | `ep2_touch_aim` |
| `Reload` (CYLINDER) | BR (192, 150) r28 | same | BR (170, 150) | `ep2_touch_reload` |
| `Interact` (hand) | BR (288, 120) r28 | same | BR (170, 250) | `interact` |
| `Run` (TOGGLE) | BR (172, 236) r28 | BR (172, 246) | BR (84, 412) | `sprint` |
| `Pause` | TR (30, 64) r17 | same | same | `pause` |

### `ep2_film`, `ep2_end`, `ep2_rotate` (layer 60)
| profile | control | phone landscape | phone portrait | action |
|---|---|---|---|---|
| `ep2_film` | `Skip` (double chevron, hold ring 0.9 s) | BR (66, 66) r36 | BR (66, 80) | `jump` (the film's own hold rule decides) |
| `ep2_end` | `Retry` (arm 0.8 s) | BC (-66, 120) r46 | BC (-66, 160) | `jump` (existing retry) |
| `ep2_end` | `Home` (arm 0.8 s) | BC (74, 112) r34 | BC (74, 152) | `ui_cancel` (existing exit) |
| `ep2_rotate` | `RotateCue` (drawn phone + arrow, swallows touches) | full screen | full screen | - |

The Episode 2 pause card (`Ep2TouchOverlay`, layer 70: dim + PLAY 44 dp + HOME 34 dp, 150 dp apart) and the portrait HOME icon are the game's own overlays, not layout scenes.

Gates: `tests/touch_controls_profiles_test.tscn` (profiles, controls, wordless sources), `tests/mobile_touch_controls_test.tscn` (a second geometry loop over these scenes on the 7-screen list with the keep-outs), `tests/blaze_rush_touch_test.tscn`, `tests/ep2_touch_controls_test.tscn`.

## DO NOT (distilled from the Kimi K3 audit; still true)

- **DO NOT** detect mobile with `has_feature("mobile")` — always false on Web.
- **DO NOT** add a second touch-parsing path, `TouchScreenButton`s, or HIDDEN tap-zones next to the new one. (Refined 2026-10-23: swipe / look / tap-field zones are allowed ONLY as real, visible `Control`s inside a layout scene with per-finger ownership, release-on-hide and the orphan rule - the founder's "players use finger movements" supersedes the blanket ban; see the ADR amendment.)
- **DO NOT** put ANY written word or key name on the touch UI (founder rule). Game UI that names a key is gated on `TouchUi.keys_shown()` and replaced by an icon or a pulse.
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

Profiles (real device, hard refresh; plain-words steps for the founder: `docs/MOBILE_TEST_STEPS_2026-10-23.md`; per-area checklists in the skills):
- Blaze x3 stages: tap anywhere jumps once per tap; the first tap only starts the run; pause card -> play / door; the stage song carries on after the door; upright phone is still readable.
- Episode 2 runner: slide left/right to hop, up to jump, down-and-hold to duck; star shoots, pickaxe swings; lose a run -> round-arrow / house after a moment.
- Hideout on foot: left thumb walks, right thumb looks, six buttons; film skip ring; upright phone shows the "turn me" picture.
- Episode 1 -> 2: no black/blue, no words on the loading picture, nothing stuck under the thumb after the dissolve.
