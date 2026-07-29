ROLE: Art director for a 2D platformer's atmospheric secret area.

CONTEXT — read carefully, this corrects a wrong assumption in the brief that
generated this request:

The requesting brief assumed "Smoke Lounge" was a brand-new level to be built
from scratch. It is not. The game already has a secret bonus area called
"the Chill Lounge" (`src/level/secret_realm.gd`), reached through a hidden
glowing door on a high ledge in Level 1. It is already non-combat: no
enemies, no traps, just a floor, two parallax layers, ~10 collectibles, and a
return portal that drops the player back exactly where they left. Separately,
the client's own protocol design docs use "the Smoke Lounge" as the name of a
real treasury/NFT-routing destination in his tokenomics, and had already
flagged the existing Chill Lounge as the natural in-game reskin target once
he wanted it "felt" by players. He has now asked for that reskin, expanded
3x in length, with dedicated music, ground-level rising smoke, slower
movement, and a place for founder/protocol art. So: this is an existing,
working room being restyled and extended — not a greenfield build.

CURRENT STATE (ground truth, not to be second-guessed):
- Two painted parallax layers already exist: a distant cosmic nebula
  (`bg_secret_far.jpg`, motion scale 0.1) and a nearer lounge painting
  (`bg_secret_mid.jpg`, motion scale 0.45).
- Width is being expanded from 1700px to 5100px (3x).
- A real bong sprite asset already exists (`sprite_item_bong.png`) and a
  soft radial-dot particle texture already exists (`fx_dot.png`) — both
  reusable, no new art pipeline needed for this pass.
- No founder portrait or protocol logo files exist in the repo yet —
  placeholders (colored rectangle + text label) are expected and fine.
- Godot 4.3 CPUParticles2D (not GPU, for HTML5 export parity), CanvasItem
  shaders only, no external image generation in this pass.

DELIVERABLE — a short art direction brief covering:
1. **Color palette** for the Smoke Lounge, distinct from the two existing
   main-game realms (Smoke Realm = forest/hazy green, Crystal Caverns =
   cyan/cave). Should read as "purple-grey haze, chill, nocturnal."
2. **Parallax layer recommendation**: keep the existing two layers (what, if
   anything, should change about them for the new length) and whether a
   third layer is worth the render cost, given the two constraints above.
3. **2-3 rest-stop concepts**: small decorative platforms along the extended
   length. What sits on them, using ONLY the existing bong sprite, simple
   primitive shapes (rectangles, circles), and text labels for logos/mural
   placeholders — no new sprite sheets.
4. **Ground haze particle direction**: color progression over the particle's
   lifetime (it fades out as it rises) and roughly how dense it should read
   without becoming a wall of fog that hides platforms.
5. **How the founder portrait and protocol logo placeholders should be
   framed** (as a mural? as signage?) so the layout reads correctly today and
   drops in real art later without rework.

CONSTRAINTS:
- Do not invent new engine features, shaders, or asset files. Everything you
  propose must be buildable from: CPUParticles2D, ColorRect/Panel primitives,
  Label, Sprite2D with the two existing backgrounds + the two existing
  sprites named above, and procedurally-generated textures (a radial gradient
  built at runtime is an established pattern in this codebase — assume it's
  available, don't spec anything more exotic than that).
- Do not write GDScript. This is an art direction brief, not code.
- If you're unsure whether something is feasible in Godot 4.3, say so rather
  than asserting it.
