---
name: gm-game-location-continuity
description: Keep the lift window and playable forest in one visual location, with shared scenery generation and an explicit pose mapping through the doorway.
---

# One doorway, one location

Never build an independent stylized forest just for a lift window. WoodsQuadChamber.build_surface_vista reuses gameplay material, floor, trail, forest-chunk and bridge builders for only the three near slices. No town, bear brains, player rig or quad is created for this vista. Keep deterministic seeds and placement identical to the playable woods. Preserve founder assets.

MineLiftChamber.SURFACE_OFFSET maps woods coordinates to the lift: (0, TOP_Y, 2). The lift mouth z=6 and woods mouth z=4 are the same doorway. Lift EXIT_Z=8 maps to woods z=6; never reset a continuing player back to the standalone SPAWN at z=2.

At handoff, carry exact player position minus the offset, Bull position minus the offset, yaw and pitch. The standalone woods/retry spawn remains unchanged. Let a ready player cross the threshold while Bull walks; do not gate on his whole exit show. Retain the actual prebuild-readiness guard.

Switch to the woods environment/sun before the doorway cut. Keep the warm mine interior below and the first-person weapon visible. Compare both player views at the mapped coordinates, including side/backward looks. Check multimesh transforms, source meshes/materials, eye pose, lighting and bridge alignment. Sharing a filename alone is not proof. Inspect actual Compatibility-rendered frames; disclose any unverified view.

Run transition_feedback_test plus ep2_interlude_test and session-root gates. Changes to this mapping must update both sides, deterministic checks and before/after captures together.

The preview floor starts at woods z=4, outside the mouth, and omits the standalone LiftPad. Never draw the full gameplay floor across the lift shaft: the cage must rise through an open shaft. The transition-feedback gate checks that opening.
