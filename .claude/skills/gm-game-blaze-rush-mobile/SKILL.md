---
name: gm-game-blaze-rush-mobile
description: "Owns Blaze Rush (the secret auto-runner behind the portal of Stages 1, 2 and 3) on phones and tablets: the tap-anywhere jump through the touch layer (profile `blaze`), the wordless pause card and exit, the armed start, the jump buffer and coyote time, framing for portrait/tablet/landscape, the fairness window gate, the return-to-level audio, and the tests that prove each. TRIGGER on Blaze Rush on a phone, tap to jump, 'taps do nothing', pause card, exit Blaze, TAP OUT (Q), candles unfair, cube too small in portrait, backdrop magnified, music restarts after Blaze, SceneRouter.revealed, blaze_rush.gd / blaze_pause.gd / blaze_tap_cue.gd / blaze_framing.gd edits. Read BEFORE touching Blaze input, HUD or camera; never add a second touch path."
---

# Blaze Rush on a phone (all three stages)

Built 2026-10-22/23 under founder rule "mobile games do not have the keys written on them; players use finger movements".
Decision record: `docs/architecture/adr-blaze-rush-mobile.md`. Touch layer rules: `gm-game-mobile-touch-experience`.
Proof recipe (how to prove it, what needs a phone): `gm-game-touch-flow-verification`. Lifecycle audit: `blaze-rush-lifecycle`.
**Everything below was verified headless (Godot 4.3) and on software-GL screenshots only. No real phone has run it.
Never write FIXED or "live" from these gates; say "pushed / deploying" and ask the founder to hard-refresh on a phone.**

## The one rule: ONE tap path

```
finger -> VirtualTapField (layout blaze_*, canvas layer 60) -> TouchActions.tap(&"jump") + buzz(8)
       -> InputEventAction "jump" -> blaze_rush._unhandled_input -> _on_tap -> _queue_jump (idempotent latch)
       -> _update_jump (buffer + coyote) in _physics_process
```
- `blaze_rush.gd` joins group `touch_controls_wanted` FIRST in `_ready` and answers `touch_profile() -> &"blaze"`,
  `touch_suspended()` (true while the pause card is up) and emits `touch_profile_changed`. The manager picks the layout
  `blaze_phone_landscape | blaze_tablet_landscape | blaze_phone_portrait` = `TapField` (VirtualTapField, first = lowest z)
  then the top-right `Pause` button (r 17 dp, offset (30,64) dp, hit pad 12, action `pause`). **No EXIT in the layout.**
- The `ScreenTouch` / left-mouse branches in `_unhandled_input` are a **guarded fallback only**, ignored while
  `_tap_field_live()` (blaze profile shown AND not suspended). They exist so a lazily detected touch device (the manager flips
  `is_touch_device` on the first real finger) or the instant before the layer is up never loses a first tap. All paths
  end in the same latch `_queue_jump()` (one latch, never a counter).
- One haptic per tap: the tap field buzzes on finger-down (8 ms); the takeoff buzz in `_update_jump` is silent while the
  field is live. Crash 30 ms, pickup 6 ms. Counter `_haptic_sent` is the test hook.
- Desktop is unchanged: Esc/Q/Backspace instant exit, Space/click jump, TAP OUT (Q) button. The mouse path is LEFT button
  only (wheel/right also arrive as pressed MouseButton).

## Files

