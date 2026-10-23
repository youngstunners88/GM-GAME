---
name: gm-game-mobile-touch-experience
description: "Owns the on-screen touch controls for Lil Blunt (phones and tablets): the analog virtual joystick, thumb buttons, the finger-movement controls (Blaze tap field, Episode 2 swipe pad and look pad), the touch PROFILES (platformer, blaze, ep2_runner, ep2_foot, ep2_film, ep2_end, ep2_rotate, none), per-device layouts, the MobileLayoutManager autoload, TouchUi.keys_shown() (the wordless rule), and the tests/browser checks that prove them. TRIGGER on any request about touch/mobile/tablet controls, 'players use finger movements', 'keys written on the screen', 'controls cover the screen', joystick, swipe, tap field, look pad, thumb reach, button size or position, safe area/notch, orientation, haptics, itch.io on a phone, 'cannot play on mobile', a new scene that needs touch controls, or any edit under src/input/mobile/. Read BEFORE touching touch input, and never add a second touch path. Area skills: gm-game-blaze-rush-mobile, ep2-mobile-touch, gm-game-mobile-seamless-transitions, gm-game-touch-flow-verification."
---

# Mobile & tablet touch experience

Founder prompt: `PROMPT_MOBILE_TABLET_TOUCH_EXPERIENCE_2026-10-13.md`. Decision record:
`docs/architecture/adr-mobile-touch-controls.md` (+ the 2026-10-23 amendment: profiles and finger-movement controls). Older spec (history + DO-NOT list + per-profile
layout tables): `docs/MOBILE_CONTROLS_SPEC.md`. Area skills that use this layer: `gm-game-blaze-rush-mobile`, `ep2-mobile-touch`; hand-offs:
`gm-game-mobile-seamless-transitions`; proving it: `gm-game-touch-flow-verification`.
**Founder rule that governs everything here (2026-10-13, angry; repeated 2026-10-22): mobile games do not have the keys written on them; players use finger movements.**

## The one rule

**InputMap actions are the only contract between touch and gameplay.** Virtual controls press the same
actions the keyboard does (`move_left/right/up/down`, `jump`, `dash`, `sprint`, `attack`, `interact`) through
`TouchActions`. Gameplay (`player.gd`, combat, forges) never references touch, the joystick, or a CanvasLayer.
Keyboard/gamepad parity is therefore by construction; the touch layer is simply hidden on non-touch machines.

