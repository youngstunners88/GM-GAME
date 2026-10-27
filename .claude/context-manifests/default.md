# DEFAULT CONTEXT MANIFEST

Read this before starting work. Load the "always" set, then **only** the
on-demand entry matching the task. Do not read the whole repo — at 100+ source
files that burns the window before any work happens.

Every path below was verified to exist. If a path 404s, fix the manifest in the
same commit — a manifest that lies is worse than no manifest, because it sends
the next agent hunting for files that were renamed.

## Always load

| Path | Why |
|---|---|
| `STATUS.md` (first 40 lines only: `sed -n 1,40p STATUS.md`) | Current shipped state — the client-facing truth. Older entries: `docs/status-archive/` (1.3 MB - never read whole) |
| `src/autoload/game_manager.gd` | Global state, progression, save/load |
| `src/autoload/state_machine.gd` | MENU/PLAYING/PAUSED transitions + web state beacon |

## Load on demand

| Task | Load |
|---|---|
| Logan cabin / porch branding / prospecting detail / wanted bills | `.claude/skills/ep2-logan-cabin/SKILL.md`, `design/ep2/lake/cabin-20261027/BRIEF.md`; then the signage/prospecting/proof component |
| Logan's Lake / supplied Logan / Blender toolkit | `.claude/skills/ep2-logans-lake/SKILL.md`, `design/ep2/lake/LOGANS_LAKE_LOCK.md`, `design/ep2/lake/IMPLEMENTATION.md`; tooling: `gm-blender-godot` |
| Episode 2 town richness / avenues / facade doors and windows / background people and animals | `.claude/skills/ep2-living-town/SKILL.md`, `design/ep2/town/README.md`; then only the needed street/facade/life/proof component |
| Player / movement / combat | `src/player/player.gd`, `src/player/combat_handler.gd`, `docs/architecture/adr-combat-system.md`, `docs/architecture/adr-gameplay-feel.md` |
| Boss work | `src/boss/boss_base.gd` + the specific boss, `docs/architecture/adr-boss-ai-overhaul.md` |
| Level work | `src/level/level_base.gd` + the specific level |
| UI work | `src/ui/hud.gd` or `src/ui/main_menu.gd` + the target scene |
| Jev / TypeSafe 1.14 / image decisions / efficient routing | `.claude/skills/jev-1-14-routing/SKILL.md`, then `scripts/jev.mjs` / `scripts/jev-request.mjs` only |
| Pause menu / Escape / pausing | `src/ui/pause_menu.gd`, `src/autoload/state_machine.gd`; gate `tests/pause_menu_test.tscn`; browser `scripts/pause-playtest.mjs` |
| Touch / mobile / tablet controls | `.claude/skills/gm-game-mobile-touch-experience/SKILL.md`, then `src/input/mobile/mobile_layout_manager.gd` + the one control/layout you change; gate `tests/mobile_touch_controls_test.tscn`; browser `scripts/touch-playtest.mjs` |
| Touch profiles / new finger-movement control / a key name written on touch | `.claude/skills/gm-game-mobile-touch-experience/SKILL.md` ("Profiles", "The wordless rule"), `src/input/mobile/touch_ui.gd`, `src/input/mobile/mobile_layout_manager.gd`; gates `tests/touch_controls_profiles_test.tscn`, `tests/mobile_touch_controls_test.tscn` |
| Blaze Rush on a phone (tap, pause card, framing, fairness, return audio) | `.claude/skills/gm-game-blaze-rush-mobile/SKILL.md`, `docs/architecture/adr-blaze-rush-mobile.md`, then only `src/dashmode/blaze_rush.gd` (TABS, ~2500 lines: grep the `# --- TOUCH WIRING` block, do not read whole) / `blaze_pause.gd` / `blaze_framing.gd`; gates `tests/blaze_rush_touch_test.tscn`, `tests/blaze_rush_window_test.tscn`, `tests/blaze_input_buffer_test.tscn`, `tests/blaze_hud_mouse_filter_test.tscn`, `tests/blaze_framing_test.tscn`, `tests/level_return_audio_test.tscn`, `tests/scene_router_reveal_test.tscn` |
| Episode 2 runner / hideout on a phone | `.claude/skills/ep2-mobile-touch/SKILL.md`, then `src/episode2/session/ep2_session_root.gd` (grep `touch_profile`, `_route_free_roam`), `src/episode2/ep2_entry.gd` (grep `_set_ended`, `_open_pause`), `src/episode2/ep2_touch_overlay.gd`; gate `tests/ep2_touch_controls_test.tscn` (`-- only=<section>`) |
| Episode 1 -> Episode 2 hand-off / menu route / cover / loading card on a phone | `.claude/skills/gm-game-mobile-seamless-transitions/SKILL.md` + `.claude/skills/ep2-seamless-transition/SKILL.md`, then `src/autoload/transition_director.gd` (TABS) / `src/autoload/scene_router.gd` (4 SPACES); gates `tests/transition_director_test.tscn`, `tests/touch_scene_swap_cleanup_test.tscn`, `tests/ep2_theme_handoff_test.tscn`; probe `scripts/mobile-transition-probe.mjs` |
| Proving a touch flow (Playwright, CDP, warps, harness build, beacon, mutation checks) | `.claude/skills/gm-game-touch-flow-verification/SKILL.md`, `scripts/lib/pw.mjs`, `scripts/cdp-touch-probe.mjs`, `src/debug/harness_hooks.gd`; gates `tests/harness_hooks_inert_test.tscn`, `tests/debug_overlay_beacon_test.tscn`, `python3 scripts/check-harness-hooks.py` |
| Shooter (v1.2) | → `.claude/context-manifests/shooter.md` |
| Episode 2 armory / living bears / Bull stealth / corpse arrows / retry / quad pursuit | `.claude/skills/ep2-living-woods/SKILL.md`, `design/ep2/LIVING_WOODS_CONTRACT.md`; then only the component skill and source paths for the task |
| Bull/bear motion / retargeting / rifle, bow, magazine or quad contact | `.claude/skills/ep2-character-performance/SKILL.md`, `design/ep2/motion/CHARACTER_MOTION_CONTRACT.md`; then the needed guide/retarget/contact/QA component |
| ICP / canisters | → `.claude/context-manifests/icp.md` |
| Security / secrets / CI | `docs/security/GAME_SECURITY_CHECKLIST.md`, `scripts/security-sentinel.sh` |
| Deploy / export | `.github/workflows/export-game.yml`, `scripts/verify-game.mjs` |

