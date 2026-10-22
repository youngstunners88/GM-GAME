# Jack Hammer - the character (founder 2026-10-21: "create Jack Hammer and make him mean with a patch eye")

Shipped model: `src/episode2/extras/people/jack_hammer.glb` (`Ep2Extras.JACK_HAMMER`, streamed in `ep2_extras.pck`), 1.92 m with the hat, rigged on the townfolk skeleton
with the five clips (Idle, Walk, Greet, Point, Carry). Gate: `tests/ep2_jack_hammer_character_test.tscn`. Skill: `ep2-jack-hammer-character`.

Pipeline that made it (all on a Runpod A40, ~1 h, ~$0.6, pod terminated):
1. `pose_guide.png` - a render of the on-box procedural figure (`tools/ep2_blender/build_jack_hammer.py`) with a patch painted on; SDXL img2img at strength 0.66
   (`tools/ep2_runpod/hunyuan/jack_ref.py`) turns it into a real man and keeps the A-pose + the patch (0.72+ loses the patch). `body_ref_sheet.jpg` = the 8 candidates; the pick is `ref_fullbody.jpg`.
2. Hunyuan3D-2.1 shape + PBR paint of the body (`jack_chain.sh`; the paint step needs `patch_bpy.py` and the trimesh `face_count=` fix).
3. The body scan's face came out smeared (a 60 px face), so the head is a SECOND scan: the head crop of the pick upscaled by SDXL img2img (`jack_head_up.py`, `head_ref_upscale_sheet.jpg`),
   Hunyuan shape at octree 512, painted.
4. `tools/ep2_motion/rig_scan_character.py --head-obj ... --head-albedo ... --head-tone 0.62 --eye-patch --boots`: cuts the body's head at the collar, grafts the head scan on the Head bone,
   paints the leather eye patch + straps into the head albedo by ray-dropping reference pixels onto the real surface (the scan's own patch was a smear), desaturates the hot skin, models boots over the flat-cut trousers.

Evidence: `1_full_front.png` .. `4_face_close.png` are the real Compatibility renderer in the town's desert light (`tools/ep2_shots/jack_hammer_shot.tscn`); `blender_face_flatlit.png` is the face without the hat's shadow.

Design calls that are MINE, not the founder's (he judges): his left eye is the patched one; weathered, scarred-looking, stubble, long black coat, black hat, dark red shirt; no sledgehammer yet.
Known weaknesses: the face reads best close up; the hat crown is irregular; clip stress (Greet) pulls the coat tails a little; boots are simple blocks.
