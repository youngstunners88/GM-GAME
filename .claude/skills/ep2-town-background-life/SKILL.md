---
name: ep2-town-background-life
description: Populate Episode 2's GoldMine town with purposeful period townspeople, horses, dogs, chickens and musicians, including routines, contacts, story-safe movement and spatial audio.
argument-hint: "district | actor-id | all"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# Background daily life

## Phase 1: Prepare activities and asset jobs

Before writing, use the user's authorized scope as approval; ask only for missing necessary inputs. Preparing jobs does not submit paid jobs or implement actors.

Start with `ep2-living-town`. The plan supplies activity, home position, radius, path, seeded phase, district, asset binding, audio suppression and duel behavior. Those are specifications, not implemented AI or clips. Do not substitute a bobbing statue for a breathing horse, walking person or pecking chicken.

Author activity by place: stable hand brushing/feeding horses; a shopkeeper sweeping; an assay worker moving ore sacks; laundry behind the hotel; a porch fiddler; dogs sniffing/settling in yards; chickens scratching around feed. Sparse independent timing and varied holds make the town feel occupied. Avoid constant chatter, synchronized loops and uniform scatter. Add worn paths, dung/feed/water cues where appropriate, with no litter wall across travel.

Resolve every asset job with source/license, mesh budget, bounds, materials, real clips and contacts. Reuse the existing `Bar_Piano` kit candidate. The starter has no pianist; do not claim its keys are visibly played. A fiddler needs an authored fiddle/bow grip and bow-on-string trajectory. Use `ep2-character-performance` and `ep2-prop-contact-animation` for measured hand/prop contacts, feet and whole clips. Horses need coherent hoof plants, breathing/ears/tail; dogs need ground contact; chickens need head/feet timing. No new meshes or paid jobs are launched by the toolkit.

## Phase 2: Integrate and verify routines

For a runtime integration:

1. Add a dedicated ambient controller driven by the existing chamber `step(delta)`/`_tick`, not independent `_process` clocks. Deterministically phase routines; pause/save/retry must not spawn duplicates or accumulate sound players.
2. Bind scene assets explicitly, normalize metres/ground pivots, keep moving bounds clear of building segments and player routes. Use avoidance/repath/stop rather than passing through bodies. Check entire paths and animal bounds, not only spawn centres.
3. Before SQUARE_UP/DRAW move/hold actors at already safe home spots without teleporting into view. Never cross the sightline or stand beside the opponent as a target. Animals are ambient and do not drop loot or become hostile. Respect Bull's existing entrance.
4. Fiddle/piano use quiet positional loops with distance rolloff and emitters attached to the source; doors attenuate. Suppress instrument/chatter audio on OFFICE/BAR/SQUARE_UP/DRAW, preserving the quarter-Bitcoin payment, Sheriff lines and draw cue. Inspect the actual audio mix and restoration after retry/exit. No new story dialogue is generated.
5. Distance-throttle offscreen animation/AI and cull in stable chunks; test re-entry without popping, desync or large spawn spikes. Proposed actor/emitter caps are starting limits, not frame-budget proof.

PASS requires real whole-loop and story/audio evidence for runtime claims. Next step: `ep2-town-proof`; unresolved assets/clips remain explicit in the handoff.
