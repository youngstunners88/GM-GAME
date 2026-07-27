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
| `STATUS.md` | Current shipped state — the client-facing truth |
| `src/autoload/game_manager.gd` | Global state, progression, save/load |
| `src/autoload/state_machine.gd` | MENU/PLAYING/PAUSED transitions + web state beacon |

## Load on demand

| Task | Load |
|---|---|
| Player / movement / combat | `src/player/player.gd`, `src/player/combat_handler.gd`, `docs/architecture/adr-combat-system.md`, `docs/architecture/adr-gameplay-feel.md` |
| Boss work | `src/boss/boss_base.gd` + the specific boss, `docs/architecture/adr-boss-ai-overhaul.md` |
| Level work | `src/level/level_base.gd` + the specific level |
| UI work | `src/ui/hud.gd` or `src/ui/main_menu.gd` + the target scene |
| Shooter (v1.2) | → `.claude/context-manifests/shooter.md` |
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
bash scripts/security-sentinel.sh          # 18 checks, 0 blockers
```
