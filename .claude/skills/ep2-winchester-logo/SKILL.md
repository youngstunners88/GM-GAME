---
name: ep2-winchester-logo
description: "Remove the brown outer ring from the Winchester GM logo and fill random holes on the receiver. Use when the rifle logo, medallion, brown circle, scalloped ring, or top-of-gun holes are reported. Do not restyle or enlarge the ring."
type: workflow
lifecycle: active
---

# Winchester logo — delete the ring

The founder has rejected this logo six times. The last pass enlarged the brown outer circle. That is a fail.

## Rule

- The logo is the GM letters on a dark disc, flush on the receiver.
- The brown/gold scalloped outer ring is not part of the logo. Delete it.
- Do not scale the ring. Do not add a bezel. Do not turn it into a medal.
- Random holes on the top of the gun are mesh errors. Fill them. Solid metal.

## Refs

- Rifle: Drive folder `1iTj7No2JaSPYKxC-_w2Pr8mAUQTUZhFE`, file `1BXzrbqfKZhYzBjFt33doouKt3wqUC1bq`
- Logo: `1CMH9lDxeW-cBtXo3Nj92-HRSPFVP_BEH`

## Before ship

Jev (`~typesafe/jev-latest`) must answer yes: ring gone, holes filled. Then the Microsoft decision model already on the OpenRouter session, same two questions. A no from either blocks the push.

## Fail signs

- Ring thicker than the last build
- New outer circle in a different color
- Logo floating off the receiver
- Holes still open on the top strap

## How it was actually fixed (2026-10-10) - read before touching the rifle again

**What made the ring.** `tools/ep2_blender/rifle_export_game.py` step 3b built a polar patch (dark steel ring -> gold rim -> socket) out to r 0.112
(pre-scale) = 0.083 m in game units. The receiver side plate only reaches 0.051 m (bottom) / 0.055 m (top) from the logo centre, so the patch
overhung the receiver: the scalloped brown disc. Earlier still, step 2b painted Tripo's emblem area 0.85x darker (the first "brown layer").

**What made the holes.** Step 3b deleted EVERY face whose centre was within r 0.10 of the logo centre, and step 2a squashed every vertex within
r 0.134 - both reached past the plate's top edge into the top strap, which came out jagged and open. Proof: a no-logo control build
(`--logo` omitted) has a clean top.

**What it does now.**
1. `make_gm_emblem.py --classic --disc`: the founder's logo (chain + GM) on its OWN dark enamel colour, 2.6 mm dark band past the chain, no gold rim.
2. The plate is MEASURED (ray walks that start outside Tripo's relief, stop where the surface falls >4 mm below the plate): box logged as `side plate box`.
3. Relief: every vertex standing >1.5 mm proud inside the old emblem radius is compressed 33x (not collapsed - shells keep their order); under the
   disc it is pushed below the plate. Below-plate geometry (frame bevel, top strap) is only touched inside the plate box, eased to its rim.
4. Custom normals of flattened loops are reset to the plate's (and frame's) own average normal - Tripo's normals made a "ghost" oval.
5. Albedo AND roughness/metal are repainted under the old emblem with the plate's (frame's) median - the gold ring otherwise still shone.
6. ONE disc (radius 0.05 pre-scale = 37.6 mm, clipped to 1 cm inside the plate), 0.9 mm proud, 1.5 mm roll-off. Only faces lying ENTIRELY
   under it are deleted (233), so no hole can appear anywhere else.
7. **Import: `winchester_1886_founder.glb.import` has `generate_lods=false`** (tracked with `git add -f`). Godot's auto-LOD folded the 0.9 mm disc
   into the plate and cut the logo to a sliver - the runtime-loaded GLB looked fine, the imported one did not. Always prove with the IMPORTED file.
8. Godot does not always re-extract a GLB's embedded images: after an export, write them over `winchester_1886_founder_<image>.*` yourself
   (the emblem jpg was a day stale).

