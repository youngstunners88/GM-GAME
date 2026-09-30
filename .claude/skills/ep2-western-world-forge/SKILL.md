---
name: ep2-western-world-forge
description: Build Episode 2's EXTENSIVE world - the "western Modern Warfare" shooter-RPG that starts at the Smelting Facility - region by region, without losing canon or scope. World bible (design/world/WORLD_BIBLE.md), one region card per place (who built it, who lives here now, how the player changes it), faction rules, the Modern-Warfare mission grammar (breach, overwatch, holdout, chase, escape), pacing, web budgets, and the cinematic hand-offs between regions. TRIGGER when the founder talks about the world, regions, factions, lore, "the world needs to be very extensive", a new area/level/town/territory, the shooter/RPG mode, or when a new chamber or runner leg needs a place to live in.
---

# Why this exists
Founder 2026-09-30: "This is now the beginning of the shooter game RPG mode of the game with high level 3D
capabilities. Remember that this is a western version of Modern Warfare. So it is important that we have world
building skills too as the world needs to be very extensive." `world-building-workflow` dresses ONE scene; this
skill decides WHAT the world is, where each place sits in it, and what the player does there.

# Research that sets the rules (Firecrawl, 2026-09-30)
| Source | Rule |
|---|---|
| The Level Design Book, "Worldbuilding" | For every place answer three questions - **who made it, who lives here now, how can the player change it**. Build only what the NEXT level needs (premature worldbuilding goes stale when scope moves). Tell history through the environment. No thinly veiled real-world stereotypes. Leave mysteries. Do not "worldbuild into a hole" - the bible serves levels, not the other way round. |
| Modern Warfare campaigns (reviews + pacing analyses) | Praised for fast pacing and VARIETY: every mission changes the verb (breach-and-clear, stealth with a mentor, sniper overwatch, holdout, vehicle chase, escape), each built around one memorable set piece, with calm beats between them. A mentor NPC carries the story (Price -> Inferno Bull). |
| RDR2 world-design studies | Regions read through geography + ecology + one signature landmark each; density is uneven on purpose (dense towns, empty wilderness between them), and points of interest carry their own small stories. |

# Canon priority (read before inventing anything)
1. The founder's latest words (chat, docs he links) and `STATUS.md` entries dated after the file below.
2. `design/client_protocol_updates.md` - protocol facts. **Anything marked CONFIDENTIAL never reaches player text,
   `docs/` or `web/`.** The world bible lives in `design/` (internal) for that reason.
3. `artifacts/episode2-gold-mine/spec/STORY_OUTLINE.md`, `INFERNO_BULL_CHARACTER_PROFILE.md`, `chambers/*.md`.
4. `design/LORE.md`, `CLAUDE.md` Game Identity. Superseded facts get marked superseded, never silently used
   (e.g. the Gold Rush AUCTION was removed from Gold on 2026-09-30 - the Gold Vein replaces it).

# Hard rules (from CLAUDE.md - never break)
- Lil Blunt is small, cute, chill, friendly, cool - never aggressive; weed content is positive and chill.
- Enemies are NOT weed-themed. Approved: Tax Collectors, fly swarms, rolling boulders, hostile vines, Compliance
  machines - and Episode 2's bear gangs (archers, shovel bears, boarders).
- No real wallet/contract addresses anywhere; protocol mechanics are taught by places, never invented.

# The loop (per region)
1. **Region card** - `design/world/regions/<nn>_<id>.md` from the template below. Fill the three questions first.
2. **Place it on the map** - update the region table + route in `design/world/WORLD_BIBLE.md` (one line each).
3. **Missions** - 1-3, each a DIFFERENT verb from the grammar, each with ONE set piece; write the calm beat.
4. **Assets** - list the Meshy/ElevenLabs/MuAPI needs (founder models first: `ep2-meshy-studio` rule zero); budget.
5. **Hand-offs** - how the player arrives and leaves: a runner leg, a walk, or a film (`ep2-cinematic-cutscene`).
6. **Build through the gates** - `ep2-layered-production` (illustration -> wire spec -> imagery -> 3D -> motion),
   prove the look with `see-it-yourself` + `ep2-reference-match-loop`.

# Mission grammar ("western Modern Warfare")
| Verb | Western form | Needs |
|---|---|---|
| Breach & clear | kick in a saloon / assay office / vault door, slow-mo on entry | door breach anim, bullet-time (`ep2-cinematic-cutscene` two-clock pattern) |
| Mentor stealth | follow Inferno Bull through a bear camp at night, lantern discipline | companion path, detection cone, "hold" command |
| Overwatch | Winchester from a water tower / ridge while the Bull moves below | long-range aim, scope, spotting |
| Holdout | defend the smelter / a rail depot for N waves | cover, ammo crates, wave director |
| Chase | minecart (built), horseback, handcar, train roof | the runner tech generalises |
| Escape set piece | collapsing mine, burning bridge, cliff jump (built) | film + scripted physics |
Pacing: set piece -> calm (a camp, a lounge, a conversation) -> build-up -> set piece. Never two chases in a row.

# Region card template
```
# <Region name> (<id>)            status: outline | wire spec | built
Protocol pillar taught here: <one, from canon, or "story">      Canon: <file:section>
Who made it:        Who lives here now:        How the player changes it:
Geography / ecology:            Signature landmark:            Time of day / weather:
Factions present:               Mystery left open:
Missions (verb - set piece - calm beat):
Arrive by / leave by:           Film hand-offs:
Assets (founder first): models / textures / voice / music      Web budget: tris, textures, pack delta
Lighting grade: (warm key / teal shadow MW grade unless the place says otherwise)
```

# Web budgets (this is a browser game)
Web pack < 190 MiB total (`scripts/ep2-local-export.sh` prints it). Per region: <= ~400k visible tris, textures
1K (hero props 2K), CPU particles only (godot#95797), no audio bus-graph changes at runtime, <1000 instances per
scene without the culling fix (godot#96968). A region is a SEQUENCE of chambers/legs the session root streams,
never one giant scene.
