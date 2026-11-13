# Logging-road canopy jumps

Three one-bear sections at 22%, 50% and 79% of PICKET_ROAD_LEN. Original ground records keep their indices and corpse IDs. Each bear stands on a bark branch projecting from a nearby giant into the road opening. The primitive-forest fallback provides a trunk as well.

Inferno uses the existing recorded “Bows in the trees! Shoot back!” carry line once per surviving section, with a growl and 1.2 s perch hold. A 1.15 s arc leads the quad along the actual rail. One simultaneous jumper; one range/LOS-checked contact attempt per bear; existing claw, three-heart, i-frame and mine-exit retry owners. Engine/roar/sight cannot prematurely dislodge perches. Shots use the normal body ray and kill/tally/corpse signal; dead airborne bears fall with momentum and remain on the ground.

`ep2_tree_jumps_test` is wired into CI with an exact 36-check count. It covers perch/air shooting geometry, warning timing, arc/landing, kill cancellation, stationary corpses, attack budget, desert exclusion, surface restoration, and all three waves during an uninterrupted full rail ride alongside ground combat and speech.

The full legacy `ep2_interlude_test` has one failure on both this change and unmodified master f33e9583: it expects the hideout to resolve at EXIT_POSITION z=15; current master requires physically crossing PORTAL_Z z=16.4. Woods checks pass. No unrelated hideout or checkpoint behavior was changed. Logs retained under work/tree-jumps during the session; concise verdicts are in validation.txt.

Native Compatibility captures use the player camera at passenger height. This does not certify a physical phone or the public deployment; release evidence is recorded separately when verified.
