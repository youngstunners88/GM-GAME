# Inferno Bull's Hideout - design (founder target 2026-10-01)

Target image: `design/ep2/inferno_bull_hideout_target.jpg`. Code: `src/episode2/chamber/hideout_dressing.gd`,
`src/episode2/chamber/smelting_facility.gd`. Skills: `ep2-hideout-set-dressing`, `ep2-character-performance`.

## Layout (world +X is screen-LEFT from the game camera)
| Element | Target | Where in the scene |
|---|---|---|
| Inferno Bull (cigar, whiskey, helmet) | left of centre | `BULL_POSITION` (1.6, 0, 6) |
| Lil Blunt | right of the Bull, 3/4 view | walks to the Bull, yaw 66 degrees while talking |
| Pin-up poster (1890s revue, clothed) | left of the Fort Knox door | back wall, x = +6.2 |
| Mounted bear heads, full taxidermy bears | left wall + far corners | +X wall, +X plinth, -X corner |
| 1800s gun wall (Winchester 1886 x3, Colt SA revolvers, shell belts) | right wall | -X wall, z 4..10 |
| Colt Gatling | right background | (-3.9, 0, 7.4), muzzle across the room |
| Whiskey table, decanter, tumblers, pickaxe | left foreground | (4.2, 0, 2.8) |
| Gold bars, ingot cart, gold pile | right foreground | (-2.7, 0, 2.4), (-4.8, 0, 3.6) |
| Cowhide rug | under the pair | (1.0, 0, 4.6) |
| Fort Knox door + longhorn skull | back centre | z = 16, skull z = 15.4 |
| Heat and flame | everywhere | 3 braziers, 3 iron cauldrons pouring, molten channel, embers off the Bull, flickering lights |

## Era rule
Everything is 1800s Western: lever-action rifles, single-action revolvers, a Gatling, oil lanterns, plank walls.
No modern weapons or props.

## Beats the hideout stages
WAKE (nursed with whiskey) -> DRINK (sip + puff) -> HANDOFF (Winchester 1886 passes through his hand) -> HELMET
(miner's helmet lands on Lil Blunt, joy hop) -> VERB_TEACH -> EXIT through the Fort Knox door.

## Still to do (needs founder OK / credits)
- Rig the Bull on Meshy (5 credits) for real arm/head acting (see `ep2-character-performance`).
- A painted poster from Meshy text-to-image instead of the PIL-drawn one.
- The poster, rug and Gatling are code-built stylised art; replace with Meshy models if the founder wants photoreal.
