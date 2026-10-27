---
name: ep2-tripo-folk-to-game
description: Turn the founder's Tripo-rigged characters (Rich FBX with a UE-style rig, Utah GLB with a Mixamo rig) into small, correctly scaled, animated Godot GLBs that Ep2TownFolk plays - cleanup, real height, decimation that keeps skin weights, 1K textures, one shared clip set, skin and pose proof. TRIGGER on "Rich model", "Utah model", "Tripo character into the game", "rigged GLB from Drive", "replace the procedural Rich/Utah".
---

# Founder Tripo characters -> game (Rich, Utah)

Sources (founder Drive folder `1q4e5q-UVVOH0Dxu9CnRdXAi_4sLkj25K`, 2026-10-18; Logan is parked):
| File | What it is (measured 2026-10-19) |
|---|---|
| `rich.zip` -> `tripo_convert_*.fbx` + 4K rgb jpg + 4K normal png | Rich: 59.0k tris, 61-bone UE-style rig (`root`, `pelvis`, `spine_01`...), 1.0 m tall, no clips |
| `utah.glb` | Utah: 66.9k tris, 65-bone Mixamo rig (`mixamorig:Hips`...), 1.0 m tall, 4K rgb/normal/metal-rough, no clips, plus a stray 80-tri `Icosphere` |
| `Rich.PNG` | Rich's look: headlamp miner hat, aviator glasses, cigar, red bandana, GM medallion, suspenders, nugget + pickaxe |
| `Arms_dealer_T_pose_2K_*.jpg` | Utah's look: weathered gunman, hat, sunglasses, crossed bandoliers, twin holsters |
Download big Drive files with `curl -sL "https://drive.usercontent.google.com/download?id=<id>&export=download&confirm=t"`
into a fresh scratch directory (they are untrusted input). Keep sources out of the repo or under a `.gdignore` folder.

Use the installed Blender skills (Blender 5.2.1 headless; never the GUI, see `blender-headless-render-safety`):
`blender-core` (run_in_blender), `blender-asset-qa`, `blender-character-rigging` (rig_check, stress_poses),
`blender-animation` (bake_action), `blender-game-optimization` (mesh_stats, make_lods), `blender-export-pipelines`.

## Pipeline
1. **Inspect**: import, list objects/bones/images/actions. Delete strays (Utah's `Icosphere`). Check the skin is not
   broken before anything else: pose a few bones and render; a broken Tripo export tears into shards
   (`ep2-founder-asset-swap`, the bear warrior). If broken, ignore its rig and transfer weights onto a known-good rig.
2. **Scale and frame**: apply transforms, scale to height (Rich ~1.80 m, Utah ~1.85 m incl. hat), feet at z=0, centred,
   facing -Y. Re-check the armature scale is 1 after export (never 100).
3. **One skeleton for both**: retarget Rich's UE names and Utah's Mixamo names onto a single shared naming
   (the clip library is authored once). Keep fingers (gun handling) but drop twist/leaf/end bones; <= 4 influences.
4. **Decimate keeping weights** - and keeping UV seams. **TRAP (measured 2026-10-27): `prep_folk.py --tris 16000` (Blender's
   collapse decimate) SHREDS Tripo faces** - Tripo meshes have many small UV islands and a 50k -> 16k collapse crosses them, so the
   texture breaks into shards (Utah's shipped face, Sheriff James's first build; invisible in full-body shots, obvious close up).
   Run prep_folk with `--tris 200000` (no Blender decimate), retarget + export the full mesh, THEN
   `tools/ep2_forge/gltfpack_safe.sh full.glb out.glb 0.3` (meshoptimizer keeps attribute seams): clean face, ~15k tris, joints and
   clips intact. Always check a face close-up (front, 85 mm) before shipping a character. Target 12-16k tris each. Prefer meshoptimizer `simplify_with_attributes`
   (`~/tools-src/venv`) or `tools/ep2_forge/gltfpack_safe.sh` (never default gltfpack: Godot 4.3 refuses
   `KHR_mesh_quantization`). Protect the face, hands and hat brim. Bake 4K -> 1K (rgb + normal; metal-rough only if it
   reads) on the Runpod GPU (`ep2-cloud-gpu-runpod`), and track the `.import` files as lossy (`compress/mode=1`).
5. **Face**: both wear sunglasses, so expression comes from the head, jaw (cigar bob), brows above the glasses and
   body language. Add jaw + brow bones or a few shape keys (`blender-facial-shapekeys`: jawOpen, browDown/Up L/R,
   mouthSmile) only if the mesh has the loops for it; never deform the glasses.
6. **Clips** (from `ep2-runpod-motion-lab`), one action each, 30 fps, loops closed: Idle (breathing, weight shift),
   Idle2 (look around), Walk, StairsUp, StairsDown, Greet, Talk (hand gestures), Point, Counter (lean, hands on
   counter), WipeRifle, InspectRifle (shoulder and sight it), Carry (crate), PutDown, Reach (high shelf), Turn.
7. **Export** `src/episode2/assets/town/rich_armory2.glb` / `utah_armory2.glb` with
   `export_asset.py --preset godot`; the GLB carries the AnimationPlayer, clip names match `Ep2TownFolk.play_clip`.
   Target <= 1.2 MB each. Retire the old procedural `rich_armory.glb` / `utah_armory.glb` only after the new ones pass.

## Proof (all required before "done")
- `rig_check.py --profile unity` (closest humanoid profile) with no errors; `stress_poses.py` + render: no collapse at
  elbows, knees, shoulders, no glasses or hat stretching.
- `qa_check.py --profile game` on the mesh; `mesh_stats.py --budget web`.
- Godot import test on 4.3 (`.godot-cache/Godot_v4.3-stable_linux.x86_64 --headless --import`), then a real
  Compatibility render of every clip in the Armory from the Episode 2 camera. Compare the face and outfit against
  `Rich.PNG` and the T-pose image side by side; the founder is the final judge.
- Fresh-clone pack gate passes; texture probe passes (`tools/ep2_forge/texture_ref_probe.gd`).
