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

## 2026-10-09 lesson: "the GM logo on the rifle is unclear"
- The decal had been on the **unseen side** (glTF -X); the founder only ever saw Tripo's own baked emblem. The shooter sees the rifle's glTF +X side = **+Y in the aligned frame** (`rifle_surgery.py --lside` default; ray from +Y).
- Never ship the raw logo: `tools/ep2_blender/make_gm_emblem.py <GOLD_LOGO.png> <dir>` crops tight on G+M+pickaxe+mountain, erases the chain ring, lifts the gold, thickens the neon, adds a thick gold bezel on an opaque enamel disc (`emblem_color.png` + `emblem_emit.png`). `rifle_export_game.py` calls it.
- Blender 4.2 writes alphaMode BLEND for the decal; the export patches the GLB JSON to MASK (cutoff 0.5) or it sorts wrong/disappears.
- UVs `((1,0),(0,0),(0,1),(1,1))` read un-mirrored on the +Y side (verified with `glb_axes_shot`, CAMSIZE=0.7, absolute `glb=` path).
- Pack budget: emblem PNGs + GLB ≈ +0.2 MB; keep it that way.

## 2026-10-09 (later): NOT a sticker - paint it INTO the rifle
Founder: the overlay "covers over the original logo ... I need it to be one with the rifle. Not a fucking sticker."
`rifle_export_game.py` no longer builds a decal mesh. It (1) flattens Tripo's rippled emblem relief to the plate plane (rippled
geometry made a painted logo look like shattered glass), (2) planar-projects `make_gm_emblem.py` output into the BAKED ALBEDO
(2048 atlas) + a 1024 emission map, edge-feathered, over the +Y receiver plate only (the -Y plate shares texels; `--both` paints it too),
(3) texels get 1-2 px dilation, depth-gated to the plate plane. Never float a quad over a baked emblem again. Known: the right edge
of the bezel is slightly ragged where UV charts are anisotropic - fix by re-packing the plate UV island if the founder objects.

## 2026-10-09 (final): a real BADGE, not paint and not a sticker
Founder: "It mustn't look like it's painted on. It must be like a badge or engraving." Praised the Blender hero render (rifle_v3: full
logo with its CHAIN RING, gold, restrained neon). Now: `rifle_export_game.py` flattens Tripo's relief, darkens the old emblem into a worn seat
(texture only, no logo), and builds REAL geometry: a bevelled raised gold bezel ring + an inset face disc carrying the classic logo
(`make_gm_emblem.py --classic`, chain ring included). Tune `--br` (radius), bezel colour is a plain factor (metal reads black without env light
in the Compatibility renderer; keep metallic <= 0.6, no emission). Pack cost: emblem jpg 92 KB + emit 18 KB.

## 2026-10-09 (failed attempt, do not repeat blindly): carving a socket by vertex displacement
Subdividing + displacing the Tripo receiver plate did NOT work: the Tripo emblem relief is several OVERLAPPING shells (y 0.09-0.13), so
collapsing them onto one profile gives coplanar shards, ragged gold, 36k polys / 2.2 MB. Patch kept in
`tools/ep2_blender/experiments/rifle_socket_carve_attempt.patch`. A real engraving needs the plate region DELETED (all layers) and rebuilt
as clean geometry in Blender (or a Tripo regeneration of the receiver), not displaced. Shipped state = flush gold-ringed inlay (commit 6d4dfe6).
