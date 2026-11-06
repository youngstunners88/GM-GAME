# ADR: Episode 2 common-sense world (2026-11-06)

## Status
Accepted

## Context
The founder reported five bugs on 2026-11-05 ("This is so stupid"): people walk through the praying Minister, Inferno makes a pointless
trip, the saloon doors don't swing, shot raft men stay aboard, and rafts ignore bullets. Each was one case of a missing shared rule.
Skill: `ep2-world-common-sense`. Gate: `tests/ep2_common_sense_test.tscn`.

## Decision

1. **Story cast as crowd obstacles (`Ep2TownPeople.keep_clear`).** The town's crowd avoided only Lil Blunt and each other, so walkers
   cut through Mike Dean while he prayed, the Sheriff, Inferno, the fallen stranger and the parked quad. The room now registers each
   of them every tick as a circle: a body's width standing (`KEEP_BODY`), a praying, talking or working man's room (`KEEP_BUSY`), and the
   gap between two people in conversation. Walkers steer round the first circle on their line (touching circles are treated as one
   enclosing circle), never step into one, and may always step out. Anyone idling where a circle appears steps back to its rim. This is
   one rule in the crowd's movement, not a per-character special case.
2. **One door behaviour (`Ep2SwingDoor`).** A doorway's leaves are hinged nodes, stepped by the room with every body near the doorway.
   A leaf swings away from the side the walker came from, is held open until he has cleared its whole sweep, then swings back on a
   damped spring and settles shut. The saloon's streamed kit had its batwings baked half-open into the building mesh. Those triangles are
   stripped from that copy at build time (`strip_baked_leaves`), so no art file changes and the main pack does not grow. Any new door
   with leaves uses this class rather than a special case.
3. **Rafts as things in the world.** A raft's timber reuses `Ep2CreatureHealth` (no second health system). Each hit splinters, leaves a
   scar and jolts the raft. At half health the raft lists and rides low with a log loose. At none, it breaks up: the hook releases,
   whoever is aboard goes into the river, and the logs float apart and drift. A shot rider leaves the raft's frame and falls over the side
   into the water (`_overboard`), where the current takes him. Six hits (the Sharps counts two) is more than the two men take, so the
   stage stays winnable without trivialising it.

## Consequences

- Scripted walks (`Ep2Actor.walk_to`) are still straight lines. The crowd yields to them, but two scripted actors do not avoid each other.
  The routes that matter are chosen to be clear (Inferno's spot by the body), and the gate measures them.
- The river's new sounds are synthesized (`tools/ep2_audio/synth_river_hits.py`) and streamed. Before the pack mounts the river is quiet.

## ADR Dependencies
None. It reuses `Ep2CreatureHealth` (wildlife combat, `design/ep2/wildlife/WILDLIFE_COMBAT.md`).

## Engine Compatibility
Godot 4.3, Compatibility renderer. It uses only `ArrayMesh.add_surface_from_arrays`, `CPUParticles3D`, `AudioStreamPlayer3D` and
plain `Node3D` transforms. No threads, no new autoloads.

## GDD Requirements Addressed
- Post-draw lock, `PROMPT_EPISODE2_CAD_TRANSITIONS_DRAW_REWRITE_2026-10-25.md` sections 4.3-4.4: every line and its
  voice id is unchanged, and each plays once. When Inferno meets Lil Blunt at the body, the whiskey line moves after the body exchange.
  The lock places that exchange "on the way / at the scene", so this stays inside it.
- Day-88 river lock, `docs/founder-feedback/2026-11-04_day88_river_cover.md`: the rafts drain the crate until stopped, the stage stays
  winnable, and the retry rule is unchanged.
