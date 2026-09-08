# Episode 2 — Smelting Facility graphics demo (Three.js)

A **web prototype only**. Per `docs/architecture/adr-episode2-runtime-engine.md`
(ADR-0001, Accepted), the game runtime is **Godot 4.3**. Nothing in this folder
ships in the game; it exists to explore the look of Chamber 0, the smelting
facility where Lil Blunt meets the Inferno Bull
(`artifacts/episode2-gold-mine/chambers/00_SMELTING_FACILITY.md`).

## Run it

```bash
cd artifacts/episode2-gold-mine/threejs/demo
python3 -m http.server 8177
# http://127.0.0.1:8177/index.html      (add ?clean=1 to hide the HUD)
```

## Controls
- **click the ground** — Lil Blunt walks there
- **drag** — orbit the isometric camera
- **scroll** — zoom

## Constraints this build honours

- **No external assets.** Every mesh is a three.js primitive; every texture
  (flagstone, rock, masonry, timber, normal maps) is painted to a `<canvas>`
  at load time. The only fetched file is `vendor/three.module.js`, which is
  vendored locally because the CDN is unreachable from the build sandbox.
- **Isometric** orthographic camera that lazy-follows the character.
- **Living scene** — flickering lanterns, a breathing molten flame column,
  rising heat haze, drifting dust, embers, falling pebbles, cigar smoke, and
  idle animations on both characters.
- Movement is deliberately confined to the chamber + a short track section.

## Performance — read this honestly

The frame rates recorded during development (**~20-22 fps**) were measured on
**SwiftShader, a software rasterizer with no GPU**, which is all the build
sandbox has. That number is *not* evidence for or against the 60 fps target.
The demo has not yet been run on real GPU hardware, so the 60 fps requirement
is **unverified**, not met. Anyone with a GPU can settle it in one page load.

## Build process

Built with the `dream-loop` skill (concept art -> build -> fresh art-director
subagent scores the live screenshot against the concept -> iterate). Working
files live in `.dream-loop/` (gitignored).
