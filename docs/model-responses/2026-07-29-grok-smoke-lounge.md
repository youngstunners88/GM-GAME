<!-- dispatched: x-ai/grok-4.5
     prompt: prompts/grok-smoke-lounge-art.md
     files inlined: 0
     tokens: 1144 in / 1441 out
     cost: $0.0109
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
# Smoke Lounge — Art Direction Brief

Reskin + 3× extend of existing Chill Lounge (`secret_realm.gd`). Not a new room.

---

### 1. Color palette

**Read:** purple-grey haze, chill, nocturnal. Distinct from Smoke Realm (forest/hazy green) and Crystal Caverns (cyan/cave).

| Role | Hex | Use |
|---|---|---|
| Deep void | `#1a1428` | Clear color / farthest falloff |
| Purple-grey mid | `#3d3554` | Floor tint, platform bodies |
| Dust lavender | `#7a6b8c` | Mid haze, muted structure edges |
| Ash rose | `#a890a0` | Soft highlight on primitives |
| Ember accent | `#c4a07a` | Sparse warm notes (bong glass glint, label glow) — not orange fire |
| Cool smoke | `#9b8fb8` → `#5c5470` | Particle lifetime (see §4) |

Avoid pure green and cyan. Keep saturation low; value contrast does the work.

---

### 2. Parallax layers

**Keep both existing layers.** Do not replace files this pass.

- **`bg_secret_far.jpg` (0.1):** Leave motion scale. For 5100px width, **tile or mirror-extend horizontally** so the nebula doesn’t stretch-smear. If the paint already reads seamless enough at 3× scroll distance, a single stretch with mild horizontal wrap is acceptable; prefer repeat over upscale.
- **`bg_secret_mid.jpg` (0.45):** Same width treatment. Optional: multiply-tint the Sprite2D toward `#3d3554` / `#5c5470` so the old “lounge painting” shifts into the purple-grey night read without repainting.
- **Third layer:** **Skip for this pass.** Two layers + ground particles already sell depth; a third parallax strip costs draw/overdraw on HTML5 for marginal gain across a long flat secret. Revisit only if mid-layer tiling looks empty at walk speed.

Floor stays a simple dark `ColorRect`/primitive strip; platforms are primitives on top — not a new BG plate.

---

### 3. Rest-stop concepts (2–3)

Decorative ledges along the extended floor. **Only** `sprite_item_bong.png`, rects/circles, Labels, and optional runtime radial-gradient quads. No new sprites.

**A — Bong alcove**  
Low wide platform (`ColorRect` `#3d3554` + thin ash-rose lip). Center: `sprite_item_bong.png`. Flank with two small circles (cushions) in `#5c5470`. Optional dim radial-gradient quad behind the bong as a soft pool of light. Reads as a sit/spot landmark; place ~1/3 into the run.

**B — Protocol signage plinth**  
Taller narrow stack of rects (pedestal). Face: a `Panel`/`ColorRect` “sign” with a **Label** placeholder (`PROTOCOL` / logo initials). Small circle bolt-heads at corners. No bong required; use as a mid-run wayfinding beat so the logo has a home before real art drops in.

**C — Founder mural ledge**  
Long low platform against an implied back wall: large landscape `ColorRect` (`#2a2238`) with inner inset rect + **Label** (“FOUNDER” / name). Two bongs optional as symmetric end-caps (reuse same sprite, flipped). Treat as the destination beat near the far third, before the return portal.

Space them so the 5100px walk has clear breath between stops; don’t cluster.

---

### 4. Ground haze particles

**Node:** CPUParticles2D, texture `fx_dot.png`.  
**Motion:** emit along the floor line, velocity mostly **up**, slight horizontal drift; low gravity or gentle upward accel; lifetime long enough to die around mid-shin-to-waist of the player, not screen-filling columns.

**Color over life (ramp):**  
`#9b8fb8` (cool smoke, ~40–50% alpha) → `#5c5470` (~20% alpha) → transparent.  
Optional tiny warm kick at birth (`#c4a07a` at very low alpha) only if it doesn’t read as fire.

**Density:** light ground mist — readable gaps between dots; platforms and collectibles stay legible. If silhouettes soften, cut amount or alpha before changing color. Particles are atmosphere, not fog-of-war.

---

### 5. Founder + protocol placeholder framing

Frame them as **diegetic wall pieces**, not HUD.

- **Protocol logo → signage (Rest-stop B):** Framed board on a plinth/post — border rect + inner field + center Label. Later swap = replace inner field contents (texture or child sprite); border and pedestal stay.
- **Founder portrait → mural (Rest-stop C):** Wide inset panel on the back plane of a long ledge — outer matte, inner portrait rect, caption Label under or on the matte. Later swap = drop portrait texture into the inner rect only.

Use fixed aspect slots now (e.g. logo roughly square; portrait 3:4 or 4:5) so real art drops in without relayout. Ember accent only on the frame edge or caption, not full-bleed glow.

---

**Out of scope this pass:** new sprite sheets, music implementation details, shaders beyond existing CanvasItem habits, GPU particles, third parallax plate.