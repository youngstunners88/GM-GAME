---
name: gm-game-mobile-touch-experience
description: "Owns the on-screen touch controls for Lil Blunt (phones and tablets): the analog virtual joystick, thumb buttons, per-device layouts, the MobileLayoutManager autoload, and the tests/browser checks that prove them. TRIGGER on any request about touch/mobile/tablet controls, 'controls cover the screen', joystick, thumb reach, button size or position, safe area/notch, orientation, haptics, itch.io on a phone, 'cannot play on mobile', or any edit under src/input/mobile/. Read BEFORE touching touch input, and never add a second touch path."
---

# Mobile & tablet touch experience

Founder prompt: `PROMPT_MOBILE_TABLET_TOUCH_EXPERIENCE_2026-10-13.md`. Decision record:
`docs/architecture/adr-mobile-touch-controls.md`. Older spec (history + DO-NOT list): `docs/MOBILE_CONTROLS_SPEC.md`.

## The one rule

**InputMap actions are the only contract between touch and gameplay.** Virtual controls press the same
actions the keyboard does (`move_left/right/up/down`, `jump`, `dash`, `sprint`, `attack`, `interact`) through
`TouchActions`. Gameplay (`player.gd`, combat, forges) never references touch, the joystick, or a CanvasLayer.
Keyboard/gamepad parity is therefore by construction; the touch layer is simply hidden on non-touch machines.

```
finger -> Godot GUI -> VirtualJoystick / VirtualButton -> TouchActions -> InputMap -> player.gd reads Input.*
```

## Files (all under `src/input/mobile/`)

| file | job |
|---|---|
| `mobile_layout_manager.gd` | **Autoload** `MobileLayoutManager`. WHETHER controls exist (touch device, PLAYING, a platformer `Player` or the `touch_controls_wanted` group, not locked, not keyboard-driving), WHICH layout, relayout on `size_changed`, release-on-hide, first-run wordless pulse, prefs (`user://touch_controls.cfg`). |
| `touch_metrics.gd` | Pure device maths: phone/tablet by **smallest side in dp (<600 = phone)**, orientation, `dp` = canvas units per dp, safe area (notch insets + minimum edge margin), `layout_key()`. |
| `touch_actions.gd` | The injector: `press/release/set_axis/release_all/set_suspended/buzz`. Mirrors `TouchScreenButton`: `Input.action_press(strength)` for polled reads **and** an `InputEventAction` on press/release edges for `_input` handlers. |
| `virtual_control.gd` | Base `Control`: anchor corner + offset in dp + radius in dp, round hit test, theme lookup. |
| `virtual_joystick.gd/.tscn` | Analog stick. FIXED / DYNAMIC (default) / FOLLOWING. Horizontal = **analog strength**; up/down = deliberate, hysteresis-gated digital (ladders, drop-through, ground pound). |
| `virtual_button.gd/.tscn` | Round thumb button. HOLD (jump, attack, dash) or TOGGLE (run). Vector glyphs, no font dependence. |
| `touch_layout.gd` | Root script of layout scenes: places controls from metrics, fans out theme/hint/release. |
| `layouts/phone_landscape.tscn`, `tablet_landscape.tscn`, `phone_portrait.tscn` | **Pure scenes** composing controls. Numbers are dp. Tablet = x1.2 tier scale + wider spacing. |
| `touch_theme.gd` + `themes/smoke_realm_touch_theme.tres` | Tints, idle/pressed opacity (0.30 / 0.78), stroke widths. Swap per biome with `MobileLayoutManager.apply_theme()`. |

Gate: `tests/mobile_touch_controls_test.tscn` (130+ checks incl. mutation-checked regressions, in CI). Browser: `scripts/touch-playtest.mjs`.

## Why real `Control`s, not TouchScreenButton or a hand-rolled `_input` router

