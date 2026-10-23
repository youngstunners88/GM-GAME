---
name: ep2-sightline-proof
description: Prove that an Episode 2 town piece is (or is not) visually "on" or "off" a street - measured sight lines from the Main Street walk plus a first-person capture - instead of arguing from coordinates. TRIGGER on "next obvious storefront", "off the main drag", "I can still see it from Main Street", "hard-won", placing the stable, lake, train or any building relative to Main Street, and before claiming a placement fix.
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# Sightline proof (placement claims need numbers and a picture)

A coordinate change is not a visual change. A prior armory pass moved the shop and the founder still saw it as a Main Street storefront. This skill makes "off Main Street" falsifiable in two layers; both are required, neither is sufficient alone.

## Layer 1: the 2D probe (cheap, run it first and often)
`tools/ep2_town/armory_offmain_probe.py` (stdlib, reads the live `LAYOUT`/`FOOTPRINT`):
```
python3 tools/ep2_town/armory_offmain_probe.py --repo .                       # as committed
python3 tools/ep2_town/armory_offmain_probe.py --repo . --set Bldg_Armory=-30,1428,1 --add Bldg_A=-30,1419,1   # candidate, no Godot edit
python3 tools/ep2_town/armory_offmain_probe.py --repo . --piece Bldg_Saloon --json   # any piece
```
It reports: metres from the door mouth to the nearest Main Street front plane (x = +-9), the % of Main Street eye points (x = -6/0/+6, z 1403-1495) with a clear 2D line to the door or its sign, where the piece is first seen from, which front-lines hold 3+ buildings (a "street"), and footprint overlaps. Exit 1 on any failed check.
Thresholds are **proposals** (`--min-off-main 20`, `--max-los-pct 25`, `--min-street-fronts 3`, `--max-row-share 3`). Tighten them if the engine capture disagrees; never loosen them to get a pass.
Limits: 2D only. No roofs, awnings, props, wagons, terrain or fog, and "visible" is not "noticeable" (a muted sign 25 m away is not a billboard). Entries are `[piece, front-plane x, front-centre z, side]` with side 1 facing +x, -1 facing -x, 0 facing -z, exactly as in the GDScript.

## Layer 2: the engine picture (the part the founder believes)
1. Use the Episode 2 gold-town chamber and the existing shot rigs `tools/ep2_shots/town_shot.tscn`, `town_beats_shot.tscn` (extend the capture job list; `ep2-town-proof` Phase 2 lists the required views). Local Godot is 4.7.2 but the pinned engine is 4.3 in `.godot-cache/` after `scripts/bootstrap-godot.sh`: capture with the pinned one.
2. Cameras at **eye height (~1.6 m)**, looking where a player looks: the drop-off (0, 1403) facing +z, the left boardwalk (-6, 1425) and (-6, 1445), the opening of the lane, and the door itself. Hyprland tiles the Godot window narrow: render through a SubViewport scene, not the window.
3. Before and after, same cameras, same time of day. Put both in `docs/episode2-quality/<topic>-<date>/` with the source SHA, and score by eye plus the probe numbers. The reference-match loop (`ep2-reference-match-loop`) applies when the founder supplies a target image.
4. Answer in the ledger, per camera: "is the door the next storefront in the row? y/n" and "does a second street read? y/n". A single "n/y" is not a pass.

## Rules
- No sign, light or prop may be added on the main sightline to "help" the player find the place. Discovery is the Sheriff tip + the lane opening.
- Moving a building changes what hides behind it: re-probe the pieces that used it as cover (Church, Bldg_E).
- Horses, wagons and the train count as occluders and as lures; capture with `Ep2TownLife` built, as the player sees it.
- Report plain results: "11 m / 57% visible before, 20 m / 12.5% after, captured from three Episode 2 cameras" beats "moved it further".
