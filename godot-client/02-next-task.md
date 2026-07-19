# godot-client — next task

**Single next action:** extend L1 depth mechanics to Levels 2 and 3
(`LEVEL_23_EXTEND.md` spec).

## Acceptance criteria
- [ ] Level 2 (Crystal Caverns): vertical-shaft ladders, crystal one-way
      platforms, ≥2 secret walls, 3 routes (Speedrunner/Casual/Explorer).
- [ ] Level 3 (Gold Rush): timed-gate route split, ≥2 secret walls, Fort
      Knox vault alcove (token-gated, Hall-of-Blaze pattern), 3 routes.
- [ ] Adaptive difficulty + snapshot moments confirmed active in both
      (global systems — verify, don't rebuild).
- [ ] All new/changed `.gd` pass `gdparse` + a `scripts/kimi-review.sh` pass.
- [ ] CI export green + strict browser verify (PLAYING) + merged to master.

**After that:** themed bitmap font (restores UI iconography), then L2/L3
boss token-phase parity (crystal/bandit equivalents of Diamond Surge).
