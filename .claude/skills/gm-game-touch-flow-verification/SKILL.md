---
name: gm-game-touch-flow-verification
description: "How to PROVE a touch flow (Blaze Rush, Episode 2 runner/hideout, the Episode 1 -> 2 hand-off, any new touch control) without a phone: the order and cost of a full local verification, the fresh-save/timeout/flock rules, the class-cache import trap, the local web export + :8899 server, Playwright through scripts/lib/pw.mjs with phone/tablet/portrait profiles, verified CDP multi-touch semantics, the URL warps (?blaze=N ?stage=N ?boss=N ?ep2=1 ?ep2probe ?debug=beacon), the gm_harness feature tag (?ep2gate=skip, ?bosskill=N) and how its inertness is proven, the window.__gm beacon, probes, mutation-checking discipline, the silent-coroutine-death and headless-density traps, the xvfb+llvmpipe screenshot recipe, and what REQUIRES a real device. TRIGGER on 'prove it works on mobile', 'test the touch flow', 'Playwright touch', 'CDP touch', 'harness', 'gm_harness', 'ep2gate', 'bosskill', 'window.__gm', 'mobile-transition-probe', 'cdp-touch-probe', 'mutation check', adding a new touch gate to CI, 'is it live on a phone'. Read BEFORE writing any claim that a touch flow works."
---

# Proving touch flows (what a script can and cannot tell you)

Companions: `gm-game-mobile-touch-experience` (the layer), `gm-game-blaze-rush-mobile`, `ep2-mobile-touch`, `gm-game-mobile-seamless-transitions`,
`always-ship-live` / `live-itch-terminal-proof` (shipping), `browser-verify-game`. **A green run here is "pushed / deploying" evidence, never "FIXED" or "live".
Only the founder's hard-refresh on a phone (and the master CI deploy proof) earns those words.**

## The order and cost of a full local verification (cheap first; stop at the first red)

| # | step | command | cost |
|---|---|---|---|
| 0 | harness inertness (no Godot) | `python3 scripts/check-harness-hooks.py` | < 1 s |
| 1 | class cache, only after a NEW `class_name` file | `flock /tmp/gm-godot.lock .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless --path . --import` (twice if images are new) | 30 s - minutes |
| 2 | compile gate | `XDG_DATA_HOME=$(mktemp -d) timeout 900 .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless --path . res://tests/script_compile_test.tscn 2>&1 \| tail -40` | ~10-60 s |
| 3 | the touch contract | `touch_controls_profiles_test` (5-8 s), `mobile_touch_controls_test` (5-8 s, 221 checks), `pause_menu_test`, `vault_touch_dialogue_test` | seconds each |
| 4 | the area gates | Blaze: `blaze_rush_touch_test` (~62 s), `blaze_rush_window_test` (~17 s), `blaze_input_buffer_test` (~9 s), `level_return_audio_test` (~14 s), `scene_router_reveal_test` (~7 s), `blaze_framing_test`, `blaze_hud_mouse_filter_test`. Ep2: `ep2_touch_controls_test` (~18 s), `ep2_session_root_test`, `ep2_theme_handoff_test`, `ep2_access_code_test`. Transitions: `transition_director_test` (~14 s), `touch_scene_swap_cleanup_test` (~8 s). Harness: `harness_hooks_inert_test`, `debug_overlay_beacon_test` | ~3-4 min total |
| 5 | the real export | `GM_HARNESS=1 bash scripts/ep2-local-export.sh` (wrap in `flock /tmp/gm-godot.lock`); serves `http://localhost:8899/game/index.html` from `web_verify/` (`scripts/serve-web.mjs`) | minutes (the script allows up to 1500 s + 1200 s of imports and 900 s of export) |
| 6 | browser | `node scripts/cdp-touch-probe.mjs`; `node scripts/touch-playtest.mjs http://localhost:8899/game/index.html web_verify/touch-playtest phone,tablet,desktop`; `node scripts/pause-playtest.mjs ...`; `node scripts/mobile-transition-probe.mjs --scenario A,B,C --throttle 1,4 --label after` | 1-15 min each |
| 7 | security sentinel | `bash scripts/security-sentinel.sh` **only AFTER `git add`** (it scans `git ls-files`; unstaged new files scan nothing) | the lead |
| 8 | founder's phone | the device checklists in the area skills / `docs/MOBILE_TEST_STEPS_2026-10-23.md` | him |

