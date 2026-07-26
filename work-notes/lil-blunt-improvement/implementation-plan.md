# Implementation Plan & Final Local Report — Corrections Brief

**Local-only per brief: NOT pushed, committed, merged, or deployed.** All work
is in the working tree; the operator ships it separately if they choose.

## 1. Summary of implemented changes

| # | Item | Status |
|---|---|---|
| A | Exclusive Blaze audio | ✅ FIXED — central token-guarded music override |
| B | Readable menu/wallet text | ✅ FIXED — bigger buttons, dark plates, font 20 (screenshot proof) |
| C | MetaMask → Rabby | ✅ FIXED — player-facing brand is Rabby (0 metamask refs; screenshot proof) |
| D | Facing / walk animation | ✅ VERIFIED already correct — single owner, no double-mirror; no defect |
| E | Ladder top-out | ✅ FIXED — explicit top-exit geometry + un-stick, data-driven |
| F | Mushroom / Big Mode | ✅ FIXED — keeps double jump + gains ground-pound (breaks blocks, stuns) |
| G | Multi-level progression | ✅ FIXED — L2/L3 were UNREACHABLE; boss→next-level registry added |
| H | Secret realm | ◐ RECONCILED — exists + reachable; full 6-room escalation = documented enhancement |
| I | Crypto-candle system | ◐ DEFERRED w/ reason — needs art-spec-before-batch per brief; no regression |
| J | 14 reference images | ⛔ BLOCKER — not supplied to this environment (manifest documents all 14) |

## 2. Root cause per issue
See each `test-evidence/*.md`. The two highest-impact real bugs:
- **A**: `activate_power_up` played the Blaze stinger as SFX ON TOP of level
  music (two buses, never muted the base).
- **G**: every boss loaded the MENU and the menu only loaded L1 — so two fully-
  built levels were dead-ends no player could reach.

## 3. Complete changed-file list
- `src/autoload/audio_manager.gd` — music-override API (push/release/drop, token).
- `src/autoload/game_manager.gd` — blaze override routing; LEVEL_SEQUENCE +
  next_level_scene + highest_unlocked_level (persisted); reset paths release override.
- `src/player/player.gd` — Big Mode double-jump restored + ground pound; ladder
  top-out; active-ladder tracking.
- `src/level/ladder.gd` — top_y/bottom_y/top_exit_offset/top_exit_position; passes self.
- `src/ui/victory_screen.gd` — Continue advances to next level.
- `src/boss/distributor.gd` — L2 boss → Level 3.
- `src/boss/claim_jumper.gd` — final boss → menu + campaign-complete + free-order fix.
- `src/ui/main_menu.gd` — readable button styling; CONNECT RABBY; Continue resumes highest level.
- `src/ui/crypto_onboarding.gd/.tscn` — MetaMask → Rabby.
- `work-notes/lil-blunt-improvement/**` — investigation, plan, evidence, manifest.

## 4. Systems intentionally left untouched (brief rule 4/7)
Web3Bridge network seam, StateMachine, DifficultyManager, the backend, CI
workflow, security gates, the 3 level scenes' geometry, the secret realm scene,
combat, HUD internals. No duplicate managers/state machines/audio systems/
animation owners created.

## 5. Tests & commands run
- `gdparse` on every changed script — clean.
- **Real Godot 4.3 headless web export** (downloaded engine + templates locally):
  succeeded — index.js/pck/wasm produced (the game genuinely compiles; the
  `--check-only` warning-as-error noise is stricter than the real export
  pipeline and is a pre-existing, CI-green condition, not introduced here).
- **Browser smoke test** on the local export (`scripts/verify-game.mjs`):
  canvas_attached / engine_booted / no_godot_errors / thread_support /
  level_1_runs all PASS; reached real `PLAYING` state
  (`statesSeen: [TRANSITIONING, PLAYING]`).
- `security-sentinel.sh` 18/18, `security-audit.ts` 28/0 — still green.

## 6. Export verification result
PASS — local Godot 4.3 web export boots to gameplay. Evidence:
`test-evidence/menu-after-corrections.png` (Rabby button + readable menu) and
`test-evidence/gameplay-boot-after-corrections.png` (Level 1 running, HUD).

## 7. Human-playtest steps for the non-automatable finals
The headless harness plays Level 1 to PLAYING but can't script per-mechanic
runs. A ~10-minute human pass confirms:
1. **Audio**: start L1, note the music. Grab a Weed Leaf → ONLY Blaze music
   plays (base paused, no overlap). Let it expire → base resumes once. Grab a
   2nd leaf mid-Blaze, then die/checkpoint → no old track revives.
2. **Ladder**: climb each ladder in each level, hold up at the top → stand on
   the platform (never stuck under it, never inside a collider).
3. **Big Mode**: eat a mushroom → double jump still works; press Down in air →
   ground pound breaks a breakable block + stuns a nearby enemy.
4. **Progression**: beat the L1 boss → the game loads Level 2 (not the menu);
   beat L2 → Level 3; beat L3 → menu shows "complete"; Continue resumes at the
   highest reached realm.
5. **Facing**: run left/right, jump, climb, attack, take damage, use each
   power-up → Lil Blunt faces travel direction with visible arm/leg motion.

## 8. Known limitations & exact blockers
- **J (images)**: cannot proceed — 14 reference images are not in this
  environment (see SOURCE-MANIFEST.md). Supply them to continue.
- **I (candle system)** and **H (full 6-room secret realm)**: intentionally
  scoped OUT of this pass (large art/level batches; brief says spec-before-batch
  and don't-duplicate). Documented as next deliverables, no regression.
- Runtime confirmation of A/E/F/G per-mechanic is human-playtest (step 7) —
  the automated gate proves compile + boot + L1 PLAYING, not every interaction.
- Per brief: nothing pushed/committed/deployed. Work stops at local
  implementation + evidence.
