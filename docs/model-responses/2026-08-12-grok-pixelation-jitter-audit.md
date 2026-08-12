<!-- dispatched: x-ai/grok-4.5
     prompt: prompts/grok-pixelation-jitter-audit.md
     files inlined: 1
     tokens: 23224 in / 3070 out
     cost: $0.0649
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## Band-art jitter/softness audit

### What the code does **not** do
Protocol landmarks are **static** after build. In `_build_protocol_landmarks()` (~lines where `art.position` / `art.scale` are set): position, scale, modulate, filter are assigned once. No per-frame rescale, no parallax parent, no `ScreenShake` coupling on these nodes.

`ScreenShake.shake(0.2, 6.0)` runs only inside `_crash()` — not a steady-run jitter source.

### Shared path (all badges, wide + square)
- Parent: root `Node2D` (world space), `z_index = 1`
- Y: `GROUND_Y + BAND_ART_Y` (`BAND_ART_Y = 122.0`, `BAND_ART_SIZE = 190.0`)
- Filter: `CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS` on every landmark sprite
- Camera follow (every physics frame):  
  `_camera.position.x = _player.position.x + 240.0`  
  — full float, **no** pixel snap. Entire band scrolls under sub-pixel camera motion.

So a *codepath fork that only moves one landmark* is **not** present for the protocol list.

### Only intentional motion on band art
**Lounge banner only** (`_build_lounge_banner`): looping scale tween `1.0 ↔ 1.03` over 1.1s (`TRANS_SINE`). That will read as continuous soft/breathing edges on that one piece.

`_build_protocol_landmarks()` does **not** attach that tween. If the circled piece is `br_diamond_certificate.png` (wide entry in `BR_ART_ORDER`), the breath tween is **not** the cause unless they mis-identified the lounge banner.

### `is_wide` vs square — real difference, weak jitter explanation
```gdscript
# wide: uniform height-fit
s = BAND_ART_SIZE / tex.get_height()   # 190 / h
art.scale = Vector2(s, s)

# square: force into 190×190 (can non-uniformly stretch)
art.scale = Vector2(190/tex.get_width(), 190/tex.get_height())
```
- Wide art keeps aspect and often ends **much wider** on screen (large `half_w` used in slot math).
- Neither path snaps scale/position to whole pixels.
- Wider + finer UI/text edges will show **sub-pixel scroll shimmer** and LINEAR minify softness more than flat circular badges, even on the same filter setting.

That matches “one rectangular card soft/warped/double-exposed, circular neighbors sharp” better than a placement bug.

### Strongest causes (ordered)

1. **Same class as TAP OUT face (asset import), not placement**  
   Code requests `LINEAR_WITH_MIPMAPS` for all band sprites. If `br_diamond_certificate.png` (or whichever wide PNG was circled) has `mipmaps/generate=false` in its `.import`, Godot has no mips to sample → soft/blocky minify. Neighbors with mips (or smaller downscale ratios) stay crisp.  
   **Check next:** `.import` for the circled wide asset vs a sharp badge (e.g. `badge_*.png`).

2. **Sub-pixel camera scroll + LINEAR on a wide, detailed sprite**  
   Camera x is unlocked float every frame at `RUN_SPEED` 320. Classic edge crawling / “double” fringe on high-contrast rect edges while discs look fine.  
   **Check next:** project `display/window/stretch/*`, any 2D snap (`rendering/2d/snap/…`), and whether camera should `floor()` position (or sprites use pixel-aligned positions) during this mode.

3. **If the circled piece is actually the lounge banner**  
   The `1.03` scale breath is a direct, continuous jitter/softness source on that node only.

4. **Not supported by this file**  
   Overlap/“masking” from dual draw of the same certificate: only one add per slot; reservations prevent stacking. Warping from different stretch math per sprite: none beyond wide vs square scale above (no rotation, no non-uniform wide scale).

### Not the root cause here
- `_landmark_slot_x` / `_find_band_slot` / `_band_reservations` — placement only at build; won’t shimmer frame-to-frame  
- Parallax layers — band art is not on them  
- `is_wide` slot pitch — spacing only, not filtering  

### Fix direction (for ship today)
1. Verify/fix **mipmaps on** for all `BR_ART_ORDER` / founder wide PNGs (especially the circled card); reimport.  
2. Optionally stop relying on mips alone: pre-scale brand art to ~display size, or use `LINEAR` **with** mips guaranteed.  
3. If shimmer remains while scrolling: pixel-snap `_camera.position` (and/or band sprite positions) in this scene.  
4. If the soft piece is the lounge banner: remove or drastically reduce the `1.03` scale breath on `banner`.  

I cannot see the certificate’s `.import` or project stretch settings in the provided file; those are the next concrete checks—not more placement logic in `blaze_rush.gd`.