Rules that bite on this shared 4-CPU box:
- **Fresh user dir and a timeout on EVERY headless run**: `XDG_DATA_HOME=$(mktemp -d) timeout 900 <godot> --headless --path . res://tests/NAME.tscn 2>&1 | tail -40`.
  The shared `user://save.json` accumulates a checkpoint at the Blaze portal and completed-level flags; level tests then spawn into Blaze and HANG (537 s seen). The shared `user://touch_controls.cfg` can hold `button_scale=0.7`.
- **A test scene whose script fails to parse just sits there forever** (no script attached): the `timeout` is what turns it into a failure. `SCRIPT ERROR` / `Parse Error` in the output is a failure even when a line says `ALL PASS`.
- **flock around anything that imports or exports** (`--import`, `--editor`, `--export*`, `ep2-local-export.sh`): several agents share one project dir. Plain test runs may run concurrently.
- **Class-cache trap**: a NEW `class_name` file is invisible until the global class cache is rebuilt (symptom: `Identifier "X" not declared in the current scope` from a file that is fine). Run step 1. `ep2-local-export.sh` imports twice for the same reason.
- Do not leave background processes running (the :8899 server included, when you are done). Do not run the local export or Playwright against :8899 unless it is yours to run.
- Existing failures that are NOT touch regressions (read why, do not chase): `ep2_smelting_facility_test` ("Bull PBR keeps fur/leather nonmetal"), `ep2_hideout_corrections_test` (4 checks), and `transition_director_test` is timing-flaky under CPU load (261 ms vs its 250 ms limit; 855 ms under load).

## Writing a gate that can fail (mutation-checking discipline - mandatory)

Every new gate must be broken on purpose: change the thing it guards (remove the guard, flip the condition), run the gate, SEE it fail, restore. Write down the mutation. A test that cannot fail is worthless.
Work on a scratch copy (a symlinked project with a real copy of the directory you mutate) so a crash never leaves the tree broken. Survivors: classify each as a real gap (fix the test) or an equivalent mutant (a redundant guard; say so).
Track record: foundation 83 mutations / 82 killed (the survivor is a redundant guard in the swipe pad), blaze 32/32, ep2 42/42 after 3 real gaps were closed, transitions 33/33. `scripts/check-harness-hooks.py` documents its own mutation set in its header.
Additional rules learned the hard way:
1. **Silent coroutine death prints ALL PASS.** An error inside awaited test code kills that coroutine, the remaining sections never run, and the final tally can still read zero failures. Pin per-section check counts (assert `N` checks ran) and grep the log for `SCRIPT ERROR|Parse Error|\[FAIL\]` (the CI contract does).
2. **Precondition checks**: assert the thing you test was really in the state you think (the fingers were really down through the film; the controls were really shown). A pass on an empty situation proves nothing.
3. Verdict line: one `NAME: ALL PASS` (or `NAME: N FAILURE(S)`) and a non-zero exit on failure, like `tests/mobile_touch_controls_test.gd`.
4. A lambda that reassigns a captured variable changes its own copy; `x == [..] as Array[int]` parses as `(x == [..]) as Array[int]`; comparing a freed instance with `!= null` is false in 4.3.
5. Headless **density trap**: the headless display reports density 1 and a 64x64 default window. Set the window first (`get_window().size = Vector2i(w, h)`) and use **dp-equivalent windows**: 844x390 (a 1688x780 @2 phone: same canvas, same dp, same phone CLASS and layout key), 390x844 (portrait), 1024x768 (tablet). A 1280x720 test window is tablet-class at 1 canvas unit per dp.
6. `Input.parse_input_event` takes **window pixels**; controls live in canvas units: map through `get_viewport().get_final_transform()`. `InputEventScreenDrag.relative` must be in window pixels too (`basis_xform`). A second finger has no emulated mouse (put a resting finger down first); a tap through a STOP control delivers ONE down event to the consumer.
7. Pin `GameManager` state in memory for any level-loading test (never `save_session`).

