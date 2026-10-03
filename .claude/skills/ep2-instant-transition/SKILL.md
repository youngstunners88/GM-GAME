---
name: ep2-instant-transition
description: The runner -> hideout cut must start on the frame it is asked to. TRIGGER on "delay", "delayed", "stuck on the cart", "slow to start", "loading hitch", edits to Ep2SessionRoot._warm_chamber_assets, SmeltingFacilityChamber.setup/_start_video_film/_ensure_room, CLIFF_HANDOFF.
---
# The rule
Nothing heavy runs between the runner's last frame and the film's first frame.
1. First runner panic (`cliff_panic`, 120 m out): `_warm_chamber_assets` requests the film `.ogv` and every hideout `.glb` on a worker thread.
2. At `chamber_z - CLIFF_HANDOFF` the session root instantiates the facility; `setup()` starts the video in the same frame (measured: setup returns in ~10 ms) and builds NOTHING.
3. `FILM_BUILD_AT` (1.2 s) into the film the room is built behind the picture. `_ready` must not build it (it defers its fallback build one frame, so `setup()` decides).
4. Film kf1 is the runner view (cart from behind in the mine, same speed): a match-cut, no fade.
# Never
Build the room, load models or run a fade-from-black before the first video frame. Gate: `tests/ep2_smelting_facility_test.gd` ("playing from frame 0", "not built at 0.5 s").
