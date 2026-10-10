---
name: ep2-founder-asset-swap
description: The founder's own 3D models (Drive doc "3D Assets": Meshy share links, Rodin, Tripo) replace every forged/primitive stand-in. TRIGGER on the founder sending meshy.ai/s/ links, a hyper3d or tripo3d URL, "swap in my assets", or any prop that looks forged/primitive.
---
# Pipeline
1. `python3 tools/meshy/pull_share.py <code> --remesh 0 --tex 1024 --aux 256 --name f_<slot>` (free download; never remesh with a 0 balance).
2. `python3 tools/ep2_forge/install_founder_props.py` bakes each to the code's conventions (rifle 1.2 m muzzle +Z; helmet base y=0 lamp +Z; whiskey unit height; bitcoin unit diameter) and shrinks textures for the pck budget (pck gate 190 MiB; ~180 MiB used).
3. `godot --headless --import`, then the facility test and `tools/ep2_shots/show_shot.tscn`.
# Drive GLB exports (no Meshy/Tripo credits needed)
`curl -sL -o f.glb "https://drive.google.com/uc?export=download&id=<fileId>&confirm=t"` works for big files the Drive MCP refuses (>10 MB).
Tripo Studio ids are NOT API task ids ("Task not found"); ask for a GLB export instead.
- Unrigged hero (Inferno Bull, Tripo minotaur 1M verts): `tools/ep2_forge/decimate_textured.py` (pymeshlab, keeps UVs; needs `apt-get install libopengl0`) then `tools/ep2_forge/retarget_bull.py` puts it on the existing Meshy skeleton (nearest-vertex skin transfer, core-fit alignment, deletes the rifle fused to the left hand) so every existing clip keeps working. Keep the old GLBs in `.farm/retired/`.
- Studio-rigged export (Tripo, UE-style 60 joints): `tools/ep2_forge/build_bull_from_tripo_rig.py <pristine meshy rig> <tripo rig> out.glb clip glbs...` keeps the Meshy bone names/rotations (clips + holders unchanged), moves joints to the Tripo positions, folds fingers/twists into the 24 joints, strips the rifle, shifts clip Hips; `Ep2Actor` drops per-bone translation keys at runtime. Check a rigged export with `scripts/glb-shot.mjs` first - a broken skin shows as stretched shards (the rigged bear did).
- Static statues (bear archer): decimate, scale to the old model's bounds, drop in.
  In a chamber the IMPORTED archer scene is already 1.69 m tall (inner node x1.9) and centred on y (base at -0.863): scale by
  2.0/1.695 and lift by 0.863*scale, or it sinks / lies down.
- **Tripo "Bear warrior" (Drive 13_LAB19..., studio-rigged, 60 joints): its export is BROKEN** - every joint node has an identity
  transform and the inverse-bind matrices are in another (z-up, offset) frame, so the skin tears into shards in Godot AND Blender.
  Fix (2026-10-10): ignore its rig. `decimate_textured.py --faces 45000` (stops ~46.7k: UV seams), then
  `retarget_bull.py src/episode2/assets/bear_rigged.glb <decimated> out.glb --rifle-dist 99` (both T-pose, core fit 3.1 cm) and write
  it OVER `bear_rigged.glb` (old Meshy copy in `.farm/retired/`): every bear (woods + runner) becomes the Tripo bear with all Meshy
  clips. The clips are an archer's (arms out round a bow): `Ep2BearArmsDown` (src/episode2/actors/) lowers the empty arms.
# Slots
Rifle wUN2J2, Helmet tVC8jD, Whiskey LKhotS, Bitcoin oLKt9Y (done). Inferno Bull (Tripo minotaur GLB) and the bear archer are in. Lil Blunt stays as he is (founder 2026-10-03). Never paste a key anywhere.