## CI wiring contract (so a new gate cannot silently not run)

CI's headless block is in `.github/workflows/export-game.yml` ("Portal room gameplay and rendered visibility"); only the long-standing touch gates (`mobile_touch_controls_test`, `pause_menu_test`, `vault_touch_dialogue_test`) are guaranteed there. The exact lines for the new gates are prepared in `scripts/ci-new-gates.txt` (check it exists and read it; the lead pastes them - never edit the workflow from a docs/skill task). The line shape that `scripts/ci-gates-local.sh` rewrites with sed:
```
timeout 180 "$GODOT_BIN" --headless res://tests/NAME.tscn 2>&1 | tee name-tests.log
grep -q 'NAME: ALL PASS' name-tests.log
if grep -E 'SCRIPT ERROR|Parse Error|\[FAIL\]' name-tests.log; then exit 1; fi
```
The log name must match `[A-Za-z-]+\.log` (a digit - the old `armory2-tests.log` - makes the local runner silently skip the `GATE_MISSING` check) and end in `-tests.log` so the runner's `mv` collects it. Run the whole block locally with `bash scripts/ci-gates-local.sh` (fresh XDG dirs, class cache rebuilt). Add tests in batches after each passes at HEAD with a fresh user dir; a flaky gate blocks every deploy.

## Playwright and CDP (scripts/lib/pw.mjs)

`import { launch, newProfilePage, collectConsole, multiTouch, ... } from './lib/pw.mjs'` - a createRequire fallback (`PLAYWRIGHT_PKG`, `@playwright/test`, `playwright`, `/opt/node22/lib/node_modules/playwright/index.js`); the bare ESM `import 'playwright'` ignores NODE_PATH and dies with `ERR_MODULE_NOT_FOUND` here.
- Chromium: `/opt/pw-browsers/chromium` (Chromium 141 / build 1194 in this container; `CHROMIUM_BIN` overrides); flags = software GL (`--enable-unsafe-swiftshader --use-gl=angle --use-angle=swiftshader`), identical to `touch-playtest.mjs`.
- Profiles (`PROFILES`, CSS px == dp): `phone` 844x390 @2, `tablet` 1024x768 @1, `portrait` 390x844 @2, `tabletPortrait` 768x1024 @1, `desktop` 1280x720 (no touch). Phones use DPR 2 and tablets DPR 1 to keep SwiftShader fast; dp is what the layout sees either way.
- **A phone has no keyboard.** `newProfilePage()` wraps `page.keyboard`, `page.press`, `page.type` and the CDP session so any key event THROWS in a touch profile (a real key event flips `MobileLayoutManager` into keyboard mode and hides the layer, so the run would prove nothing; it also hides panels that cannot be dismissed by touch). A deliberate hybrid-laptop scenario uses `hybridKeyboard(page)`.
- **Verified CDP multi-touch semantics** (Chromium 1194; re-prove with `node scripts/cdp-touch-probe.mjs`, which prints `CDP_TOUCH_PROBE: ALL PASS`; run it after any Playwright/Chromium bump): `touchStart`/`touchMove` list EVERY active point; `touchEnd` releases exactly the point(s) LISTED in it (list only the finger you lift); `touchEnd` with `[]` ends ALL fingers; a `touchMove` that omits a finger releases NOTHING.
  An older note claimed the opposite and a script written to it never lifted a finger (false green). `multiTouch(cdp)` encodes the truth: `down/move/up/upAll/cancelAll/tap/dragTo/swipe`. Polled reads can miss a press+release inside one frame: dwell >= 3 measured frames (`suggestedDwellMs(page)`).
