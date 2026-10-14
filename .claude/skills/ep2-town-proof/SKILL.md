---
name: ep2-town-proof
description: Validate Episode 2 town proposals and require actual first-person visual, animation, story, audio, performance and export evidence before reporting a rebuilt living town.
argument-hint: "proposal | runtime"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# Proposal and runtime proof

## Phase 1: Proposal checks

Before writing evidence, use the user's existing scope as approval; ask only for missing necessary inputs. Do not introduce another permission gate for authorized work.

Start with `ep2-living-town`. Run `tools/ep2_town/README.md` commands and its unittest suite. `validate` exit 0 means valid proposal geometry/declarations only. `runtime_approved` stays false, unresolved assets remain listed, null PCK size is unmeasured. `handoff` writes marker positions and job lists; it never produces a populated playable scene.

For skills-only delivery, include the schematic, source hashes, passing script checks and unresolved asset/camera/runtime evidence. Do not export or claim a new live game for preparation alone.

## Phase 2: Runtime evidence

After actual runtime work:

1. Re-audit/replan if layout/kit hashes changed. Preserve current master and other sessions. Keep source SHA, reference image, baseline and candidate evidence together in `docs/episode2-quality/`.
2. Use existing `tools/ep2_shots/town_shot.tscn` and `town_beats_shot.tscn`, extended for the capture job coordinates. Capture arrival, connected avenues/turns, stable/feed yards, both doors/interiors, duel and Bull's return. Verify at first-person height with the equipped gun visible. Include temporal clips; stills cannot prove animal motion, footsteps, grips, audio or crowd avoidance.
3. Verify collision through office/saloon, ride-off, no animal/person blocking duel or witness, no cancelled cast/new protocol text, no teleport/pop across the woods/town handover. Test pause, retry, leaving/re-entry, controller cleanup and audio duck/restore through every beat.
4. Run the current native town, interlude and Fort Knox arc gates; real Godot 4.3 nonthreaded Compatibility web export (gdparse alone is insufficient), browser playtest and final PCK <190 MiB. Compare baseline/candidate frame timings, draw calls, active actors, build peaks and memory at the same cameras/scenario, including a lower device tier. Do not guess GPU cost from character counts.
5. Follow existing reference-match and measured external-review workflows when reachable; record actual unavailability rather than inventing decisions. Release runtime work through `smokerealm-ship`, with actual CI/butler and public-build proof before claiming live.

Next step: fix FAIL results in the owning component skill; a proposal PASS routes to art/runtime production, while verified runtime work routes to `smokerealm-ship`.
