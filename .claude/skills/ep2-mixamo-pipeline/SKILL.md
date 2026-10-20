---
name: ep2-mixamo-pipeline
description: Use Mixamo with the game's humanoids - download Mixamo animations (FBX) from the terminal with the HaD0Yun/unity-mcp-mixamo client, retarget with the tdw46 "Mixamo Rig" Blender extension or tools/ep2_motion/retarget_bvh.py, and generate high-quality humanoid meshes on Runpod (Hunyuan3D 2.1) for rigging onto a Mixamo skeleton. TRIGGER on "Mixamo", "humanoid animation", "download animations", "retarget", "rig a new character", "Hunyuan", "Runpod character", or before building a new human NPC that needs real clips.
---

# Mixamo + humanoids (founder 2026-10-20: "I heard it works well for humanoids")

## What each repo is (checked 2026-10-20)
- `~/tools/unity-mcp-mixamo` (HaD0Yun, MIT): a standalone MCP server/client that downloads Mixamo animations as FBX. Unity is optional (only a helper
  package). It authenticates with the account's Adobe `access_token`. Wrapper: `tools/ep2_motion/mixamo_dl.py` (status | search | get).
- `~/tools/mixamo_blender4-main` (tdw46, Blender 4.2-5.5 extension "Mixamo Rig" 1.2.2): builds a control rig from a Mixamo armature and imports/bakes Mixamo
  animations onto it (operators `mr.make_rig`, `mr.import_anim_to_rig`, `mr.bake_anim`, `mr.export_gltf`). Packaged and installed here:
  `blender -b --command extension build --source-dir ~/tools/mixamo_blender4-main --output-dir <d>` then
  `blender -b --command extension install-file -r user_default --enable ~/tools/mixamo-dist/mixamo_rig-1.2.2.zip` (verified: operators register in 5.2.1).

## The credential rule (hard)
The token is a login credential. Never paste it in chat, never commit it, never print it. The founder writes it ONCE, privately, in his own terminal:
`mkdir -p ~ && read -rs -p "Mixamo access_token: " T && printf %s "$T" > ~/.mixamo_mcp_token && chmod 600 ~/.mixamo_mcp_token && unset T`
(get it on mixamo.com signed in: DevTools Console `copy(localStorage.access_token)`). Then:
`uv run --quiet --no-project --with httpx --with pydantic python tools/ep2_motion/mixamo_dl.py status` (exit 0 = valid, 2 = missing/expired).
Without a token, use the CMU mocap path (`ep2-runpod-motion-lab`, `tools/ep2_motion/retarget_bvh.py`) - it needs nothing.

## Using Mixamo clips on a game humanoid
- Mixamo skeleton names are `mixamorig:Hips ... mixamorig:LeftHandIndex4` (65 joints with fingers); Utah (Tripo, Mixamo rig) already uses them, so
  a Mixamo FBX retargets by bone name (`retarget_bvh.py` already maps `mixamorig:` rigs; for an FBX source import with `bpy.ops.import_scene.fbx`).
- The on-box townfolk (build_armory_folk.py skeleton: Hips/Spine/Chest/UpperArm...) need a name map to `mixamorig:*` first; add it to the retargeter
  rather than renaming the rig.
- Download "without skin" at 30 fps; one clip per file; keep them in `~/tools/mocap/mixamo` (never in the repo; licence = Adobe Mixamo terms, free
  for use in games but not redistributable as a library).
- Gate every clip with `ep2-character-motion-qa` frames and the skin-stretch check before it ships.

## High-quality new humanoid (Runpod)
Existing pipeline: Hunyuan3D 2.1 on a Runpod pod (`tools/ep2_runpod/hunyuan/`: install.sh, gen.py, paint_*.py; skill `ep2-gpu-character-regenerate`).
1. Reference image: a clean T-pose front view (founder art, or a render of the on-box figure for a consistent look).
2. Pod: the stopped A40 `pqcfms6z98llt8` ($0.59/h, 60 GB volume) or a new 4090/A40 (`ep2-runpod-motion-lab` money rules). Tripo/Meshy have no credits here
   (Tripo balance 0 on 2026-10-20), so Hunyuan is the generator.
3. Mesh -> `tools/ep2_motion/prep_folk.py` (scale, decimate, 1K textures) -> rig onto a Mixamo-named skeleton (bind with
   `~/.claude/skills/blender-character-rigging/scripts/bind_mesh.py`, proxy weights) -> clips (Mixamo or CMU) -> `export_folk.py` -> streamed extras.
4. Check against the street/jail in the real renderer (`tools/ep2_shots/*`); stylised on-box people are the fallback that ships.

## Not possible without the founder
Mixamo downloads and Mixamo's own auto-rigger need his Adobe sign-in (browser upload of a mesh is manual).
