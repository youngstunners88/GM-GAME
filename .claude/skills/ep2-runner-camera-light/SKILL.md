---
name: ep2-runner-camera-light
description: Frame and light the Episode 2 runner so the hero, the lanes and the hazards ahead are readable — camera height/back/look-ahead, hero placement in the lower third, value hierarchy, three-point lighting with a rim, fog as contrast, and the squint/greyscale test. TRIGGER when the founder says the hero is hard to see, is "in the way", is positioned awkwardly, the lighting looks wrong/washed/orange/muddy, or before changing camera, environment, ambient, fog, exposure or emission constants.
---

# Episode 2 runner — camera, placement, lighting

Research: `docs/research/3d/011_runner-camera-light-placement.md` (Subway Surfers, Temple Run,
GMTK camera talk, Game Developer readability + illumination articles, Level Design Book).

## The five laws (each has a number or a test)

1. **The hero lives in the lower third.** Never at screen centre: a centred hero gives half the display
   to what is around him. Camera above and behind, looking far down the run (`CAM_HEIGHT 2.9`,
   `CAM_BACK 4.0`, look 12 m ahead, `CAM_LOOK_Y 1.1`). Gate: `tests/ep2_camera_framing_test`.
2. **The vanishing corridor stays open.** No character part, call-out or HUD may sit on the rails between
   the hero's hat and the vanishing point. The player must see ~2 tile lengths (≥ 24 m) of track.
3. **Value before hue.** Hero, coins, hazards = brightest, highest-contrast band. Rock, timber, floor =
   darker, lower contrast. Everything is warm here, so hazards separate by VALUE and SHAPE. Squint test:
   desaturate the screenshot; hero and hazards must still read. (`ref_compare.py` board + greyscale.)
4. **Three-point lighting on the hero:** key (lantern-warm, from ahead/above) for shape, fill (ambient) for
   volume, RIM/back light only where his silhouette meets busy rock. Findable things emit; inert rock does not.
5. **Fog is contrast management.** Dark warm fog, low density; near = more contrast, far = less. Bright
   particles (streaks, dust, crystals) never outshine the hero's rim — that is how "white swords" happened.

## Working order (from the Level Design Book)

global light → wayfinding light (lanterns down the corridor) → gameplay light (hazards, coins, bears) →
detail/mood. Do not start at the last one.

## Tuning loop

1. `bash tools/ep2_shots/shoot.sh <out> 0 20,100 800,300` (about a minute, software GL).
2. Look at it beside the founder's target (`ep2-reference-match-loop`), then greyscale it.
3. Change ONE constant family at a time: `CAM_*`, `HERO_SCALE`, ambient colour, fog, `SHELL_EMISSION`.
4. Never stack warm tints: ambient colour × exposure × saturation × emission compounds into the brown
   wash the founder rejected on 2026-09-29. If the frame reads orange, remove a tint before adding contrast.

## Traps

- The palette (`ep2_palette.gd`) pins ambient ENERGY with a gate; colour and exposure are the view's to change.
- Web Compatibility renderer: no volumetric fog, per-light cost per object — fake light with emission.
- A pose that reads well in the Meshy contact sheet can be wrong from the runner camera (back view): always
  check from the game camera.
