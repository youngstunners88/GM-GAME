---
name: ep2-jail-privy
description: The jail cell's privy with flies and buzz (founder 2026-10-24 "the toilet with flies in the jail house") - geometry in build_jailhouse.py, the Ep2JailFlies swarm, the synthesized buzz loop, and the jail-only wood texturing. TRIGGER on "toilet", "privy", "bucket", "flies", "buzz", "jail cell detail", or jail furniture looking flat/cheap.
---

# Jail privy + flies

- Geometry: `tools/ep2_blender/build_jailhouse.py` (PX, PZ = -0.42, -6.35 in cell A against the divider): plank box, seat cut round a dark hole, lid up, slop bucket, stain, news-sheet on a nail; `Jail_Nav/Spot_privy` at seat height. Rebuild: `blender -b --factory-startup -P tools/ep2_blender/build_jailhouse.py -- --out src/episode2/extras/jail/jailhouse.glb`, then pinned-4.3 import.
- Flies: `Ep2JailFlies` (src/episode2/chamber/ep2_jail_flies.gd) - 18 flies, two MultiMeshes (bodies + wing blur), 6 "landers" sit/crawl on the seat; deterministic (index + time); no updates beyond 16 m. Spawned by `Ep2GoldTown._furnish` when `jail_spots.has("privy")`.
- Buzz: `uv run --with numpy python3 tools/ep2_forge/make_fly_buzz.py --out src/episode2/extras/jail/fly_buzz.wav` - seamless 2 s loop (every tone whole cycles, wobbles integrate to zero); loop set at runtime; -13 dB, max 9 m - under the jail dialogue.
- Jail DarkWood -> textured timber via `Ep2GoldTown._texture_dark_wood` (jail ONLY - the kit's and Armory's DarkWood are approved as they are).
- Flies are ambient, never enemies or targets.
