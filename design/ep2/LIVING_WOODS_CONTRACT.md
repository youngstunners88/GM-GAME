# Living woods, personal armory, and the mountain escape

Status: founder requirements and implementation conventions; runtime changes are NOT implemented by this skill package.
Source: founder request in this session, 2026-10-10 (Asia/Seoul). Baseline inspected: aebdee36797cd7f85776ee2e6802ef952dd32f6c.
Read this with PROMPT_EPISODE2_FORT_KNOX_AWESOMEX_FOUNDATION.md before changing the escape.

## Scope and precedence

The requested route is hideout exit -> mine lift surface -> quiet woods -> hidden quad -> noisy escape -> park -> climb the mountain -> binocular observation of the bear camp.
The skills prepare this job for Claude/Codex while Claude builds the world foundations. They do not claim new playable combat, models, animations, or a deployment.

This founder clarification supersedes three earlier conventions within this route:
- Winchester-only carry becomes an equipped first-person weapon selected from the personal armory. Winchester 1886 and the golden Remington 1875 remain owned once legitimately acquired.
- Harmless interludes become dangerous encounters with a surface-exit checkpoint.
- Quad concealment is removed through Inferno's visible hand movements, not leaves flying away before contact.

The later Fort Knox plot, decoy, sacrifice and AwesomeX rescue remain governed by the foundation document. Encounter failure before/during this escape is an unsuccessful attempt: both protagonists return on checkpoint retry. It is not a permanent story death or a new ending. The founder's request for a dangerous quad approach/escape is explicit; do not ask again whether those specified systems may be prepared. Do not silently expand into implementing the later vault run.

## Verified baseline and integration traps

| Current location | Observed behavior | Required integration |
|---|---|---|
| src/episode2/chamber/ep2_winchester.gd | Pure deterministic gun logic; MAG 4, RESERVE_START 24; lesson locks, cycle, per-shell reload | Preserve lesson and handling while binding ammo to the session owner |
| src/episode2/chamber/ep2_viewmodel.gd | attach() refills MAG and RESERVE_START | Rendering a gun must not create ammunition |
| src/episode2/chamber/interlude_base.gd | get_health() returns 3; HUD health fixed, rooms harmless | Read authoritative player health, cap at 3, show when needed |
| src/episode2/session/ep2_session_root.gd | chamber_failed ends the session | Route encounter failure to atomic surface checkpoint restoration |
| src/episode2/chamber/woods_quad.gd | Three patrols, six camp bears and two static archer sentries; local turn/shush reactions | Preserve founder forest/bears; give actors routines, senses and combat |
| Same woods | Running hearing 19 m; shot hearing 46 m; spy/camp separation about 41 m | Baseline constants are not calibrated mountain-scale acoustics |
| src/player/combat_handler.gd; tests/ep3_stage3_golden_revolver_test.gd | Golden revolver earned before Stage 3 | Migrate earned ownership; do not re-award it or change Episode 1 combat |
| tests/ep2_runner_revolver_test.gd | Separate runner convention | Preserve runner behavior; do not assume it supplies a finished FPS revolver |

All names for new components below are proposed interfaces, not existing classes. Inspect current master again before implementation; reuse equivalent work if Claude added it.

## Personal armory convention

Start with two stable weapon IDs: winchester_1886 and remington_1875_gold. Display the full names: Winchester 1886; Golden Remington 1875.
Do not rename founder models or replace the golden revolver with an unrelated pistol. Owned, equipped and visible are separate facts. Import ownership from the actual acquisition/save path; a new player does not get either weapon merely because a room attaches a viewmodel.

Proposed ownership surface: one session ArmoryState owns owned_weapon_ids, equipped_weapon_id, loaded rounds per firearm, reserve pools by ammo_type, acquired items and unique loot claims. Gun logic consumes this state; viewmodels/HUD project it. Snapshot it at checkpoints and serialize through the existing save owner with a schema version and old-save migration.

Quick controls: rebindable slots 1/2 for the two firearms, previous-weapon toggle (default Q), and an armory panel (default Tab). Mobile/controller expose equivalent named slots and previous-weapon action. Inspect actual bindings before assigning keys. Wheel support can supplement these controls later; it must not be the only way to discover possessions.

Use a small persistent equipped icon/name plus loaded / reserve values and visible slot hints, with a short acquisition notice. The expanded armory shows both owned weapons, current state and stored arrows. Empty weapons remain selectable with explicit empty feedback. No automatic swap or magic refill. A switch completes within a measured handling interval, is interruptible under declared rules, cannot complete a cancelled reload twice, and does not reset lever/reload cooldowns. No hidden control conflict with scope/binocular input.

