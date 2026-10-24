---
name: gm-game-mobile-seamless-transitions
description: "The Episode 1 -> Episode 2 hand-off and the other scene cuts as a PHONE player feels them: boss-3 death -> prewarm -> film -> cover -> swap -> settle -> reveal -> first runner frame, the menu route into Episode 2, the Blaze portal in/out, runner -> film -> hideout, a failed swap, rotation mid-film, audio at every cut, touch input across every swap. TRIGGER on 'transition on mobile', 'hand-off', 'blue/black screen on phone', 'freeze before Episode 2', 'stutter at the film', 'Episode 2 loading card', 'game frozen under the cover', music blip at film end, TransitionDirector / SceneRouter / Stage3BossDefeatCutscene / claim_jumper.die() edits, [TD] log lines, mobile-transition-probe. Read BEFORE changing any heavy scene swap; complements ep2-seamless-transition (the mechanism) with the phone rules, the measurements and the open items."
---

# Seamless transitions on a phone (Episode 1 -> Episode 2 and friends)

Founder: "Make sure the transitions are smooth and that the transition from Episode 1 to Episode 2 is smooth and seamless."
Mechanism and history: `ep2-seamless-transition` (TransitionDirector, seamless cover mode), `ep2-no-blackouts`, `ep2-film-always-plays`,
`ep2-state-transition-audit`. This skill adds what the 2026-10-22/23 mobile pass changed, what was **measured**, and what is still **measure-first**.
Touch rules: `gm-game-mobile-touch-experience`. Episode 2 controls: `ep2-mobile-touch`. Blaze: `gm-game-blaze-rush-mobile`.
Proof: `gm-game-touch-flow-verification`. **All numbers below come from headless Godot or SwiftShader Chromium: a RELATIVE gate, not a phone.
Never write FIXED/"live" - say "pushed / deploying" and ask the founder to hard-refresh on a phone.**

## The traced path (Stage 3 boss kill -> first runner frame)

1. `ClaimJumper.die()` (and `bandit_boss.gd`, identical): `GameManager.mark_boss_defeated` (progression + NFT; the harness fast-kill skips ONLY this line) ->
   `TransitionDirector.prewarm(GameManager.EPISODE2_SCENE, true)` (**one allowed stall, in the death tween**: the scripts compile now) ->
   `AudioManager.fade_out_music(0.8)` (empties the playlist; no Music-bus mute any more) -> `StateMachine -> LEVEL_COMPLETE` -> 1.0 s death tween.
2. Models/textures/audio warm ONE resource at a time inside `BUDGET_MS` 5 per frame while the film plays (`WARMING`, held in `_hold`); scripts/scenes wait in `_late`.
   Draw-warm: every warmed GLB is drawn once, one per 0.3 s, in a hidden 64x64 SubViewport.
3. `Stage3BossDefeatCutscene` (`touch_profile() -> &"ep2_film"`: a SKIP ring 0.9 s, the film itself skips on a 1.0 s hold after one release; joins/leaves group `touch_controls_wanted`)
   plays ~15 s. Its rect follows `size_changed` (rotation mid-film). `make_cover()` -> `build_cover(frame)` rebuilds the rect from the CURRENT viewport at the moment it is made.
