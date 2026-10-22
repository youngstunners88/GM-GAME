---
name: ep2-jack-hammer-character
description: Build, fix or re-skin the Jack Hammer (Jackson Mccree) character model - mean, eye patch - end to end (SDXL pose-guided reference, Hunyuan body + separate head scan on Runpod, rig_scan_character head swap / eye patch / boots, streamed extra, engine shots). TRIGGER on "Jack Hammer model", "Jack Hammer look", "eye patch", "make him meaner", "re-do his face", "Jack Hammer in the town", or any edit to extras/people/jack_hammer.glb or rig_scan_character.py.
---

# Jack Hammer, the model (founder 2026-10-21: "make him mean with a patch eye")

Narrative lives in `ep2-jack-hammer-narrative`; this skill is only the body. Shipped: `src/episode2/extras/people/jack_hammer.glb` (`Ep2Extras.JACK_HAMMER`), streamed, 1.92 m with the hat,
townfolk skeleton + Idle/Walk/Greet/Point/Carry (so `Ep2TownFolk.setup(Ep2Extras.JACK_HAMMER, Ep2JackHammer.HEIGHT_M)` drives him). Evidence + the full recipe: `design/ep2/jack_hammer/character-2026-10-21/README.md`.

## Rules
1. The look is the founder's call: **mean, eye patch (his left eye)**. Everything else (scar, coat, stubble) is a proposal - say so, never bake in a sledgehammer or tooth he did not ask for.
2. Gate: `tests/ep2_jack_hammer_character_test.tscn` (EP2_JACK_HAMMER_CHARACTER). Grade the look with `tools/ep2_shots/jack_hammer_shot.tscn` in the real renderer, not a Blender preview.
3. Streamed extra rules apply (`ep2-streamed-extras-web`): pinned 4.3 `.import` files, created from an existing people/folk template (path hash = md5 of the res:// path), `git add -f` the `.import`s and the extracted `jack_hammer_textured_mesh*.jpg`.
4. Local godot is 4.7 and rewrites tracked `.import`/`.uid` files: restore them (`git ls-files -z -m | grep .import | xargs -0 git checkout --`) before committing.

## Pipeline (what worked; ~1 h, ~$0.6 on an A40, terminate the pod after)
1. Pose guide: render the on-box figure (`tools/ep2_blender/build_jack_hammer.py --shots`), paint a patch on it. SDXL img2img (`tools/ep2_runpod/hunyuan/jack_ref.py <strength> <n> <seed> <tag>`): 0.62-0.66 keeps A-pose AND patch, 0.72+ loses the patch. Fill 93 % of the frame height so the face is big.
2. Pick one, `jack_chain.sh` (Hunyuan shape octree 384 -> 60k -> PBR paint). Paint needs `patch_bpy.py` and `sed 's/simplify_quadric_decimation(target_count)/simplify_quadric_decimation(face_count=target_count)/'` on the pod.
3. The body scan's face is mush (a 60 px face). Crop the pick's head, SDXL img2img up to 1024 (`jack_head_up.py`, strength 0.45), Hunyuan shape octree 512, paint.
4. `blender -b -P tools/ep2_motion/rig_scan_character.py -- --obj body.obj --albedo body.jpg --height 1.92 --tris 14000 --tex 1024 --head-obj head.obj --head-albedo head.jpg --head-tris 9000 --head-tex 1024 --head-tone 0.62 --eye-patch --boots --out jack_hammer.glb --debug dbg/`.
   The patch is PAINTED into the head albedo by ray-dropping reference pixels onto the real surface (landmarks are pixel positions of a 900 px render 0.9 m in front of the face); a modelled 3D patch intersected the scan and read worse.

## Traps paid for
- Jupyter `dl.py` hangs on multi-MB files: make a small JPEG/tgz on the pod first. `pkill -f <text>` kills your own shell when `<text>` is in the command.
- SDXL with no guide gives sepia 1880s photos with hats and no patch; the guide image is what carries the patch.
- Godot reuses extracted texture JPGs: delete `jack_hammer_textured_mesh*.jpg` (+ `.import`) before re-importing a rebuilt GLB.
- Hat shadow hides the face at noon: judge the face from the `3_face_meeting` shot and the flat-lit Blender shot together.

## Open (founder's)
Voice; whether he carries a sledgehammer (the name suggests it); a hat with a crown he likes better (the scan's is irregular); a second look for the auction (cleaner coat).
