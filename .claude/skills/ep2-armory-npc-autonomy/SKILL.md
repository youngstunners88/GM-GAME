---
name: ep2-armory-npc-autonomy
description: Give Rich and Utah believable autonomy inside the two-storey Armory - daily-work routines across both floors and the stairs, reactions to Lil Blunt (notice, turn, greet, serve), no lock-step, no walking through counters, deterministic for tests. TRIGGER on "good autonomy", "Rich and Utah working in it", "NPCs just stand there", "make them do things", "shopkeeper behaviour".
---

# Rich & Utah autonomy (founder 2026-10-19: "move properly with detailed movements and good autonomy")

Body: `Ep2TownFolk` (`src/episode2/actors/ep2_town_folk.gd`) already loads a rigged GLB, walks along a path, turns to
face, and plays named clips (`play_clip`). Build the behaviour as a small brain on top of it, not a new actor class.
Building and spots: `ep2-armory-two-story`. Clips: `ep2-runpod-motion-lab` + `ep2-tripo-folk-to-game`.

## Design
- **Waypoint graph, not free navigation**: named spots measured in the Armory's local frame (door, counter_front,
  counter_rich, case_revolvers, rack_left, rack_right, bench, stair_bottom, stair_top, gallery_rack, gallery_crates,
  gallery_window, storeroom). Edges only where a person can walk; the stair edge plays StairsUp/StairsDown and moves
  y along the stair. A* over ~15 nodes is enough and is deterministic.
- **Utility-picked tasks with personality** (seeded RNG per NPC, so tests are repeatable):
  - Rich (counter owner, measured, dry): mostly at the counter (Counter, Idle2, CigarPuff), wipes a revolver at the
    case, fetches a rifle from the rack when the player looks at it, goes upstairs rarely (stock check).
  - Utah (river-linked partner, busy): carries crates from the gallery to the storeroom and back, cleans a rifle at
    the bench (WipeRifle), checks the window, shoulders a rifle to test the sight (InspectRifle), uses the stairs often.
  - Each task = go to spot -> face the target -> play clip for a duration (with a moving hold, never a frozen pose)
    -> pick the next task. Cooldowns stop repeats; never both on the stairs at once (a reservation on the stair edge).
- **Reactions to Lil Blunt** (interrupt the current task, then resume it):
  - enters the door: both glance; Rich turns and Greets within ~1 s; Utah nods and keeps working.
  - in front of the counter: Rich holds Counter facing him (this is where the trade UI opens, `ep2_armory_shop.gd`).
  - looks at the sniper case / river crates for > 2 s: Rich Points at it / Utah walks over (`RICH_UTAH_LINES.md`).
  - head-look: turn the neck/head bones toward the player within limits (+-70 deg yaw), body turns only past that.
  - gunfire inside: both duck, then a dry line. No combat AI: they are shopkeepers.
- **Never**: walk through the counter, a rack, the player or each other (1 m avoidance radius, wait-and-retry at
  doors and stairs); snap between clips (cross-fade 0.25 s); move faster than the walk clip's stride.

## Gates
- `tests/ep2_armory_npc_test.gd` (headless, fixed seed): over 6000 simulated steps Rich spends > 60% at the counter
  spots, Utah uses both floors (visits upstairs >= 3 times), neither is ever inside a blocker rect, never on the
  stair together, a player entering triggers Rich's Greet within 1.2 s, and the walk speed matches stride.
- Captures from the Episode 2 camera: Rich greeting at the door; Utah on the stairs with a crate; both working while
  the player browses. Run it in the real town room, not only in a test scene.