| file | job |
|---|---|
| `src/dashmode/blaze_rush.gd` (TABS) | the run; touch wiring block `# --- TOUCH WIRING`; consts `TOUCH_PROFILE`, `REVEAL_TIMEOUT_S 1.0`, `PAUSE_ZONE_W_DP 62`, `HUD_PAUSE_GAP_DP 4`, `JUMP_BUFFER_TOUCH_S 0.10`, `JUMP_BUFFER_DESKTOP_S 0.06`, `COYOTE_S 0.06`, haptic ms |
| `src/dashmode/blaze_pause.gd` (`BlazePause`) | wordless pause card, canvas layer 40, PROCESS_MODE_ALWAYS |
| `src/dashmode/blaze_tap_cue.gd` (`BlazeTapCue`) | pulsing tap-hand cue for the armed start, layer 30, mouse IGNORE |
| `src/dashmode/blaze_framing.gd` (`BlazeFraming`) | pure framing maths (zoom, camera y, band depth, backdrop plan, sky stops) |
| `src/dashmode/blaze_rotate_cue.gd` (`BlazeRotateCue`) | one-time wordless "turn the phone" cue in portrait, layer 30 |
| `src/dashmode/blaze_portal.gd` | portal: `request_fade_hide()` + realm wipe at 0.30 s; touch hint font in dp (`touch_hint_font_px`) |
| `src/dashmode/blaze_rush_layouts.gd` | course data (candle/gap/FUD positions); 5450 / 6400 / 7350 u |
| `src/input/mobile/virtual_tap_field.gd` + `layouts/blaze_*.tscn` | the tap field and the three layouts |
| `src/autoload/scene_router.gd` (4 SPACES) | `revealed`, `is_revealed()`, `blaze_wipe_seconds()` |
| `src/autoload/audio_manager.gd` / `game_manager.gd` / `src/level/level_base.gd` | return audio (see below) |

## Profile, layer, suspension (LAYERING RULE)

Profile `blaze` is on layer 60 (`MobileLayoutManager.LAYER_OVER_FILMS`). Layer-60 profiles go **inert while suspended**
(state PAUSED/GAME_OVER or `touch_suspended()`), so the pause card (layer 40) receives the touch. While the profile is LIVE its
full-screen field swallows touches. Consequence: any overlay of Blaze's own that needs touches must be shown while
`touch_suspended()` is true (that is what `_card_open` does), or the scene must return `&"none"`.

## Armed start (touch only)

Desktop and every headless test that instantiates `blaze_rush.tscn` directly keep auto-running (`_armed` defaults true).
On touch (`_begin_play`): `_armed = false`, `_reveal_ready = false`; physics is skipped entirely while `_armed` is false (cube holds at
x = 0). `_on_revealed()` fires on `SceneRouter.revealed` **or** the `REVEAL_TIMEOUT_S` 1.0 s safety timer (the web
`change_scene_to_file` watchdog path never emits `revealed`) -> `StateMachine -> PLAYING` **at the reveal, not `_ready`**
(the manager only shows controls in PLAYING, they must not pop in under the dissolve) -> `BlazeTapCue` shows. The first
tap starts the run via `_start_run()` and **is not a jump** (`_arm_frame` drops a second event of the same tap). A tap before the
reveal is ignored. PLAY on the pause card re-holds the cube with the cue (touch only); that tap is not a jump either.

## Pause card (wordless)

`BlazePause`: dim 0.58 + big PLAY disc (`PLAY_RADIUS_DP` 40 = 80 dp, hit pad 12) + smaller EXIT doorway (`EXIT_RADIUS_DP` 26,
`EXIT_GAP_DP` 48 away from PLAY). Opens on: the layout Pause button, the `pause` action (gamepad Start too), and
`NOTIFICATION_APPLICATION_FOCUS_OUT` / `WM_WINDOW_FOCUS_OUT` **touch only** (a phone call must not drop the player back into a
moving cube; desktop carries on as before). `_open_pause_card()` -> `_pause_run()` (clears `_jump_buffer` + `_coyote`,
physics off) + `touch_profile_changed`. EXIT calls the **same** `_exit_to_level()` as Esc and the finish line. The card reacts to raw
finger events with a same-frame dedupe against the emulated click (touch trap 11: only the first finger becomes a mouse click).
Its one STOP Control is `BlazePauseField`, allowlisted by name + parent in `blaze_hud_mouse_filter_test`.

## Wordless exit and HUD

`TAP OUT (Q)` is hidden when `TouchUi.keys_shown()` is false (`_sync_touch_hud`, re-run on `controls_visibility_changed`,
`layout_changed`, `profile_changed`, `size_changed` because the build happens once before any finger). The face icon stays.
Founder-restored text stays: `BLAZE DIAMONDS n`, `ATTEMPT n`, the FUD box, the toast, the portal's score text (do not
"wordless-ify" these; the founder asked for them). On touch the HUD row sits inside the safe area and stops short of the
Pause button (`PAUSE_ZONE_W_DP` + `HUD_PAUSE_GAP_DP`, or the real button rect on tablets / big button scale).

