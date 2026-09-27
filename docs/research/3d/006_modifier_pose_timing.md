# 006 — SkeletonModifier3D pose timing in Godot 4.3 (VERIFIED)

A `SkeletonModifier3D` (`_process_modification`) runs after the AnimationPlayer, but reading
`get_bone_global_pose()` from `_process` returns the pose WITHOUT the modification: inside the
modifier the aimed arm measured dot 1.00 toward the target, from a test's `_process` −0.54.
Read modified poses in a `skeleton_updated` callback (that is what BoneAttachment3D does).
`RunnerView._place_weapons` puts the revolver/pickaxe on the hands there.
