---
name: ep2-bull-debug-mesh
description: No debug box, crate, IK target or collision mesh may render on (or follow) Inferno Bull in a shipping build. TRIGGER on "a box follows Bull", any node parented to Ep2Actor / the Bull rig, any new prop added in _build_bull, or before shipping any change to ep2_actor.gd / smelting_facility.gd.
---
# The bug (founder 2026-10-02)
"A box follows Inferno Bull." Cause: `BullSeat`, the crate he sits on, was `reparent`ed to `_bull`, so when he stood and walked the crate walked with him.
# Rules
1. Scenery goes on `_visuals` (the room), at a WORLD position. Only these may be children of the Bull actor: his rig, glass (holder), cigar tip, ember particles.
2. IK targets/poles are vectors in `Ep2ArmIK`, never nodes; if a marker is needed, no mesh.
3. Gate: after a change, walk capture (`tools/ep2_shots/show_shot.tscn`) frames 4-6: nothing but Bull moves.
4. Test: facility test asserts `_bull` has no MeshInstance3D child outside the rig model/holder/glass/cigar/embers.