## Framing (BlazeFraming) - mind the dp direction

`TouchMetrics.dp` is **canvas units per dp**. The cube is `PLAYER_SIZE / dp` dp tall, so
`zoom = clamp(MIN_PLAYER_DP * dp / PLAYER_SIZE, 1.0, MAX_ZOOM)` with `MIN_PLAYER_DP 14`, `PLAYER_SIZE 28`, `MAX_ZOOM 2`.
The audit wrote it inverted (`14 / (28 * dp)`), which evaluates to ~0.27 and clamps to 1.0 everywhere, so the portrait fix
would have silently done nothing. At 1280x720 (any density) `dp = 1`, zoom 1, camera y 360, band 220, byte-identical to before.
- Camera y puts the ground ~66 % down a tall view (`GROUND_SCREEN_FRAC`); the floor **band is extended visually only**
  (collision stays 220 u, asserted); `look_ahead = max(240, 490 - vis.x/2)` keeps the 450 u telegraph on screen.
- **Parallax fact**: a ParallaxBackground plate **IS scaled by Camera2D zoom** (probed: layer.scale 1.64, plate 1.25 -> 2.05;
  the audit claimed otherwise). Fix used: `ParallaxBackground.scroll_ignore_camera_zoom = true` so the plate's scale equals the
  `BlazeFraming.backdrop_plan` fill. Without it the live run draws 2.054 instead of 1.252.
- Portrait: `backdrop_plan` returns mode `horizon` (plate rows from 40 % down, width-fit ~1.25x, never the 4.8x blur) over a
  2-stop gradient (`BlazeFraming.SKY_STOPS`, **baked constants** because `Texture2D.get_image()` is a GPU readback on web;
  `blaze_framing_test` re-measures the shipped plates and fails if they drift - a regenerated plate must update the table).
- Backdrop, camera and band re-frame on `root.size_changed` (rotation mid-run, no reload). Thresholds asserted: cube >= 14 dp,
  candle body >= 9 dp, telegraph >= 6 dp at phone landscape / portrait / tablet.

## Input feel: buffer, coyote, respawn

Before: the tap was a latch cleared every tick (a tap 1 tick before landing was lost; every tap in the ~6 airborne ticks after
a respawn was lost). Now `_jump_buffer` (0.10 s touch / 0.06 desktop) + `_coyote` (0.06 s). A tap queued at tick T jumps iff
`J - T < window * 60` (J = first tick that starts on the floor): touch buffer reaches 5 ticks, desktop 3
(`blaze_input_buffer_test` pins 2/5/9 and 2/5). A jump zeroes both (one tap can never be two jumps). Respawn is at `GROUND_Y - 12`
(standing) with coyote granted; the camera x is set in `_reset_player` so the crash frame is not empty. `_pause_run` / `_resume_run`
clear both buffers (they only decay inside `_physics_process`, so a tap at the pause edge would fire on resume).
`is_on_floor()` is stale-true for the first tick after a teleport; the test accounts for it (Tick 7, not 2).

## Fairness gate (the window formula)

