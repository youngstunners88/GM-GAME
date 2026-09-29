---
name: gm-game-portal-prop-integration
description: Make Protocol Portal props (Smoke/Diamonds/Gold study rooms) sit INSIDE the painted map instead of looking like pasted-on "gameware". Photoreal prop sheet generation, white-key atlas build, per-room light grade, contact + cast shadows, edge-safe placement. TRIGGER when the founder says icons/props feel crowbarred in, hang off an edge, look like gameware, float, or don't match the realistic background; or when a room's props are regenerated or repositioned.
---

# Portal prop integration (founder brief 2026-09-29)

Founder: props "feel a little crowbarred in ... more like gameware compared to the more realism backgrounds";
the Diamonds balance scale "sits awkwardly on the edge as if it's hanging off". Cause was a style gap
(pixel-ish props on photoreal plates), not a positioning bug alone. Fix it on all three axes below.

## 1. Draw props in the map's own language
- `python3 scripts/or_image_ref.py google/gemini-3.1-flash-image <prompt.md> <sheet.png> --ref map_<protocol>.jpg --ref <realistic sheet>`
  (about $0.05 a sheet; env `OPENROUTER_API_KEY`, never print it). First reference = the room map (palette/mood),
  second = a finished realistic sheet (quality/scale target). Ask for exactly 8 props, 4x2, pure white background,
  no text, three-quarter top-down view, lit from the map's light direction, generous gaps.
- Cell order is the contract in `RoomFixture.CELLS` (row-major). Keep the prop-per-cell meaning.
- Re-roll the sheet if two props touch, a prop is cut off, or a prop is cartoon/pixel style.

## 2. Build the atlas
`python3 scripts/build_prop_atlas.py <sheet.png> src/assets/portals/fixtures/<protocol>.png --no-shadow --debug dbg.jpg`
- Use `--no-shadow` for generated sheets: it drops baked shadows and pale glow halos, keeps thin chains
  (no morphological opening) and de-fringes the white matte. The room draws its own shadows, and a baked one
  would double up and point the wrong way.
- Look at `dbg.jpg` (grey checker). Expect "props 8". White patches inside a prop = enclosed background
  (raise the pocket rule) or a glass highlight (accept).

## 3. Integrate in the room (`RoomFixture.gd`)
- Share one ground anchor for the opaque feet, compact contact shadow and collider. Current admitted atlas feet land at approximately y=410 in each 443px cell; verify this if replacing the atlas.
- Keep the contact shadow tight (about 14px high). Detached flattened silhouettes and giant dark pools were rejected as floating furniture; do not restore them.
- Grade toward the room with `prop_integrate.gdshader`. Keep highlights restrained rather than bleaching the top of every object.
- Size props against nearby painted furniture and the character. Gold/ Diamonds now use roughly 120-200px cell widths; making every prop 235-315px caused crowding.

## 4. Place props (`RoomLayout.STOPS` + `GROUND`)
- Keep every prop base **>= 80 px inside** any cliff lip/parapet/bridge edge, and never on a low wall.
  Overlay stops + polygons with `PIL` on the map (room y = image y - 50) before committing coordinates.
- Space props so half-widths do not overlap (prop fill is ~0.75-0.86 of `PROP_WIDTH`).
- Keep the ground polygon narrower than the walkable painting, not wider, so the player can't stand on air.
- If the painting already shows the thing (an archway, a door), do NOT add a duplicate prop on it:
  use an interaction hotspot on the painted feature without additional furniture (see `gm-game-portal-atmosphere`).

## 5. Prove it
`SHOT_OUT=<new dir> xvfb-run -a -s "-screen 0 1280x720x24" .godot-cache/Godot_v4.3-stable_linux.x86_64 --rendering-method gl_compatibility --rendering-driver opengl3 --path . res://tests/portal_capture_tool.tscn`
then LOOK at `<protocol>-overview.png` and every per-stop close-up. `tests/portal_room_test.gd` must pass
(reachability, footprints block walking, painted props or the existing doorway hotspot). Never `rm -rf` old captures; use a new dir.

Run `tests/portal_traversal_test.gd` too: walk collision-aware routes using real input, press E at each station, and verify the advisor stays nearby.
