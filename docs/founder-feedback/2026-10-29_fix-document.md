# FIX document — regression brief

Source: https://docs.google.com/document/d/1h0P1K6xiPnvdBqolLs7VxOecj5y2P7VF_T6W6ifw1KI/edit
Read 2026-10-29. Native document title: FIX. Baseline: a862c16515f55bff53af55fa3c4619dd248dd57a.
Revision: AHj4eMTrUgYoKyEDyamp8e-Xp8l4SLBiJSZJAhSyCT_m9A8SctMmVFGwUP26lpp5sCi8H8JiWhHOHcLfFxymqiEC6tDtsTXgE93Rp1MgMw.

The founder reports these defects and asks for skills followed by implementation:

1. Tunnel-runner transition video repeatedly glitches.
2. Smelting facility → elevator still glitches after repeated repair requests.
3. Sheriff bounces instead of clearly walking.
4. Trading with Rich needs an × at the top left. Apply visible dismissal consistently to tabs so players can close them without Escape exiting browser fullscreen. Preserve intentional fullscreen exit.
5. Utah's walk is erratic; improve his movement.
6. After Mike Dean sends Lil Blunt to Dude, horse mounting fails and the instructions incorrectly point back to Mike Dean.

## Reproduced causes

- The routed journey crosses the town boundary at z=1345 before reaching the ranch at z=1230. It enters the woods' independent stable-yard instance, losing the town-owned referral and purchase signal. Standalone town tests teleported directly to Dude, missing this failure. New integrated baseline: 6 checks, 4 failures, including the referral/objective and forced-GEARED return.
- Visited-world return unconditionally assigns GEARED to town, even if its actual errand was STABLES. Preserve the unfinished beat and objective.
- The restored founder Sheriff GLB has **zero skins and zero animations**. Ep2TownFolk's static fallback animates the whole object, not legs. Keep the founder's original appearance; add a weighted rest rig to a separate asset.
- Utah's authored mocap still receives procedural bob and its root/leg performance is not contact constrained. Install an instance-owned rest-aware in-place gait, with stance speed matched to actor translation; keep existing work gestures.
- The film hides the main viewport's 3D pass but requests elevator prebuild during playback. The independent SubViewport can still build and render the elevator and woods. Move that request to the lesson's existing early prebuild point.
- The physical elevator handoff clamps x to ±1.2m and yaw to ±0.9 radians, even when the doorway camera showed a different position/gaze. Preserve the physical pose, and hide the next room's first-person viewmodel/HUD while it is only a portal view.
- Rich's shop only exposes keyboard cancellation. Use a shared nonfocusable × calling each panel's own close/resume path; do not synthesize Escape or change browser fullscreen.

## Required proof

Full routed referral→Dude negotiation→explicit E mount; interrupted town return; film playback and background work; oblique held-input doorway continuity; articulated Sheriff/Utah loops with foot contact and final-scale measurements; visible close controls and actual fullscreen click-close. Run existing affected regressions, real Compatibility export, pack/security/title/access gates and normal verified release workflow. Record results and any unverified limitations under docs/episode2-quality/fix-document-20261029/.

Skills: ep2-founder-regression-repair; ep2-story-boundary-regressions; ep2-gaits-and-panel-exits. No paid provider required.