**Rebuild** (headless bpy, ~4 min):
```
python3 - <<'PY'
import sys,runpy
sys.argv=["x","--","--glb","design/ep2/blender/rifle/bolt-action-rifle_source.glb","--align","--flipx","--pre","tools/ep2_blender/rifle_surgery.py",
 "--logo","artifacts/episode2-gold-mine/references/founder_2026-10-06/GOLD_LOGO.png","--lz","0.443","--sr","0.05","--bake","1024","--tex","1024",
 "--post","tools/ep2_blender/rifle_export_game.py","--game-out","src/episode2/assets/weapons/winchester_1886_founder.glb"]
runpy.run_path("tools/ep2_blender/rifle_hero.py",run_name="__main__")
PY
```
**Prove**: `tools/ep2_shots/rifle_vm_shot.tscn` (hip view + receiver side / top / top-3q close-ups; `glb=<file>` for a candidate, `badge=x,y,z`
to frame a build without a disc) and the gate `tests/ep2_winchester_logo_test.tscn` (no ring surfaces, radius <= 40 mm, flat, LODs off,
no delete cylinder). Numbers that passed: band outside the disc 10.9 vs open plate 10.1 (shipped ring 14.8, flat std 0.6); old relief max 2.1 mm
proud (was 15.8); top-strap depth vs untouched model: 0 changed texels on the receiver top (shipped: 799 new holes + 158 bumps).
Jev 0.98 / 0.86 and microsoft/microsoft-decision-1 0.998 / 0.947 (ring gone / holes filled), both "ship"; both chose the dark edge band.
The Microsoft model is `microsoft/microsoft-decision-1` on the same `/api/alpha/decisions` endpoint: `JEV_MODEL=microsoft/microsoft-decision-1 node scripts/jev.mjs ...`.
Both are text-only: give them the measurements above, never a screenshot.

## Third pass (2026-10-10, LIL BLUNT'S RIFLE = the founder's Tripo "rifle 3d.glb", green arm baked in) - texture-only, no geometry added
Founder: "The rifle that I gave you is Lil Blunt's rifle ... fix the issue of the logo on it, but dont fuck it up like before!!!!"
His Tripo model had the GM logo as a SMEARED GOLD BLOB inside a recessed DISH with a raised LIP (the lip reads as the brown ring).
`tools/ep2_forge/repaint_rifle_logo.py` (then `tools/ep2_blender/lil_blunt_rifle_to_game.py` for the viewmodel frame):
1. Find the blob (gold texels on receiver-facing verts), then MEASURE the plate with rays from outside (first hit = what is seen);
   fit the true plate plane (the blob normal was 1.6 / 5.2 deg off: a disc on it shaded as a dark band).
2. Flatten the dish: grow from the visible dish faces through mesh edges, per-15-degree sector out to where the hits return to the
   plate (one side's groove ran to 1.48x on one arc only), within -22/+6 mm, eased over 0.08x radius. A depth-window flatten pulled the
   panel edge (~10 mm down at 1.3x) into slivers; a first-hit-only flatten left shards - both rejected by render.
3. Paint, per texel via its 3-D point: emblem inside 0.95x the old blob radius (NEVER larger), emissive green GM, flat normal;
   the old rim band is refilled with the plate's own colour at that angle (60-bin median, no per-texel copy: it speckled) and lifted
   to the plate's brightness (band gain ~1.27, tapered).
4. No face is ever deleted (topology identical) -> no hole can appear. Gate: `tests/ep2_winchester_logo_test.tscn` reads
   `docs/episode2-quality/lil-blunt-rifle-logo-2026-10-10/logo_fix_report.json`.
Numbers: band/plate on the first-person side 0.70 -> 0.93; far side 0.67 -> 0.58 (faint trace left - next pass); 77 660 faces before
and after; 0 verts moved outside the receiver. Jev 0.92 / 0.91 / 0.95, microsoft-decision-1 0.905 / 0.994 / 0.996 (ring gone /
no holes / not enlarged), both "ship". Close-up render camera: `track_quat('-Z','Y')` - with 'Z' the camera rolled 180 deg and a
correct logo looked mirrored (cost a round).
