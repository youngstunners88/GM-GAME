---
name: ep2-handoff-props
description: The Winchester 1886 and the miner helmet are real hero meshes, separate from every body, used on the rack, in the hand-off, on Lil Blunt's head and as the first-person viewmodel. TRIGGER on "rifle/helmet looks cheap/trash/blocky", any edit to winchester_1886.glb, miner_helmet.glb, RIFLE_*/HELMET_* constants, or the FPS viewmodel.
---
# Source of truth
`python3 tools/ep2_forge/make_handoff_props.py` regenerates both GLBs (welded, smooth, PBR factors, no Meshy credits). The rifle is 1.2 m, muzzle +Z, stock -Z, centred; the helmet's base is y=0, lamp +Z, brim radius ~0.325.
# Rules
- Look at `node scripts/glb-shot.mjs <glb> sheet.png` BEFORE wiring: loose parts (the old rifle's stock floated off) are the usual defect.
- Meshy on these two props only if the balance allows and the generated mesh beats the script's; never fuse them to a hand.
- Hand-off uses `holder("RightHand")`; FPS reparents the rifle to the camera (lower right, `FPS_RIFLE_POS`) and hides Lil Blunt's own body and helmet.
