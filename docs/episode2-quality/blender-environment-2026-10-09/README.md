# Blender environment finish — 2026-10-09

Compared against master `40a585e`, using actual Godot 4.3 Compatibility gameplay cameras. The comparison boards show rendered game assets, not concept art.

## Delivered

Blender 4.0.2 authored hollow iron crucibles and pouring ladles, a stone furnace arch and grate, stamped beveled gold bars, a trestle firing bench, and a weathered plank backstop with stone wings, reinforcement and lamp hoods. Shared project wood/stone textures have generated normal maps. Material calibration keeps iron dark under the room's warm lights; lantern cages and glass use separate materials. Bullet scars now sit on the relief surface rather than disappearing behind the planks.

Editable packed asset workbench (six named collections, spaced for inspection; runtime pivots are exported before the source-only layout): `design/ep2/blender/hideout_finish.blend`. Rebuild with `blender -b --python tools/blender/build_hideout_finish.py -- <repository-root>`. Asset geometry, provenance and counts are in `hideout_finish_manifest.json` alongside the source. The runtime shares texture imports; import presets omit duplicated optimization meshes without removing visible geometry.

## Validation

Nine suites pass 295 checks, including the five-target lesson, facility, scene session, art direction, GLB pipeline, transition and compilation of 294 scripts / 215 scenes. See `tests.json`. Fresh nonthreaded Web export is 198,702,624 bytes, below the 199,229,440-byte gate; no script or parse errors. Security sentinel, front-page lock and green-VFX gates pass. Native screenshots use the existing player camera at 960×540. Existing engine cleanup warnings were also present in the baseline.

The founder character assets, Bull's poses and hand props, voice, film, access gate, controls and five-target lesson remain intact. This is an environment improvement; the previously unresolved Bull sculpt and full cinematic reference fidelity are not claimed as solved. No paid asset generation, external visual grade, mobile validation or long soak was performed. Blender ran headlessly here; the user's PC was not remotely controlled.

## Release

CI run [37934980430](https://github.com/youngstunners88/GM-GAME/actions/runs/37934980430) completed successfully for source `e380e63e4b991d786ada057addf548dc235c8299`. Its log confirms build `2026-10-09-e380e63`, the pack gate and successful butler upload to SmokeRealm. Public BUILD matched `2026-10-09-e380e63`. The access screen rejected an invalid code. An isolated HTML-only saved-unlock fixture left the production PCK and access gate unchanged. The browser used normal Space-hold film skip, then real mouse/keyboard input. Mouse yaw changed 2.444 → 4.290; W changed position; pointer lock worked; walking reached the firing line; Bull's demo completed and returned control. R produced four loaded shells / 20 reserve, and the ADS capture shows the sights view. No script, parse or browser page errors. Backend/telemetry requests were blocked intentionally.

The first 1280×720 software-browser run exhausted its 240-second demonstration wait. The 960×540 rerun with a longer bounded wait completed successfully. This is functional evidence, not a frame-rate benchmark. The live capture reaches aim stage 2/4; all-five-target completion and firing progression are covered by native tests, not claimed as a completed public-browser run. Full film playback, Boss 3 traversal, mobile and long soak were not repeated. See `live.json`, live screenshots and `release-receipt.json`.