```
finger -> Godot GUI -> VirtualJoystick / VirtualButton / VirtualTapField / VirtualSwipePad / VirtualLookPad -> TouchActions -> InputMap -> player.gd reads Input.*
```
(One documented non-action exit: the look pad's delta goes into `TouchActions.add_look()` and the first-person room drains it with `take_look()` once a frame.)

## Files (all under `src/input/mobile/`)

| file | job |
|---|---|
| `mobile_layout_manager.gd` | **Autoload** `MobileLayoutManager`. WHETHER controls exist (touch device, PLAYING, a platformer `Player` or the `touch_controls_wanted` group, not locked, not keyboard-driving, profile not `none`), WHICH profile + layout, relayout on `size_changed`, release-on-hide, per-profile first-run wordless pulse, prefs (`user://touch_controls.cfg`). |
| `touch_ui.gd` (`TouchUi`, static, null-safe) | **The one predicate.** `keys_shown()` = `not (is_touch() and not is_keyboard_mode())`, `is_touch()`, `is_keyboard_mode()`, `metrics()`, `is_portrait()`, `profile()`. Game code never re-derives "touch" from `OS.get_name()`. |
| `touch_metrics.gd` | Pure device maths: phone/tablet by **smallest side in dp (<600 = phone)**, orientation, `dp` = **canvas units per dp**, safe area (notch insets + minimum edge margin), `layout_key()`, `profile_layout_key(profile, device, orientation, available_keys)`. |
| `touch_actions.gd` | The injector: `press/release/set_axis/release_all/set_suspended/buzz` plus `pulse/tap/add_look/take_look/look_pending/ensure_action`. Mirrors `TouchScreenButton`: `Input.action_press(strength)` for polled reads **and** an `InputEventAction` on press/release edges for `_input` handlers. |
| `virtual_control.gd` | Base `Control`: anchor corner + offset in dp + radius in dp, round hit test, theme lookup, `dp`, `set_inert(bool)`, `on_suspended(bool)`, `base_mouse_filter`. **No text helper** (`_draw_label` was removed). |
| `virtual_joystick.gd/.tscn` | Analog stick. FIXED / DYNAMIC (default) / FOLLOWING. Horizontal = **analog strength**; up/down = deliberate, hysteresis-gated digital (ladders, drop-through, ground pound). Option `analog_vertical` (default false; first-person rooms) makes forward/back analog and bypasses "vertical intent beats sidestep". |
| `virtual_button.gd/.tscn` | Round thumb button. HOLD or TOGGLE. Vector `Glyph` enum (append-only ints): NONE0 JUMP1 ATTACK2 DASH3 RUN4 GRAB5 PAUSE6 SKIP7 PICKAXE8 CYLINDER9 SCOPE10 RETRY11 HOME12 PLAY13 EXIT14 EYE15. Exports `hold_seconds` (ring fills while down, `hold_completed` once), `ring_progress`, `arm_delay_s` (ignores presses for N s after it appears; `is_armed()`), `touch_only` (`ensure_action` on `_ready`). |
| `virtual_tap_field.gd/.tscn` | `VirtualTapField` - full-viewport "tap anywhere" (Blaze). Every NEW finger = `TouchActions.tap(action)` + `buzz(8)`; last finger up releases; draws only a 0.18 s ring. A real (device != -1) left click counts as a finger; the emulated mouse is swallowed. |
| `virtual_swipe_pad.gd/.tscn` | `VirtualSwipePad` - Episode 2 runner hop / jump / duck from finger travel (constants in dp at the top; pure inner `Classifier`). See `ep2-mobile-touch`. |
| `virtual_look_pad.gd/.tscn` | `VirtualLookPad` - first-person look by dragging (`add_look(dp_travel * gain * 1.85)`, gain 1.6, 4 dp slop, 48 dp clamp). |
| `virtual_rotate_cue.gd/.tscn` | `VirtualRotateCue` - dimmed screen + drawn phone + curved arrow, `swallow_input` (profile `ep2_rotate`). |
| `touch_layout.gd` | Root script of layout scenes: places controls from metrics, fans out theme/hint/release; `profile`, `set_inert`, `on_suspended`. |
| `layouts/phone_landscape.tscn`, `tablet_landscape.tscn`, `phone_portrait.tscn` | The **platformer** scenes (`LAYOUT_SCENES`). Numbers are dp. Tablet = x1.2 tier scale + wider spacing. Each ends with the small **Pause** button (top-right, below the HUD's lives + fullscreen cluster, action `pause`, glyph PAUSE). |
| `layouts/<profile>_{phone_landscape,tablet_landscape,phone_portrait}.tscn` | The 18 **profile** scenes (`PROFILE_SCENES`): blaze, ep2_runner, ep2_foot, ep2_film, ep2_end, ep2_rotate. Tables below / in `docs/MOBILE_CONTROLS_SPEC.md`. |
| `touch_theme.gd` + `themes/smoke_realm_touch_theme.tres` | Tints, idle/pressed opacity (0.30 / 0.78), stroke widths. Swap per biome with `MobileLayoutManager.apply_theme()`. |

Gates: `tests/mobile_touch_controls_test.tscn` (`MOBILE_TOUCH_CONTROLS`, 221 checks incl. mutation-checked regressions and a second geometry loop over the profile scenes, in CI) and
`tests/touch_controls_profiles_test.tscn` (`TOUCH_CONTROLS_PROFILES`, 218 checks: TouchUi, the new TouchActions verbs, swipe classifier, tap field, look pad, profile selection, build-before-show, one release per profile change, layer above the films, scoped hide fade, analog_vertical golden signature, every layout scene and every source file in `src/input/mobile` wordless).
Browser: `scripts/touch-playtest.mjs`. Pause: `tests/pause_menu_test.tscn` (69 checks, in CI) and `scripts/pause-playtest.mjs` (real Chromium, keyboard + touch).

## Profiles (which control set is up) - the profile source contract

The scene tells the manager WHICH set it wants; the manager never knows the scenes. It reads the **FIRST node (group order = tree order) in group `touch_controls_wanted` that has `func touch_profile() -> StringName`**
(nodes queued for deletion are skipped). Group nodes WITHOUT the method keep the legacy platformer behaviour (the Stage 3 film's old hold-JUMP semantics, `StudyRoom`). Optional on the same node:
`func touch_suspended() -> bool` (controls stay up but inert - "the armory is open, do not orphan the walking thumb") and `signal touch_profile_changed` (the manager connects `refresh()` to it the first time it reads the node: an immediate swap instead of the 5 Hz poll). An unknown name -> platformer + one `push_warning`.

| profile (`MobileLayoutManager.PROFILE_*`, `KNOWN_PROFILES`) | controls | layer |
|---|---|---|
| `platformer` (default) | stick + jump/attack/dash/run/grab + pause | 18 |
| `blaze` | `TapField` + top-right Pause | **60** |
| `ep2_runner` | `SwipePad` + attack + pickaxe + pause | 18 |
| `ep2_foot` | look pad + analog stick + fire/jump/aim/reload/interact/run + pause | 18 |
| `ep2_film` | one SKIP button with a hold ring | **60** |
| `ep2_end` | retry + home (armed after 0.8 s) | **60** |
| `ep2_rotate` | the drawn "turn your phone" cue (swallows touches) | **60** |
| `none` | hide + release everything | - |

- **Registries**: `LAYOUT_SCENES` = the three platformer scenes ONLY; `PROFILE_SCENES` = the 18 others, keyed `<profile>_<phone_landscape|tablet_landscape|phone_portrait>`. A missing key falls back to that profile's landscape scene, then to the platformer layout (`TouchMetrics.profile_layout_key`).
  **TRAP: keep them separate.** `tests/pause_menu_test.gd` walks EVERY `LAYOUT_SCENES` entry and demands a Pause button (the film/end/rotate scenes deliberately have none), and the platformer geometry loop must stay platformer-only.
- **`LAYER_OVER_FILMS = 60`** (profiles `blaze, ep2_film, ep2_end, ep2_rotate`; `LAYER = 18` for the rest). Episode 2's film and weapon-selector layers sit at 40, the Blaze pause card at 40, the Episode 2 pause card at 70.
- **LAYERING / inert rule**: layer-60 profiles go INERT while suspended (state PAUSED / GAME_OVER, or `touch_suspended()`), so a game overlay on a lower layer receives the touch. While such a profile is LIVE its full-screen field/cue swallows touches: an overlay that needs touches must be shown while suspended, or the scene must return `none`.
- The layout for a changed profile/orientation is **built BEFORE the layer is shown** (no one-frame flash of the wrong layout) and a profile change releases everything **exactly once** (`release_count()`).
- `request_fade_hide(seconds := 0.12)`: call it just before the one hide you want faded (the Blaze portal, right before `SceneRouter.load_scene`). One-shot, valid 1.5 s; held actions release at once and the controls are `mouse_filter = IGNORE` for the whole fade. Every other hide stays instant (the vault lock test depends on that).
- First-run pulse is per profile in `user://touch_controls.cfg` (`hint_seen` for platformer, `hint_seen_blaze`, `_ep2_runner`, `_ep2_foot`; film/end/rotate never pulse).
- Introspection: `current_profile()`, `current_layout_key()`, `layout()`, `metrics()`, `debug_line()`, `is_hide_fading()`; signals `controls_visibility_changed`, `layout_changed` (fires BEFORE `controls_visibility_changed(true)` and before the new layout is positioned), `profile_changed`.

## The wordless rule, and what "no invisible zones" means now

- **`TouchUi.keys_shown()` gates every key name and keyboard instruction** (`SPACE`, `[E]`, `R - reload`, `HOLD Tab`, `TAP OUT (Q)`, "press X"). A pure phone never sees keys; a hybrid laptop driven with a keyboard still does. Replace with a vector icon or a pulse. Plain stat labels the founder asked for (BLAZE DIAMONDS n, ATTEMPT n, HP/ammo numbers, dialogue, a modal's own buttons, the access-code gate) stay.
  Source-level gate: `touch_controls_profiles_test` fails on any `draw_string` / `fallback_font` / `Label.new` / `Button.new` in `src/input/mobile` and on any text in a layout scene; `ep2_touch_controls_test` section `words` and `blaze_rush_touch_test` scan the Episode 2 / Blaze UI with the touch flag forced.
- **REFINED (2026-10-23; the founder's "players use finger movements" supersedes the old blanket "no invisible tap zones")**: swipe / look / tap zones ARE allowed - but only as real, VISIBLE `Control`s in the layout scene (a faint ring + chevrons, corner brackets, a tap ring, a first-run pulse) with **per-finger ownership, release-on-hide, and the orphan rule** (never adopt a finger the control did not press), sitting FIRST in the layout so buttons drawn after them win their own touches.
  Still forbidden: `TouchScreenButton`, a second parser next to this layer, any gesture detector in game code, any hidden hit area. If you add a zone, give it a resting visual cue and put it in the layout scene.

## Why real `Control`s, not TouchScreenButton or a hand-rolled `_input` router

Verified on Godot 4.3 (not assumed): the GUI delivers `InputEventScreenTouch/Drag` **per finger index** to the
Control under that finger, keeps routing that finger's drag **and release to the same control even after it
slid off or left the window**, and fingers are independent (stick + jump + attack at once). Consequences:
true multi-touch, correct **z-order** (a modal on a higher canvas layer wins its own buttons; the touch layer
is `LAYER = 18`, below vault/oracle/companion panels at 20-30 and how-to-play at 80; the profiles that must stay usable over films
and the Blaze card sit at `LAYER_OVER_FILMS = 60`), and round hit areas via
`_has_point`. Only the finger-0 touch also becomes an emulated mouse event (`emulate_mouse_from_touch` stays
ON so menus work); the controls ignore mouse events and the STOP filter stops them leaking to the game.

## Device classes and sizing

Sizes are designed in **dp** (density-independent) and converted: `canvas_units = dp x metrics.dp`. Project stretch
is `canvas_items` + `expand` (1280x720 or larger canvas), so the same 40dp JUMP is ~74 canvas units on a phone
and ~50 on an iPad: constant *thumb* size, smaller share of the screen on tablets. Web density = device pixel
ratio (CSS px == dp); native mobile = dpi/160. Safe area: `DisplayServer.get_display_safe_area()` is trusted only
when the window fills the screen; on web it is empty so a 14dp side/top and 18dp bottom margin is always kept.
**`TouchMetrics.dp` is CANVAS UNITS PER dp** (not dp per unit): a 28-unit cube is `28 / dp` dp tall. Writing the ratio the other way round is a one-line bug that clamps to 1.0 and silently does nothing
(it almost shipped in `BlazeFraming`). Headless runs report density 1, so test in dp-equivalent windows (844x390, 390x844, 1024x768).
HUD keep-outs for Episode 2 are CANVAS units (150x96 bottom-right ammo box, 140x80 bottom-centre holster), i.e. larger in dp on a tablet.

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
- **The pause button** (`action = pause`, a HOLD button like the others) is the touch route to the pause menu: Escape does not
  exist on a phone. It presses the `pause` action (project InputMap: gamepad Start; deliberately NOT a key, `P` is the
  checkpoint share-snapshot hotkey and Escape stays `ui_cancel`). `pause_menu.gd` toggles on either action. While PAUSED the
  layer is suspended like on death, so the button is inert; **Resume is the menu's own button**, which sits on canvas layer 40,
  ABOVE this layer (18), so the dimmed stick region underneath can never swallow a tap on it.
- **Vault dialogues (Gideon / Fort Knox, Mira / Diamond Vault) are modal AND lock the touch layer.** Their panels sit on layer
  30 over the GRAB button, and GRAB is just the `interact` action, which `vault_realm.gd._physics_process` also reads as
  "advance" and, on the last step, as the stake / `clerk_confirm`. So `gideon_open()` / `clerk_open()` call
  `MobileLayoutManager.set_locked(&"vault_panel", true)` (released in `*_close()` and `_exit_tree()`): a stray GRAB can never
  reach a value-moving step. Gideon's panel has real **NEXT / CONFIRM STAKE / LEAVE** buttons (>=96px, `FOCUS_NONE` because a
  focused Button also answers `ui_accept`, which the vault reads too = double fire). Rules for any NPC panel that moves value:
  background taps do nothing; the confirm button exists only on the last line, away from NEXT; it is disarmed for a short window
  after appearing (`GIDEON_CONFIRM_ARM_SEC`); NEXT is guarded so it can never be the terminal step. The panel BUTTONS keep
  their words (a modal's own buttons, not the touch overlay); its `[E] / NEXT   [ESC] / LEAVE` hint line and the vault's
  `[E] TALK` / `press E` prompts are hidden / reworded on touch devices via `_keys_shown()` (no-words rule). Gate:
  `tests/vault_touch_dialogue_test.tscn`.
- **Hybrid devices**: a real key press hides the controls, the next screen touch brings them back.
  A real finger also proves a touchscreen even if the platform said no.
- **NO WRITTEN WORDS on the touch UI (founder 2026-10-13, angry; repeated 2026-10-22).** Phones show icons and finger movement only: no
  JUMP/ATK/MOVE/"?" text, no key names, no hint line. Teach with a first-run opacity pulse (`flash_hints()`, wordless) or a drawn cue.
  Never add a `label`, a Label node or a keyboard hint on touch devices; gate any existing key-naming string on `TouchUi.keys_shown()` (see "The wordless rule").
- Haptics: `Input.vibrate_handheld(12)` on press where the platform has it (Android browsers; no-op on iOS Safari).

## Extending

- **New button**: drop a `virtual_button.tscn` instance into each layout scene; set `anchor_corner`, `offset_dp`,
  `radius_dp`, `action` (must exist in the InputMap), `glyph` (vector icon, no text), `role` (tint). No code changes.
- **New screen shape**: add `layouts/<key>.tscn`, register it in `MobileLayoutManager.LAYOUT_SCENES` (platformer) or `PROFILE_SCENES` (a profile), return the key
  from `TouchMetrics.layout_key()`. The geometry test then checks it automatically if you add the screen to its list.
- **A new profile**: add the name to `PROFILE_*` + `KNOWN_PROFILES` (+ `PROFILES_OVER_FILMS` / `PROFILES_WITH_HINT` if needed), the three layout scenes to `PROFILE_SCENES`, a
  geometry/keep-out entry in the profile loop of `mobile_touch_controls_test`, and a `touch_profile()` on the scene's group node. Layout scenes contain real `Control`s only (no text), `TapField`/`LookPad`/`SwipePad` FIRST.
- **A new scene that needs controls** (a chamber, a portal explorer): put a node in group `touch_controls_wanted` (in `_ready`, before anything can reach PLAYING) and give it
  `touch_profile()`. A platformer `Player` already counts. **Remove the node from the group when the scene ends** or the layer lingers over menus. Group order is TREE order:
  a parent that returns `none` beats its children - only join the group while you really are the source (Ep2Entry joins only while the run is over).
  Episode 2 rooms: see `ep2-mobile-touch` (profiles `ep2_runner` / `ep2_foot` / `ep2_film` / `ep2_end` / `ep2_rotate`); Blaze: `gm-game-blaze-rush-mobile`.
- **A touch-only verb** (no key): register an EMPTY InputMap action with `TouchActions.ensure_action(&"x")` (a layout button with `touch_only = true` does it on `_ready`), then read it like any action.
  `TouchActions.press` silently returns for an unknown action.
- **A momentary gesture** (swipe hop / jump): `TouchActions.pulse(action)`; **a tap that must always be a fresh edge**: `TouchActions.tap(action)`; **look**: `add_look` / `take_look`.
- **A skippable film that needs the controls** (the Stage 3 boss-defeat film is skipped by HOLDING jump): add the node to
  `touch_controls_wanted` while it plays. That group is the only thing that keeps controls through LEVEL_COMPLETE (victory
  and menu screens never opt in, so their buttons stay free). Remove it when the film ends. A film that returns `touch_profile() -> &"ep2_film"` gets one SKIP button
  with a hold ring instead of the whole platformer cluster; the film's own skip rule (hold `jump` after one release) is unchanged.
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
4. Never use `TouchScreenButton`, HIDDEN tap zones, or a second parser next to this one (the 2026-08-01 audit's
   double-fire/stuck-input bugs). One path only. (Visible swipe / look / tap-field Controls in a layout scene are the sanctioned exception - see "The wordless rule".)
5. `move_up` and `jump` share the W key on the keyboard but are separate actions on touch - do not merge them.
6. Do not rely on `emulate_mouse_from_touch` for controls (single pointer); do not turn it off (menus need it).
7. `gdparse` is syntax-only. The truth is the headless test + a real export.
8. The GUI keeps delivering a finger's drags to the control it pressed **even while that control is hidden** - code that
   releases on hide must also decide what a later drag from that finger means (we adopt it in the stick).
9. Never adopt a finger the control did not press: after `GAME_OVER` / pause the GUI still sends that finger's drags
   to the control, and a finger that pressed while it was hidden gets drags but NO release.
10. Run the security sentinel **after** `git add`. Do not commit the `.godot-cache` symlink or `export_presets.cfg`.
11. **Godot only turns the FIRST finger down into a mouse click** (`Input.mouse_from_touch_index`). A thumb resting on the stick owns
    that slot, so a second finger tapping an ordinary `Button` (the pause menu's Resume) does NOTHING until the first thumb lifts
    (measured: `tests/pause_menu_test.gd`, mutation M5). Any modal opened while a thumb can still be down must also react to the raw
    `InputEventScreenTouch` its buttons receive in `gui_input`, and dedupe against the emulated click arriving in the SAME frame
    (see `PauseMenu._activate`). Never fix this by cancelling the stick's finger: that throws away the "thumb never has to lift" model.
12. **`press()` only pushes an `InputEventAction` on the not-held -> held edge**, so a resting finger swallows the next finger's tap. Use `TouchActions.tap()` (fresh edge) or `pulse()` for edge-reading consumers.
    A tap through a STOP control gives the consumer exactly ONE down event; a probe in `_unhandled_input` counts press AND release (2 touches / 2 mouse events per tap) when nothing swallows it.
13. **`ColorRect` defaults to `mouse_filter = STOP`** in 4.3 and eats taps meant for `_unhandled_input` (it killed Blaze's tap-to-jump over most of the screen). Any non-button Control under a tap-driven scene must be IGNORE.
14. **Layer-60 profiles swallow touches while LIVE** (their field is full-screen). An overlay of the game's own on a lower layer only gets touches while the profile is suspended (`touch_suspended()` / PAUSED / GAME_OVER) - or return `none`.
15. A profile change releases everything exactly once; a thumb resting on the old profile's control is dropped at the swap (acceptable at a cover). A paused tree drops release events, so a held verb that began as an event must be resynced from polled `Input` (`Ep2SessionRoot._resync_held_verbs`).
16. `TouchActions.pulse` releases on the first process frame AFTER the next physics frame (at high render rates there may be no physics tick in between, and a polled `_physics_process` reader would otherwise never see a one-frame pulse).
17. `move_down` is in `TouchActions.RESUME_ACTIONS`: a control that holds it (the swipe pad's duck) must drop it ITSELF on suspend or it comes back at respawn.
18. Comparing a freed instance with `!= null` is false in 4.3; keep nodes in locals only while alive. `x == [..] as Array[int]` parses as `(x == [..]) as Array[int]`.
19. `tests/pause_menu_test.gd` walks EVERY `LAYOUT_SCENES` entry and requires a pause button: profile scenes live in `PROFILE_SCENES`.
20. A tap through the emulated mouse: only the FIRST finger down becomes a click and carries `device == InputEvent.DEVICE_ID_EMULATION` (-1); check it before treating a mouse event as a real mouse (Episode 2 router fix F8).
21. GDScript 4.3 facts used here: inner classes DO see the outer class's consts and enums (`VirtualSwipePad.Classifier` relies on it); a `static func` can be bound as a `Callable` and connected one-shot (`TouchActions.pulse`); `:=` inferred from a Variant is a hard error.
22. Per-file indentation: a mixed file passes gdparse and FAILS a real export. `src/input/mobile/**` is TABS (check with `grep -c $'^\t'` vs `grep -c '^    '` before editing any file).

## Verify (in this order)

(Always with a fresh `XDG_DATA_HOME=$(mktemp -d)` and a `timeout` - full recipe, order, cost and traps: `gm-game-touch-flow-verification`.)
```bash
godot --headless res://tests/mobile_touch_controls_test.tscn      # ends MOBILE_TOUCH_CONTROLS: ALL PASS
godot --headless res://tests/touch_controls_profiles_test.tscn    # ends TOUCH_CONTROLS_PROFILES: ALL PASS (profiles + new controls)
godot --headless res://tests/vault_touch_dialogue_test.tscn       # ends VAULT_TOUCH_DIALOGUE: ALL PASS (Gideon/Mira buttons + lock)
godot --headless res://tests/script_compile_test.tscn             # every script/scene still compiles
bash scripts/ep2-local-export.sh                                   # CI-identical non-threaded web export
node scripts/touch-playtest.mjs http://localhost:8899/game/index.html web_verify/touch-playtest phone,tablet,desktop
godot --headless res://tests/pause_menu_test.tscn                 # ends PAUSE_MENU: ALL PASS (pause, resume, Talk, thumb-down Resume)
node scripts/pause-playtest.mjs http://localhost:8899/game/index.html web_verify/pause-playtest desktop,phone
```
`touch-playtest.mjs` boots the export in Chromium with a touch-capable mobile context, taps PLAY, then sends real
multi-finger events over CDP (`Input.dispatchTouchEvent`): light tilt, firm push, JUMP + ATK with the stick held,
RUN toggle, hold-through-death. Every shot carries the game's own F3 overlay (`?debug=1`: player pos, |v|, floor,
dying, and an `INPUT held:` line listing every action the game really sees held) as hard evidence - read the PNGs, not the button visuals. The game also prints rare `[Touch] ...` lines (controls SHOWN / HIDDEN / SUSPENDED / RESUMED, layout builds, focus loss, and - only while the F3 / `?debug=1` overlay is on - every finger DOWN/UP/CANCELED); the playtest echoes them, which is how a "thumb stopped steering" report is diagnosed (e.g. a last-life death reloads the level: HIDDEN (TRANSITIONING), so a held thumb needs one tiny drag to resume - a scripted thumb that never moves will not). CDP note (verified on Chromium 1194 with a bare page, re-prove with `node scripts/cdp-touch-probe.mjs`; the helper `multiTouch()` in `scripts/lib/pw.mjs` encodes it): `touchStart`/`touchMove` list EVERY active point; `touchEnd` releases exactly the point(s) LISTED in it, so list ONLY the finger you lift; `touchEnd` with `[]` ends ALL fingers; a `touchMove` that omits a finger releases NOTHING (an earlier version of this note claimed the opposite and a script written to it never lifted a finger). A phone has no keyboard: touch profiles from `scripts/lib/pw.mjs` throw on `page.keyboard.*`, so dismiss panels by tapping. Desktop profile = keyboard only, no touch layer. A console error
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
8. Fort Knox: walk to Gideon, tap the hand button. The controls hide and his panel shows NEXT; tap through to CONFIRM STAKE (greyed for ~0.6 s); LEAVE works on every line; the controls return after.
9. Blaze Rush (all three stages), Episode 2 runner + hideout, and the Episode 1 -> 2 hand-off have their own checklists in `gm-game-blaze-rush-mobile`, `ep2-mobile-touch`,
   `gm-game-mobile-seamless-transitions`; the plain-words version for the founder is `docs/MOBILE_TEST_STEPS_2026-10-23.md`. The BUILD tag at the bottom-left must have changed after the hard refresh.

## Known gaps (found, not fixed - outside the touch layer)

- (FIXED 2026-10-13, was listed here) `src/ui/pause_menu.gd` called `event.is_action_just_pressed(...)`, an `Input` method that
  `InputEvent` does not have, so it threw on every event and PAUSED could never be entered. Now `is_action_pressed` + no echo,
  gated by `tests/pause_menu_test.tscn`. Whether pausing should exist at all is still the founder's call.
- **Vault altars / Assay Scale** (`vault_realm.gd`): reached with GRAB, and ONE press stakes 25% (E always did the same).
  A founder decision, not changed: whether a touch player should get a confirm step there too.
- Console noise `Can't change this state while flushing queries ... area_set_shape_disabled` is pre-existing game noise.
- The existing PAUSE glyph reads as a stop SQUARE at r 17 dp (pre-existing; left alone so the platformer looks unchanged).
- Every threshold of the new finger-movement controls is a PAPER number until a device pass: swipe hop 22 / jump 20 / duck 24 (release 12) / slop 8 dp, lockouts 120 / 150 ms, the 24 dp back-swipe inset, look gain 1.6 x 1.85, look slop 4 dp.
- Known game-side leftovers that still write key names on touch (Episode 2 later rooms, the armory shop): `ep2-mobile-touch` "Known gaps". `hud.gd` (line ~144) keeps a private copy of the touch predicate (ignores `force_touch_ui` and a finger-proven touch device); `how_to_play_panel.gd` has a words TOUCH column (a modal's own content; it is shown from the main menu).

## Not built (on purpose)

- No gesture detector in game code, no `TouchScreenButton`, no HIDDEN tap zones. (Built since the first version, as visible Controls in layout scenes: the Blaze tap field, the Episode 2 swipe pad, the look pad - see "The wordless rule".)
- Still not built: a player-draggable layout editor, left-handed mirror, a second look stick, an aim-assist FirePad (`ep2_fire`, `press_at`) for the Episode 2 runner, a runner reload button, a contextual tutorial / ghost-finger demo, a `BlazeProfile.lite`.
- Native Android/iOS export paths use `dpi/160` density and the safe-area API but are untested on hardware; no real phone has run the 2026-10-23 profiles (Chromium + SwiftShader and headless only).
