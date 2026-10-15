# Gemini 4 Argon - 3D character review (advice only; Claude verifies and owns every change)

You are reviewing a game-ready 3D character for a Godot 4 first-person shooter ("Lil Blunt", Episode 2).
You do NOT have the repository. Everything you may rely on is in this message. If a fact you need is missing, say
"MISSING: <fact>" instead of guessing. Do not invent file names, node names or engine features.

## Images (in this order)
1. REFERENCE: the founder's target art (what the character must look like).
2. OLD: the shipping model captured in the real engine at the same camera.
3. NEW: the candidate model captured in the real engine at the same camera.

## Facts
- NEW = Hunyuan3D-2.1 shape (677k faces) -> PBR paint at 512 -> decimated by the painter to 40,000 faces -> skinned onto
  the OLD model's 24-bone skeleton (weights transferred), packed as a 3.98 MB GLB, 2048 albedo + 2048 metal/rough.
- The painter output is a shredded atlas (thousands of small islands), so face/skin areas cannot be repainted by simply
  editing the albedo in 2D; UV islands for the face must be located first.
- Engine: Godot, StandardMaterial3D, Compatibility/OpenGL, forge lighting (warm, dark). Self-emission lifted from the
  albedo fogged the whole figure; do not propose emission as a fix.
- Observed defects in NEW: (a) the face under the hat is nearly black, aviators and cigar do not read; (b) a bright
  orange dot on the face; (c) clothing detail is richer than OLD; (d) file is smaller than OLD.
- Hard constraints: same skeleton and clip names; pack budget (new asset must be <= old); no new paid generation unless
  you justify it with a number.

## Answer in this exact structure (be concise, no preamble)
1. VERDICT: one of SHIP / FIX_THEN_SHIP / REJECT for NEW vs OLD, with the 2 observations that decide it.
2. FACE_DIAGNOSIS: the most likely technical cause of the black face (texture content vs normals/tangents vs material
   vs lighting), ranked, each with a cheap test that would confirm or kill it.
3. REPAIR_PLAN: <= 6 ordered steps, each with the tool/operation, expected result and how to measure it
   (e.g. mean luminance of a region, SSIM against REFERENCE crop). Prefer fixes that do not need a GPU pod.
4. GEOMETRY_RISKS: anything in NEW that will break in animation or at gameplay distance (silhouette, baked props,
   thin shells, face count), each tagged CONFIRMED_IN_IMAGE or HYPOTHESIS.
5. NOT_SURE: what you could not judge from these images.
