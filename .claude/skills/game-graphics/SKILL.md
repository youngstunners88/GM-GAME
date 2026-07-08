---
name: game-graphics
description: Build or change any visual in the game (characters, HUD, levels, effects). Enforces the client's art direction and the procedural-drawing standards until sprite sheets exist. Use for "make X look like...", new enemies/collectibles, level dressing, or juice/VFX work.
---

# Game Graphics — Lil Blunt Visual Standards

## Source of truth

1. `design/art_direction_reference.md` — canonical written spec distilled from
   the client's key art (character anatomy, per-realm palettes, HUD language).
   READ IT FIRST. If a request conflicts with it, surface the conflict.
2. `src/player/lil_blunt_visual.gd` — reference implementation of the
   procedural-drawing approach and the character's proportions.

## Non-negotiables (from client art + CLAUDE.md)

- Lil Blunt: green shaggy nugget, leaf mane, googly eyes with red-dotted cream
  rims, huge grin, blunt + cute smoke. Stage outfits: cowboy (L1/L3),
  miner/crystal (L2). NEVER aggressive or gross.
- Enemies are never weed-themed (Tax Collectors, flies, boulders, vines).
- Palette: saturated neon on dark (purple night / blue cavern / orange sunset),
  bold dark outlines, chunky readable silhouettes.
- 420/69 recur as flavor numbers (BLOCK 420, prices) — keep the gag alive.

## Procedural drawing rules (until sprite sheets land)

- One `Node2D` subclass per entity visual, all painting in `_draw()`;
  `queue_redraw()` only from property setters (no per-frame redraws).
- Draw centred on origin inside the entity's collision footprint.
- Expose `color` (tint) and rely on inherited `visible` so power-up glows,
  damage flicker, and outfit code work without changes.
- Layer order: silhouette/mane → body+outline → clothing → face → props.
- Use `draw_set_transform` for squash/ellipse effects; ALWAYS reset with
  `draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)` after.
- Godot 4.3 API traps: `CPUParticles2D.EMISSION_SHAPE_SPHERE` (no _CIRCLE) with
  `emission_sphere_radius`; `draw_arc` needs point count + antialiased args.

## Scene-file (.tscn) rules — parse errors ship silently otherwise

- NEVER write `SomeShape2D.new()` inside a .tscn — declare a
  `[sub_resource type="..." id="..."]` block and reference `SubResource("id")`.
- `load_steps` = (ext_resources + sub_resources + 1). Update it when adding.
- Reference scripts via `[ext_resource]`, never `SubResource(...)` for scripts.
- Autoload scripts must NOT declare `class_name` equal to the autoload name.

## Verify every visual change

Run the real-browser gate before calling it done:

```bash
node scripts/serve-web.mjs 8899 web &          # prod-faithful COOP/COEP server
CHROMIUM_BIN=/opt/pw-browsers/chromium-1194/chrome-linux/chrome \
  node scripts/verify-web.mjs http://localhost:8899/ /tmp/claude-0/shot.png
```

Exit code 0 = engine booted, zero Godot script errors, Level-1 click-through
screenshotted. Read the `-level.png` screenshot to EYEBALL the change —
"compiles" is not "looks right". Note: local pck comes from the last CI
export; script changes need a push→CI cycle (see /export-deploy) before they
appear in the local web/game/ build.
