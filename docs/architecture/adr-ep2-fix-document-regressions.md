# Episode 2 regression boundaries, locomotion and panel dismissal

Status: accepted implementation; release evidence tracked separately.
Brief: [FIX document](../founder-feedback/2026-10-29_fix-document.md).

The founder reported recurring film/elevator glitches, static or erratic story-character walks, Escape disrupting fullscreen, and a lost horse referral on the way to Dude.

## Decisions

- The town owns both Main Street and the ranch at z=1230. Reversible world routing uses a 1150/1152 boundary south of the ranch. Returning to an unfinished town retains its beat, show, referral, purchases and objective. Parking disconnects obsolete forward-clear callbacks; an unfinished return reconnects the current story owner.
- The tunnel film keeps its existing decoder, soundtrack, release-before-skip and sliced hideout build. Later-room GPU preparation starts in the lesson, through the existing prebuild mechanism. A disabled main viewport must not hide a separately rendering elevator viewport from diagnostics.
- A physical doorway carries the player's actual gaze, movement and stride. Its preview excludes the second first-person weapon/HUD and mirrors Inferno's current clip, time and rotation. The actor animation owner receives the carried clip so its next step cannot restart it.
- The founder's restored Sheriff remains the same mesh, material and texture set. A separate weighted nine-bone lower-body asset supplies articulation. Instance-owned grounded clips use each rig's own rest transforms, preserve segment lengths, match stance travel to actor translation and vary pelvis height only for reach. Utah's work animations remain intact; carry retains its own upper-body pose. Tuning is in `src/episode2/config/grounded_walk.json`, explicitly included in web exports.
- A shared nonfocusable × invokes each dismissible panel's existing cancel/resume function. It does not synthesize Escape, change fullscreen, buy/equip anything or complete a quiz. Escape remains available. Raw finger taps and emulated clicks are deduplicated. The selector's input owner yields clicks on this button to GUI handling.

## Verification and limits

Integrated routing tests cover the actual held walk toward the ranch, real referred conversation and explicit mount. Motion tests sample both feet through multiple loops at final model scale; Compatibility captures inspect the town/player view. Continuity tests inspect the real session root, preview and first active camera. Shared close tests cover trade, map and both pause paths; an external-only fixture exercises the production web engine/packs, full film and fullscreen dismissal. The fixture lives under excluded authoring tools and never adds a production unlock or warp.

The native/headless and desktop-browser checks do not certify a physical phone. Normal regression, title/access/security, fresh-pack and CI/public-release gates remain required. See `docs/episode2-quality/fix-document-20261029/` for final evidence and release status.
