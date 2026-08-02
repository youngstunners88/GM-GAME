# Qwen — static review: facing, camera clamps, Blaze Rush exit targets

No screenshots this session. Do the static review. For each file below, list
the specific nodes/lines that could cause: WRONG BOSS FACING (scale.x flips
not tracking the player), CAMERA CLAMP mismatches (limits not matching level
bounds), or BLAZE RUSH EXIT going to the wrong level. Output a concise
bulleted list of concrete risks with file:line, most-likely-cause first.
No fixes needed — just the risk map for the implementer.

## Files
@include src/boss/auditor.gd
@include src/dashmode/blaze_rush.gd
@include src/dashmode/blaze_portal.gd
