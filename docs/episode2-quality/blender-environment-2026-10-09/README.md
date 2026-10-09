# Blender environment finish — 2026-10-09

Compared against master `40a585e`, using actual Godot 4.3 Compatibility gameplay cameras. The comparison boards show rendered game assets, not concept art.

## Delivered

Blender 4.0.2 authored hollow iron crucibles and pouring ladles, a stone furnace arch and grate, stamped beveled gold bars, a trestle firing bench, and a weathered plank backstop with stone wings, reinforcement and lamp hoods. Shared project wood/stone textures have generated normal maps. Material calibration keeps iron dark under the room's warm lights; lantern cages and glass use separate materials. Bullet scars now sit on the relief surface rather than disappearing behind the planks.

Editable packed source: `design/ep2/blender/hideout_finish.blend`. Rebuild with `blender -b --python tools/blender/build_hideout_finish.py -- <repository-root>`. Asset geometry, provenance and counts are in `hideout_finish_manifest.json` alongside the source. The runtime shares texture imports; import presets omit duplicated optimization meshes without removing visible geometry.

## Validation

Nine suites pass 295 checks, including the five-target lesson, facility, scene session, art direction, GLB pipeline, transition and compilation of 294 scripts / 215 scenes. See `tests.json`. Fresh nonthreaded Web export is 198,702,624 bytes, below the 199,229,440-byte gate; no script or parse errors. Security sentinel, front-page lock and green-VFX gates pass. Native screenshots use the existing player camera at 960×540. Existing engine cleanup warnings were also present in the baseline.

The founder character assets, Bull's poses and hand props, voice, film, access gate, controls and five-target lesson remain intact. This is an environment improvement; the previously unresolved Bull sculpt and full cinematic reference fidelity are not claimed as solved. No paid asset generation, external visual grade, mobile validation or long soak was performed. Blender ran headlessly here; the user's PC was not remotely controlled.

## Release

Publication and live browser verification pending.