Ammo types are explicit game IDs, not guessed historical calibers. Keep rifle_round, revolver_round and bear_arrow independent until canon supplies ammunition compatibility. Choose finite initial supplies from the existing acquisition state. The rifle lesson's four-round MAG is an existing game choice, not a historical accuracy claim. Revolver capacity and reload rules require current asset/logic inspection and a tested weapon profile; do not invent a verified six-round implementation.

Future arrows can be collected and displayed before a bow is usable. Collecting bear_arrow does not silently grant a bow, make a firearm shoot arrows or unlock a third equipped slot. Preserve a capability field for a later bow, and show stored quantity rather than a usable weapon hint.

## Bear life and awareness

Give each authored bear a stable ID, territory, home/routine points, awareness memory, combat role and inventory. Every routine has visible motion and purposeful pauses: roaming within a safe area, following a patrol, reading an adult magazine prop, or sleeping. A reading prop needs no explicit artwork; age-appropriate cover art and a readable seated action establish the behavior. Use available founder rigs and assets; a static archer mesh does not prove an animated archer.

Separate routine state (roam/patrol/read/sleep) from awareness (unaware/suspicious/investigating/confirmed/searching) and combat (approach/claw/aim/release/recover/dead).
Sight uses range, field of view, occlusion and dwell time. Hearing uses a source world position, category, strength, timestamp, emission ID and cover/terrain attenuation. Sleeping/reading changes response delay and attention, not permanent deafness. An unconfirmed sound gives an investigation location, not the player's exact current position. A confirmed sighting or credible local ally signal may start combat. Last-known position decays; search can end. No global omniscient alert.

Gunfire, footsteps/running and engine starts are separate world events. Gunfire is not acoustically erased by the quad engine; engine masking may affect quieter events while independent stimuli remain. Emit one event per physical action; repeated animation/audio callbacks cannot generate duplicate alerts.

Choose near/middle/far hearing samples on the real map, including behind terrain. Arrival time is sound travel + perceptual reaction + actual navigable travel, not an instant spawn timer. Hearing across a large mountain does not imply seeing, targeting or immediately reaching the source. Keep a sparse authored population near Inferno's territory. Cap active attacks and stagger arrival through valid paths without disabling the rest of the world's simulation.

Combat is attackable and reversible: shots can hit/kill bears, claws have reach/windup/recovery, arrows have warning, flight, collision and finite attacker ammo. No damage through walls, no instant lethal overlap, no overlapping attack spam. Use the existing 3-heart player owner and its invulnerability contract. Companion failure state is explicit, not a second player health system.

## Bodies, ammunition and loot

A dead bear exits AI, firing, aggro sharing and attack collision exactly once, plays a real fall/death pose and remains visibly on the ground. No immediate queue_free(), corpse fade timer or proximity disappearance. Mesh/physics representation may sleep or stream outside the active area, but a persistent record restores the same corpse and depleted loot when revisited; never remove the record to meet a frame budget.

Proposed CorpseRecord: stable bear_id, death transform/pose, drop inventory, recovered projectiles, looted quantities and attempt/checkpoint ownership. World state keeps one corpse per bear. Prompt only within reach and clear line of sight: Search bear, with available arrow/round counts. Transactionally transfer quantities to the armory and decrement the corpse. Reopening, backtracking, saving/loading or a repeated interact event cannot duplicate drops.

Recoverable arrows come from the bear's actual remaining quiver and individually tracked intact embedded/missed projectiles. An arrow cannot exist in quiver, flight and corpse simultaneously. Broken/spent projectiles grant nothing. Dropping ammunition is not permission to replenish every firearm; ammunition compatibility is explicit. Do not hide important ammo under the floor or make bodies impossible to search.

## Inferno Bull behavior

From the hideout departure and especially at the surface exit he moves slowly, checks ahead and to either side, lowers his posture/voice and pauses at cover. The player can read lookout behavior. He waits for separation and uses valid navigation. His view/weapon pose must not regress into a T pose or floating hands.

Before the quad, credible detection/threat changes him from cautious guide to alarmed protector. Panic is controlled urgency: a brief warning, move toward cover/quad, aim and shoot approaching bears, protect the player, avoid friendly-fire lanes. He cannot shoot through trees or the player; his shots also make world noise. It is not an uncontrolled scream loop, teleport or invulnerable scripted rescue. He can be incapacitated/fail this attempt, which restarts at the surface exit; later canon still rescues him.