- Hooks installed before the game loads (`installHarnessHooks`): `window.__states/__stateT` (StateMachine beacon), `__gm/__gmLog` (overlay beacon), `__fr` (rAF gaps > 40 ms), `__logT` (`[TD] [EP2] [HARNESS] [MEM] [SceneRouter] [Touch] [Blaze]` console lines on the same clock), `__long` (longtasks), `__lum` (opt-in canvas luminance, black frame < 0.08). Gaps > 100 ms are visible hitches; > 250 ms is a stall (`TransitionDirector.STALL_MS`). Take frame-time runs WITHOUT video recording and without the words walk; they perturb the numbers. Compare before/after in the SAME conditions.

## URL warps (web builds only; the menu ones live in founder-locked `main_menu.gd` - use them as they are)

`?blaze=1|2|3` straight into that realm's Blaze Rush (sets `dash_return`); `?stage=N` start of a level; `?boss=N` the level warped to its boss arena (marks the level unlocked); `?ep2=1` Episode 2 (now routed through `TransitionDirector`; asks for the access code unless unlocked);
`?ep2probe=1` prints `[EP2] d=<m>` per distance; `?ep2leg=N` start at leg N; `?ep2bot=1` runner autopilot; `?ep2chamber=1` a short first runner stretch (reach the cliff film fast); `?spawn_x=N` move the player; `?debug=1` the F3 overlay + beacon, **`?debug=beacon` the beacon WITHOUT the on-screen label** (clean screenshots).
**Harness-only** (a `GM_HARNESS=1 scripts/ep2-local-export.sh` build AND web): `?ep2gate=skip` (treat the access gate as passed, exactly what beating boss 3 does in memory) and `?bosskill=N` with `?boss=3` (kill the Claim Jumper N seconds after the arena opens through his REAL `die()`, so prewarm -> film -> `go()` all run unchanged).

### Why the hooks cannot ship (and how that is proven)
- `src/debug/harness_hooks.gd` reads the URL only inside `gated_value()` after `web AND OS.has_feature("gm_harness")`; the custom tag is written ONLY by the opt-in `sed` in `scripts/ep2-local-export.sh` (`GM_HARNESS=1`). The CI preset heredoc (`export-game.yml`) and `scripts/export-web.sh` keep `custom_features=""`, so on itch.io `?ep2gate=skip` is ignored. Without `GM_HARNESS=1` the local export stays CI-identical (the pack gate and `ship-to-master.sh` call it).
- The fast kill skips ONLY the `GameManager.mark_boss_defeated("claim_jumper")` line (`skip_boss_credit()`), so no progression write and no soulbound NFT. A production `?bossdie=1` would mint the NFT and bypass the founder's code gate: never add one.
- `python3 scripts/check-harness-hooks.py` (H1-H6; CI, no Godot) fails if a harness param is read outside the gate, the gate stops requiring both web and the tag, `JavaScriptBridge.eval` appears elsewhere in the hooks file, the API is called from an unsanctioned file, either preset writer lacks `custom_features=""` or mentions `gm_harness`, or a NEW raw `DisplayServer.is_touchscreen_available` appears (the single touch predicate is `TouchUi` / `TouchMetrics`).
- `tests/harness_hooks_inert_test` (`HARNESS_HOOKS_INERT`) drives the gate with every web/tag combination (with a positive control) and checks the real call sites; the headless run can never carry the tag, so it proves the untagged behaviour.
- `OS.has_feature("<custom tag>")` is documented to be true in a tagged export but was not proven from a pck here: the beacon field `harness` is the evidence. `mobile-transition-probe` records `harness_tag` and tells you when the build lacks it ("this build does not carry the gm_harness tag"); the first run of a tagged export that shows `harness: true` is the proof.

## The overlay beacon (assert on data, not pixels)

