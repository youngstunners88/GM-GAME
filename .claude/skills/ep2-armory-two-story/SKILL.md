---
name: ep2-armory-two-story
description: Rebuild Rich & Utah's Armory as a two-storey Western gun shop off Main Street - proper entry, glazed and barred windows, stairs to an upper gallery, dense period weaponry, lamps, no horse inside, Rich and Utah working in it. TRIGGER on "armory", "Rich and Utah's shop", "double storey", "beef up the armory", "horse inside the armory", "windows / entry / details on the armory".
---

# Rich & Utah's Armory, two storeys (founder 2026-10-19)

Canon still holds: `PROMPT_EPISODE2_RICH_ARMORY_UTAH_RIVER.md` (off Main Street, Armory != Treasury, crypto-only trade,
the sniper and the river gear are bought here) and `design/ep2/armory/RICH_DEPARTMENT_SPEC.md`. This skill adds the
founder's 2026-10-19 brief: **double storey, crazy weaponry, Rich and Utah working in it, real windows, a proper
entry, detail and character, and no horse inside**.
Characters: `ep2-tripo-folk-to-game`. Their behaviour: `ep2-armory-npc-autonomy`. Motion: `ep2-runpod-motion-lab`.

## Where it is (measure, do not guess)
- `Ep2GoldTown.BUILDINGS`: `["Bldg_Armory", -20.0, 1468.0, 0]`, footprint `[8.0, 9.0, 0.7]` (`src/episode2/chamber/ep2_gold_town.gd`).
  The town is built once by `Ep2GoldTown.build()` and drawn by both the quad ride and the town room at the same
  coordinates; interiors only when `interiors == true`.
- **The horse inside**: `Ep2TownLife.HORSES` has `[-24.0, 1472.0, 2.4, "horse_graze"]`, which is inside the Armory's
  footprint. Move that horse to the lane outside the door (a hitch rail), and add a test that no horse, prop or
  walker spawns inside any building footprint grown by 0.5 m. **Do not replace the 3D horses** (founder 2026-10-18).

## The building (what "beefed up" means, checklist)
| Part | Required |
|---|---|
| Storeys | 2 floors, ground ~3.6 m, upper ~3.2 m, false front + parapet over the upper floor, total ~9 m |
| Entry | porch/boardwalk with 2-3 steps, posts and awning, a double door (one leaf ajar or swung open), a lit lamp each side, threshold the player walks through without snagging |
| Windows | ground: 2 display windows with iron bars + glass panes, guns visible behind them; upper: 3 sash windows with frames, sills and shutters; glass = a transparent material, never a black hole |
| Sign | hanging "RICH & UTAH - ARMS" board plus a painted false-front sign (`tools/ep2_forge/paint_town_signs.py`), muted against the protocol buildings |
| Ground floor | long counter (Rich's side), glass revolver cases, ammunition shelves by calibre, powder kegs, a cleaning bench, the lit long-rifle case (the day-88 sniper) |
| Stairs | a straight or L stair against a side wall with a rail, walkable by NPCs (and the player if the room allows), ~0.18 m risers |
| Upper gallery | mezzanine with a rail looking down on the shop: rifle wall racks, a Gatling gun on a tripod, crates of dynamite and cartridges, Utah's workbench and river gear (sealed crates, a skiff) |
| "Crazy weaponry" | at least 40 visible long guns and 20 sidearms as INSTANCES of a few low-poly rack models (one mesh, many transforms), plus 3-5 hero pieces (Gatling, a scoped sniper, a cannon or punt gun, a mounted buffalo rifle) |
| Light | oil lamps with warm OmniLight3D (a small budget: <= 4 lights, no shadows except one), light spilling out of the windows at the lane |
| Detail and character | weathered siding, trim, cornice brackets, bullet-hole decals, posters, a wanted board, a mounted longhorn skull: the "expression" of the building |

## Build path
1. **Blender kit piece**, headless, extending `tools/ep2_blender/build_town_kit.py` (keep `Bldg_Armory` for history,
   add `Bldg_Armory2` and new `Arm2_*` props). Follow the installed `blender-hardsurface-modeling` stack rules
   (Mirror, Booleans EXACT with cutters past the surface, Bevel 30 deg clamp, Weighted Normal), real metres, origin at
   the door threshold, -Y = out of the door.
2. **QA every piece**: `~/.claude/skills/blender-asset-qa/scripts/qa_check.py --profile game` (z-fighting is the classic
   failure on stacked boards and glass in frames; floating parts on hanging signs) and `review_shots.py`.
3. **Budget**: `blender-game-optimization/scripts/mesh_stats.py --budget web`. Shell + interior <= 25k tris, <= 4
   materials on a shared atlas/trim sheet, textures <= 1024 lossy. Weapons as instances, not copies.
4. **Export** with `blender-export-pipelines/scripts/export_asset.py --preset godot` (or the kit's own exporter, which
   must keep `Bldg_*` / `Arm2_*` node names). Use the `-colonly` suffix for walls, counter and stairs collision.
5. **Place** in `ep2_gold_town.gd` (BUILDINGS, footprint, interior dressing list, lamp list, NPC spots for Rich and
   Utah) and keep the side-lane approach off the Main Street sightline.

## Pack budget (hard gate, read before adding a single MB)
The web pack has a 190 MiB gate (`scripts/pack-gate-fresh.sh`, fresh clone). On 2026-10-19 the margin was ~0.47 MB.
The new building, two Tripo characters and the clips need ~3-4 MB. Get the founder's choice of where the room comes
from BEFORE building past a blockout (never trim visible/audible content without his yes, `ship-visual-proof`).
Retiring the old `rich_armory.glb` + `utah_armory.glb` frees ~0.46 MB.

## Gates and proof
- New test `tests/ep2_armory_two_story_test.gd`: the building has two floors (upper floor node above y 3.0), a door
  gap, >= 5 window panes with a transparent material, stairs reachable from the counter side, Rich and Utah present,
  no horse/prop/walker inside a building footprint, Treasury untouched, Level 3 untouched.
- Wire it into `.github/workflows/export-game.yml` like the other `EP2_*: ALL PASS` gates.
- Captures from the **Episode 2 camera** only (`ep2-design-verify`): the lane approach (entry, windows, sign), the
  door from inside, the counter with Rich, the gallery with Utah, light from the windows at the lane. Put them in
  `docs/episode2-quality/armory-two-story-<date>/` and compare against the founder's reference image.
- Ship through `scripts/ship-to-master.sh`, then CI + butler + itch, then the founder's hard refresh.
