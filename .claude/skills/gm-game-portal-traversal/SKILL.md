---
name: gm-game-portal-traversal
description: Keep Protocol Portal rooms freely walkable - lounges enterable, no pinch points, no cramped clusters beside empty space. TRIGGER when the founder says Lil Blunt is restricted/blocked/can't enter/can't pass a point in an education room, or that props are cramped while the map is wide open.
---

# Portal traversal (founder 2026-09-30)

Walkable space = `RoomLayout.GROUND[protocol]` polygons (union). The map painting is the truth; the polygons follow it.
1. Doorways/interiors the painting shows (Smoke: main lounge door, west + east pergola lounges) get their own
   polygon overlapping the plaza by 40+ px. Never leave a painted room unwalkable.
2. Every seam between polygons needs a **wide overlap** (>= 120 px). A narrow lobe is a pinch point the
   player snags on (Diamonds bridge -> plateau). Add a junction polygon instead of nudging vertices.
3. Overlay polygons + stops on the map with PIL (room y = image y - 50) and look for gaps before shipping.
4. Space stops by half-widths (see `gm-game-portal-prop-integration`); use the whole walkable area, and
   keep each base >= 70 px from a lip.
5. Verify: `tests/portal_room_test.gd` (A* reaches every stop) + capture overview.
Player and advisor share `constrain_to_ground`; education falls were withdrawn by the founder. Run `tests/portal_traversal_test.gd`: collision-aware routes must be walked with actual inputs, every station must respond to E, and the advisor must keep up. Never count a teleported interaction or a point-only path search as proof of traversability.