Verified on Godot 4.3 (not assumed): the GUI delivers `InputEventScreenTouch/Drag` **per finger index** to the
Control under that finger, keeps routing that finger's drag **and release to the same control even after it
slid off or left the window**, and fingers are independent (stick + jump + attack at once). Consequences:
true multi-touch, correct **z-order** (a modal on a higher canvas layer wins its own buttons; the touch layer
is `LAYER = 18`, below vault/oracle/companion panels at 20-30 and how-to-play at 80), and round hit areas via
`_has_point`. Only the finger-0 touch also becomes an emulated mouse event (`emulate_mouse_from_touch` stays
ON so menus work); the controls ignore mouse events and the STOP filter stops them leaking to the game.

## Device classes and sizing

Sizes are designed in **dp** (density-independent) and converted: `canvas_units = dp x metrics.dp`. Project stretch
is `canvas_items` + `expand` (1280x720 or larger canvas), so the same 40dp JUMP is ~74 canvas units on a phone
and ~50 on an iPad: constant *thumb* size, smaller share of the screen on tablets. Web density = device pixel
ratio (CSS px == dp); native mobile = dpi/160. Safe area: `DisplayServer.get_display_safe_area()` is trusted only
when the window fills the screen; on web it is empty so a 14dp side/top and 18dp bottom margin is always kept.

## Behaviours worth knowing

- **Analog walk**: tilt 0.14 = dead, 0.14-0.86 maps 0.30..1.0 strength, 0.86+ = full. `player.gd` already does
  `direction * walk_speed`, so it just works. Light tilt = gentle walk (measured 44% of full speed).
- **Climb/drop** only when the push is >=0.58 and within ~53deg of vertical (release at 0.42): a thumb drifting up
  while running never grabs a ladder.
- **RUN is a toggle** (tap on/off) so the right thumb is free for JUMP while sprinting.
- **Dash direction uses only the sign** of the move axis (`player.gd:_try_air_dash`): an analog light tilt must
  not weaken the dash (test `light-tilt air dash`, mutation-checked: 178 vs 400 without it).
- **Hide = release; death/pause = SUSPEND.** Scene transitions, locks, keyboard use, focus loss and layout swaps hide the
  controls and call `TouchActions.release_all()`. A DEATH (GAME_OVER) or a PAUSE keeps the controls up, dimmed to 0.4:
  `TouchActions.set_suspended(true)` releases every pressed action but REMEMBERS what the fingers hold, fingers keep being
  tracked, and on resume the held direction and RUN come straight back (a thumb never has to lift; a press made during the
  death animation counts; no flicker on every death). Edge actions (jump, attack, dash, interact) are deliberately not
  restored, so a JUMP held through a death does not fire on respawn (a held key would not either).
- **After a real hide (scene transition, lock) a thumb still down is RESUMED, but only if this stick owned it**: Godot keeps
  routing a finger's drags AND its release to the control it pressed even while that control is hidden (measured), so
  `release()` remembers the finger and its base (`_orphan`, `_orphan_origin`); its next drag resumes the stick on the SAME base,
  so a thumb that has not moved gets the same output straight back. A finger that pressed while the controls were hidden also
  produces drags but its release is NEVER delivered (measured) - adopting it would leave the hero running forever, so it is
  ignored. The same goes for a rebuilt layout (rotation): the new stick never owned it.
  (Real-browser playtest found the dead-stick-after-death bug; the adversarial review found the stuck-input hazard of the
  naive fix; the suspend model then removed the death/pause cases from this machinery.)
- **The stick measures from where the thumb landed.** Only the DRAWN base is clamped onto the screen near the region
  edge; output is measured from the logical origin, so touch-down alone never reads as a push.
- **Vertical intent beats sidestep**: while up/down is engaged and |y| > |x| the horizontal axis is 0, otherwise a thumb
  a few degrees off vertical drifts the hero off a ladder (player.gd moves x at 0.6 x climb speed while climbing).
