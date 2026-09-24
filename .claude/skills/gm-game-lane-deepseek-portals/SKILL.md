---
name: gm-game-lane-deepseek-portals
description: DeepSeek V4.1 Flash does ≥70% of portal implementation tokens — GDScript, scenes, wiring, vision pregrade. Model slug deepseek/deepseek-v4.1-flash.
---


# DeepSeek lane — workhorse


Slug: `deepseek/deepseek-v4.1-flash`
Call: `node scripts/or-call.mjs deepseek/deepseek-v4.1-flash prompts/portals/<brief>.md prompts/portals/<brief>.out.md`


## Strength
Fast multi-file GDScript + `.tscn` scaffolding. Cheap enough to draft, fail, retry. Native vision for capture notes.


## Owns
- `PortalLadder.gd/.tscn` (glow, no player-block, E → DESCENT, snap to `_floor_y_at`)
- Shared `StudyRoom.tscn` + three skins
- `WhitepaperJump.gd`, `VideoShrine.gd`, `Examiner.gd`, result UI hook
- Instancing into the three stage `.tscn` files (minimal diffs)
- Headless test that: instances exist, glow color per protocol, clearance ≥200px from forbidden entries, session legal edges still pass
- Vision pregrade of Playwright packs (describe, do not vote)


## Must receive in every brief
- `@include` of the target `.tscn` / `.gd`
- Negative example: `src/level/ladder.gd` is NOT this ladder
- Floor is runtime-built; do not bake a floating Y
- Locked URLs and token ids
- "Players must be able to SEE the ladder at gameplay zoom"


## Must not
- Change quiz facts
- Call Meshy / mint
- Write Jev votes
- Touch Vault / Knox / Blaze / Lounge
- Use `▼` as a font glyph (draw the caret)


## Output contract
Return full files, not patches, unless the brief says patch-only.
If thinking eats the budget, stop thinking and emit files. Claude already caps this in `or-call.mjs`.
