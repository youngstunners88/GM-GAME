---
name: ep2-saloon-drinkers
description: People drinking in the GoldMine saloon and on its balcony (founder 2026-10-24 "sitting and drinking in the saloon as well as the balcony above") - the Ep2DrinkPose clips built from each townsperson's own rig, saloon visits (aisle-side table chairs, places at the bar), the two balcony regulars, single-file doors and waiting slots. TRIGGER on "drinking", "saloon patrons", "balcony", "sit at a table", "whiskey glass", "seated pose", adding a sit/drink/lean pose to the town cast, or townspeople walking through each other indoors.
---

# Saloon drinkers

## Pose (no model re-export)
`Ep2DrinkPose.install(player, skel, fwd, up, unit, seated)` (src/episode2/actors/ep2_drink_pose.gd) builds `SitDrink` / `StandDrink` from the
rig: bones aimed by shortest arc in the character frame (fwd/up IN SKELETON SPACE), a two-bone reach for the drinking arm (table/chest ->
mouth), keyed at BEATS and looped (6.4 s per sip). Added to the player's "" library at runtime; `Ep2TownFolk.play_clip` finds it by name.
- Character right = `fwd.cross(up)` (facing +z with +y up is -x). Spine forward = `Basis(right, -angle)` (positive tips it BACK).
- Captures must `advance(clip_blend + 0.05)` before `seek()` - manual seeking does not finish a cross-fade (a half-blended frame looks standing).
- The glass: `attach_prop` resets the held node's scale, so the tumbler GLB (unit height) is scaled 0.1 INSIDE a "Glass" holder.

## Places (`Ep2GoldTown.saloon_seats()`)
Aisle-side chair of each of the three tables (kind "table", seated), four places at the bar (kind "bar", standing), two at the balcony rail
(kind "balcony", standing - a seated head is below the 1.3 m rail and invisible from the street). Each has `approach` and a `route` from the
door down the aisle; a back table is reached along the bar's walking row (0.75 m clear of anyone at the bar).

## Traffic (Ep2TownPeople)
States shop_queue -> shop_in -> shop_buy -> shop_leave_wait -> shop_out. One person walks between street and place at a time per building
(`door:<piece>`); visitors wait at their own slot along the front (`slot:<piece>#k`, SLOT_OFFSETS 1.3 m apart). Saloon places are reserved
per seat (`shop:Bldg_Saloon#<i>`). BALCONY_REGULARS (grandfather, oldtimer) are seated at build and never leave. Indoors is safe in a danger;
a queuer outside abandons the visit and shelters. Save/restore carries shop, seat, slot, height, legs, parcel; overlaps are height-aware
(the balcony is above the porch); restore tolerates 2 cm at a prop edge (`is_standing_clear`).

## Proof
`tools/ep2_shots/saloon_shot.tscn` (balcony from the street, table and bar drinkers at rest and mid-sip). Gates: ep2_town_autonomy_test,
ep2_town_people_test, ep2_gold_town_test.
