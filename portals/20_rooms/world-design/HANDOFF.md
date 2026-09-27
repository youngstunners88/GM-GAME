# Educational world design handoff — 27 September 2026

Reviewed master `aa5e1f5a12387abbd8c98e46f57e745dc0ebd798`, including Codex’s top-down map work in `85ad269` and export repair `ce9ce1c`. Inspected all 18 images in the founder’s [reference document](https://docs.google.com/document/d/1HSqakFkrnyASYnzLRghu2q3nVTiJr7UzknQlwMkkdDM/edit). See reference-index.json for section order, object IDs and hashes; no temporary authenticated image URLs are retained.

## Deliverables
Three reusable skills are installed for the user and mirrored under `.claude/skills/gm-game-{smoke,diamonds,gold}-world/` for repository collaborators. Each includes a region brief, explicit reference interpretation, grounded station anchors, prop prompts, modular terrain guidance, provider routing, budgets and runtime review criteria. The three layout JSONs are reviewable route proposals, not final collision geometry or human-approved 3D layouts.

| World | Direction |
|---|---|
| SMOKE | Smoky forest archive, hedge paths, mossy stone, ash-ring rotunda, purple lounge alcoves and green lamps. Neutral drifting smoke; clear feet, routes and markers. |
| DIAMONDS | Faceted basalt terraces, crystalline works, visible water crossings and a three-seat assay court. Sparse cyan glints; distinct CUT/WEIGH/STAMP desks. |
| GOLD MINE | Frontier mining town, ochre ground, timber boardwalks, vault frontage, foundry and a claim office. Warm lanterns and local dust. |

Use strategy-RPG district scale, connected routes and camera reveals. Preserve the current 2D explorer; do not convert the game to a 3D engine or paste a poster across the ground. Reference lettering—especially “288 CYCLE”—is not authority for financial or quiz facts.

## Concrete defect and patch
`FloorSlab` is an opaque 2800×1100 rectangle at z=-50 in the baseline; it covers `Backdrop` at z=-100. Change the substrate to z=-110 so existing backdrop art is visible above it. Preserve floor collision, actors, landmarks, learning gates, questions, study sources and scorecard code.

Added instantiated-room regression checks to `tests/portal_room_test.gd`. Verified in checksum-checked Godot 4.3: **90 checks passed**, with no SCRIPT ERROR in the room-test log. Temporarily restoring baseline z=-50 produces exactly three failures, one per protocol, then the patch is restored. Logs are included. This proves the draw-order contract and room logic; it is not pixel or deployed-build evidence.

## Follow-up issues found
- DIAMONDS crystal loop runs to x=4610; its bridge ends at x=3000. GOLD beam loop reaches x=4700. The map is 2800px wide. Replace obsolete strip spacing with authored in-bounds district placement.
- Visual paths are 42/54px wide; the explorer body is 32px. Proposed primary routes are 128px with at least 96px clear passage; route around all interaction envelopes.
- The GOLD paper at y=300 uses a 380px label offset, placing its label above the map. Inspect and clamp/reflow against camera bounds during terrain integration.
- The vignette reaches alpha 0.55 at the edges. Review at gameplay zoom after the occluder repair; do not indiscriminately brighten all art.

## Provider and release status
MuAPI and Meshy environment API keys were absent; this does not prove there is no Meshy stored-login session. No Meshy authentication or paid task was started because this request’s deliverable is design skills, and approved isolated prop references/budget are not yet established. The `game-dev` CLI is absent, so no Game Development Studio capture/package receipt exists. No generated production assets or provider spend are claimed.

Personal skills are installed and independently exercised against the source and image contact sheet. Repository copies and the code patch are a review handoff. New terrain assets, exported-build before/after captures, visual approval, Jev evidence and live deployment are still pending. The repository’s portal shipping skill requires those gates; do not call this game change SHIPPED or use the publishing script until they pass. The initial fresh import surfaced first-import asset ordering and a sparse-checkout tools dependency; the isolated portal test completed cleanly. No full-project export claim is made.
