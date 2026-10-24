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

## Transition 2 follow-up

Clear the shaft-front brace at TOP_Y+1 before the surface gate opens; characters must not pass through timber. Check the actual doorway from INSIDE the cage, not only after crossing it.

The input router forwards held keys only on changes. A seamless handoff must retain move/run input, moving state and walk/bob phase before the first draw, and the next physics tick must keep advancing without a new key press. Test the real session root with Input.action_press held across the swap, release it afterwards, and verify immediate stop. Preserve sideways/backward/diagonal inputs too.

Carry Inferno's facing and walk phase and select the next trail point AHEAD of his mapped position. Never replay the standalone first waypoint behind him or reannounce the woods walking introduction. Build wildlife/ambience resources during prebuild; start their audio only on activation. Native and web captures must distinguish a held-input stop from a renderer stall; record actual handoff/frame times without screenshot I/O in those timing samples.
