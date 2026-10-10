---
name: ep2-bear-awareness
description: Give the woods bears roaming, patrol, reading and sleeping routines, local sight/hearing awareness, claws and finite arrow combat, and persistent searchable bodies with conserved loot. Use for bear intelligence, gunfire reactions, corpse persistence, projectile recovery or anti-duplication.
---

# Bears that live in the woods

Read design/ep2/LIVING_WOODS_CONTRACT.md. Inspect woods_quad.gd, Ep2Actor, founder bear rigs and existing archer/runner conventions. Load ep2-bear-design for rigs/telegraphs, but its runner-only single-answer hazards do not restrict this multi-outcome woods encounter.

## State and senses

- Give every authored bear a stable ID and home bounds. Separate routine (roam/patrol/read/sleep), awareness (unaware/suspicious/investigate/confirmed/search) and attack/dead state. Quiet behavior must keep moving or visibly reading/sleeping rather than all actors standing in a frozen ring.
- Use navigation-safe routes, seeded pauses and bounded routine changes. Reading an adult magazine uses non-explicit prop artwork and actual seated hand/head motion. Sleeping has a wake transition; reduced attention has a tested reaction delay.
- Hearing events carry source/type/strength/time/ID; sample distance, terrain and cover. Sight uses FOV/occlusion/dwell. Sound alone reveals a last-heard point, not exact player tracking. Communication is local and finite; no global alert.
- Investigate before attacking an unseen target. Confirmed threats can approach, claw or shoot arrows. Memory/search decays so evasion can work. Dead actors cannot sense, alert, attack or respawn because a beat changes.
- Attacks need telegraphs, LOS, windup/recovery and actual range/projectile collision. Finite quiver arrows move through quiver -> projectile -> intact recovery or spent state; never count one arrow twice. Integrate the existing player damage owner and invulnerability rules.
- Distance affects arrival through reaction + navigation time. Nearby bears may react promptly; far bears do not teleport or all charge when a gun/engine sounds. Carry aggro across quiet/reveal/ride/park beats.

## Death and loot

Reuse the real fall/hit rig where possible; verify it on the founder's retargeted model. A static bow mesh cannot animate or fall by assertion.
Keep the corpse visible in the active area; disable attacks and harmful collision at death, preserve ground contact, death pose and a reachable Search bear prompt.
Persist death transform, remaining quiver, compatible loot, intact recovered arrows and depleted quantities per stable ID. Out-of-area streaming reduces representation, not the persistent record; return restores the same body and loot.
Commit inventory transfer once per interaction/claim ID. Repeated input, reopening, save/load, moving across room bounds or duplicate death callbacks cannot grant duplicates. Failed attempts roll back corpse and inventory together through ep2-encounter-checkpoints.

## Required evidence for implementation

Proposed future gate ep2_bear_awareness_test: routine activity; bounded roam/navigation; sleeper wakes; hearing thresholds at near/mid/far/occluded points; investigate vs confirmed sight; loss/search; claw invulnerability and LOS; finite arrows; dead actor silence; death idempotence; corpse revisit and one-time loot; projectile recovery conservation. These tests do not exist yet.

Capture all four quiet routines, investigation, claw/bow warnings, projectile impact, actual bear death/body and arrow looting. Record sound source/receiver positions, reaction/arrival time, event IDs and counts. Use ep2-living-woods to submit real candidate measurements to Jev and Microsoft, then preserve the chosen scope and uncertainty.