## Non-negotiables (cheaper to state here than to rediscover)

- **Web export stays non-threaded.** `variant/thread_support=false`. Threaded
  builds need SharedArrayBuffer and silently fail to boot on itch.io. This was
  the root cause of the "game sometimes doesn't play" bug.
- **Never hardcode wallet/contract addresses or canister IDs.** They live in
  `config.json`.
- **`gdparse` is syntax-only.** It passes files that a real export rejects
  (notably mixed tabs/spaces, and `:=` inference from a Variant, which Godot
  4.3 treats as a hard error). A real export is the only ground truth.
- **Run the sentinel AFTER `git add`.** It scans `git ls-files`, so running it
  on unstaged new files silently scans nothing.
- **Touch traps (2026-10-23, each cost hours):** no key name or instruction word on a touch UI - gate it on `TouchUi.keys_shown()` and use an icon (the founder
  is angry about this one); `TouchMetrics.dp` is canvas units PER dp (inverting it clamps to 1.0 and silently does nothing); a `ColorRect` defaults to `mouse_filter = STOP`
  and eats taps; `press()` swallows a second finger's tap (use `TouchActions.tap`); layer-60 touch profiles swallow touches while live; `MobileLayoutManager.LAYOUT_SCENES` is
  platformer-only (profile scenes live in `PROFILE_SCENES`, `pause_menu_test` walks every `LAYOUT_SCENES` entry); group `touch_controls_wanted` is read in TREE order (a parent
  returning `none` beats its children); a test scene whose script fails to parse just hangs - always `timeout`, always a fresh `XDG_DATA_HOME=$(mktemp -d)` (the shared save is
  polluted by Blaze tests); wrap every `--import`/`--export*`/`ep2-local-export.sh` in `flock /tmp/gm-godot.lock`; a NEW `class_name` file needs `--import` before anything sees it;
  a silent coroutine death inside an awaited test still prints `ALL PASS` (pin check counts, grep `SCRIPT ERROR`); indentation is per file (TABS: `blaze_rush.gd`, `level_base.gd`,
  `src/input/mobile/*`, `transition_director.gd`, `ep2_entry.gd`; 4 SPACES: `scene_router.gd`, `audio_manager.gd`, `game_manager.gd`, `state_machine.gd`, `level_01_smoke_realm.gd`, `hud.gd`).
