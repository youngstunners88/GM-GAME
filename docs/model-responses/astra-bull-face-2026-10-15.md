<!-- dispatched: openai/gpt-6-astra
     prompt: prompts/gemini/gemini-4-argon-3d-review.md
     files inlined: 0
     images attached: 3 (artifacts/episode2-gold-mine/references/founder_2026-10-10b/inferno_bull_with_rifle.jpg, docs/episode2-quality/bull-hunyuan-2026-10-15/engine_old_front.png, docs/episode2-quality/bull-hunyuan-2026-10-15/engine_new_front_emis035.png)
     tokens: 4855 in / 1201 out
     cost: $0.1086
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
1. VERDICT: **FIX_THEN_SHIP**
   - NEW loses facial identity: the aviators, muzzle and cigar are substantially less legible than OLD and REFERENCE.
   - NEW retains richer clothing detail at a reported smaller file size, making targeted repair preferable to regeneration. Its visibly washed-out shading is not ship-ready.

2. FACE_DIAGNOSIS:
   Ranked hypotheses, not confirmed causes:
   1. **Texture content:** dark face shading or missing feature contrast baked into the painted albedo. **Test:** inspect the face in an albedo-only DCC preview. If it remains featureless, texture content is implicated; if readable, investigate shading instead. A 2048 export does not establish detail beyond the original 512 paint.
   2. **Lighting / hat occlusion:** the brim may suppress already-dark facial features. **Test:** temporarily hide the hat and compare under identical lighting; separately try neutral frontal illumination. Recovery isolates occlusion or illumination. OLD’s readable face makes scene lighting alone less convincing.
   3. **Material:** unsuitable metal/rough values or channel interpretation could darken the face while flattening the body. **Test:** retain albedo but temporarily use constant nonmetallic, moderately rough shading without self-emission. Recovery implicates material settings/maps.
   4. **Normals/tangents:** decimation or transfer could introduce shading discontinuities. **Test:** inspect a constant-gray surface under a moving light, then compare a duplicate with corrected normals. Persistent face-shaped dark patches support a normals problem. Tangents matter here only if tangent-dependent shading is used. **MISSING: whether a normal map is assigned.**

3. REPAIR_PLAN:
   1. **Godot capture / controlled baseline:** disable the failed self-emission treatment if still active; hold camera, pose and lighting constant. Expected: comparable OLD/NEW shading. Measure face and torso mean luminance plus facial-feature contrast. **MISSING: whether NEW’s screenshot includes the emission experiment.**
   2. **Godot inspection / isolate the orange dot and weapon:** the same-looking orange disk appears on OLD too; NEW also shows a large gun beside a thinner gun-like element. Temporarily isolate character geometry from other visible elements. Expected: identify ownership before editing textures. Measure whether each artifact survives isolation and follows the character versus screen position.
   3. **DCC / run the diagnostic substitutions above:** change one variable at a time. Expected: separate albedo, material and geometry causes. Measure muzzle-to-surround and glasses-to-face luminance contrast, not just overall brightness.
   4. **DCC UV selection + localized 3D painting:** locate face islands first; restore neutral-lit muzzle/fur values, distinct aviator rims/lenses and cigar separation. Apply material or normal corrections only if supported by tests. Expected: readable identity without brightening the whole figure. Measure feature contrast against OLD at equal projected head size; visually compare landmarks with REFERENCE.
   5. **DCC/Godot / animation sweep:** inspect all existing clips, especially shoulder, wrist, neck and hip extremes; correct transferred weights or prop ownership where necessary. Expected: no visible tearing, prop bending or intersections. Measure defect count and verify unchanged skeleton and clip names.
   6. **Export / engine acceptance:** compare repaired NEW with OLD at near and intended gameplay distances. Require recognizable glasses/cigar, no unintended dot or duplicate weapon, and no shading washout. Measure frame cost and total packaged size, not GLB size alone. **MISSING: OLD’s exact asset/pack size, gameplay distances and performance budget.** No paid generation justified.

4. GEOMETRY_RISKS:
   - **CONFIRMED_IN_IMAGE:** NEW’s weapon-side silhouette contains a broad gun plus a separate thin gun-like element. **HYPOTHESIS:** generated weapon geometry duplicates an existing prop; ownership is unverified.
   - **CONFIRMED_IN_IMAGE:** aviators and cigar have weak separation at this camera distance. **HYPOTHESIS:** insufficient geometric separation or baked-only detail will disappear further away.
   - **HYPOTHESIS:** transferred weights bend rigid props, horns, hat or accessories, or collapse shoulders/wrists. A matching skeleton does not guarantee good deformation.
   - **HYPOTHESIS:** thin brim, straps or weapon surfaces have holes, backface exposure or decimation damage; this view cannot establish topology.
   - **HYPOTHESIS:** 40,000 faces may be expensive at the intended simultaneous character count. File size does not establish rendering cost. **MISSING: triangle count, character concurrency and target hardware.**

5. NOT_SURE:
   - **MISSING:** mesh/UV inspection, actual material settings and texture samples.
   - **MISSING:** animation captures, back/side views and unobscured feet.
   - **MISSING:** provenance of the orange disk and weapon-like elements.
   - These differently lit, differently posed images cannot establish precise reference fidelity through raw SSIM; use aligned feature crops and controlled engine comparisons instead.