4. `TransitionDirector.go(path, "", "", cover)`: `COVERING` (the film's last frame, Lil Blunt in the cart, is the cover; no card) -> **`_set_frozen(true)`** (tree paused; the director and
   AudioManager are PROCESS_MODE_ALWAYS) -> `LOADING` (finish the queue; bar fades in after `ALIVE_AFTER_SECONDS` 1.2 s, driven by `warm_fraction()`) -> `SWAPPING`
   (`change_scene_to_packed`) -> settle (new scene's `_ready` + first draw; wait until 2 normal frames follow a >250 ms frame, max `MAX_SETTLE_SECONDS` 3) -> `REVEALING`
   (`_set_frozen(false)`, **StateMachine -> PLAYING**, cover dissolves over `DISSOLVE_SECONDS` 0.6) -> `IDLE` (`finished`).
5. `Ep2SessionRoot` joined `touch_controls_wanted` in `_ready`, so at PLAYING the manager already has the profile `ep2_runner` (no 0.2 s gap).
   The first `RunnerGraybox` leg `handoff_holding()`: it holds at distance 0 and starts NO music until REVEALING, then `play_playlist(..., fade 1.6 s)` (`HANDOFF_MUSIC_FADE_SECONDS`).
   Later legs and retries are created with the director idle and are never held. `RunnerGraybox.is_reveal_holding()`; `RunnerGraybox.step()` is NOT gated (tests drive `_physics_process`).

States: `IDLE -> WARMING -> READY -> COVERING -> LOADING -> SWAPPING -> REVEALING -> IDLE`. Logs: `[TD] <from>-><to> t=<ms>` at every change and `[TD] stall <ms> <path>`
for one blocking item/settle frame over `STALL_MS` 250 (counted in `stall_count`). Public: `is_busy()`, `handoff_holding()`, `is_screen_covered()`, `is_frozen()`, `warm_fraction()`,
`last_compile_ms`, `abort_count`, `home_scene_path` (empty = real menu; tests point it at a fixture), signal `aborted(path)`.

## What was fixed (each with the gate that pins it)

| # | fix | gate |
|---|---|---|
| F06 audio chain | boss `die()` -> `fade_out_music(0.8)`; the Stage 3 film no longer mutes the Music bus (it used to keep the boss theme playing silently and re-enter mid-song at film end); runner tracks added to the Ep2 preset `files`; first-leg runner music waits for REVEALING and fades in 1.6 s | `ep2_theme_handoff_test`, `cutscene_music_mute_test`, `stage3_defeat_cutscene_test` |
| F08/F10 menu route | `SceneRouter.load_scene(path)` diverts `path == GameManager.EPISODE2_SCENE` to `TransitionDirector.go(path)` **before** `_loading_path` is set (so the guard can never be left set); `main_menu.gd` (founder-locked) untouched; access gate kept. The card is **dp-sized and wordless on touch**: a drawn mine cart (`CardGlyph`) + ONE bar >= 8 dp (`TOUCH_BAR_DP` 10), ~half the short side; desktop keeps title/subtitle/440x8 bar. The card was dead code before (both boss callers pass a cover); it is live only through this divert, which is why F10 shipped with F08 | `transition_director_test`, `ep2_reachability_test` (menu-route check) |
| F09 cover alive | the cover's progress bar (hidden first 1 s, fades in at ~1.2 s, follows `warm_fraction()`); the old scene is frozen under the cover (paused, re-asserted after every StateMachine change and once per frame because `change_state` re-applies `paused = (state == PAUSED)`). `PROCESS_MODE_ALWAYS` nodes in the new scene still run | `transition_director_test` |
| F02 abort | a failed swap (`change_scene_to_packed` error / unbuildable scene) -> cover/card faded and freed, StateMachine recovered, house glyph lifted above the cover, route to `home_scene_path`/menu, **no retry-go loop** (`_abort()` clears the warm hold on purpose). `go()` with a missing destination frees the passed cover (`_fail_early`). Cheapest test: an empty `PackedScene` (`instantiate()` returns null) | `transition_director_test` |
| F11 orientation | Stage 3 film rect + `make_cover()` follow `size_changed`; the card layout follows a rotation while up | `transition_director_test` |
| F15 first-leg hold | see path step 5 | `transition_director_test`, `ep2_theme_handoff_test` |
| input across swaps | `TouchActions.held_count() == 0` and no InputMap action pressed at EVERY moment of: boss kill -> film -> go(cover) -> reveal; a failed swap -> menu; menu -> Episode 2. Four fingers down at the start; fingers landing DURING the hand-off press nothing | `touch_scene_swap_cleanup_test` |
| menu-route PLAYING | `Ep2Entry._enter_playing()` (TRANSITIONING -> PLAYING after the access gate, when the director is idle): without it the menu route never showed controls | `ep2_touch_controls_test` |

Fixes found in the interrupted first attempt (so you do not repeat them): the failure house was hidden behind the opaque cover; the compile started under a half-faded card (new `is_screen_covered()`: a COVER is opaque from the first covering frame,
the CARD only once faded in/LOADING); an abort race hid a card owned by a second hand-off (it now checks `_going`); a stale "cover freed" test assumption (`queue_free` lands one frame after IDLE).

## Blaze portal in/out choreography (the other phone cut)

In: `BlazePortal._on_body_entered` -> `MobileLayoutManager.request_fade_hide()` (only if controls are visible; one-shot, valid 1.5 s) -> `SceneRouter.load_scene(blaze, blaze_transition_for_level(N), blaze_wipe_seconds())` (0.30 s, the realm's own SMOKE/DIAMOND/GOLD wipe) ->
TRANSITIONING hides the layer (0.12 s fade, controls inert) -> `blaze_rush` joins the group, builds -> wipe-in -> `SceneRouter.revealed` -> PLAYING -> `blaze` profile (layer 60) + tap cue. Out: `_exit_to_level` -> checkpoint under `_level_index`, `side_return`, music fade 0.35 s, same wipe 0.30 s ->
the level's `_start_stage_audio` resumes the stage song (no intro voice) -> platformer controls. Details and tests: `gm-game-blaze-rush-mobile`. **Never** shorten a wipe globally: boss-3 / Ep2 / vault hand-offs keep 0.45 s.

## MEASURED (headless Godot 4.3 debug build, relative only)

- Warm-frame stall during the film: 210-262 ms across runs; the dominant single item is `inferno_bull_rigged.glb` (~254 ms) which sits ON the 250 ms test limit - **the limit is the flake** (`transition_director_test` has failed at 261 ms and, under CPU load, 855 ms). Cold runs: 561 ms and 5177 ms.
- `ep2_entry.gd` compile is ONE blocking call of 1.9-2.3 s (+ ~0.4 s for the scene) on this headless debug build. (An older desktop figure, "453 ms of compile", is from a different build - do not mix them.)
- `ep2_transition_prebuild_test` flaked once (555 ms vs its 450 ms hideout-prebuild limit) then passed twice: the limit is borderline.
- Desktop software-GL baseline from `ep2-seamless-transition`: go -> finished 1.9 s with covered frames hiding a ~600 ms spike; entering Episode 2 after everything is loaded still costs ~330 ms (`_ready`) + a 1.1-2.3 s first draw.
- Text-only Jev, 2026-10-03: never a black card (A 0.01), simple freeze-frame dissolve (B) or B + early compile (D) - UNCERTAIN, confidence 0.18. The shipped config is B + C (draw-warm) + the compile in the death tween.

## MEASURE-FIRST (no evidence yet: do not "fix" without a number)

- **F05 "slice the compile" is a NO-OP as audited.** GDScript reports no preload dependencies: `ResourceLoader.get_dependencies` returns 1 for `ep2_entry.tscn` (`ep2_entry.gd`), 0 for `ep2_entry.gd`, 0 for `ep2_session_root.gd`. The compile queue is `[ep2_entry.gd, ep2_entry.tscn]`, and the whole cost is the transitive preload closure
  (session root, six chamber scenes, runner, armory scripts, weapon/hideout GLB preloads) inside ONE `ResourceLoader.load`. One-per-frame slicing cannot split it. If a browser measurement shows a stall > 250 ms at the film cut or the `die()` frame, the real options are (1) a curated leaf-first closure list in `PRESETS`,
  (2) compile under the still-frame cover after the film (invisible and inaudible there), (3) draw-warm in an off-screen SubViewport like `Ep2Interlude`. Do not claim it fixed on the old premise. `bandit_boss.gd` has the identical call.
- **F07 mobile warm-list tiering**: the preset warms 43 GLBs (~28 MiB), ~11 MiB images, ~6 MiB wav (~115-155 MiB decoded RGBA8 estimate; the export has `vram_texture_compression for_mobile=false`, so GPUs without S3TC/BPTC decompress to RGBA8 and desktop Chromium UNDER-reports). "Cap `BUDGET_MS`" is a no-op (checked after each item; every frame loads at least one). Tier-B deferral needs F21.
- **F12 hideout cut**: the hideout prebuilds at film second 3 (`PREBUILD_AT`); 3D is OFF during the film because 3D starved the decoder (8 fps with 3D vs 53 without). Any warm during the film must be single `UPDATE_ONCE` slices, never a continuously rendering SubViewport. The session root already has `_on_prebuild_requested` / `_pb_vp` to reuse.
- **F21**: `ResourceLoader.load_threaded_request` stalls forever on the non-threaded web export (`scene_router.gd` documents it). Needs a budgeted loader before F07's Tier B.
- **OPEN (menu route)**: after the access code is typed on the menu route the first runner is built with the director idle - no cover, the first-draw stall is on screen, music starts at once; the `ep2_runner` layout is built at REVEALING (could be pre-built under the cover).
- Founder-policy items left alone: the earned unlock is memory-only (`GameManager.ep2_story_unlocked`, `EP2_STORY_BYPASSES_CODE`); the menu button still asks for the code; a phone cannot type in the gate while `html/experimental_virtual_keyboard=false`. Do not weaken `code_ok` / `ACCESS_SHA256`.

## Scripts and probes

- `scripts/mobile-transition-probe.mjs` (imports `scripts/lib/pw.mjs`): phone profile 844x390 @2, `Emulation.setCPUThrottlingRate` 1x and 4x, rAF-gap + longtask + luminance logging, `[TD]`/`[EP2]` lines, beacon `window.__gm`. Scenarios A (boss kill -> film -> first runner frame, a thumb on the stick the whole way), B (menu boot warp -> Episode 2), C (runner -> cliff film -> hideout).
  Needs `GM_HARNESS=1 bash scripts/ep2-local-export.sh` for A/B/C (the hooks are compiled out of the shipped build); against a normal build it reports exactly how far each scenario got. `node scripts/mobile-transition-probe.mjs --selftest` checks the pure analysis. Read the file header for the metric names.
- Re-baselined for the menu divert (`?ep2=1` now goes via the director): `scripts/capture-ep2.mjs`, `ep2-play.mjs`, `ep2-film-web-probe.mjs`, `ep2-blank-frame-probe.mjs`, `ep2-fps-probe.mjs`, `live-itch-probe.mjs` wait for `[TD] REVEALING->IDLE` and type the access code only after the reveal (a `LineEdit` in a paused tree drops key input). They were only `node --check`ed, **not run**.
- Tests: `transition_director_test` (~14 s), `touch_scene_swap_cleanup_test` (~8 s), `ep2_theme_handoff_test`, `cutscene_music_mute_test`, `stage3_defeat_cutscene_test`, `ep2_reachability_test`, `scene_router_reveal_test`, `ep2_transition_prebuild_test`. 33 mutations were run on this work and all killed. Engine `ERROR:` lines inside the abort sections are EXPECTED (they are the failures).
- Visual: `tools/ep2_shots/transition_shot.tscn` (blue stand-in level so a blue flash would show; `black_frames=0`, min luminance 0.17 in the 2026-10-03 run).

## AFTER numbers (the lead completes this from the probe - FILL FROM mobile-transition-probe)

| metric key in `result.json` (scenario A unless noted) | BEFORE (baseline commit 78d09db6) | AFTER | 1x / 4x |
|---|---|---|---|
| `longtask_die_ms` (long tasks in the 2.5 s after `die()`) | _fill_ | _fill from mobile-transition-probe_ | |
| `gap_die_ms` / `gap_film_ms` / `gap_handoff_ms` (longest rAF gap) | _fill_ | _fill_ | |
| `over120_film` (rAF gaps > 120 ms during the film; goal <= 2) | _fill_ | _fill_ | |
| `cover_hold_ms` (TRANSITIONING -> PLAYING) | _fill_ | _fill_ | |
| `first_runner_after_go_ms` | _fill_ | _fill_ | |
| `black_cut` (luminance < 0.08 samples between film end and reveal) | _fill_ | _fill_ | |
| `runner_over100_30s` (goal < 5) | _fill_ | _fill_ | |
| `held_after_swap` (goal 0) | _fill_ | _fill_ | |
| B: `load_to_runner_ms`; C: `film_ms`, `gap_film_to_hideout_ms` | _fill_ | _fill_ | |
| `mem_peak_mb`, `tex_peak_mb` | _fill_ | _fill_ | |

Record the exact command lines and the `--label before|after` JSON next to the numbers. SwiftShader + throttle is a relative gate: say so.

## TRAPS

1. A paused tree drops GUI key input and release events; the director freezes the old scene by pausing the tree (it and AudioManager are ALWAYS), and `StateMachine.change_state` re-applies `paused = (state == PAUSED)`, so the freeze is re-asserted after every change. Any new `change_state` during a hand-off needs the same thought.
2. A lambda that reassigns a captured variable changes its own copy (tests: use an array/dict cell). `await signal` in a test resumes at `process_frame` before `_process`/`queue_free` flush; `queue_free` lands one frame after a director state change.
3. The home route leaves the StateMachine in TRANSITIONING if the target sets no state; the abort path relies on the target (or `recover_from_transition`) to leave it.
4. Both boss callers pass a cover, so the card is only live through the menu divert; do not assume the card is exercised by the boss path.
5. `ErrorReporter` / engine `ERROR:` lines in abort tests are expected output, not a failure.
6. Indentation: `scene_router.gd`, `state_machine.gd`, `game_manager.gd`, `audio_manager.gd` = 4 SPACES; `transition_director.gd`, `ep2_entry.gd`, `claim_jumper.gd`, `stage3_boss_defeat_cutscene.gd`, `ep2_session_root.gd` = TABS. A mixed file passes gdparse and fails the export.
7. Do not add `?bossdie=1`-style params to production: `claim_jumper.die()` runs `mark_boss_defeated` -> `NftIssuer` (mints the soulbound NFT) and sets `ep2_story_unlocked` (skips the code). The only fast kill is the `gm_harness` build hook, which skips ONLY the credit line.
8. `RunnerGraybox._ready` runs on every leg and retry: a "defer while the director is busy" guard must apply to the hand-off only (it does: `handoff_holding()`), never delay later legs.
9. `AudioManager.fade_out_music` clears the playlist: anything relying on it refilling must be rechecked.
10. Never build or load anything heavy while the film moves (one stall is allowed, in the death tween); never show the card when a cover exists; never free the film before its last frame is copied into the cover.

## Founder device checklist (hard refresh; BUILD tag at the bottom-left of a stage must have changed)

1. Beat Stage 3's boss. The music fades out (no song coming back at the film end). Film plays; hold the skip ring to skip it.
2. The last picture of the film (Lil Blunt in the cart) stays up; after a moment a thin bar appears, then it dissolves into the live tunnel. No black, no blue, no words.
3. The cart does not move and no music starts until the picture has dissolved; music then fades in. Put a thumb down during the whole thing: after the dissolve nothing is stuck (the swipe pad answers a fresh touch).
4. Menu -> Episode 2 button: a calm dark card with a small cart and a bar (no words), then the same dissolve. Turn the phone while it loads: it re-centres.
5. Portal into Blaze and back: the wipe is quick, the song carries on at the level.
Tell me: how long did the picture sit before the tunnel, did the sound crackle, and did anything freeze.
