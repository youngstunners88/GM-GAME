# 003 — Rig Armature scale trap (VERIFIED)

`bear_rigged.glb` has an Armature node with a 0.01 scale; `lil_blunt_rigged.glb` does not.
A skinned MeshInstance's own AABB is already in metres, so measuring through the node chain
(`_rel_xform * mesh.get_aabb()`) read the bear as 0.018 m tall and scaled it ×130 — it rendered
far above the scaffold, invisible, while its headlamp (a separate node) sat where the head should be.
Fix: `RunnerView._measure_rig()` uses `mi.get_aabb()` directly. Gate: the motion test asserts every
rig scale is within 0.5–5.
