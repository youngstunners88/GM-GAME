# Bug Audit — Release-Candidate Pass (2026-07-12, build `ac6c0b4` / export `88ff359`)

Method: every claim below states HOW it was verified. Three tiers:
- **HARNESS** — exercised in a real headless-Chromium run of the shipped web
  export (`scripts/verify-game.mjs`, `scripts/stress-game.mjs`).
- **LOGIC** — verified by code-path reading + parse check (gdparse, 25 files)
  but not driven end-to-end this session.
- **FLAGGED** — cannot be honestly verified headless; needs a human playtest.

| Checklist item | Tier | Result / evidence |
|---|---|---|
| Game boots on web export, menu renders | HARNESS | PASS — engine boots, zero console errors |
| Player moves/jumps/double-jumps (Level 1) | HARNESS | PASS — verify harness clicks PLAY, runs L1 with live input; stress harness mashes all inputs 45s, no crash |
| Rapid pause/unpause stability | HARNESS | PASS — 40 rapid toggles, no error |
| Memory stable (no leaks) | HARNESS | PASS — heap 150→99→98→99 MB over soak (initial drop = post-load GC; flat after). New FX/labels self-free (one-shot timers / tween-finished frees) |
| No console errors in playtest | HARNESS | PASS with 1 benign known warning: `Invalid state transition: MENU → MENU` on boot (double menu-enter guard fires as designed; cosmetic, pre-existing) |
| Levels 2/3 movement parity | LOGIC | Same Player scene/scripts as L1 (harness covers L1 only) |
| Attack damages every enemy type | LOGIC | Axe/fire hit CharacterBody2D enemies via body_entered AND Area2D-hitbox enemies (vine) via area_entered→owner resolution — added after PR #4 review; boulder shatters via `smash()` |
| Collectibles increment counters | LOGIC | Single shared collect path per type into GameManager/GoldMineSystem signals; HUD subscribes to all |
| Power-ups activate/expire (blaze/big/diamond/purple/pickaxe/torch) | LOGIC | Central `GameManager.power_up_timer` countdown; HUD bar reads same source; diamond aura FX attaches/detaches on the same flag |
| Checkpoints save/restore | LOGIC | Save path unchanged this pass; **new:** loaded values now clamped (see SECURITY_AUDIT.md #6) |
| Scene transitions between all levels without crash | LOGIC | New SMOKE/DIAMOND wipes reuse the proven fade code path (same await/change_scene skeleton, web-sync branch preserved); shader is uniform-driven, no external textures |
| Boss 1/2/3 reachable, fightable, defeatable | FLAGGED | Boss AI unchanged this pass; zoom/confetti/diamond-wipe additions are fire-and-forget calls that cannot block the victory path — but full boss runs need a human playtest on itch |
| Mobile touch controls visible + functional on web | LOGIC→FLAGGED | Fixed this session (`DisplayServer.is_touchscreen_available()`); headless Chromium reports no touchscreen so the harness can't see the overlay — verify on a real phone via itch |
| Audio on all platforms | FLAGGED | Music/reverb/ducking code paths parse + degrade silently when files missing; loudness/mix needs ears |

## Bugs found & fixed during this audit

1. **Save tampering / load-order defect** (`game_manager.gd`): `user://save.json`
   values were deserialized unclamped (9999 health, level 42 accepted), and
   `max_health` loaded *after* `player_health`, so the health clamp ceiling was
   stale. Fix: load order corrected + all numeric fields clamped. Verified by
   code re-read; regression risk low (defaults unchanged).
2. *(Earlier today, PR #4 review, included in this build)*: web touch controls
   disabled on Web export; vines unhittable by combat; stale committed web
   export; CI checksum-fallback shell scope bug.

## Known non-bugs / accepted

- `MENU → MENU` boot warning — guard doing its job, logged once, no effect.
- Three `[SceneRouter]` console prints — intentional web-boot diagnostics.

## Human-playtest checklist (the FLAGGED rows, ~15 min on itch.io)

Run through: beat all 3 bosses, watch for boss-zoom in/out, diamond wipe on
victory, confetti, combo counter, damage numbers, parallax depth while
running, purple fan + fire breath on a vine, phone touch controls + ATK.
