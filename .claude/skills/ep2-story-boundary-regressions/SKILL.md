---
name: ep2-story-boundary-regressions
description: Trace Episode 2 film/elevator and town/ranch failures through Ep2SessionRoot and visited-world routing, retaining movement, actor instances, referral flags and story beats.
---

# Stateful boundaries

Read the parent ep2-founder-regression-repair skill and ep2-film-always-plays / ep2-no-blackouts / gm-game-location-continuity as needed.

Primary paths: src/episode2/session/ep2_session_root.gd, session/world_routes.gd, chamber/smelting_facility.gd, mine_lift.gd, gold_town.gd, ep2_stable_yard.gd.

- Test a real session tick while walking from the Certificates office past z=1345 to the stable horse at (-13,0,1230). Confirm the same town-owned yard receives the referral and horse-purchase signal. Generic woods scenery can contain another yard; never let that duplicate own this story exchange.
- Preserve the active beat when parking and returning to unfinished town. A revisit must not force GEARED, clear a half-finished show or replace the objective while referral/purchase remain false. Completed travel can resume free roam without replaying rewards or charging again.
- A parked chamber is still alive. Disconnect its forward chamber_cleared/failed listeners when parking so a later revisit cannot trigger an obsolete chain transition.
- Keep film playback isolated from lift/woods GPU warm-up and heavy asset upgrades. Schedule later-room prebuild when the visible lesson starts, early enough to be ready at the door.
- Capture both sides of the doorway with held forward, lateral and backward input; compare world-space camera/weapon transforms, not just stored player coordinates.
- Re-run world routes, full town story, stable yard, seamless chain, transition prebuild and the new integrated regressions. Preserve map and explicit E mount.