`DebugOverlay` (`src/autoload/debug_overlay.gd`; everything behind `DebugOverlay.is_on()`, off by default) adds SCENE / TOUCH (`MobileLayoutManager.debug_line()`) / FRAME avg+worst / MEM lines and posts a scalar JSON object ~4 Hz to the page with the SAME fixed-template
`window.parent.postMessage(JSON.stringify(...), window.location.origin)` form as `StateMachine._announce_state_to_page` (sentinel INJ-003 safe; a no-op off web and in the cross-origin itch iframe, which never has `?debug`). Keys: `t, build, harness, state, paused, time_scale, scene, td, td_frozen, held, touch{shown,susp,profile,layout,held}, win, frames, avg_ms, worst_ms, worst_all_ms, mem_mb, mem_peak_mb, tex_mb, tex_peak_mb`.
Words are fetched ON DEMAND (`requestWords(page)` bumps `window.__gmWordsReq`; the tree is walked only when asked, so the beacon never perturbs frame times). Gate: `tests/debug_overlay_beacon_test`. Assert `touch.held == 0` after every scene swap, `touch.profile` per scene, `td` states, `scene` path.
The console also prints rare `[Touch] ...` lines (SHOWN / HIDDEN / SUSPENDED / RESUMED, layout builds, focus loss) and `[TD]` / `[Blaze] build N ms` / `[EP2]` lines: a "thumb stopped steering" report is diagnosed from them first.

## Pixels without a browser (xvfb + Mesa llvmpipe)

`xvfb-run -a -s '-screen 0 1280x800x24' .godot-cache/Godot_v4.3-stable_linux.x86_64 --rendering-driver opengl3 --path . res://scratch/X.tscn` with `get_viewport().get_texture().get_image().save_png(path)`; `await RenderingServer.frame_post_draw` before the grab; ~5 s per shot.
Put throwaway scenes under a gitignored folder or the scratchpad project and never commit them. Headless `get_image()` ERRORS (guard `DisplayServer.get_name() != "headless"`). Blaze recipe with phone-shaped windows: `gm-game-blaze-rush-mobile`. Screenshots show layout and legibility only - read them, but they do not prove feel.

## What REQUIRES a real device (say so in every report; never claim these)

Touch latency (60-110 ms estimate) and feel of every threshold (swipe hop 22 / jump 20 / duck 24 dp, look gain, jump buffer); thumb reach and button size; haptics (`Input.vibrate_handheld` is not observable; only the forwarded-call counter is tested; no-op on iOS Safari); iOS Safari and Android Chrome behaviour (Chromium only here); 90/120 Hz judder; real safe-area insets and the notch; the OS back-swipe edge strip; `NOTIFICATION_APPLICATION_FOCUS_OUT` delivery to a non-autoload node on web; the virtual keyboard for the access-code gate (`html/experimental_virtual_keyboard=false`); GPU texture compression / decoded memory (desktop Chromium has S3TC, iOS/Mali do not); audio crackle at the cuts; thermal throttling and tab memory kills; SwiftShader + `Emulation.setCPUThrottlingRate` conflate CPU and GPU cost, so they are a RELATIVE regression gate ("did this get worse than before"), never "60 fps on a phone".

## Definition of done for a touch change

1. Gates green with fresh XDG (list them with their verdict lines) + `script_compile_test` + a real scene load of every scene you changed; no `SCRIPT ERROR`/`Parse Error` anywhere in the output.
2. Every new gate mutation-checked (name the mutation).
3. `check-harness-hooks.py` clean; no wallet/contract address, no new `JavaScriptBridge.eval` with dynamic strings, no binary asset (the web pack is at its 190 MiB gate with ~2 MiB spare).
4. Written down: what you could not verify (no phone), what is untuned, what you deferred and why.
5. Ship per `always-ship-live`: say "pushed / deploying" until master's CI deploy and the BUILD tag match; then ask the founder to hard-refresh and run the checklist. Never "FIXED", never "live" before that.
