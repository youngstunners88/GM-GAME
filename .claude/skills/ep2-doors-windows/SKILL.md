---
name: ep2-doors-windows
description: The door/window standard for Episode 2 town buildings - what "improved" means (real holes, framed glass, shutters, panelled/double/batwing doors, side and back windows), which kit pieces to reuse, and the ray test plus first-person capture that prove it. TRIGGER on "doors and windows", "blank boards", "windows never improved", editing town_kit2.glb, build_town_kit.py or adding a building to the town.
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# Doors and windows standard

**"Improved" means all of:** (1) openings are real holes through the wall (no flat textured rectangle on a slab); (2) framed glass with >= 5 panes per building front, glass material named `GlassDay`/`GlassClear`/`Glass` and see-through (alpha < 0.5, never a black hole); (3) shutters or sills so a window reads from street distance; (4) a door type per building role - panelled (offices), double (saloon/bank), batwing (saloon), plain plank (sheds); (5) side and back windows on buildings seen from the lanes; (6) the false-front slab never covers the facade; (7) the doorway is walkable (nothing in `Ep2GoldTown.collide` pushes a body standing in it).

## Where it lives
- Source: `tools/ep2_blender/build_town_kit.py` (headless Blender, rules in `ep2-blender-skills-bridge`). Output: streamed `src/episode2/extras/town/town_kit2.glb` (same piece names as the pack-resident `town_kit.glb`, which is the fallback). Use `Ep2Extras.TOWN_KIT`; never grow `index.pck` (190 MiB gate).
- Reuse the existing kit pieces (`Bldg_Certificates`, `Bldg_Saloon`, `Bldg_Treasury`, `Bldg_A/B/D`, `Bldg_Armory`/`Armory2`, `Bldg_Jail`); a new building copies a sibling's opening modules rather than inventing new ones.

## Proof (both required)
1. Geometry: `godot --headless res://tests/ep2_town_people_test.tscn` - casts a ray through each window centre and doorway and fails if it meets a wall triangle; control ray proves the test can fail. Add the new building's windows to its `specs` table.
2. Picture: first-person capture from the Main Street walk (`ep2-sightline-proof`, `scripts/capture-ep2.mjs`) at street distance, plus one close-up of a door. Compare with `docs/episode2-quality/` captures; judge with `art-direction-fidelity-check`.
3. Live: `scripts/check-ep2-extras-pack.sh web/game` proves `town_kit2.glb` is in the deployed pack; `live-itch-probe.mjs --extras` proves it mounts. If the pack fails to mount, the town silently falls back to the blank-board kit - that is the usual reason the founder "still sees" old windows.
