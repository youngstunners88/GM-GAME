# 011 — Runner camera, hero placement and lighting (2026-09-29)

Trigger: founder — "the way Lil Blunt is positioned in the middle cart makes it difficult to see what's
going on" and "someone fucked with the lighting". Question: what do the best runners do that we don't?
Sources: Exa + WebSearch (Firecrawl's key was rejected 401 this session).

## What the shipped runners agree on

| Finding | Source | What we do about it |
|---|---|---|
| Camera slightly above and BEHIND the runner, looking down the run, revealing ~2 tile lengths of upcoming track; too close = no reaction time, too far = hazards too small to read | Bertoa, Unreal endless runner write-up; Gkanatsios Unity runner | `CAM_HEIGHT 2.9`, `CAM_BACK 4.0`, look 12 m ahead |
| A hero pinned to screen CENTRE spends half the display on what is behind/around him; offset the camera vertically so the hero sits near the bottom, give the future more pixels | GMTK "How to make a good 2D camera" (look-ahead, vertical offset) | Hero in the lower third; the vanishing point and the rails ahead stay clear of his body |
| Lane readability: perspective makes side lanes visible; path colour separates play area from background; lane markers | codeopsstack hyper-casual runner UX | 3 copper rails on dark ballast; carts flank the hero and read as the lanes |
| Fog and a bending world hide pop-in and give depth cues for approaching hazards (Subway Surfers curved-world shader) | orcunnisli, endless runner UX | Fog kept, but dark and low-density: it manages contrast, it is not distance cosplay |
| Camera changes at set pieces (long jump: aim higher, then look down to reveal the landing) | orcunnisli, Subway Surfers catapult | Zipline raises the camera (+1.7 m) — same idea |
| Value hierarchy: actors and hazards get the brightest/highest-contrast band; environment sits darker and lower-contrast; squint (greyscale) test | Game Developer "Reduce visual confusion"; Frozenbyte wiki | Rock/timber dark; hero, coins, hazards lit; check in greyscale |
| Near = more contrast, far = less (atmospheric perspective) | Frozenbyte wiki | Fog colour dark warm, not orange |
| Three-point lighting: key defines shape, fill gives volume, rim defines the border — rim only where the silhouette meets a busy background | Game Developer "Basic illumination for games"; gamineai contrast rules | Rim/back light on the hero from the tunnel ahead (open) |
| Light in four passes: global → wayfinding → gameplay → detail/mood | Level Design Book | Order the lighting work this way |
| "Findable = emits": anything the player must find is itself a light source | quench ART-DESIGN (Foothold) | Hazards/coins/gold glow; inert rock does not |
| Bright particles must never outshine the hero's rim or the UI; fog must not eat telegraphs | gamineai 12 contrast rules | Streaks/dust dimmed, crystals shrunk (the "white swords") |
| Hue-only separation collapses on cheap panels; separate by value first | gamineai | Squint test is a gate |
| Warm = hazard/urgency, cool = safe/reward (hyper-casual convention) | codeopsstack | Our whole mine is warm, so hazards need VALUE and shape, not hue |

## Why our middle-cart hero failed

Camera 2.35 m up, 3.4 m back, looking at (x, 1.55, +9): the hero (1.9 m × 1.35) filled the screen centre,
his pickaxe crossed the vanishing point and his body covered the two rails and the hazards that matter.
Every reference above keeps the hero low and the horizon/vanishing corridor open.

## What changed (this pass)

- Camera constants `CAM_*` in `runner_view.gd`; hero scale 1.25; hero in the lower half, rails and hazards
  visible above his hat.
- Lighting: the orange ambient/exposure/saturation/emission stack (which read as a brown wash in the web
  build) is gone; ambient neutral-warm, saturation 1.0, exposure 1.0, rock emission 0.09, hero self-light 0.05.

## Still open

- Rim/back light on the hero, lantern light pools with spacing, crystals as emitters not confetti.
- Grade against the target with the value (greyscale) board, not by eye.
