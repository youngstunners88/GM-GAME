---
name: ep2-wanted-posters
description: Make, change or place the GoldMine town's wanted posters (founder 2026-10-24) - engraved portraits from the real game models, period hand-bill paper and wood type, the founder's own posters (Crypto Queen, RH), placement on the notice board, shop fronts and the jail. TRIGGER on "wanted poster(s)", "bounty poster", "notice board", "posters not visible", a new outlaw/bandit poster, or a founder poster image to hang.
---

# Wanted posters

## Pipeline (no paid generation needed)
1. Bust from the REAL model the game draws: `blender -b --factory-startup -P tools/ep2_forge/render_poster_bust.py -- --glb <glb> --out <dir>/bust_<id>.png [--yaw 0.35] [--full]` (`--full` = whole figure, e.g. the horse side-on at `--yaw 0.25`). Characters face glTF +Z.
2. Poster: `uv run --with pillow --with numpy python3 tools/ep2_forge/paint_wanted_posters.py --busts <dir> --out src/episode2/extras/town/posters` (640x880 JPEG ~180 KB). Specs live in `SPECS` in that file. Fonts are OFL in `tools/ep2_forge/fonts` (tools/ is excluded from the export).
3. Founder images (square, torn edges on white): key the white with `magick in.jpg -alpha set -bordercolor white -border 2 -fuzz 9% -fill none -draw "color 0,0 floodfill" -shave 2x2 -trim +repage -resize 760x760 poster_<id>.png` - PNG keeps the torn edge (alpha scissor in game).
4. Hang: `Ep2TownPosters` (src/episode2/chamber/ep2_town_posters.gd) - `IDS`, `WALL` (building-local: wall face z=0, porch floor y=0.44, ground windows at x=+-(w/2-1.3)), `JAIL_BOARD`, `BOARD_BILLS`. Aspect comes from each image. Hideout uses two of them via `HideoutDressing._wanted_poster`.

## Rules
- Wording (ep2-jack-hammer-narrative): no digits, no "$", no tickers on OUR posters; Jack Hammer's bounty is "paid in gold"; the accomplice has no name yet (founder's call) - "NAME UNKNOWN" + CAPTURED. The founder's posters are hung as supplied.
- Streamed (ADR-0005): images under `src/episode2/extras/town/posters/`; commit their `.import` with `git add -f` in pinned-4.3 format.
- Engraving tone: equalise inside the figure, `dark ** 1.45 * 0.92` - darker reads as a black blob (first pass did).
- Proof: `tools/ep2_shots/posters_privy_shot.tscn` (board from the drop-off and close, saloon/certificates porches, jail board).
