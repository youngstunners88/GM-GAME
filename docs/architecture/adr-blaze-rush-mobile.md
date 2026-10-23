# ADR: Blaze Rush on phones - one tap field through the touch layer, armed start, wordless pause card

Date: 2026-10-23 · Status: Accepted · Founder request: "Build the Blaze Rush section for mobile in all 3 stages" and, earlier
and angrily, "mobile games do not have the keys written on them; players use finger movements."
Skill (how to use/extend): `.claude/skills/gm-game-blaze-rush-mobile/SKILL.md`
Verification recipe: `.claude/skills/gm-game-touch-flow-verification/SKILL.md`

## ADR Dependencies
Builds on `adr-mobile-touch-controls.md` (InputMap is the only contract; Control nodes; one autoload) and its 2026-10-23 amendment
(profiles, visible finger-movement controls). Independent of the Episode 2 ADRs. Shares `SceneRouter` with the Episode 2 hand-off,
which is why the new `revealed` signal and the 0.30 s wipe are scoped (see Decision 7).

## Engine Compatibility
Godot 4.3.stable only, non-threaded web export (`variant/thread_support=false`, never change). Uses `Control._gui_input` with
`InputEventScreenTouch`, `ParallaxBackground.scroll_ignore_camera_zoom`, `Camera2D.zoom`, `CanvasLayer`, `Node.NOTIFICATION_APPLICATION_FOCUS_OUT`,
`Input.vibrate_handheld`. No post-cutoff API. Verified headless and on software-GL (Mesa llvmpipe) captures; **not** on a real phone or a
real GL-compat WebGL export - see the skill's "Known gaps".

## GDD Requirements Addressed
No design-doc requirement IDs exist for input (`tr-registry.yaml` untouched). Addresses the founder instruction above for Stages 1-3
(portals at 1500 / 2500 / 4000 points), the Blaze exit/finish contract (`blaze-rush-lifecycle`), and the pack gate (190 MiB, ~2 MiB
spare: every new glyph and cue is code-drawn, no binary asset was added).

## Context
Measured before the work (audit, engine probes):
1. Tap-to-jump was dead over most of the screen. Godot 4.3 `ColorRect` defaults to `mouse_filter = STOP`; the floor band, the candles and the
   full-screen void rect take part in GUI hit-testing and swallow the press before `_unhandled_input`. Only the ~84 u HUD strip worked.
2. The only exit was the written button `TAP OUT (Q)`; a phone has no Q and no Escape. A backgrounded tab left the cube running.
3. Framing was 16:9 only. Under `canvas_items` + `expand` a 390x844 portrait phone gets a 1280x2770 canvas: cube 8.5 dp, plate magnified 4.8x.
4. Candle triples left a 27 ms (Level 3) / 89 ms (Levels 1-2) takeoff window; phone touch latency is 60-110 ms.
5. Returning from Blaze restarted a shuffled level track and replayed the 4-10 s stage-intro voice.

## Decision
1. **ONE tap path through the touch layer.** Profile `blaze` = full-screen `VirtualTapField` (layer 60) + a top-right Pause button. A new finger
   is a fresh `jump` edge (`TouchActions.tap`), so a resting thumb never swallows the next tap. `blaze_rush.gd` reads the `jump` action; its
   ScreenTouch / left-click branches stay only as a guarded fallback while the layer is not live (lazily detected touch device).
2. **Every non-button STOP Control under the run becomes IGNORE** (`_let_taps_through`); the pause card's `BlazePauseField` is the single
   allowlisted STOP. A gate fails on any other.
3. **Wordless exit and pause.** `TAP OUT (Q)` is hidden when `TouchUi.keys_shown()` is false; the exit lives on a wordless pause card
   (`BlazePause`, layer 40: dim, big play triangle, small door), opened by the Pause icon, the `pause` action or app focus loss (touch only).
   EXIT is the same `_exit_to_level()` as Esc and the finish line. Text the founder asked for (BLAZE DIAMONDS, ATTEMPT, FUD box, toast) stays.
4. **Armed start on touch only.** The cube holds at x = 0 until `SceneRouter.revealed` (1.0 s safety timeout) and the first tap, which is not a
   jump, with a drawn tap-hand cue. Desktop and headless tests keep auto-running.
5. **Input feel.** Jump buffer 0.10 s touch / 0.06 s desktop, coyote 0.06 s, respawn standing on the floor, buffers cleared on pause/resume.
6. **Framing.** `BlazeFraming`: `zoom = clamp(14 dp * m.dp / 28, 1, 2)` (`m.dp` = canvas units per dp), ground at ~66 % of a tall view, floor band
   extended visually only (collision unchanged), portrait horizon band + baked sky gradient, `scroll_ignore_camera_zoom` on the backdrop, re-framed on
   `size_changed`. At 1280x720 every number is byte-identical to before.
7. **Router and audio, scoped.** `SceneRouter.revealed` and the 0.30 s wipe exist, but only callers that pass `blaze_wipe_seconds()` (portal, Blaze exit)
   shorten the wipe; boss-3 / Episode 2 / vault hand-offs keep 0.45 s and `_play_in_transition` is still not awaited (so `_abort_load` order is unchanged).
   Return audio: `AudioManager.release_music_override_faded` resumes the paused stage track; `GameManager.side_return` tells the level
   (`LevelBase._start_stage_audio`) not to restart music or replay the intro voice.
8. **Fairness gate.** `tests/blaze_rush_window_test` (real physics replica, 0.5 u sweeps): every hazard group's single-jump window >= 120 ms at the flat
   320 u/s. The seven candle triples were respaced to 50 u (data only; gap widths unchanged). Candles stay red (founder).

## Consequences
+ A tap anywhere jumps exactly once on a phone, tablet, landscape and portrait; the run can be left, paused and resumed with fingers only.
+ Desktop (keyboard, mouse) behaviour is byte-identical except two intended changes: click-to-jump now works anywhere (LEFT button), and the
  new 0.06 s desktop buffer / coyote.
+ Return from Blaze is audibly continuous; the 0.30 s dive is shorter than the 0.45 s default only for Blaze.
- Three Level-2 gap+candle chains remain weak (BEST re-jump 118 ms, JOINT window 0 / 61 / 92 ms): **open founder decision**, printed as `[WEAK]` by the gate.
- The layer-60 tap field swallows touches while live: any new Blaze overlay must be shown while `touch_suspended()` is true or the scene must return `none`.
- Everything is proven headless / software-GL only. Haptics, latency, 90/120 Hz, iOS Safari, real safe-area insets and focus-out delivery on the web build
  need the founder's phone.

## Rejected / deferred (with reason)
- `level_taken` entity persistence, changing the `990 + N` checkpoint write, portal refund on early tap-out: founder rules / lifecycle tests assert the current behaviour.
- Hold-to-confirm exit, portal dwell + gauge, `auto_hop_on_hold`, `reduce_motion` via `JavaScriptBridge.eval`: polish with no founder request (and a new eval for the sentinel).
- `BlazeProfile.lite`, per-stage speeds: measure first (`[Blaze] build N ms` is logged; 4x-throttle browser number still to take).
- `ResourceLoader.load_threaded_request` prewarm: stalls on non-threaded web; `TransitionDirector` presets are the right tool if ever needed.
- Recolouring candles magenta, hiding the FUD tag, stripping BLAZE DIAMONDS: contradict founder-restored items.
