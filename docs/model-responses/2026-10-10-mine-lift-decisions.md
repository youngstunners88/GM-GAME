# Mine lift rework - decision models and metrics (2026-10-10)

Founder target: `artifacts/episode2-gold-mine/references/founder_2026-10-10/lift_walkway_target.jpg`. Skill: `ep2-set-piece-forge`.
Captures: `docs/episode2-quality/mine-lift-2026-10-10/` (board_target_before_now.jpg = target | old | new, top row entry, bottom row exit).

## Closeness to the references (tools/ep2_forge/ref_metrics.py, 0-1)
| framing | old lift | new lift |
|---|---|---|
| entry vs founder target | 0.20 (arrival) | 0.42 |
| arrival vs Muapi arrival ref | - | 0.51 |
| inside the rising cage vs rise ref | - | 0.57 |
| top exit vs top_exit ref | 0.45 | 0.73 |

## Decisions (text-only models, fed the numbers above)
| question | Jev (~typesafe/jev-latest) | microsoft/microsoft-decision-1 |
|---|---|---|
| layout: shorten the 13 m cavern / keep / narrow the FOV | shorten 0.99 | shorten 0.96 |
| is the new lift clearly better? | yes 0.83 | yes 0.97 |
| is it at the founder's target quality? | no 0.09 | no 0.01 |
| next | ship_and_iterate 1.00 | ship_and_iterate 0.99 |

## Art review (GPT-6 Astra, vision): 4/10 "partly" on both passes - raw answers in `2026-10-10-mine-lift-astra-pass1.md` / `-pass2.md`.
Pass-1 fixes done: cage dominant (cavern 8 m), Inferno out of the exit sightline + gate slid clear, conifers/rocks/trail beyond the
mouth, neutral fill, cage darkened, banners desaturated, barrels/crates/chain coil, emblem wall, braces. Pass-2 list = the skill's
"Next increment" section.
