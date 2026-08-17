---
name: model-fable-boss-stage3
description: Explicit Fable-5 / Claude-fable lead skill for the critical residual — Stage 2/3 boss chase that founder has rejected >10 times, Stage 3 aesthetics/hammer/clutter, and Fort Knox Assay Scale UI text/background. Use when the founder demands all models attack these live fails. Fable owns final code, gates, STATUS, and deploy.
---

# Fable-5 / Lead Implementer — Boss Chase + Stage 3 + Assay UI

**Founder has rejected every prior "FIXED" claim on the 2nd and 3rd bosses more than ten times.** Treat previous browser-proof claims as insufficient. Live behaviour is the only proof that counts.

## Your mandatory load order

1. `STATUS.md` (current live branch and residuals)
2. `PROMPT_CRITICAL_BOSSES_STAGE3_ASSAY_ALL_MODELS.md` (the binding founder directive)
3. This skill + the sibling model skills (Kimi, Grok, Qwen, DeepSeek, B.AI)
4. Real boss scripts: `src/boss/distributor.gd`, `src/boss/claim_jumper.gd`, `src/boss/boss_base.gd`
5. Stage 3: `src/resources/level_03_data.tres`, `src/level/level_03_gold_rush.gd`, `src/level/level_base.gd`
6. Assay / Fort Knox UI: vault realm scripts + any Assay Scale Label / Control nodes
7. The founder screenshot of the Assay panel (text still fucked, background busy)

## Hard rules

- **No FIXED without hard-refreshable live proof.** Local green is not enough. Founder must be able to Ctrl/Cmd+Shift+R and see the change.
- **Boss chase is the #1 priority.** Distributor (Stage 2) and Claim Jumper (Stage 3) must visibly close distance on a moving player in the real arena. Headless gates that never damage the boss or never run in the real level box have already failed the founder.
- **Stage 3 clutter must be removed or given purpose.** Functionless blocks, random orange props, dual-purpose sprites that read as decoration — delete or relocate. Hammer / big_axe must read substantial and distinct from pickaxe (pickup + thrown projectile).
- **Assay Scale panel:** remove or mute the busy background behind the right-side instrument panel; fix overlapping / unreadable labels (title, STAKED, RETURN, values, [E] WEIGH GOLD). Text must be sharp and hierarchical.
- Do **not** mix VO work, Smoke Lounge video, or PR #36 stake CONFIRM into this branch unless the founder expands scope.

## Execution order (Fable owns)

1. Dispatch the other models **first** (Kimi geometry/chase, Grok aesthetics, Qwen vision on the Assay screenshot, DeepSeek compliance, B.AI parallel drafts). Log every response under `docs/model-responses/`.
2. Integrate only what survives gates and real-arena probes.
3. Real-level chase proof: drive Distributor and Claim Jumper in their actual arenas (or `?boss=2` / `?boss=3` warp if present). Record distance closed and whether the player can be killed by pursuit.
4. Stage 3 clutter list with approximate x positions of everything removed.
5. Assay panel: measure real Label rects after outline; no overlaps; hierarchy clear.
6. Full gate battery + Security Sentinel → STATUS → butler fresh data.
7. Honest STATUS: what still needs founder eyes vs what is live.

## Anti-patterns (do not)

- Claiming FIXED because a prior session already claimed FIXED.
- Synthetic arenas only.
- Adding more atmosphere objects instead of removing clutter.
- Touching VO, music, or lounge video in this session.
---
