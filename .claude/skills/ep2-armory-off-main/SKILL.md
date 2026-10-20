---
name: ep2-armory-off-main
description: Move Rich & Utah's Armory clearly off Main Street and give the Episode 2 town a real second street (founder prompt PROMPT_EPISODE2_ARMORY_FURTHER_OFF_MAIN, 2026-10-18). Placement and streets only. TRIGGER on "further off Main Street", "armory too close", "the armory is the next storefront", "more than one street", "side lane", "second block", moving Bldg_Armory, LANE_MARK, or before reporting that pass done.
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# Armory further off Main Street (placement + side streets only)

> **Status 2026-10-19:** this is a real founder prompt but it is NOT the active job; the active prompt is Logan's Lake (`ep2-logans-lake`). Nothing here is built. It was written first from the wrong Drive file and is kept because the armory distance complaint is still open.

Source of truth: Drive `PROMPT_EPISODE2_ARMORY_FURTHER_OFF_MAIN.md` (id `12Ddyg5W8Mg27lA3XH6OGr_JROI9sLNvM`). Quote it in the ledger (`ep2-design-verify`), never paraphrase it weaker. Founder's own test: "If a player standing on Main Street can treat the armory door as the next storefront in the same row, the placement is still wrong." He accepts only after a hard refresh on the live itch page. **Do not claim FIXED for a one-metre nudge.**

## Scope
- IN: where `Bldg_Armory` stands, the approach to it, and enough walkable side-street geometry (facades, lamps, fences, props) that a second street is visible on first load.
- OUT (do not touch): Rich/Utah bodies and clips, trade rules and prices, the day-88 river set-piece, voice, new weapons, Certificate/Saloon/Hotel/duel lane/Treasury positions, protocol chambers. The interior, door gap (`FOOTPRINT["Bldg_Armory"] = [8, 9, 0.7]`) and trade panel stay as shipped.
- The two-storey rebuild of the building is a separate job (`ep2-armory-two-story`, branch `feat/armory-two-story`). This job only changes the `LAYOUT` row, the lane dressing and the approach. Merge conflicts in `ep2_gold_town.gd`: keep BOTH sessions' changes.

## Measured starting point (master `1f81ead2`; re-run, do not trust)
`LAYOUT` in `src/episode2/chamber/ep2_gold_town.gd`: Main Street fronts at x = +-9 (`STREET_HALF`), left row z 1412-1447, right row z 1414-1447, Church (0, 1478). `["Bldg_Armory", -20.0, 1468.0, 0]` faces -z, door mouth (-20, 1467), `LANE_MARK` (-12, 0, 1452) in `gold_town.gd`.
`python3 tools/ep2_town/armory_offmain_probe.py --repo .` gives: **11 m** off the Main fronts, **visible from 57%** of the Main Street walk, **no second street** (only the two Main rows have 3+ fronts). That is the founder's complaint in numbers.

## Candidate that passes the probe (a starting point, not the answer)
"Back lane": a lane at x ~ -24 behind the left row (the row's own backs at x -18 hide it), buildings on its west side fronting east:
`--set Bldg_Armory=-30,1428,1 --add Bldg_A=-30,1419,1 --add Bldg_C=-30,1448,1 --add Bldg_F=-30,1407,1` -> 20 m off, 12.5% visible, 3 fronts on `1@-30`, no overlap. Fillers reuse existing kit pieces, so **zero new GLB bytes**. Re-score any variant with the probe before editing Godot. The probe is 2D and ignores roofs, props and terrain: it narrows candidates, the engine capture decides.

## Order of work
1. Ledger rows (`ep2-design-verify`): quote the five Definition-of-Done lines; status starts IN CODE / nothing.
2. Probe the committed layout and 2-3 candidates (`ep2-sightline-proof`). Pick one that also leaves a **findable** entrance: the founder wants "slightly hard-won", not hidden. The Sheriff tip and the lane opening are the discovery path.
3. Build it (`ep2-side-lane-build`): `LAYOUT` rows, lane dressing, bounds, tests.
4. Everything the old position drags along must move with it: `LANE_MARK`, the lamp at (-10, 1450), `Arm_PowderKeg`/`River_Crate`/`River_Skiff` staged at the lean-to (`dress` array), the Sheriff `face_point`/`look_toward` in the TIP beat, the grazing horse `Ep2TownLife.HORSES[3]` (-24, 1472) which sits inside the old footprint (move it outside; **do not replace the horses**, founder lock), and the test waypoints in `tests/ep2_gold_town_test.gd` (~line 207-215: street -> `LANE_MARK` -> `door_world("Bldg_Armory", 2.2)` -> `ARMORY_SPOT`).
5. Update the TIP objective wording only if the lane description changes ("side lane, one block off the left row"). `ep2_gold_town_test` asserts the word "lane".
6. Gates + proof + ship (below).

## Gates (all must pass, none loosened)
`tests/ep2_gold_town_test.tscn` (64 checks incl. 18 Armory), `ep2_personal_armory_test`, `ep2_fort_knox_arc_test`, character motion, bow, cart; the probe; then `scripts/ci-gates-local.sh`. Fort Knox scans `gold_town.gd`/`ep2_gold_town.gd` for the lowercase words "diamond" and "pickup truck": keep them out of comments too.
**Pack:** the fresh-import gate is `scripts/pack-gate-fresh.sh` (<= 199,229,440 B). Margin after the texture fix was ~467 KB. This job should add ~0 B: transforms and reused kit pieces only. Any new texture/GLB needs a measured pack number first (`ep2-3d-tools`). Never "recover" bytes by excluding files without `ship-visual-proof` (the 2026-10-18 white-rifle incident).

## Proof the founder will accept
- Real Episode 2 camera, eye height, from the drop-off (0, 1403), the left boardwalk and the cross-lane mouth: the armory door must not read as the next storefront, and the second street must read as a street. Use `tools/ep2_shots/town_shot.tscn` / `town_beats_shot.tscn` (extend, do not invent a new camera). Capture from Episode 2, never the Level 3 backdrop.
- Walk the real approach in the test and record the path length.
- STATUS.md: name the build tag, say "further off Main Street", describe the approach in one line. Log it in the vault (VAULT-LOG rule) with SHAs and status words.

## Ship (standing rules)
Work in its own worktree (`~/Documents/GitHub/GM-GAME-offmain`, branch `feat/armory-further-off-main`). `scripts/ship-to-master.sh` is blocked for Claude by the permission classifier: the user runs it with `! cd <worktree> && bash scripts/ship-to-master.sh`. Then verify run success + the "Deploy to itch.io via butler" step + log "Pushed to ..." + the on-boot `[BUILD]` tag. Say "live" only after that; before it say "pushed / ready to ship". Ship the texture-margin-eating branches in the order the vault says.
