---
name: ep2-mobile-touch
description: "Episode 2 Part 1 on a phone or tablet: the mine-tunnel RUNNER (swipe pad, attack, pickaxe), the Smelting Facility hideout on foot (stick, look pad, fire/jump/aim/reload/interact/run), the film skip, the run-over retry/home, the wordless pause card, the portrait 'turn your phone' cue, and the Episode 2 input-router fixes that make touch possible. TRIGGER on Episode 2 on mobile, swipe to hop/jump/duck, look pad, 'cannot play Episode 2 on my phone', 'RUN FAILED black screen on phone', film cannot be skipped on touch, ep2_runner / ep2_foot / ep2_film / ep2_end / ep2_rotate, ep2_touch_* actions, Ep2TouchOverlay, any new Episode 2 room that must be playable by touch, any key name written in an Episode 2 HUD. Read BEFORE adding a verb, a room or a string to Episode 2."
---

# Episode 2 Part 1 on a phone

Scope built 2026-10-23: the mine RUNNER (`LEG_DESCENT`, 1800 m), the runner -> cliff film -> hideout cut, and the Smelting Facility on foot
**through its exit** (range lesson: walk/look/reload/ADS/fire/jump). Later rooms (mine lift, woods quad, gold town, Logan's Lake) get the
`ep2_foot` profile where they use the shared free-roam verbs but are NOT acceptance scope - see "Known gaps".
Rules come from `gm-game-mobile-touch-experience` (one path, wordless, no invisible zones). Desktop controls: `ep2-free-roam-controls`,
`gm-game-episode2-runner-combat`. Hand-off into this scene: `gm-game-mobile-seamless-transitions`. Proof recipe: `gm-game-touch-flow-verification`.
**Verified headless (181 checks in `ep2_touch_controls_test`) only. No phone. Never write FIXED/"live"; the founder confirms on a device.**

## Who returns which profile (the group-order trap)

`MobileLayoutManager` takes the profile from the FIRST node in group `touch_controls_wanted` (tree order) that has `touch_profile()`.

| profile | when | returned by |
|---|---|---|
| `ep2_runner` | RUNNER mode, `is_running()` | `Ep2SessionRoot.touch_profile()` |
| `ep2_foot` | CHAMBER, free roam, `has_player_control()` (or armory open) | `Ep2SessionRoot` |
| `ep2_film` | CHAMBER and the active room's `is_film_skippable()` (Smelting Facility: beat CINEMATIC and the Seedance film or the in-engine fallback `is_skippable()`, i.e. >= `SKIP_SHOW_AT` 1.0 s in and not finishing) | `Ep2SessionRoot` |
| `ep2_rotate` | RUNNER / foot while the window is portrait on a touch device not in keyboard mode | `Ep2SessionRoot` |
| `none` | TRANSITION, IDLE, scripted beats, shop-style modals | `Ep2SessionRoot` (manager hides + releases) |
| `ep2_end` | run over (`_ended`), retry + home | **`Ep2Entry`** - it joins the group ONLY while ended |

TRAP: `Ep2Entry` is the PARENT of the session root, so in tree order it comes first. If it stayed in the group returning `none`, it would
win and hide everything. It therefore joins in `_set_ended(true)` and leaves in `_set_ended(false)`. When the run ends the session root is
IDLE (it returns `none`), which is why the end profile cannot live there. `Ep2SessionRoot` joins in `_ready` (so there is no 0.2 s gap at the
hand-off reveal) and emits `touch_profile_changed` (the manager connects to it on first read: immediate swap instead of the 5 Hz poll).
`touch_suspended()` = CHAMBER and `armory_open()` -> controls stay up but inert so the walking thumb is not orphaned.
The manager's 5 Hz poll may lag a change by up to 200 ms where no signal fires.

**StateMachine precondition.** Controls exist only in PLAYING. The boss hand-off gets PLAYING from `TransitionDirector` at REVEALING. The menu /
`?ep2=1` route leaves the machine in TRANSITIONING and nothing in Episode 2 used to change it: `Ep2Entry._enter_playing()` (called from `_begin()`, i.e.
AFTER the access gate so the code screen never sits in PLAYING) moves TRANSITIONING -> PLAYING when `TransitionDirector.state == S.IDLE`.

## Runner layout (`ep2_runner_{phone,tablet}_landscape`, `_phone_portrait`)

`SwipePad` (VirtualSwipePad; region x 0..0.44, y 0.12..1.0 of the safe rect; rest ring at (112, 92) dp; left edge kept `EDGE_INBOARD_DP` 24 in from the
screen edge so the OS back-swipe is not triggered) - `Attack` (bottom-right (92,96) dp r40, action `attack`; tablet (92,118)) - `Pickaxe` (bottom-right
(188,58) r34, action `ep2_touch_swipe`, `touch_only`) - `Pause` (top-right (30,64) r17, action `pause`). **No reload button** (the runner auto-reloads on empty
and on a dry fire), no stick, no fire pad, no aim assist.
- `attack` -> router `runner_shoot()` = the existing **auto-aim** shot at the nearest archer. `ep2_touch_swipe` -> `runner_swipe()` (the pickaxe at a boarder).
- A tap in a FREE area (outside every control) still fires an aimed round: finger 0 becomes an emulated LMB (`device == -1`) and the RUNNER branch keeps
  `runner_fire_at_screen`. Pads are STOP so a finger on a pad never fires. The top 12 % strip and the safe margins are free area (a stray touch there wastes a round).
- Only finger 0 makes an emulated mouse event (and only the FIRST finger down); a steer thumb parked on the pad cannot also aim with a second finger - that is why
  `attack` exists.

### Swipe-pad gestures (all dp of finger travel; constants at the top of `virtual_swipe_pad.gd`, tune on a device)

| constant | value | meaning |
|---|---|---|
| `SLOP_DP` | 8 | nothing counts below this travel from the anchor |
| `HOP_DP` | 22 | sideways: `abs(dx) >= 22` AND `abs(dx) >= AXIS_RATIO * abs(dy)` -> `TouchActions.pulse(move_left/right)` and **x re-anchors** (another 22 dp hops again without lifting) |
| `JUMP_DP` | 20 | upward: `dy <= -20` AND `abs(dy) >= 1.3 * abs(dx)`, armed, not locked -> `pulse(jump)`, y re-anchors |
| `AXIS_RATIO` | 1.3 | dominant axis must beat the other by this ratio |
| `JUMP_LOCKOUT_MS` | 120 | after a jump |
| `JUMP_REARM_DP` | 10 | the finger must come back down 10 dp (or lift) before the next jump; coming back down also re-anchors y at the finger (otherwise a wiggle after a long swipe jumps again - found by the test) |
| `DUCK_DP` / `DUCK_RELEASE_DP` | 24 / 12 | `dy >= 24` -> `press(move_down)`, held while the finger stays below anchor + 12 (hysteresis) |
| `DUCK_MIN_HOLD_MS` | 150 | a flick ducks an arrow volley even if the finger lifts early |
| `RING_RADIUS_DP` / `FLASH_SECONDS` | 44 / 0.28 | visible faint ring + chevrons under the thumb; DYNAMIC origin |

The decision logic is the pure inner `VirtualSwipePad.Classifier` (dp coordinates, explicit msec clock, `enum Cmd`) so a test feeds synthetic point streams.
Outputs are ordinary InputMap verbs (`move_left/right/jump/move_down`), read by the router exactly like the keyboard. TRAPS: `move_down` is in
`TouchActions.RESUME_ACTIONS`, so a duck left wanted would come back at respawn - the pad drops it ITSELF in `on_suspended(true)` and the finger that
was down during a suspension is ignored until it lifts (never adopted). `TouchActions.pulse` lasts one physics tick + a process frame (a polled
`_physics_process` reader always sees it; `_input` handlers see down + up).

## On-foot layout (`ep2_foot_*`)

`LookPad` (region 0.42, 0, 0.58, 0.8 of the safe rect; FIRST = lowest z) - `Stick` (VirtualJoystick DYNAMIC, region 0, 0.30, 0.40, 0.70, base r58, **`analog_vertical = true`**) -
`Fire` (BR (92,96) r44, `attack`) - `Jump` (BR (196,62) r36, `ep2_touch_jump`) - `Aim` (BR (84,196) r30, `ep2_touch_aim`, SCOPE glyph, HOLD) - `Reload` (BR (192,150) r28,
`ep2_touch_reload`, CYLINDER) - `Interact` (BR (288,120) r28, `interact`) - `Run` (BR (172,236) r28, `sprint`, TOGGLE) - `Pause`. Tablet scenes use larger Fire offsets
(118 dp vs 96) because the ammo HUD keep-out is 150 x 96 CANVAS units, i.e. bigger in dp on a tablet.
- Stick: forward/back are ANALOG (`Input.get_axis(&"move_down", &"move_up")`) and the platformer's "vertical intent beats sidestep" suppression is bypassed;
  platformer stick output is byte-identical (golden md5 signature in `touch_controls_profiles_test`).
- Look: `VirtualLookPad` -> `TouchActions.add_look(dp_travel * gain * 1.85)` (gain 1.6, 4 dp slop then the accumulated travel is applied, per-event clamp 48 dp,
  1.85 = canvas units per dp on the 844x390 reference). The router drains `TouchActions.take_look()` **once a frame** in `_poll_free_roam` into the same `look(relative)` verb
  the mouse uses. Cleared by `release_all()` and `set_suspended(true)` (a pause never banks a camera jump).
- Touch-only actions `ep2_touch_swipe / _reload / _aim / _jump` are registered EMPTY with `TouchActions.ensure_action` (layout buttons with `touch_only = true`
  do it on `_ready`; `Ep2SessionRoot._ready` does it too so a test without a layout works). No key event exists for them, so they can never collide with W = `jump` + `move_up`.
  `ep2_touch_aim` press/release -> `set_aim(true/false)`; `_resync_held_verbs()` ends an ADS or duck whose release was dropped while the tree was paused.
- The RUN button is a persistent TOGGLE: on touch it must never pick the Diamond-burn payment at `chamber_start_rig` (`interact` with `sprint` held) - gated on `TouchUi.keys_shown()` (audit F13).

## Router fixes (`ep2_session_root.gd`) and why

- **F5**: the `move_*` swallow was inside the `InputEventKey` branch; `TouchActions` pushes `InputEventAction`, which fell through to `chamber_walk` / `take_cover` (a horizontal push walked FORWARD).
  Hoisted out: `event.is_action("move_up"|"move_down"|"move_left"|"move_right")` returns true in `_route_free_roam`. Side effect (accepted): a gamepad D-pad no longer walks forward in free roam; `_poll_free_roam` reads the same axes.
- **F6**: `ep2_touch_jump` -> `jump()`; the W key is still NOT jump. `InputEventAction(jump)` does not match `move_up`/`ui_accept` (probed), so a separate touch action was kept only for clarity.
- **F8**: `InputEventMouse` with `device == InputEvent.DEVICE_ID_EMULATION` returns false in `_route_free_roam`: a look-drag must never fire, look or capture the pointer. A real mouse (device 0) is untouched.
  Keep this in mind when you add a pointer branch anywhere in Episode 2.
- Reticle (`runner_view.gd`): on touch no resting reticle at (0,0) (the initial `get_mouse_position()`); a ring at the last tap for `TOUCH_RING_S` 0.45 s; the gun arm aims at the tap only for `TOUCH_AIM_FRESH_S` 0.6 s then falls back to forward.

## Pause, portrait, run-over, film skip

- **Pause card** (`src/episode2/ep2_touch_overlay.gd`, `Ep2TouchOverlay`, canvas layer 70, wordless dim + PLAY + HOME). The Pause button presses the `pause` action; `Ep2Entry._unhandled_input` opens it **on touch devices only**
  (`TouchUi.is_touch()`), only for `ep2_runner` / `ep2_foot`, via `StateMachine -> PAUSED` (controls go dim and inert; deviation from DECISIONS: they stay `suspended`, not `none`, so a resting thumb survives).
  HOME = the same two lines as Escape (`_go_home`). `pause_menu.tscn` is NOT reused (its Restart/Quit call `reset_session()`). Desktop Esc is unchanged. Pads react to raw finger events with a one-activation-per-frame dedupe (touch trap 11).
- **Portrait**: the 3D runner/hideout cannot be framed upright (`Camera3D` keeps height, ~1.0 m half-width at the rider's depth on 390x844), so `touch_profile()` returns `ep2_rotate` (drawn phone + curved arrow, STOP over the screen) and the session root **pauses the tree itself**
  (`get_tree().paused`, `_rotate_paused`; StateMachine stays PLAYING so the manager still shows the cue) until landscape; a HOME icon sits on top so a portrait-locked phone is never trapped (`Ep2Entry._sync_portrait_exit`). `_exit_tree` never leaves the tree frozen.
- **Run over**: wordless -> banner text cleared, last frame kept as a dim scrim (`_show_scrim`, layer 8; the headless renderer has no viewport texture so a dark plate is used) and profile `ep2_end`: RETRY (BC (-66,120) r46, action `jump` = the existing retry) and HOME (BC (74,112) r34, `ui_cancel` = the existing exit),
  both with `arm_delay_s 0.8` (the player is mashing fire at the moment of death) and placed away from the fire button. Keep emitting `session_failed` and the armory restore in `_on_run_failed` (`ep2_personal_armory_test`, `ep2_stress_soak_test` rely on them): change only what is torn down and when.
- **Film skip**: profile `ep2_film` = one SKIP button (BR (66,66) r36, glyph double-chevron) that presses `jump` with a hold ring (`hold_seconds 0.9`). The film's own rule is unchanged (hold `jump` after one release, only from `SKIP_SHOW_AT`). Applies to `Ep2VideoFilm`, `CliffJumpCinematic` and
  (separately) `Stage3BossDefeatCutscene`. Untuned mismatch: ring 0.9 s vs the in-engine `CliffJumpCinematic.SKIP_HOLD` 0.6 s; the video film is 0.9 s.

## The wordless table (what replaced what; all gated on `TouchUi.keys_shown()`)

| was | on touch |
|---|---|
| `HOLD SPACE TO SKIP` / `hold SPACE to skip` (`ep2_video_film.gd`, `cliff_jump_cinematic.gd`) | hidden; SKIP button + ring |
| `R - reload` / `RELOADING` (runner_view) | hidden; the cylinder pips pulse and the reload bar says it |
| `RUN FAILED / SPACE / R try again / ESC menu`, `TO BE CONTINUED... SPACE / R`, lake-complete banner (`ep2_entry.gd`) | scrim + RETRY / HOME buttons |
| `HOLD Tab` (holster), `Search bear [E]`, `RELOAD [R]` (`ep2_fps_hud.gd`) | hold gesture / Search button hidden and routed to `interact` / icon |
| `OUT OF ROUNDS - PRESS R`, `EMPTY - NO RESERVE` (`smelting_facility.gd`) | `Ep2FpsHud.Token` icon (`EMPTY`/`CYLINDER`) with counts; `toast(text, seconds, token)` |
| range-lesson objective lines | icon path `Ep2FpsHud.LESSON_PATH` = BOOT, EYE, CYLINDER, SCOPE, BURST, TARGETS drawn with primitives + counts; `lesson_token`, `drawn_texts` test hook |
| runner telegraph `Label3D` `DUCK / HOP! / JUMP / SWIPE! X / right-click` | flat arrow / ring / cross cue glyphs (`CueGlyph`, `is_cue_wordless()`) |
| ep2 heat / retry hint (`smelting_facility.gd:1084`) | `Token.HEAT` / `Token.RETRY` |

`Episode2Mode.control_hint` is kept (a desktop test asserts it). Plain stat labels, dialogue and the access-code gate keep their words (the code gate is touch-reachable but a phone cannot type in it while
`html/experimental_virtual_keyboard=false`; flipping that flag changes focus handling for the whole game and needs a device test - NOT done).

## Tests (fresh `XDG_DATA_HOME`, `timeout`)

`ep2_touch_controls_test` (`EP2_TOUCH_CONTROLS`, ~18 s, `-- only=<section>` runs one of profile / runner / lifecycle / foot / film / portrait / entry / words): profile table; real-finger gestures (hop +-1 lane without spending ammo, jump, duck + min hold, pickaxe, attack -1 round, tap in free area fires once, steer + fire fingers);
suspend drops a held duck and it is NOT restored; mode swap releases everything; chained foot->foot hand-over keeps held input and never flips to `none`; F5/F6/F8; look pad -> yaw; ADS; reload; keyboard map unchanged; film skip with the real `Ep2VideoFilm` and the in-engine film; portrait pause/resume + HOME; Entry PLAYING on the menu route, pause card, run-over;
the wordless scan with a desktop control (the words return when the flag is off). Also: `touch_controls_profiles_test`, `ep2_session_root_test`, `touch_scene_swap_cleanup_test`, `ep2_smelting_facility_test`
(section **13** is the real-keys routing check; the old `ep2-free-roam-controls` cite of section 12 was wrong - 12 is the Bull rig).
Mutations: 42 were run, all killed in the end; 5 survived the first pass and 3 of those were real gate gaps that were then closed (the specific list lives in the build report, not in the repo - re-do the exercise for any new gate: break the guarded behaviour, watch the gate fail, restore).
Pre-existing failures NOT from this work: `ep2_smelting_facility_test` ("Bull PBR keeps fur/leather nonmetal"), `ep2_hideout_corrections_test` 4 checks (`ep2_bull_hero.gd PAINTED_GLB := true`, `smelting_facility.gd:1879` hides the guard rifle - both in HEAD before).

## TRAPS

1. CRLF files: `smelting_facility.gd` and `tests/ep2_smelting_facility_test.gd` use CRLF - edit binary-safe (a text-mode rewrite flips every line).
2. `get_nodes_in_group` is tree order: the profile source with the lowest tree position wins (see above).
3. A paused tree drops **release** events: a duck/ADS held through a pause sticks unless resynced (`_resync_held_verbs`). A `LineEdit` in a paused tree also drops key input.
4. Headless `get_texture().get_image()` errors: guard with `DisplayServer.get_name() != "headless"`.
5. A second finger has no emulated mouse: tests need a resting finger down first. A 1280x720 test window is tablet-class at 1 canvas unit per dp.
6. `ep2_fps_hud` raw `_input` touch handlers (holster hold, Search) must not sit under the look pad (layer 18/60 over the HUD layer): the Search button is hidden on touch.
7. `ep2_armory_shop._input` consumes `move_up/move_down/interact/ui_cancel`, so a live stick scrolls its rows: modals keep the profile suspended or `none`, never live.
8. Do not add a node to `touch_controls_wanted` without removing it when it ends (the layer would linger over menus).
9. Do not weaken `code_ok` / `ACCESS_SHA256`; `ep2_story_unlocked` is memory only and the menu route still asks for the code (founder policy).

## Known gaps (later rooms, verbatim from the build report; not acceptance scope)

- `ep2_armory_shop` is keyboard-driven with a key-naming hint line.
- Strings still shown on touch: `interlude_base.gd` ("OUT OF ROUNDS - PRESS R"), `woods_quad.gd` ("Search %s [E]"), `gold_town.gd` ("[E]", "click to fire"), `logans_lake.gd` ("[E]"), `ep2_armory_intro.gd`, the shop hint.
- Miner Shaft / `LEG_DEEPER` is unreachable on touch (cover / dash verbs have no touch route).
- A hybrid in portrait that flips to keyboard mode stays paused until rotated.
- Deferred by decision: FirePad / aim assist / `ep2_fire` / `press_at`; a runner reload button; a contextual hazard tutorial and ghost-finger demo; persisting the earned unlock; flipping `experimental_virtual_keyboard`.

## Untuned (paper numbers, need a real device)

Swipe: hop 22, jump 20, duck 24/12, slop 8, lockouts 120/150 ms, edge inset 24 dp. Look: gain 1.6 x 1.85, slop 4 dp, clamp 48 dp. Overlay: PLAY 44+10 dp, HOME 34+10 dp, spacing 150 dp, dim 0.58. Retry arm 0.8 s; film ring 0.9 s vs 0.6 s.
Also unmeasured: thumb reach, haptics, `get_image()` readback on the web renderer (scrim), iOS Safari, the OS back-swipe inset effect.

## Founder device checklist (hard refresh; BUILD tag at the bottom-left of a stage must have changed)

1. Runner: slide the left thumb sideways = hop one lane; slide up = jump; slide down and hold = duck. Right thumb: big star shoots the nearest archer, pickaxe swings at a boarder.
2. Tap on the open tunnel: one aimed shot and a small ring where you tapped (no crosshair sitting in the corner).
3. Pause icon: dim + play triangle + house. Play resumes; house goes to the menu.
4. Lose a run: dim last picture, round-arrow and house appear after a moment (not instantly). Round-arrow restarts.
5. Cliff film: a skip button with a ring fills while held and skips. Hideout on foot: left thumb walks (push up = forward), right thumb drags to look, fire/jump/scope/cylinder/hand/run buttons all work; scope is hold.
6. Turn the phone upright: a "turn me" picture and a house; turning back resumes exactly where you were. No key names anywhere.
