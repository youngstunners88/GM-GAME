---
name: world-building-workflow
description: Assemble Episode 2's props, materials and lighting into a coherent mine — tunnel enclosure, cavern rhythm, lantern placement, gold seams, chamber dressing — rather than a pile of isolated assets. Use when the task is how a SCENE reads, not how one prop is built.
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Grep, Glob
---

# World-Building Workflow (Episode 2 — the Gold Mine)

## The lesson this skill is built on

A correct palette on correct props still rendered as a black void, because the
runner had **no walls**. There were no surfaces for the light to land on. Every
material value was right and the frame was empty.

Environment art is not the sum of its props. Build the enclosure first, then
light it, then dress it.

## The order that works

### 1. Enclose it
Walls, ceiling, floor. Until light has something to fall on, no amount of
material accuracy shows up in a capture.

### 2. Break the corridor
Uniform walls read as "a rectangular shaft, not a cavern" — a direct fidelity
finding. `_build_tunnel()` in `runner_graybox.gd` segments the walls in 20 m
bays and opens every fourth one into a wide, tall pocket with loose rock on the
floor. **Deterministic, index-driven** — no RNG, so two captures of the same
track are comparable and a visual diff means a real change.

Anything that hugs the wall must follow it. `_wall_x_at(z)` exists for exactly
that: veins, timber posts and lanterns all query it, or they float in mid-air
where a bay opens out.

### 3. Light it with practicals, not ambient
The references light the mine with **warm lamps on the timber** against **cool
stone**. That colour contrast is the whole look. Raising ambient to fix darkness
destroys it — the scene gets brighter and flatter at the same time.

- `Ep2Palette.make_lantern_light()` — warm omni, range 17 m, energy 3.6.
  Range matters more than energy: at range 7 the lamps hung 4.6 m off the rails
  never reached the track and the capture came back nearly black.
- `Ep2Palette.make_key_light()` — **cool** directional, fill only.
- Spacing ~14 m, alternating sides. Closer becomes continuous warm fill and the
  pools stop reading as individual lamps.

### 4. Dress it
Gold seams as **many small scattered pieces**, never a few large slabs — big
ones read as decals taped to the wall. Gold is always clustered in the
references, never a lone nugget; that is what `gold_pile.glb` is for. Keep piles
off the driving line so they never read as collectible.

### 5. Give the frame a subject
All three references are anchored by Lil Blunt's green silhouette. Without a
rider the runner reads as an empty cart rolling itself downhill. Today that is
`lil_blunt_placeholder.glb` — a placeholder, described as one, per
`hero-character-pipeline`.

## Where the numbers live

**One file: `src/episode2/art/ep2_palette.gd`.** Every surface, the environment
and all three light types. Both scenes pull from it in `_apply_art()`; nothing
defines a material inline. Four files each holding their own colours is how
"everything is grey" became a four-file problem.

`table()` is plain data on purpose so `tests/ep2_art_direction_test.tscn` can
assert over it.

## Web-backend constraints that silently no-op

The web build runs Godot's **Compatibility** backend, not Forward+:

- **Volumetric fog does not exist.** Use plain distance fog.
- **No reflection source ⇒ metallic renders near-black.** Cap metallic around
  0.3-0.8 and carry metal through albedo, roughness and a little emission.
- No SSR, SSAO, SDFGI.
- Watch the mesh count. The runner is currently ~600 `MeshInstance3D`s; that is
  fine, but it is the budget being spent.

Anything you set that is Forward+-only will look right in the editor and do
nothing on itch.io. That failure mode is invisible unless you capture.

## Closing the loop

Never call a dressing pass done from the editor or from a headless gate.

1. Export → 2. `scripts/capture-ep2.mjs` → 3. `art-direction-fidelity-check`
→ 4. work the ranked drift list top-down → 5. re-capture.

When a finding is real and numeric, add it to
`tests/ep2_art_direction_test.gd` so it is locked. That gate now holds the
anti-blowout bounds and the camera-framing checks precisely because earlier
reviews found those problems by eye.
