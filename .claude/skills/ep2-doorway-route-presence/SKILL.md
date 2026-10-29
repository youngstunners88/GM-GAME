---
name: ep2-doorway-route-presence
description: Diagnose and prevent sheriff-office doorway pop-in and the lake road appearing only on mount. Require continuous views and shared survey/geometry before and after the story boundary.
---

# Visible before crossing

Use ep2-world-presence-and-consumables, ep2-town-proof, gm-game-episode2-town-windows-doors and gm-game-location-continuity.

- Capture the real jail/sheriff doorway from the yard, threshold, first interior step and deeper room; also check Certificates to avoid confusing the two buildings. Keep eye height, look, environment, props and characters comparable. Inspect meshes, opening/leaf geometry, world transforms, AABBs, materials, near plane and any visibility switches. Establish the actual cause; do not invent a distance-culling rule when none exists.
- A player approaching an open room must see its existing furniture and people through the physical opening. Door leaves may occlude naturally, but a doorway-sized hidden slab or late whole-room activation is unacceptable. Preserve side/back walls, collision and the law/cell gates.
- The lake trail is already a surveyed path relative to `GoldTownChamber.DEPART_HORSE`. Show the same near road/terrain on foot at Dude's ranch and while mounting; use a shared builder/coordinate mapping. Do not add a separate approximate strip that will move or change at handoff.
- Inspect mounted/unmounted approach, lateral/backward views, reverse travel, retry and streamed extras readiness. Keep bandits, forest/lake transition, map marker, story order and the purchased horse intact.
- Add regressions that fail on the reproduced cause and real Compatibility/WebGL captures on both sides. Geometry declarations or prebuild readiness alone are insufficient.

## Verified repair lesson

The 2026-10-29 reproduced cause was the jail leaf at 69 degrees crossing x=-0.4 inside the allowed walking lane, not whole-room culling. Preserve the 100-degree authored opening and the three-lane mesh-ray plus solid-wall control. Use one shader/material survey across mounting; reject asphalt-gray strips from the actual camera.
