---
name: gm-game-portal-ledge-fall
description: Real drops in Protocol Portal rooms - the player may walk off a bridge/cliff and loses a life, the advisor/governor never does. TRIGGER when the founder wants freedom on bridges/ledges, falling, lives in education rooms, or says the advisor must not die.
---

# Ledge falls

- `RoomLayout.FALL_MARGIN[protocol]` (px) enables it (Diamonds 46). 0/absent = hard walls.
- `StudyRoom.constrain_player()` lets the player overhang the ground by the margin; `PortalExplorer._check_fall()`
  starts a fall after 0.28 s off-ground (drop + fade), then `GameManager.lose_life()` and respawns at the last
  safe spot. On the LAST life it only respawns (a classroom never wipes the run).
- The advisor (`Companion`) keeps using `constrain_to_ground()`: hard-clamped, cannot fall.
- Scripts referencing the layout must `preload` it (`const Layout := preload(".../RoomLayout.gd")`); RoomLayout has no class_name.
- Verify: `Layout.overhang(protocol, p)` > 0 outside, 0 inside; capture the ledge; run portal_room_test.
