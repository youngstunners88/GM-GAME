---
name: ep2-living-town
description: Prepare and implement Episode 2 town richness: connected avenues, visible doors and windows, period townspeople, horses, dogs, chickens, instruments and purposeful background activity. Use when the GoldMine town feels empty or consists of one block.
argument-hint: "audit | plan | validate | handoff"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# Build a town with daily life

The founder requested skills/scripts preparation on 2026-10-15. This toolkit prepares a reviewable proposal; it does not claim the town has been rebuilt. Start with AGENTS.md, `smokerealm-resume`, current CLAUDE.md and `.claude/context-manifests/default.md`. Read `PROMPT_EPISODE2_SURFACE_TO_TOWN_DRAW_SPEC.md`, `ep2-surface-to-town` and `ep2-gold-rush-town`; the current cast is the founder's Sheriff and Minister Mike Dean, not cancelled JakeX. Preserve concurrent armory/world work.

Before writing, use the user's existing task authorization; approval is already supplied for this preparation. Ask only for missing necessary inputs, not repeated permission for authorized writes.

## Route by job

| Job | Skill |
|---|---|
| More streets, smaller blocks, service yards and clear travel | `.claude/skills/ep2-town-streets/SKILL.md` |
| Doors, windows, porches and shop identity | `.claude/skills/ep2-town-facades/SKILL.md` |
| People, horses, dogs, chickens, period instruments and audio | `.claude/skills/ep2-town-background-life/SKILL.md` |
| Proposal checks, camera proof, budgets and runtime handoff | `.claude/skills/ep2-town-proof/SKILL.md` |

Run the commands in `tools/ep2_town/README.md` to audit the existing town, generate a deterministic proposal, validate it and export its handoff. Work under `work/` until accepted; durable contracts belong in `design/ep2/town/`. The code has no provider calls. Missing models/clips stay unresolved in `asset-jobs.json`; use existing approved assets/local Blender before the established paid-provider pipeline if needed.

## Creative direction

Keep warm late-afternoon GoldMine western realism, weathered timber, dusty lanes, occupied porches, Fort Knox on the hill. Preserve useful open space as the main arrival/duel street, with active edges: saloon fiddler, shopkeeper sweeping, assay worker carrying ore, horses shifting at rails, dogs resting/sniffing and chickens pecking near feed. Side avenues connect into a walkable circuit; yard details explain the nearby trade. Buildings must show recognizable entry/window depth from first-person height. Later Auctions/Reserve/Treasury destinations remain scenery until their story is opened.

## Narrative boundaries

- Keep first-person equipped firearm, three-heart cap, title/access/export contracts and existing beat order.
- Bull leaves on the one quad and is absent during office/early bar; the existing runtime controls his return after the draw. Background routines never create a second Bull, Sheriff or Minister.
- No bears in town, no Diamonds signs/mechanics and no invented protocol numbers or additional quests/dialogue. People are human townsfolk; preserve the founder's locked Minister model.
- Protect office/saloon passages, arrival/ride-off corridor, witness and duel sightline. Animals cannot be new combat targets or accidental mandatory obstacles.
- Instruments and chatter yield to dialogue; quiet and hold background routines before SQUARE_UP/DRAW, restore only after the room authorizes it. No forced encounter on a background walk.

Only a runtime implementation task changes the shared builder/kit/actors. For that task use the existing art/motion/reference/ship skills. A successful proposal check proves input geometry, not a rendered scene, working navigation, animation or deployed game.

## Next step

PASS means a valid proposal only; FAIL means fix the reported input/geometry errors. Continue through `ep2-town-proof` and the existing runtime production skills when implementing the town.