`tests/blaze_rush_window_test` builds a REAL-PHYSICS replica (static floor, CharacterBody2D cube, Area2D candles, FUD wall, pits; shapes
read off a live `blaze_rush.tscn`; positions from `BlazeRushLayouts`) and sweeps the takeoff x in 0.5 u steps at the flat
`RUN_SPEED 320`. **Single-jump window of a hazard group = longest contiguous run of clearing takeoff x / 320.** Gate: >= 120 ms for
every group of every level (touch latency is 60-110 ms + jitter; 120 ms is engineering judgement, not a human threshold).
Sweep rules (so a new layout row cannot fool the gate): the sweep ends before the first hazard of the NEXT group; gap lanes sweep `SWEEP_FWD_GAP` 40 u past the pit's near lip (past it the cube cannot jump, so the late edge stays unclipped and coyote-free); every lane's bodies are created up front and freed together; a "group" = a candle train (candles <= 100 u apart), one FUD wall or one pit; a "chain" = a pit followed by a group whose first hazard is <= 260 u past the far lip (`CHAIN_REACH`).
Measured: single candle 464 ms; triples were 89 ms (L1/L2, 60 u spacing) and **27 ms** (L3, 70 u, two physics ticks) -> respaced
to **50 u** exactly (data only, seven triples; gap widths unchanged): 152 ms. Widest gap 148 ms. True gap constant ~237.5 u
(the audit's `(227.5 - w)/v` and "190 u gap = 117 ms" were ~10 u wrong). `speed_start/speed_end` in the layouts are **unused
data**; speed is flat 320 (`blaze_rush_layout_test` was fixed to the real 320: analytic conservative reach 233 u vs engine 237.5).
**OPEN FOUNDER DECISION - three weak gap+candle chains, all on Level 2**: gap 3750 -> double (BEST re-jump 118 ms, JOINT 0 ms),
5650 -> triple (JOINT 61 ms), 4980 -> triple (JOINT 92 ms). A late first jump makes the second window impossible. Gate asserts
FIRST-jump >= 120 ms and BEST re-jump >= 100 ms (winnable); JOINT is printed and tagged `[WEAK]`. Fix would be moving the
post-gap candles ~+60 u or a longer landing runway - not done (only the seven triples were authorised). Candles stay RED
(founder: "bring back the red candles"); readability comes from a 3 u dark outline + 2 u cream rim (collision unchanged) and a 14 u
cream-capped telegraph (contrast vs plate 2.99/2.42/1.30 -> best edge >= 7.5).

## STOP-ColorRect trap (why taps were dead on most of the screen)

Godot 4.3 `ColorRect` defaults to `mouse_filter = STOP`. The floor band, candles and the full-screen void ColorRect on CanvasLayer -2 take
part in GUI hit-testing and swallow the press before `_unhandled_input` (measured pre-fix: only the ~84 u HUD strip worked; keyboard never
affected). `_let_taps_through(node)` walks the finished tree once and sets every non-`BaseButton` STOP Control to IGNORE; it runs **before**
`_build_touch_extras()` so the pause card's `BlazePauseField` stays the single intentional STOP. `blaze_hud_mouse_filter_test` fails on
any other STOP under the run (allowlist an overlay by name only if it must be one). Any Control you add later: IGNORE it or call
`_let_taps_through` on it. Side effect: desktop click-to-jump now works for the first time (LEFT button).

## Return audio and router (the exit)

`_exit_to_level` writes the checkpoint under `_level_index` (never a literal 1; keep - see `blaze-rush-lifecycle`), sets
`GameManager.side_return = {kind:"blaze", level:N}`, calls `_release_music(true)` -> `AudioManager.release_music_override_faded(token, 0.35)`
(Blaze fades out while the SAME paused stage player fades in from its saved position; rebuilds from `_saved_stream` if freed) and
`SceneRouter.load_scene(return_path, blaze_transition_for_level(N), SceneRouter.blaze_wipe_seconds())`. The level's
`_start_stage_audio(paths, voice, force_first)` (levels 1-3) reads **and clears** `side_return` always (a stale flag must never suppress
the next ordinary load); on a matching return it leaves a playing stage track alone (`AudioManager.is_playing_playlist(paths)`) and
**never replays the 4-10 s `stageN_intro` voice**. `_exit_tree` still does the old `discard_music_override` (safety net: a route that is
not the exit would otherwise overlap the resumed track with a fresh one = the founder's "faint second song"). The 2.5 s exit watchdog
(`change_scene_to_file`) remains - the player must never be stranded.
`SceneRouter.revealed` (no args) fires after wipe_in / fade_in completes (immediately for INSTANT/SLIDE), never for a superseded load
(`_load_gen`); `_play_in_transition` stays un-awaited by callers so `_abort_load` keeps its order. **The 0.30 s wipe applies ONLY where a
caller passes `blaze_wipe_seconds()`** (portal + Blaze exit, asserted by scanning `src/`); `DEFAULT_WIPE_SECONDS 0.45` stays for boss-3,
Episode 2 and vault doors. Portal: `MobileLayoutManager.request_fade_hide()` just before `load_scene` (only if controls are visible) so the
level's controls dissolve (0.12 s, inert) with the dive wipe instead of snapping.

## Tests (run with a FRESH XDG_DATA_HOME and `timeout`; see gm-game-touch-flow-verification)

| test (`tests/*.tscn`) | verdict line | proves |
|---|---|---|
| `blaze_rush_touch_test` (347 checks, ~62 s) | `BLAZE_RUSH_TOUCH` | profile/layout/layer, wordless, armed start, 1 tap = 1 jump, resting thumb, lazy touch detection, pause card, EXIT = Esc path, focus-out, HUD, lifecycle on all 3 stages at 844x390, 390x844, 1024x768 |
| `blaze_input_buffer_test` | `BLAZE_INPUT_BUFFER` | buffer/coyote tick maths, respawn, pause/resume clear, haptic counter 0 on desktop |
| `blaze_hud_mouse_filter_test` | `BLAZE_HUD_MOUSE_FILTER` | no STOP Control under the run except `BlazePauseField` |
| `blaze_framing_test` | `BLAZE_FRAMING` | zoom/cam/band per shape, plate scale, rotation mid-run, plate colour drift |
| `blaze_rush_window_test` (~17 s) | `BLAZE_RUSH_WINDOW` | the fairness windows above |
| `blaze_rush_layout_test` | `BLAZE_RUSH_LAYOUT` | course data, finish -> return flow at real speed 320 |
| `level_return_audio_test` | `LEVEL_RETURN_AUDIO` | stage track resumes, no second song, no intro voice replay; pins `GameManager` in memory (never `save_session`) |
| `scene_router_reveal_test` | `SCENE_ROUTER_REVEAL` | `revealed` timing, superseded loads quiet, 0.30 s only for Blaze callers |
| `blaze_lifecycle_e2e_test`, `blaze_claim_reset_test`, `blaze_diamond_bounce_repro_test`, `blaze_band_*`, `blaze_lounge_banner_test`, `blaze_hud_label_fit_test`, `blaze_rush_no_pixelation_test`, `blaze_transition_palette_test` | | older founder regressions; all must stay green |
| `touch_controls_profiles_test`, `mobile_touch_controls_test`, `pause_menu_test`, `vault_touch_dialogue_test` | | touch layer contract |

Mutations that were run and killed (do the same for any new gate): pause not clearing buffers; resume not clearing; EXIT bypassing
`_exit_to_level`; IGNORE removed from the dim; cue made STOP; dedupe removed; no armed start; no reveal gate; no 1.0 s timeout; start tap
jumps; double haptic; written exit visible on touch; HUD ignoring Pause zone; focus-out ignored; `touch_suspended` false; portal without fade.

## Traps (each cost time once)

1. Silent coroutine death inside awaited test code prints `ALL PASS` - pin per-section check counts and grep `SCRIPT ERROR`.
2. Closing the card hides the emulated click: test dedupe standalone. Manager `layout_changed` fires BEFORE the new layout is positioned: read the pause rect on shown/resize/visibility, not on that signal.
3. A resting finger swallows the next finger's tap with plain `press()`; the field uses `TouchActions.tap`. Never "simplify" to press.
4. Headless density is 1: dp-equivalent windows (844x390, 390x844, 1024x768) give the same phone CLASS and layout key as a real @2 phone.
5. The shared `user://save.json` accumulates a checkpoint AT the Blaze portal (id 991 at 1450,250) and completed flags, which send level tests into Blaze and HANG (537 s seen). Fresh `XDG_DATA_HOME` always; pin `GameManager` in any new level-loading test. The live-portal step of `blaze_rush_touch_test` only runs when `XDG_DATA_HOME` or CI is set (the portal calls `save_session`).
6. 4-space files: `scene_router.gd, audio_manager.gd, game_manager.gd, level_01_smoke_realm.gd`; TAB files: `blaze_*.gd, level_base.gd, level_02/03*.gd`. A mixed file passes gdparse and FAILS a real export.
7. `ScreenShake` on a freed camera never decays its duration (a stale 0.2 s/6 px jolted the level on return). The dead call in Blaze was removed; do not re-add a shake without registering a valid camera.
8. Do not add the cube to group `player` (coins, portals and hazards test `is_in_group("player")`).
9. `ResourceLoader.load_threaded_request` prewarm stalls forever on the non-threaded web export; use `TransitionDirector` presets if Blaze ever needs a warm list.
10. Whether Godot web delivers FOCUS_OUT to a non-autoload node is untested (tests call `notification()` directly).

## Capture without a browser

`xvfb-run -a -s "-screen 0 1700x2800x24" .godot-cache/Godot_v4.3-stable_linux.x86_64 --path . --rendering-driver opengl3 res://tests/zz_capture.tscn -- --out=DIR --win=780x1688 --density=2 --level=1`
with a throwaway scene (delete it afterwards): set the window size and `MobileLayoutManager.is_touch_device`, instantiate `blaze_rush.tscn`
with `run.framing_metrics_override = TouchMetrics.compute(view, Vector2(win), density, Vector4.ZERO, true)`, park `_player.position.x` ~140,
wait 30 frames, `await RenderingServer.frame_post_draw`, `get_viewport().get_texture().get_image().save_png(path)`.

## Founder device checklist (hard refresh first; the BUILD tag at the bottom-left of a stage must have changed)

Per stage (1 Smoke Realm needs 1500 pts at the portal, 2 needs 2500, 3 needs 4000 - or ask for a warp build):
1. Walk into the glowing ring. The level's buttons fade and the wipe in the stage's own colour (smoke / blue / gold) takes ~0.3 s.
2. Cube waits at the start with a pulsing hand. Tap ANYWHERE (sky, floor, corner): the run starts, that tap does NOT jump.
3. Tap anywhere: one hop per tap, one buzz per tap, even with another finger resting on the screen.
4. Clear the candles; fall in a gap: the cube restarts instantly with no empty frame and the diamonds come back.
5. Top-right pause icon: dim + big play triangle + small door. Play: the cube waits for a tap again. Pull down the notification shade: the card opens by itself.
6. Door icon: back at the level, same song carrying on (no restart, no spoken intro again), standing at the portal.
7. Turn the phone upright: one "turn me" picture once, then the course is still readable (cube not tiny). Tablet: no strip under the floor.
8. No letters or key names on any button. (The words BLAZE DIAMONDS / ATTEMPT / the toast remain by design.)

## Known gaps - NOT built, with the reason

- `level_taken` per-entity persistence: large cross-cutting change; a normal death reload respawns pickups the same way; founder-gated ticket.
- Changing the checkpoint write (`990 + N`): `blaze_lifecycle_e2e_test` and the lifecycle skill assert it; founder decision.
- Portal refund on early tap-out: contradicts the founder's one-Blaze-run-per-stage burn rule (`blaze_portal.gd` header).
- Hold-to-confirm exit, 0.30 s portal dwell + gauge, `auto_hop_on_hold`, `reduce_motion` (would need a new `JavaScriptBridge.eval`): polish / no founder request.
- `BlazeProfile.lite` and per-stage speeds (320/330/340): measure first. `[Blaze] build N ms (Ln)` is logged (91-160 ms on the headless dummy renderer, budget 250 ms at 4x CPU throttle in a browser - NOT yet measured there); trim only if that shows a problem. Speed stays flat 320 so the fairness gate stays one number.
- L3 magenta hazards / hiding the FUD tag / stripping BLAZE DIAMONDS: contradict founder-restored items.
- The three weak L2 chains (above): founder decision pending.
- `scene_router_reveal_test` exercises the NON-web threaded path; the web path (`change_scene_to_file` + `_play_in_transition`) shares the reveal code but is not reachable headless.
- Not run in a real web export: `scroll_ignore_camera_zoom`, the portrait gradient/StyleBoxFlat path, haptics, iOS Safari, 90/120 Hz judder, real safe-area insets.
