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

## Extracted from MengTo/Skills (game-development family) — only what fits our Godot build

Reviewed 2026-09-29 (`docs/research/3d/012_mengto-skills-extraction.md`); nothing installed, the Three.js code was left behind.

### Camera
- **Position and look-at ease independently** (done: `_look_x` lerp in `_update_camera`); never bind the camera to jittery state.
- **Shake, lock-on, scripted moments are temporary modifiers over the base camera** (ours: `_shake`, zipline +1.7 m).
- **Test the corners, not just the middle:** `ep2_camera_framing_test` now hops to lanes 0/1/2 and asserts hat-in-lower-frame, 24 m of track above the hat, hero on screen, hero ≤ 45 % of screen height.
- **Reduced motion is a real setting** (open): shake, speed streaks and dust must be switchable; `debug_off` keys `streaks`/`dust` already exist to hang it on.

### Motivated light (every local light needs a visible emitter)
Inventory (keep it true when you touch lights):

| Light | Emitter it belongs to | Where |
|---|---|---|
| 4 pooled OmniLights | the nearest real lantern props | `_build_lanterns`, moved with the camera window |
| Lantern flame glow (small amber orb) | the same lantern props (`_lantern_pos`) | `_build_mine_detail` §2 |
| Crystal glow | crystal meshes (vertex-colour shader) | `crystal_glow.gdshader` |
| Coin glow | the coin itself | `_build_gold` |
| Rock self-light (0.09) | none — this is GLOBAL mood, documented as such | `SHELL_EMISSION` |

Rule: no floating glows. The white orbs that hung between the lanterns (found by this review, fixed) were exactly the forbidden case. Ambient is for global visibility/mood, never to fake a lantern.

### VFX spec (write this before adding an effect)
trigger · owner · duration · gameplay meaning · silhouette at camera distance · colour hierarchy · spawn cap · cleanup rule · reduced-motion equivalent. Separate telegraph / contact / success / failure looks.

| Effect | Meaning | Cap | Note |
|---|---|---|---|
| muzzle flash + tracer | shot fired | 1 | brightest thing near the hero is allowed for 80 ms |
| rail sparks | speed/contact | 40 | dim, under the hero's rim |
| gold dust | atmosphere | 70 | tiny round motes, never diamonds |
| speed streaks | speed | 10 | short, warm, dim — long white ones read as swords |
| crystals | wall wealth | 2/point | emissive but below hero rim |
| coin burst | pickup success | 1 burst | success = warm gold, distinct from hazard |

Additive/transparent effects stay away from the hero and the reticle. Cleanup must be idempotent (reset, death, pause).

### Audio cue matrix (input accepted → windup → contact → damage → warning → death → objective)
Every stage needs a cue with priority so critical ones survive a crowd. Gaps found and closed: **windup** (bow creak ~26 m before an arrow — `RunnerVoice`), **death** (`run_failed` line), **objective** (`chamber_reached` line). Voices: one at a time, higher priority cuts lower. Open: on-screen captions for the barks (accessibility).

### Combat verbs (startup / active / recovery)
Ours are sim-authoritative already (`RunnerGraybox` resolves hits; the view is downstream). Keep it that way: the view never decides an outcome. Telegraph before contact for every hazard (creak, boulder roll, "!" emote), apply each contact once by stable id, and prove timing with seeded tests (`RunnerAutopilot`).

### Encounters
One new pressure source at a time; each hazard must demand a different answer; cap simultaneous committed attackers (arrows/bears) in one window; no offscreen damage; a retry must not duplicate a reward (owned by `ep2-state-transition-audit`).