- RUN survives death and pause (it is suspended, not reset) but switches itself off on a real hide (transition, lock).
- **Hybrid devices**: a real key press hides the controls, the next screen touch brings them back.
  A real finger also proves a touchscreen even if the platform said no.
- **NO WRITTEN WORDS on the touch UI (founder 2026-10-13, angry).** Phones show icons and finger movement only: no
  JUMP/ATK/MOVE/"?" text, no key names, no hint line. Teach with a first-run opacity pulse (`flash_hints()`, wordless).
  Never add a `label`, a Label node or a keyboard hint on touch devices.
- Haptics: `Input.vibrate_handheld(12)` on press where the platform has it (Android browsers; no-op on iOS Safari).

## Extending

- **New button**: drop a `virtual_button.tscn` instance into each layout scene; set `anchor_corner`, `offset_dp`,
  `radius_dp`, `action` (must exist in the InputMap), `glyph` (vector icon, no text), `role` (tint). No code changes.
- **New screen shape**: add `layouts/<key>.tscn`, register it in `MobileLayoutManager.LAYOUT_SCENES`, return the key
  from `TouchMetrics.layout_key()`. The geometry test then checks it automatically if you add the screen to its list.
- **A new scene that needs controls** (a chamber, a portal explorer): put a node in group `touch_controls_wanted`.
  A platformer `Player` already counts. Episode 2 first-person rooms deliberately do NOT (mouse-look, different
  controls) - give them their own layout + a `look` control before opting them in.
- **A skippable film that needs the controls** (the Stage 3 boss-defeat film is skipped by HOLDING jump): add the node to
  `touch_controls_wanted` while it plays. That group is the only thing that keeps controls through LEVEL_COMPLETE (victory
  and menu screens never opt in, so their buttons stay free). Remove it when the film ends.
- **A modal / dialogue / cutscene that must own the screen**: `MobileLayoutManager.set_locked(&"my_key", true/false)`.
- **Re-skin**: assign a `TouchTheme` via `apply_theme()`. **Disable everything** (desktop builds): `enabled = false`.
- Desktop testing: run with `-- --touch-ui` or `GM_TOUCH_UI=1`; the layout then shows on a mouse machine
  (mouse is not turned into touch; use a real touch device or the Playwright script for finger events).

## Traps (each one cost time once)

1. `enum Anchor` and `enum Corner` **collide with Godot built-ins** (`Control.Anchor`, global `Corner`) - the whole
   hierarchy silently failed to compile. The enum is `ScreenAnchor`. Check names against the engine before using them.
2. Events pushed with `Input.parse_input_event` are in **window pixels**, controls live in **canvas units**. In tests
   map with `get_viewport().get_final_transform() * pos`; headless windows default to **64x64**, so set 1280x720 first.
3. `class_name` equal to an autoload name is a parse error - the manager has none.
4. Never use `TouchScreenButton`, invisible tap zones, or a second parser next to this one (the 2026-08-01 audit's
   double-fire/stuck-input bugs). One path only.
5. `move_up` and `jump` share the W key on the keyboard but are separate actions on touch - do not merge them.
6. Do not rely on `emulate_mouse_from_touch` for controls (single pointer); do not turn it off (menus need it).
7. `gdparse` is syntax-only. The truth is the headless test + a real export.
8. The GUI keeps delivering a finger's drags to the control it pressed **even while that control is hidden** - code that
   releases on hide must also decide what a later drag from that finger means (we adopt it in the stick).
9. Never adopt a finger the control did not press: after `GAME_OVER` / pause the GUI still sends that finger's drags
   to the control, and a finger that pressed while it was hidden gets drags but NO release.
10. Run the security sentinel **after** `git add`. Do not commit the `.godot-cache` symlink or `export_presets.cfg`.

## Verify (in this order)

