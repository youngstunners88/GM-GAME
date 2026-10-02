---
name: ep2-bull-handoff-walk
description: Inferno Bull's hideout performance - he walks to the gun wall, takes the Winchester off its rack, walks to Lil Blunt and hands it over; same with the helmet; 1 BTC deal; bear-hunt line; leave together. TRIGGER on any complaint about Bull's movement, "oil patch", arm waving, whiskey, speech speed, or edits to facility_show.gd / ep2_actor.gd / ep2_arm_ik.gd / smelting_facility.gd.
---
# Architecture
- `Ep2Actor` (src/episode2/actors): rig + walk/run clips, `walk_to`, `face_point`, `reach`/`release` (2-bone IK via
  `Ep2ArmIK`), `holder(bone)` = metre-scaled prop parent (Meshy skeleton scale is ~0.0121).
- `FacilityShow` (chamber/facility_show.gd): data-driven beats `steps_for(beat)`; the room only supplies props.
# Rules
- Never teleport a prop: it leaves the rack in his hand, rides the walk, and lands in Lil Blunt's hand.
- Idle is a breath. Arms move only for sip / grab / offer.
- Materials: matte non-metal (`_fix_bull_materials`) - Meshy drops the metal-rough map, glTF default metallic=1 = "oil".
  Keep rim/emission LOW or he reads as a pale ghost.
- Whiskey: separate glass node on the table and in his hand (`GLASS_IN_HAND_POS`), never inside the rifle mesh.
- Voice: ElevenLabs speed 1.08 for Bull (0.8 was the "too slow" bug). Lines: intro (Inferno Bull, out of Blaze), rifle,
  helmet, 1 BTC for both (coin visibly leaves Lil Blunt; `btc_paid` is a ledger line, mints nothing), bears have the
  Gold Mine, partnership -> Fort Knox. No Diamonds mechanic.
# Gate
`tests/ep2_smelting_facility_test.tscn` + `tools/ep2_shots/show_shot.tscn` (14 moments) read by eye.
