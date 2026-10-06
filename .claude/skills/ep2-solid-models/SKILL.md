---
name: ep2-solid-models
description: Make Episode 2 models read SOLID from every camera - no see-through heads, no hollow rifle, no black squares at the lens. Tripo/Meshy meshes are single-sided open shells; the fix is double-sided materials, no geometry inside the lens, no flat caps showing, measured with a ray audit and ruled on by Jev. TRIGGER on "Inferno Bull is see-through", "the rifle is hollow / not solid / a random square", "I can see through the head", any new Tripo/Meshy GLB in first person, any edit to _fix_bull_materials or rifle_surgery.py / rifle_export_game.py.
user-invocable: true
allowed-tools: Bash, Read, Edit, Grep
---

# Why things look see-through (found 2026-10-05/06)
1. **Back-face culling on open shells.** Tripo/Meshy heads, hats, masks and rifle bodies are single-sided and open at the back/underside. With culling the camera looks through them. Fix: `StandardMaterial3D.cull_mode = CULL_DISABLED` + opaque + `DEPTH_DRAW_OPAQUE_ONLY` on every BODY surface (`_fix_bull_materials` in `smelting_facility.gd`); for a baked GLB set `material.use_backface_culling = False` before export (-> glTF doubleSided). Glass/smoke stay alpha.
2. **The camera sits INSIDE a shell.** Shouldered, the eye was 1 cm under the barrel-top shell, so it saw the inside (back faces) of the rifle: "thin tan sheet + dark boxes". Fix: `Ep2ViewHands.founder_ads_cam.y` raised to 0.19 (over everything ahead of the eye).
3. **Flat caps of procedural parts.** Surgery pieces added with `cap_ends=True` start where the old part was deleted, leaving a flat black disc ("random square") visible from the eye. Start new barrel/tube INSIDE the receiver (x 0.36 / 0.40) and drop decorative boxes (the front-sight dovetail) the founder calls a square.

# The audit (numbers, not eyeballs)
`python3 ... rifle_hero.py ... --post tools/ep2_blender/rifle_export_game.py --rays` fires 15 rays from the shouldered eye across the lower screen and logs `hit mat / dist / n.d`: **n.d > 0 = the ray hit the BACK of a surface (inside view); dist < 0.05 = geometry at the lens.** `node tools/ep2_sim/rifle_solid_jev.mjs before.log after.log` hands the counts to Jev (text-only): before 10 back-face hits + 6 lens hits, after 0 + 0 -> Jev SHIP. For models in the scene: `tools/ep2_shots/bull_close_shot.tscn` (front/side/back shots + `BULLMAT surfaces/alpha/cull_back` counts; `old=1` re-applies culling for a before picture).

# Rules
- Never "fix" see-through by adding alpha or a second mesh; close the culling/lens cause.
- Every new first-person prop gets the ray audit before it ships; every NPC mesh gets `BULLMAT`-style counts (`cull_back` must be 0 on body surfaces).
- Pack budget: rebuilding a GLB must not grow it (rifle 0.86 MB); CI pck headroom was ~2 MiB.
