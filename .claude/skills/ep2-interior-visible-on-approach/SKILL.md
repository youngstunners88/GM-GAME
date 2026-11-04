---
name: ep2-interior-visible-on-approach
description: The rule that a room behind an open door is already furnished, lit and peopled on approach, never only after the player crosses a trigger or a chamber hand-over. Covers the certificate office bug (the woods chamber's copy of the town had no interiors), how to find the real cause from the founder's screenshot, and the gate. TRIGGER on "contents of the office need to be visible", "walks in to make things appear", "pop-in at the door", "empty room until I enter", any new enterable building, any chamber that draws another chamber's street, or Ep2GoldTown.build's `interiors` argument.
---

# Interiors are visible on approach

**The rule:** whatever is behind an open door is there before he reaches it. Furniture, lamps, wall dressing and the people standing inside are
visible from the street, from the doorway and through the threshold with no change. Never gate a room behind a walk-in trigger, a beat or a
chamber swap.

## How the certificate office broke (founder 2026-11-04, "I've told you many times")
The town chamber was correct and every capture of it looked fine. The founder was not in the town chamber:

- After the drop-off, Lil Blunt walks in the **woods chamber's copy of the town** until Inferno has ridden out of sight (`woods_quad.gd`,
  `_dropoff_done` then the `next_chamber: gold_town` cut).
- That copy called `Ep2GoldTown.build(_visuals, false)`: walls and an open door, but no furniture, no lamps, no people.
- So the room looked empty and dark, then filled up at the hand-over, which usually happens as he reaches the door. It looked like walking
  in was the trigger.

**The clue was in his screenshot:** the objective read "Get the sheriff to sort you a certificate", and that string exists only in `woods_quad.gd`.

## Find the real cause first
1. Read the words on the founder's screen, then `grep` them. They say which room and beat he was in.
2. Capture that room, not the one you expect: `tools/ep2_shots/shipment_bears_shot.tscn` takes `mode=woods` for the drop-off town.
3. Compare one eye-level ladder (street, steps, doorway, threshold, inside). A capture of a different chamber proves nothing.

Earlier false lead, for contrast: on 2026-10-29 the jail's pop-in really was a door leaf in the walking lane (`ep2-doorway-route-presence`).

## Doing it right
- Any chamber that draws the town calls `Ep2GoldTown.build(parent, true)`. `interiors = false` remains only for tests of the bare street.
  Measured on the pod: the two builds cost the same, about 105 ms once the kit is loaded.
- Dress that does not live in `build()` goes through a static builder both copies call: `GoldTownChamber.build_license_wall`,
  `GoldTownChamber.build_office_stand_ins`. Stand-ins use the same models, marks and facing as the live cast, so the hand-over shows no change.
- A new enterable building needs a lamp in `_furnish`. An unlit room reads as empty from the street.

## Gate
`tests/ep2_interior_visible_test.tscn` (in CI): the woods copy and the town both hold the office's pieces and its lit lamp, the Sheriff and Mike
Dean stand where the town chamber will show them, and the old objective text is gone. Add any new enterable room here.
