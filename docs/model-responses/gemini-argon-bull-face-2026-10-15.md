<!-- dispatched: google/gemini-4-argon
     prompt: prompts/gemini/gemini-4-argon-3d-review.md
     files inlined: 0
     images attached: 3 (artifacts/episode2-gold-mine/references/founder_2026-10-10b/inferno_bull_with_rifle.jpg, docs/episode2-quality/bull-hunyuan-2026-10-15/engine_old_front.png, docs/episode2-quality/bull-hunyuan-2026-10-15/engine_new_front_emis035.png)
     tokens: 4012 in / 1457 out
     cost: $0.0226
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
1. VERDICT: REJECT (or FIX_THEN_SHIP only if major material/mesh surgery is performed).
- Observation 1: The entire NEW figure suffers from severe washout/low-contrast haze (likely broken roughness/metallic channels or residual ambient/fresnel settings) and lost surface micro-detail compared to OLD, while the face/snout is an unreadable black blob.
- Observation 2: NEW has a massive baked-in rifle in the left hand that duplicates and collides with the engine's existing equipped weapon mesh (both rifles are visible simultaneously in the NEW screenshot).

2. FACE_DIAGNOSIS:
- Rank 1 (Texture Content - Baked Shadow/Low-Res Bleed): The 512 PBR painter baked ambient occlusion under the hat brim and dark fur into near-zero albedo values, obliterating the aviators, nose ring, and cigar.
  - Cheap test: In Godot, temporarily enable `Shading Mode > Unshaded` on the `StandardMaterial3D`. If the face remains solid black, the defect is baked into the 2048 albedo texture.
- Rank 2 (Material - Metal/Roughness Channel Mapping): In dark OpenGL environments without bright reflection probes, a metallic value near 1.0 or inverted roughness turns dark albedo completely black while making rough areas look chalky/washed out.
  - Cheap test: Unassign the metallic/roughness texture in `StandardMaterial3D`, set `Metallic = 0.0` and `Roughness = 0.8`. If the face and body regain normal shading contrast, the ORM packing or values are wrong.
- Rank 3 (Normals/Tangents - Decimation Artifacts): Decimating 677k to 40k faces without re-baking custom normals often leaves crushed or inverted vertex normals in high-curvature pockets (snout/glasses).
  - Cheap test: Set a white `StandardMaterial3D` (no albedo texture) on the mesh. If the snout/glasses still render black under scene lights, vertex normals/tangents are broken.
- Note on the "bright orange dot": Present in both OLD and NEW at the exact same screen coordinates; this is an engine particle/sprite (cigar ember) misaligned with NEW's head position, not a texture defect on NEW.

3. REPAIR_PLAN:
- Step 1: Remove duplicate baked rifle geometry.
  - Tool/Op: Blender Edit Mode -> Select linked vertices (`L`) on the baked left-hand rifle and sling -> Delete vertices.
  - Expected result: Only the engine-spawned weapon remains in the left hand; file size drops further.
  - Measurement: Visual inspection in engine (1 rifle instead of 2) and vertex count reduction.
- Step 2: Fix global material washout and contrast.
  - Tool/Op: Python (`PIL`/`numpy`) or Blender -> Inspect metallic/roughness texture channels; clamp metallic to `0.0` on non-metal areas, scale roughness to `0.65–0.90`, and apply a gamma curve (`1.2–1.4`) to the body albedo to restore dark fur contrast.
  - Expected result: Fur and leather match OLD's richness and stop looking milky/fogged.
  - Measurement: Mean luminance and standard deviation (contrast) of a torso crop in engine within 10% of OLD.
- Step 3: Isolate face UV islands on the shredded atlas.
  - Tool/Op: Blender -> Select head/snout/glasses/cigar faces in 3D Viewport -> Create a black/white vertex-color mask -> Bake vertex colors to a 2048x2048 mask image.
  - Expected result: Exact pixel mask of all shredded UV islands belonging to the face/aviators/cigar.
  - Measurement: Mask coverage > 99% of selected 3D face triangles with zero bleed onto body islands.
- Step 4: Project REFERENCE face onto NEW geometry.
  - Tool/Op: Blender Texture Paint (Stencil/Project from View aligned to front camera) -> Project the REFERENCE head crop onto the face mesh, then composite with the Step 3 UV mask over the 2048 albedo.
  - Expected result: Crisp aviators, nose ring, snout highlights, and cigar texture restored across the shredded UV islands.
  - Measurement: Mean luminance of the face region increases from near-0 to match OLD; SSIM of the unshaded face crop against REFERENCE crop > 0.70.
- Step 5: Recalculate normals on the 40k mesh.
  - Tool/Op: Blender -> Clear Custom Split Normals Data -> Recalculate Outside -> Weighted Normal modifier (applied) -> Export GLB with tangents enabled.
  - Expected result: Smooth shading under the hat brim without black polygon faceting.
  - Measurement: Zero inverted face normals in Blender Face Orientation overlay.

4. GEOMETRY_RISKS:
- Duplicate baked rifle + thin sling (CONFIRMED_IN_IMAGE): NEW bakes a thick rifle and a free-hanging thin sling loop into the left hand, colliding with the in-game weapon and guaranteed to clip/stretch during arm animations.
- Baked cigar and nose ring merging (CONFIRMED_IN_IMAGE): The cigar in NEW is a short, blob-like protrusion fused into the snout geometry rather than a distinct cylinder.
- Shredded UV mipmap bleeding at gameplay distance (HYPOTHESIS): Thousands of tiny UV islands on a 2048 map will bleed background/padding colors across seams when OpenGL downsamples to lower mipmap levels at FPS combat distances.
- Weight transfer on thin shells/straps (HYPOTHESIS): Automated weight transfer from OLD's 24-bone rig onto NEW's 40k decimated topology (especially the backpack roll, collar, and horn tips) risks jagged vertex spikes during torso/head rotation.
- 40,000 face budget in Compatibility renderer (HYPOTHESIS): MISSING: OLD face count and target FPS/platform budget, but 40k triangles skinned on a 24-bone CPU/OpenGL pipeline may cause frame hitches if multiple instances spawn.

5. NOT_SURE:
- Whether the overall milky/washed-out look of NEW is caused by an active normal map (MISSING: whether a normal map is packed in the 3.98 MB GLB), wrong sRGB/Linear flag on the albedo texture, or scene fog interacting with the material's roughness.
- Back-side geometry and texture quality (backpack bedroll, lantern, rear belt) as no rear camera angle was provided.
- Deformation quality of the transferred skin weights during actual animation clips (only the idle pose is shown).