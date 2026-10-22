# Current continuation status

Completed and publicly verified: BUILD `2026-10-22-13cbfad`, production source `13cbfad0dbcb6652ceefc5ece0d0efc8a5b2e981`, successful run `39727661169`. All thirteen public figures plus the separate prisoner pass QA and are in the publicly served packs. See `release-receipt.json`, `VERIFICATION.md`, and `evidence/`. The following reboot checkpoint is historical; its movement, geometry, save, camera and release failures are resolved. Public Episode 2 access controls remain active; no protected public walkthrough is claimed.

# Resume after owner-requested reboot — 2026-10-22

Owner explicitly requested STOP and a resume prompt. Do not infer completion. No new release was published. Preserve all current work; do not reset or rebuild over original sources.

## Objective
Complete living, individually autonomous town NPCs using ALL supplied figures. User authorized Blender/creative-hub tools and creating reusable skills, plus implementation and normal repository release workflow. Latest instruction paused work for reboot.

## Checkout and baseline
- Worktree `/home/kofibeatz/GM-GAME-town-people`.
- Branch `codex/ep2-town-autonomy-20261022`, based on `209c4e0ae77d0839b754a0d259bec2ead8f7a50d`.
- This turn's work is UNCOMMITTED. Other checkouts are stale; do not switch to them or overwrite their unrelated dirty work.
- Git shell fetch failed DNS. GitHub connector independently confirmed master at 209c4e0a before editing. Refresh on resumption.

## What exists
- `.agents/skills/ep2-town-autonomy/SKILL.md` and `ep2-town-cast/SKILL.md`, both pass skill-creator quick_validate. Global ~/.codex/skills was read-only, so project-local skills were used.
- `CONTRACT.md` and `cast-build.json` in this folder define the expanded cast and behavioral requirements.
- Eight NEW Blender figures built serially with source .blend, textures and receipts under sources/: bald_worker, grandma, grandfather, grandmother, youth, boy, braided_girl, bob_girl. Outputs in src/episode2/extras/people/.
- Existing five retain geometry, get five additional conservative standing clips (Observe, Rest, Talk, Inspect, Alert). Sources saved separately in this folder, originals preserved in people-rebuild-20261021.
- All 13 reference images were inspected together. Manifest in ../people-rebuild-20261021/references/manifest.json. Thirteen images represent 14 figures: grandparents has TWO, boy-and-girl actually has ONE youth. 13 public ambient NPCs plus existing separate jail prisoner. Original clerk uses the pianist reference; no claim of actually playing keys.
- New `Ep2TownNavigation` graph uses real town walls/props and excludes buildings/porches/firing yard. New Ep2TownPeople has 13 profiles, utility/novelty activity choices, per-person seeded RNG, destinations/reservations, dynamic avoidance, greeting/social memory, danger/sheltering/recovery, JSON snapshot/restore.
- gold_town.gd integrates collision/context, shot reactions, and requires the lane clear before DRAW. BAR starts evacuation.
- Existing town test updated to roster count; NEW tests/ep2_town_autonomy_test.{gd,tscn} added, NOT yet in CI workflow.

## Actual evidence and unresolved defects
- Installed Blender toolkit audit passed (two copies, 89 files each, zero mismatches). Eight cast builds completed. Original-five activity exports completed.
- Initial Godot compile tangent inference error FIXED with explicit Vector2. Godot editor/import sockets denied by sandbox (expected environment limitation); no subsequent compile error seen.
- Movement bug found: base folk arrival tolerance .06 exceeded per-frame travel. Added optional arrival_radius preserving old default; ambient folk sets .003. Last 120s town test now has 12/13 walking >12m, so still FAILS one travel check; geometry, placed roster, stagger and greeting tests passed. Inspect /tmp/town-behavior3.log if still present; do not lower the threshold without understanding who is blocked.
- Earlier long autonomy run compiled BEFORE the arrival-radius correction; its 0m failures are stale. AStar building exclusion also corrected from centered-footprint to actual FRONT-EDGE origin; final corrected graph needs fresh tests. Re-run new autonomy test after reboot, inspect all assertions and timing.
- Boy installed asset QA FAILS 13 coplanar overlapping hair triangles (curly clumps use capped loft rings). Rig QA passes. Detailed asset/rig/deformation receipts under qa/boy/, logs ignored under logs/. Fix curls geometry for boy AND youth (likely same issue), rerun sequential builds and full QA. Do not silently waive coplanar errors.
- New clips sampled at 12/s in boy QA; all 10 finite. Mild-to-moderate stretch measured, receipts preserved, needs visual review.
- No gameplay captures of NEW cast/autonomy yet. No new main/extras export, pack gate, complete regression, commit, push, CI or public deployment yet.
- Snapshot API is controller-local; not wired to durable session saves. Validate malformed scalar/memory shapes and overlap handling; current restore is first pass and incomplete. Do not claim persistent cross-session memories.
- Crowd movement currently resolves inside _move then suppresses a second folk.step if position changed. Review stride/bob animation and blocked-state clips on camera.

## Next work
1. Read repo instructions/resume skill and this checkpoint, inspect git diff, refresh remote, preserve work. Verify free -h, zramctl, df -h /tmp after reboot.
2. Fix remaining crowd travel/avoidance/duel safety/recovery issues; run both tests plus imported asset gate. Test actual chamber story progression for softlocks.
3. Fix curly hair QA, inspect remaining 12 source assets using review_street_people.py (now supports expanded sources/all 10 clips). Build one heavy Blender job at a time. Tool paths in ~/creative-hub/AGENTS.md. ALSOFT_DRIVERS=null, no changes to owner's open Blender.
4. Create complete reference coverage receipt, gameplay-camera whole-loop evidence, and scoped memory/save integration if appropriate. Do not invent dialogue, combat targets or unsupported task props.
5. Add autonomy test to existing CI block, update documentation/skills/routing, run required regressions, semantic/visual QA and fresh-import <=190MiB main-pack gate. All extra art streams via existing extras.
6. Scoped commit, ship through existing non-forced workflow, verify source SHA, successful butler upload and actual public BUILD. Network/renderer restrictions must be reported honestly; no false live claim.
