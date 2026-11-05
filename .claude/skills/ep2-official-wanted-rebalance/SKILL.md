---
name: ep2-official-wanted-rebalance
description: Import the founder's OFFICIAL "Jackhammer Wanted" art as the one Jack Hammer poster texture, point every Jack Hammer bill in Episode 2 at it (town walls, notice board, jail, hideout, Logan's cabin, the Armory front's blank papers), and slide-reduce the RH (Rich) bills so Jack Hammer is the majority and largest wanted face. TRIGGER on "official Jackhammer poster", "replace the Jack Hammer posters", "fewer RH posters", "Rich looks like the villain", "blank posters on the Armory", or any edit to poster_jack_hammer.* / Ep2TownPosters WALL / BOARD_BILLS.
---

# Official Jackhammer Wanted + RH slide reduction

Parent: `ep2-jackhammer-wall-boss`. Pipeline background: `ep2-wanted-posters`.

## 1. Import the official art (one canonical file)
Source: Drive `1GCG24Wf3uzR6GX_xVstsOFWnt596UEAM` ("Jackhammer Wanted"), 2048x2048 JPEG, 3 471 099 bytes,
sha256 prefix `2f8056dc2537b898`. It is a square aged-paper bill with **torn edges on white** (same format as the RH and
Crypto Queen bills). It downloads without the Drive tool (verified 2026-11-05; do not pull 3.4 MB of base64 into context):
```bash
mkdir -p "$SCRATCH/jh" && curl -sSL -o "$SCRATCH/jh/jackhammer_wanted.jpg" "https://drive.usercontent.google.com/download?id=1GCG24Wf3uzR6GX_xVstsOFWnt596UEAM&export=download&confirm=t"
sha256sum "$SCRATCH/jh/jackhammer_wanted.jpg"   # must start 2f8056dc2537b898, else stop and ask the founder for the file
```
Key the white margin to alpha exactly like the founder's other bills (ep2-wanted-posters step 3), 1024 px so the name and
"DEAD OR ALIVE" read at walk-up distance and the billboard is not mush:
```bash
magick "$SCRATCH/jh/jackhammer_wanted.jpg" -alpha set -bordercolor white -border 2 -fuzz 9% -fill none -draw "color 0,0 floodfill" -shave 2x2 -trim +repage -resize 1024x1024 src/episode2/extras/town/posters/poster_jack_hammer.png
git rm src/episode2/extras/town/posters/poster_jack_hammer.jpg src/episode2/extras/town/posters/poster_jack_hammer.jpg.import
```
Keep the original JPEG outside the export: `artifacts/episode2-gold-mine/references/founder_2026-11-05_jackhammer_wanted.jpg`.
**Trap:** `Ep2TownPosters.build` tries `.jpg` before `.png` for each id - leaving the old JPEG in place silently keeps the
painted engraving. Delete it; do not keep two Jack Hammer files.

Every hard-coded path to the old JPEG must move to the PNG in the same commit (`git grep -n poster_jack_hammer`):
`src/episode2/art/ep2_logan_cabin.gd` (`JACK`, and its `_picture("WantedJackHammer", ..., Vector2(.65, .894))` size -> square,
e.g. `Vector2(.72, .72)` like RH, with alpha cut on), `src/episode2/chamber/hideout_dressing.gd` `_wanted_poster`,
`src/episode2/extras/lake/cabin/sign_manifest.json` + its generator `tools/ep2_cabin/paint_signs.py`,
`tools/ep2_cabin/check_pack.gd`, `design/ep2/lake/cabin-20261027/README.md`, and the line in
`.claude/skills/ep2-logan-cabin-signage/SKILL.md` that says Jack Hammer keeps the engraved game portrait (now superseded).
`paint_wanted_posters.py` keeps its `jack_hammer` SPEC only as history - never re-run it over the official file.

