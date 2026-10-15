---
name: ep2-mountain-quad-escape
description: Build a sparse, distance-aware mountain escape where engine noise attracts delayed bear pursuit, some bears board or shoot from behind, and the pair park, climb uphill and use binoculars on the camp. Use for noisy quad combat, terrain acoustics, travel pacing, dismount or lookout transitions.
---

# Home territory to mountain lookout

Read design/ep2/LIVING_WOODS_CONTRACT.md and ep2-interlude-chain; inspect the existing quad landmarks, trails, passenger pose, mount music and spy beat. Preserve the actual founder quad and nearby Claude world-building. The later Fort Knox decoy/vault/rescue remains outside this skill.

## Geography before attack tuning

Map shaft exit, thicket, nearby roaming/patrol areas, quad trail bends, cover/occlusion, parking, uphill footpath and protected lookout in meters/elevation. Place a sparse local bear population: this is Inferno's territory, not a dense camp at the hideout.
Record source-to-receiver distance, navigation route length and actual speeds. Test near/mid/far/occluded hearing samples with engine/shot sources; current 19/46 m constants are uncalibrated baselines. Do not globally stretch geometry to fake a mountain.

## Escape sequence

- Engine start and moving engine emit spatial sound with cadence/debounce. Nearby bears can investigate then pursue; far bears have reaction + path travel time. No teleport spawns or global instant wave.
- Preserve quiet/noisy approach histories. Engine noise escalates risk without guaranteeing an overwhelming attack. Gunfire remains its own world stimulus.
- Pursuit supports rare telegraphed feasible board/leap attempts and rear/side bow shots with LOS, projectile lead, finite arrows, recovery and readable dodge/fire counterplay. A boarder needs real relative-position/velocity conditions, not a timer that jumps through any obstacle.
- Cap simultaneous contact/attacks as a tunable fairness budget, retain other actors' world state, and stagger arrivals through valid navigation. Do not spawn an arbitrary crowd to fill a script.
- Inferno drives; Lil Blunt is first-person passenger with the selected armory weapon. Keep existing driver hand/grip and seated pose, mounted camera and Deep Mining 3 start. A mount does not clear all aggro or grant invulnerability.
- At parking: engine off, both dismount, quad stays, then walk up the mountain before binocular observation. Bears continue searching last-heard positions and may arrive later if time/distance supports it. Cover and competency can reduce pressure.
- Binoculars have raise/lower/zoom/exit input, enforce tool-vs-ADS context and restore the selected firearm on lowering. Camp sentries and patrols remain observable through a clear sightline. Preserve neighboring-building/vault-road observation requirements.
- Failure before/during the escape restores hideout_surface_exit via ep2-encounter-checkpoints; never add an unrequested safe mount/park auto-checkpoint.

## Required evidence for implementation

Proposed future gate ep2_mountain_escape_test: local engine detection vs distant non-immediate response; measured earliest feasible arrivals; seeded sparse population; LOS bow shots; boarding feasibility/cooldowns; riding ammo conservation; aggro continuity; park/dismount identities; uphill traversal precedes binoculars; input/camera restore; safe and alerted lookout branches. These are future gates.

Capture quiet mount with lower early pressure, noisy pursuit with sparse delayed arrivals, rear-arrow/board warnings, parking, actual uphill walk and binocular raise/lower. Record route time, attack concurrency, source/receiver paths and frame/pack cost. Submit real tuning candidates to Jev and Microsoft through ep2-living-woods; no fabricated playtest counts.