```bash
godot --headless res://tests/mobile_touch_controls_test.tscn      # ends MOBILE_TOUCH_CONTROLS: ALL PASS
godot --headless res://tests/script_compile_test.tscn             # every script/scene still compiles
bash scripts/ep2-local-export.sh                                   # CI-identical non-threaded web export
node scripts/touch-playtest.mjs http://localhost:8899/game/index.html web_verify/touch-playtest phone,tablet,desktop
```
`touch-playtest.mjs` boots the export in Chromium with a touch-capable mobile context, taps PLAY, then sends real
multi-finger events over CDP (`Input.dispatchTouchEvent`): light tilt, firm push, JUMP + ATK with the stick held,
RUN toggle, hold-through-death. Every shot carries the game's own F3 overlay (`?debug=1`: player pos, |v|, floor,
dying, and an `INPUT held:` line listing every action the game really sees held) as hard evidence - read the PNGs, not the button visuals. The game also prints rare `[Touch] ...` lines (controls SHOWN / HIDDEN / SUSPENDED / RESUMED, layout builds, focus loss, and - only while the F3 / `?debug=1` overlay is on - every finger DOWN/UP/CANCELED); the playtest echoes them, which is how a "thumb stopped steering" report is diagnosed (e.g. a last-life death reloads the level: HIDDEN (TRANSITIONING), so a held thumb needs one tiny drag to resume - a scripted thumb that never moves will not). CDP note: `touchEnd` must carry no points (it ends everything); release ONE finger with a `touchMove` listing the others. Desktop profile = keyboard only, no touch layer. A console error
`Can't change this state while flushing queries ... area_set_shape_disabled` is PRE-EXISTING game noise (reproduces
with the keyboard on desktop) and is whitelisted by exact text; anything else fails the gate.
Phone sizes use DPR 2 and tablet DPR 1 to keep SwiftShader fast; dp (== CSS px) is what the layout sees either way.

Never write FIXED/live on the strength of these alone. Say "pushed / deploying", then ask the founder for a
hard-refresh check on his phone and tablet.

### Founder device checklist (hard refresh first)
1. Start Stage 1: controls fade in, controls pulse ~4s (no words), then drop to see-through.
2. Hold a thumb on the left: the stick appears under it. Light push walks, firm push runs; slide up on a ladder.
3. Hold the stick, tap the jump icon (double tap = double jump) and the attack icon at the same time.
4. Tap RUN once: stays lit and keeps sprinting; tap again to stop.
5. Rotate the phone: controls re-lay out and nothing sticks. Pause/resume: nothing keeps running.
6. Tablet: buttons larger and further in from the edge; nothing covers the character.
7. Laptop: touch layer absent; keyboard plays exactly as before.

## Known gaps (found, not fixed - outside the touch layer)

- **Vault realms**: the Diamond Vault clerk's intro can be tapped through, but Gideon's (Fort Knox) dialogue still needs
  `interact` / ESC and its last `interact` STAKES gold, so it needs its own Next / Confirm / Leave buttons before touch
  can drive it (value-moving: follow `goldmine-economy-invariants`). The Smoke Lounge and vault rooms do get the stick,
  buttons and a way back out.
- `src/ui/pause_menu.gd:12` calls `event.is_action_just_pressed(...)` (an `Input` method, not an `InputEvent` one): a
  script error on every event and PAUSED can never be entered. Pre-existing (keyboard Escape logs it too); fixing it
  would switch a dead pause menu on, so it needs the founder's call.
- Console noise `Can't change this state while flushing queries ... area_set_shape_disabled` is pre-existing game noise.

## Not built (on purpose)

- No gesture detector / swipe-dash / invisible tap zones: the DO-NOT list forbids invisible zones and buttons are
  more reliable. Extension point: a `Control` that emits through `TouchActions` like the others.
- No player-draggable layout editor, left-handed mirror, dual-stick or Episode 2 look-stick yet.
- Native Android/iOS export paths use `dpi/160` density and the safe-area API but are untested on hardware.
