---
name: ep2-inferno-stealth
description: Make Inferno Bull creep and scan from the hideout exit, become an alarmed protective shooter before the quad when bears detect them, and physically brush leaves off the concealed bike. Use for companion lookout, panic, defensive shooting, hand contact or companion encounter failure.
---

# Inferno's cautious departure

Read design/ep2/LIVING_WOODS_CONTRACT.md and ep2-interlude-chain. Inspect mine_lift.gd, woods_quad.gd, facility_show.gd, Ep2Actor, arm IK and the current founder Bull work. Reuse his real rig, hands and weapon; preserve concurrent rest-arm/whiskey fixes. Art changes use .agents/skills/smokerealm-episode2-art/SKILL.md.

## Companion states

Cautious lead -> pause/scan/cover -> alarmed protector when a credible bear threat is detected -> retreat/defensive shooting -> reveal/mount/drive, or incapacitated encounter failure.
- Begin cautious behavior on departure, not only at a later HUD prompt: slower locomotion, readable forward/side scans and stops at cover, natural whispered warnings. Surface navigation must avoid ledges/player blockers.
- Wait within a measured follow distance and recover from blocked paths. Do not drag or teleport the player into detection to keep dialogue timing.
- React to real threat evidence. Suspicion produces restraint; detected/approaching bears before the quad produce urgency and defensive fire. Panic changes pace, voice and posture without endless screaming or flailing.
- Aim with actual LOS at an approaching threat, protect the player without firing through them, obey shot cadence/ammunition, and emit normal gunshot noise. Do not erase enemies by scripted call.
- Companion incapacitation ends this attempt and invokes hideout_surface_exit retry; it does not permanently kill the later story's rescued Bull. Use existing player health plus an explicit companion condition, not a replacement player health system.

## Brushing the quad clear

The quiet branch MUST show several hand strokes on camouflage clusters in the player's first-person view. Build contact markers and a deterministic timeline: hand approaches -> reaches/braces -> touches one cluster -> strokes/displaces leaves -> releases -> leaves settle.
No leaf displacement before the relevant contact. Preserve idle camouflage until reached. Free seat/grips and riding path; fallen leaves remain plausibly grounded. A hurried variant is allowed with contact and extra noise, not an instant explosion of foliage.
Use look_toward only where needed to present the contact; return view control reliably, keep the equipped firearm/low-ready pose, and do not force a permanent cinematic camera. Show Bull's torso weight, hands and weapon management rather than intersecting the pile.

## Required evidence for implementation

Proposed future gate ep2_inferno_stealth_test: cautious speed/scan pauses; separation/path recovery; suspicion vs panic; real target/LOS/friendly-fire checks; defensive shot cadence/noise; companion failure -> checkpoint; leaf motion begins after hand contact; quiet/hurried reveal; camera/control release after interruption/retry. Future test names are not existing gates.

Capture an uninterrupted first-person quiet departure/reveal and a detection/panic/defensive-fire branch. Include close and normal-camera contact frames before/during/after each brush; a reach signal or particle burst alone is not proof. Measure hand/leaf contact timing, shot targets and follow spacing, then use the two-model review through ep2-living-woods.
