---
name: gm-game-portal-map-art
description: Make the three Protocol Portal tour rooms look like a detailed Warcraft-style overhead map instead of a black void. Painted MuAPI maps from the founder's references, Jev picks the variant, wired as the room backdrop. TRIGGER when the founder says a portal room/background is shit, black, empty, not "like Warcraft", or not detailed.
---

# Portal map art (founder brief 2026-09-28)

Founder: "expansive like Warcraft — like walking on a mapped-out section. The 1st one must be smokey."
References: `docs/founder_briefs/2026-09-28/ref/` (sheet_smoke/diamonds/gold.jpg). The style
anchor is image4: a high-angle painted fantasy RTS map with forest, winding roads and a lit district.

## Pipeline
1. `python3 scripts/gen_portal_maps.py <out_dir> 2` generates 2 variants per protocol with MuAPI Flux.
   - Size: **1344x576 works**; 1440x576 and 1024x416 return HTTP 400. 1280x512 also works.
   - The prompt keeps a clear left-to-right road in the lower third (the walk line), with no text, UI or characters.
2. Look at a contact sheet yourself, then let **Jev pick** each variant (`scripts/jev.mjs --choice`)
   from short written notes. Jev is text-only, so never send it pixels. Votes go in `portals/90_gates/map_pick_*.jev.txt`.
3. Upscale the pick to 2800x1200 JPG q86 at `src/assets/portals/maps/map_<protocol>.jpg`
   (about 0.5 MB each; the pack budget is 190 MB).
4. `StudyRoom._add_painted_map()` lays it inside the `Backdrop` layer (z -100), above the procedural
   backdrop and below stops, props, companion and player. The paths are in `PAINTED_MAPS`.
5. Check it: run the portal tests plus `tests/portal_capture_tool.tscn` under xvfb (visibility should rise),
   look at the three in-game frames, then ship with `scripts/ship-to-master.sh`.

## Current picks (2026-09-28)
smoke v0 (purple-green smoke pagoda lounge, ring plazas), diamonds v1 (green crystal citadel, bridge road),
gold v0 (golden canyon mining town, boardwalks, gold piles).

## Next upgrades
- Line the stop positions (`MAP_POSITIONS` in StudyRoom.gd) up with the painted landmarks: the lounge, well, gate, vault.
- Optional parallax: a second transparent "smoke/fog" layer drifting over the map in the smoke room.