The quiet branch reaches the quad concealed. Inferno performs several visible brushing/reaching strokes on specific leaf clusters; leaves move only after hand/tool contact, fall with plausible timing and remain where dropped. Show contact, torso weight, hand release and clear seat/grips in the player's first-person view. A hurried branch can remove cover faster with corresponding noise, but still needs physical contact. Remove only obstructing camouflage rather than launching the entire bush.

## Quad, mountain distance and binoculars

Engine start is a new acoustic phase. Some nearby bears investigate, chase, attempt a telegraphed jump/boarding, or fire from behind when they have sight and a feasible angle. A limited active attack budget is a starting tuning constraint, not a mandatory wave count. Distant bears travel; they do not materialize behind the bike. Preserve one quad, Inferno driving, Lil Blunt as first-person passenger with an equipped gun, and Deep Mining 3 beginning at mount.

Mounting cannot invalidate a nearby claw or delete all alerted bears. Vehicle collision, boarding windows and knock-off rules need tests. Do not force shooting or an attack on a clean approach merely to satisfy a script. A quiet approach reduces the first pressure; a noisy route carries existing pursuers into the ride.

Make geography do the pacing: home/shaft cover, thicket, winding trail, exposed bends, concealed parking, uphill path, protected overlook, camp beyond. Measure meters, elevation, travel speed, real route time, line of sight and hearing at landmarks before choosing radii. Do not extend the map by scaling all objects or stretching a cinematic timer.

At parking, stop the engine, dismount both characters, walk uphill and raise binoculars at the lookout. The parked quad remains at the park and does not follow the camera. Pursuers retain last-heard/last-seen information and may arrive after a delay. Silent park/climb and rushed combat lead to different pressure at the overlook. Binoculars are an explicit first-person tool with readable raise/lower, zoom and exit controls; lowering restores the previously equipped firearm. Avoid the existing RMB iron-sight/spyglass conflict. Keep later camp observation, vault-road/neighboring-building sightlines and the Fort Knox boundary.

## Surface checkpoint and varied outcomes

Checkpoint ID: hideout_surface_exit. Capture after both protagonists exit the lift onto solid surface ground, before woods risk. Retrying does not replay target practice, the lava sequence or the elevator cinematic. Until a later founder change, this is the recovery point for the whole requested escape slice, including the quad; do not invent a later auto-checkpoint.

Snapshot both spawn/navigation states, player health (max 3), companion readiness, equipped/owned weapons, loaded/reserve/arrow inventory, corpse/loot ledger, bear population and routines, camouflage/quad state, objectives, scene chain, audio/camera state and world seed. Failed-attempt kills, loot and ammo consumption roll back together. Once-only story/acquisition facts already earned before the checkpoint remain.

Failure is terminal and idempotent for an attempt: stop input/damage/AI callbacks, discard outstanding projectile/loot transactions, cancel scripted waits, restore atomically, rebind nodes and resume one running simulation. Do not leave old shooters/timers alive or double-start music. Health cannot remain fixed at 3 in UI when damaged. Show a concise cause and Retry from surface exit.

Bounded seeded variation affects routines, reaction delays and local arrival order; player decisions remain consequential. Stable world identities, loot contents and the checkpoint baseline are not rerolled by repeated retries. Use an explicit attempt seed for variation and record it for reproduction; same checkpoint + same seed + same inputs must reproduce. Do not create randomized unfair damage, instant spawn crowds or a guaranteed all-silent/all-hostile script. Required playable branches are: quiet escape; detection before quad; gunfire/defensive recovery; noisy ride; fail/retry; delayed pursuit at parking/lookout.

## Implementation evidence and handoff

Read these component skills only for the owned slice:
- .claude/skills/ep2-personal-armory/SKILL.md
- .claude/skills/ep2-bear-awareness/SKILL.md
- .claude/skills/ep2-inferno-stealth/SKILL.md
- .claude/skills/ep2-mountain-quad-escape/SKILL.md
- .claude/skills/ep2-encounter-checkpoints/SKILL.md

Use .claude/skills/ep2-living-woods/SKILL.md for order, file ownership and decision-model review.
All proposed test names in these skills are future acceptance work, not files that currently exist. Preserve the existing range, interlude, session, Fort Knox, runner, save-compatibility and Stage 3 revolver gates.

Before declaring implementation done, capture in-game: named quick slots and both FPS guns; scarce/empty/reloaded ammo; different bear routines then detection/attack/death/loot; Bull scanning, panic and defensive fire; hand-to-leaf contact; sparse delayed quad attacks; park/dismount/climb/binoculars; and failure/retry with correctly restored supplies. Record runtime metrics and screenshots from the exact tested source SHA. New combat needs runtime tests; this document-only package does not validate combat.
