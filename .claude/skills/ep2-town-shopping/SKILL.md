---
name: ep2-town-shopping
description: Townspeople who go into the walk-in shops, buy and come out carrying it (founder 2026-10-24 "people in the town have real activities. perhaps some entering the stores and leaving. buying things"). The shop-visit errand in Ep2TownPeople - reservations, scripted porch/door/counter legs with heights, the parcel, danger and save rules. TRIGGER on "people go into shops", "buying", "shoppers", "carry a parcel", or adding an indoor activity to the town cast.
---

# Shopping errands

- `Ep2TownPeople._choose`: an "errand" becomes a shop visit (`_start_shopping`, SHOP_CHANCE 0.55) when a counter is free (`reservations["shop:<piece>"]`); children skip the assayer.
- Street graph to `shop_spots.out` (foot of the porch steps), then `_enter_shop`: `folk.use_height = true`, `walk_path([porch, door, counter])` with `shop_floor_y` heights -> "shop_in" -> "shop_buy" (face the keeper side, Inspect, 4-8 s) -> general store attaches a paper parcel to RightHand (`attach_prop`), "shop_out" back to `out` -> `_leave_shop_done` (height off, reservation released). Parcel dropped after PARCEL_SECONDS.
- Indoors is safe: `_seek_safety` returns early for SHOP_STATES (danger/duel). Snapshot saves a shopper standing at `out`, state pause - never inside a wall.
- Navigation stays outdoor-only (Ep2TownNavigation blocks buildings + porches); the indoor legs are scripted straight lines through the door gap.