- **Harness hooks are compiled out by a custom feature tag, not a URL flag**: `?ep2gate=skip` and `?bosskill=N` work only in a `GM_HARNESS=1 bash scripts/ep2-local-export.sh` build;
  the CI preset keeps `custom_features=""` and `python3 scripts/check-harness-hooks.py` guards it. Never add a production kill/unlock URL (it mints the soulbound NFT and skips the code).
- Never write FIXED or "live" from a headless/Chromium run: no real phone has run the 2026-10-23 touch work; say "pushed / deploying" and use `docs/MOBILE_TEST_STEPS_2026-10-23.md`.
- Enemies are never weed-themed. Approved: Tax Collectors, flies, boulders,
  hostile vines, Compliance machines.

## Verification gates (before claiming anything works)

```bash
gdparse <changed>.gd                       # syntax
<godot> --headless --export-release Web …  # real compile, expect 0 SCRIPT ERROR
node scripts/verify-game.mjs <url>         # v1.0 campaign, 5 gates
node scripts/verify-shooter.mjs <url>      # v1.2 prototype, 6 gates
godot --headless res://tests/save_compat_test.tscn   # save format
godot --headless res://tests/pause_menu_test.tscn    # PAUSE_MENU: ALL PASS
# touch + mobile gates: ALWAYS XDG_DATA_HOME=$(mktemp -d) timeout 900 <godot> --headless --path . res://tests/NAME.tscn
godot --headless res://tests/touch_controls_profiles_test.tscn   # TOUCH_CONTROLS_PROFILES: ALL PASS
godot --headless res://tests/mobile_touch_controls_test.tscn     # MOBILE_TOUCH_CONTROLS: ALL PASS
godot --headless res://tests/blaze_rush_touch_test.tscn          # BLAZE_RUSH_TOUCH: ALL PASS  (+ the other blaze_*_test)
godot --headless res://tests/ep2_touch_controls_test.tscn        # EP2_TOUCH_CONTROLS: ALL PASS
godot --headless res://tests/transition_director_test.tscn       # TRANSITION_DIRECTOR: ALL PASS (timing-flaky at its 250 ms limit)
godot --headless res://tests/touch_scene_swap_cleanup_test.tscn  # TOUCH_SCENE_SWAP_CLEANUP: ALL PASS
godot --headless res://tests/harness_hooks_inert_test.tscn       # HARNESS_HOOKS_INERT: ALL PASS
python3 scripts/check-harness-hooks.py                           # no Godot; the shipped build must be inert to the harness hooks
node scripts/cdp-touch-probe.mjs                                 # CDP_TOUCH_PROBE: ALL PASS (re-prove after a Chromium/Playwright bump)
bash scripts/security-sentinel.sh          # 18 checks, 0 blockers

# icp-contract gate NEEDS a local price fixture or it reports 6 false failures:
node scripts/icp-price-fixture.mjs &        # serves :8788/prices
godot --headless res://tests/icp_contract_test.tscn  # 13/13 only with the above
```

Town voices / ElevenLabs / Rich / Utah / prisoner / sheriff / bell-only draw: `.agents/skills/ep2-town-voices/SKILL.md`; offline source `assets/town-audio.json`, receipts `assets/town-audio-generated.json`, runtime `src/episode2/audio/`, gates `tests/ep2_town_audio_test.tscn`, `tests/ep2_gold_town_test.tscn`, `tests/ep2_armory_guns_test.tscn`.