## 2. Census before you move anything (2026-11-05, measured from the code)
| Where | RH | Jack Hammer (painted 640x880, now replaced) | Blank |
|---|---|---|---|
| Street `WALL` (`ep2_town_posters.gd`) | Saloon 0.62 m (largest bill on the street), Bldg_A 0.52 | Saloon 0.44, Bldg_B 0.44, Bldg_C 0.44, Jail 0.40 | - |
| Notice board `BOARD_BILLS` | 0.56 (right) | 0.40 (centre, smallest of the top row) | - |
| Jail wanted board `JAIL_BOARD` | - | 0.26 | - |
| Logan's cabin (`ep2_logan_cabin.gd`) | 0.72 | 0.65 | - |
| Hideout (`hideout_dressing.gd`) | - | 1 | - |
| Armory front (`tools/ep2_blender/build_armory2.py`, baked "Paper" boxes 0.42x0.58 at local (-1.75,1.6) (1.8,1.45) (-4.6,1.5), z=0.005) | - | - | **3 placeholders** |
The founder's complaint is prominence, not just count: RH holds the two biggest street spots. Re-run the census (grep +
the gate) before editing - another session may have moved things.

## 3. Rebalance target (a proposal that satisfies the brief - adjust only with a reason)
- Saloon 0.62 RH spot -> `jack_hammer` at the same size (the street's biggest bill becomes his).
- Notice board: swap the centre and right bills - `jack_hammer` takes the 0.56 slot, RH drops to a 0.40 slot.
- Keep **Bldg_A RH** (street) and the **cabin RH** (locked by `ep2-logan-cabin-signage`) -> RH 4 -> 3 instances, all smaller
  than the largest Jack Hammer.
- Armory front: hang `jack_hammer` over all three blank papers (Ep2TownPosters `WALL` rows with `"Bldg_Armory"`, local
  centres from the table, width 0.42, z 0.02 so the bill sits proud of the baked paper - no z-fighting). Optionally one of the
  three as RH ("Rich's own shop") - then RH stays at 4 but Jack Hammer still wins count and area; decide and write it down.
- Leave crypto_queen / masked_riders / horse_thieves / accomplice untouched (supporting faces, brief section 4).
Result to prove: Jack Hammer instances > RH instances, Jack Hammer total bill area >= 2x RH area, RH >= 1, the largest
wanted bill in town is Jack Hammer, zero blank papers left on the Armory front.

Square art changes heights: `WALL` widths are widths; the aspect comes from the image. A 0.44 m square bill is 0.44 tall
(the painted one was 0.61) - recheck that nothing now overlaps a window/door frame (`Kit fronts` comment in the file).
Alpha-scissor (`_mat(tex, true)`) keeps the torn edge; tacks/lighting as for the RH bill.

## 4. Gate: `tests/ep2_wanted_rebalance_test.tscn` (new)
Build the real town (`gold_town.tscn`) + Logan's cabin + hideout dressing headless, walk every `MeshInstance3D` whose
material albedo texture path is a poster, and assert: (a) every Jack Hammer bill's texture `resource_path` ends
`poster_jack_hammer.png` and no `poster_jack_hammer.jpg` resolves; (b) count/area rules above; (c) the Armory front has 3
bills over its papers; (d) no two bills overlap on the same wall (AABB in building-local space). Mutation-check it once:
put the saloon spot back to `rh` and watch (b) fail. Then the existing gates: `ep2_logan_cabin_test`, `ep2_gold_town_test`,
`bash scripts/check-ep2-extras-pack.sh`.

## 5. Visual proof
`tools/ep2_shots/posters_privy_shot.tscn` (board, saloon/certificates porches, jail board) plus an Armory-front walk-up and
the cabin view: name + "DEAD OR ALIVE" legible at 1280x720, no black void, no stretch, no blowout (ep2-wanted-posters
tone). Compare the saloon porch before/after on one board (`ep2-reference-match-loop`).
