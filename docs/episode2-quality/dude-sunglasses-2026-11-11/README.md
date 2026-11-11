# Dude's sunglasses are black (founder 2026-11-11)

**What was wrong.** Dude's model (`src/episode2/assets/town/dude_stable_owner.glb`, the founder's Tripo model) has real black frames,
but the lenses are the face mesh itself and its baked texture there was half skin, half jagged black patches.

**What changed.** Every texel seen through the two lens openings from the front is now near-black in the model's own base-colour
texture. 369 of 1,048,576 pixels differ; nothing else in the image changed. Geometry, rig, clips, UVs, the normal map and the
roughness map are byte-identical (12 of 13 buffer views identical; the 13th is the image). The file is 280 KB smaller (the JSON chunk
was re-written compact).

**How.** `tools/ep2_blender/dude_black_sunglasses.py` (headless Blender: ray-casts the lens openings on the posed mesh and paints the
hit texels), then `tools/ep2_blender/glb_swap_image.py` (swaps the one embedded image, rebuilding the binary chunk).

**Proof.** `before_after_face.jpg` (orthographic close-up, flat lighting), `after_bust.jpg`. Both are Blender renders of the shipped GLB,
not an in-game capture; the game applies its own lighting on top. Not founder-verified.

Left as it was: a dark smear under his right lens and one at his temple are in the original bake (beard / hair shadow) and were not
part of this request.
