---
name: ep2-weapon-logo-decal
description: Put the founder's GM (Gold Mine) logo on a weapon as a glowing gold-and-neon-green engraved-look decal - crop + circular mask + dark-disc transparency + neon outline emission - placed on the receiver side plate by ray-cast so it never floats or sinks. TRIGGER on "put the logo on the rifle", "Gold Logo.png", "the GM logo on the receiver", "mine4gold.app engraving", or any decal on a baked-albedo prop. Proven on the Winchester 1886 (2026-10-06).
user-invocable: true
allowed-tools: Bash, Read, Write, Edit
---

# GM logo on the receiver plate

Source art: `artifacts/episode2-gold-mine/references/founder_2026-10-06/GOLD_LOGO.png` (1024x1024: the emblem sits on a gold vignette).
Target look: `REF_winchester_1886_fps.jpg` - gold GM lettering with a **neon-green outline**, on a dark engraved plate, readable from the shooter's view.
Code: step 4 of `tools/ep2_blender/rifle_surgery.py` (runs only with `--logo <png>`; `run_rifle.sh` passes it).

## Recipe (all measured on the Winchester)
1. **Find the plate with a depth map**, not by eye (`ep2-tripo-mesh-surgery` step 2). After the roll fix the plate is flat at y ~ 0.0025 over x -0.18..0.09, z 0.38..0.52 (0.27 x 0.14).
2. **Ray-cast the surface** (`BVHTree.ray_cast` from y=-1 along +Y at the logo centre) and put the quad 1.2 mm in front of it (`--lx -0.075 --lz 0.45 --ld 0.12`). A guessed y put the first attempt on the wrong surface.
3. **UV crop** of the PNG around the emblem: u 0.14..0.86, v 0.186..0.926 (emblem circle: centre (0.5, 0.556), radius ~0.36 of the image).
4. **Alpha** = radial mask (smooth 0.352 -> 0.37 around that centre) x value-mask (max(R,G,B) 0.16 -> 0.30). The value mask makes the emblem's dark background disc transparent so only gold letters, pick, chain ring and green outline remain - a black sticker disc reads as a decal, not as engraving.
5. **Neon outline mask** = clamp((G - 1.15 R) mapped 0.05 -> 0.35). Emission colour = mix(logo colour, (0.2, 1.0, 0.08), mask); strength = 0.45 + 7 x mask. The 0.45 self-light is what keeps the gold readable in a dark forge scene; without it only the green showed (v-h2), with it alone the green vanished (v-h3) - you need both.
6. Principled: metallic 0.55, roughness 0.30 (metallic 0.9 reflected the dark stage and went black).

## Orientation
Camera at -Y sees +X to the right, +Z up: the quad's UV runs u along +X, v along +Z, so "GM" reads upright with the muzzle to the right. The plate on this GLB faces -Y; a mirror-image rifle needs the quad flipped.

## Not done (be honest about it)
- The logo is a flat alpha card; the reference shows it **engraved** into the plate. Next level: feed the same mask as a height into the plate's bump/normal, or cut a real inset.
- No "mine4gold.app" script lettering from the reference yet.
- The decal has its own object: when exporting a game GLB, merge it into the receiver material (bake) or keep it as a separate mesh.

## Check
Render `--view fps` and `--view oside`; the logo must (a) sit flush on the plate, (b) be fully inside the plate bounds, (c) show gold AND green at 960 px width.
