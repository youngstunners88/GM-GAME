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
| Episode 2 town richness / avenues / facade doors and windows / background people and animals | `.claude/skills/ep2-living-town/SKILL.md`, `design/ep2/town/README.md`; then only the needed street/facade/life/proof component |
| Player / movement / combat | `src/player/player.gd`, `src/player/combat_handler.gd`, `docs/architecture/adr-combat-system.md`, `docs/architecture/adr-gameplay-feel.md` |
| Boss work | `src/boss/boss_base.gd` + the specific boss, `docs/architecture/adr-boss-ai-overhaul.md` |
| Level work | `src/level/level_base.gd` + the specific level |
| UI work | `src/ui/hud.gd` or `src/ui/main_menu.gd` + the target scene |
| Pause menu / Escape / pausing | `src/ui/pause_menu.gd`, `src/autoload/state_machine.gd`; gate `tests/pause_menu_test.tscn`; browser `scripts/pause-playtest.mjs` |
| Touch / mobile / tablet controls | `.claude/skills/gm-game-mobile-touch-experience/SKILL.md`, then `src/input/mobile/mobile_layout_manager.gd` + the one control/layout you change; gate `tests/mobile_touch_controls_test.tscn`; browser `scripts/touch-playtest.mjs` |
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
bash scripts/security-sentinel.sh          # 18 checks, 0 blockers

# icp-contract gate NEEDS a local price fixture or it reports 6 false failures:
node scripts/icp-price-fixture.mjs &        # serves :8788/prices
godot --headless res://tests/icp_contract_test.tscn  # 13/13 only with the above
```
