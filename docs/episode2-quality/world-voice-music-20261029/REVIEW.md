# Episode 2 world, voices and draw music — 2026-10-29

Source base 575664b1. Founder explicitly requires commit, push and verified itch.io release. Status: release checks in progress.

## Exact requested audio

Mike Dean:`CfxYdK3WmF3bmrvyLAiU` (ELE). Dude:`3N5PpVsIKXqmtLAhF2Lj`; Logan:`01s40UXbrIC3SwHf5nUh` (both verified on the owner's new ELEVEVE binding). 27 takes generated/replaced: 9 Minister, 13 Dude, 3 Logan, 1 Lil Blunt reply and 1 corrected stranger auction demand. All 147 roster entries have matching source/receipt hashes and actual Ogg recordings. Rich/Utah/Sheriff identities remain unchanged. Keys stay in process bindings; the game uses offline recordings.

The supplied `06_28 (Remastered).mp3` is retained byte-for-byte as streamed `06_28_remastered.mp3`. A paired music override starts when the Sheriff enters the bar, restores the paused prior song/position after the draw, runs for the lake ride and restores on arrival. Speech ducks the override as well as base music. Road barks have a separate positional voice lane, so they cannot cancel Lil Blunt's speech; shared interlude speech now reads the streamed voice bank rather than silently looking only for legacy root MP3s. Logan's actual recordings determine dialogue duration. Crowd whoops/whistles/cheers use a dedicated non-positional player for 14s, immune to pooled footstep/greeting replacement.

The stranger's demand is: “Give me a Bitcoin in exchange for this map to the auction. You could walk away with more gold and Bitcoin.” No intel substitution.

## Connected authored world

The session retains visited story places in process-disabled, render-disabled SubViewports with isolated 3D worlds. Cameras, lights, HUD and ambient sounds cannot leak into the active place. The original town visuals, crowd, fallen stranger and other actors are adopted into the mounted world and restored when revisited; they are not reconstructed into a substitute town. Crossing into town restores the original interactive chamber, including the armory counter. Held movement/gaze are carried through returns; no rewards or story lessons replay. The actual horse travels in the surface world. The same elevator descends/ascends on boarding, and the original completed smelting room can be entered again through its open doorway.

The facility warms the lift during the existing film; woods warm the town before the quad mount; town warms the trail during the stables dialogue. The lake's actual prebuilt geometry appears ahead, one root node per frame. 100 authored firs become denser along the approach; sand/grass and lighting blend gradually into the destination. Desert geometry is cut out beneath the actual lake terrain/water. A 0.6s visible dismount preserves exact position/gaze/standing eye height at the handoff, replacing the 2.6s frozen wait. 19 road bandits retain the maximum of two concurrent telegraphs and finite ammo/three-heart rules.

## Evidence

World route 26/26, focused residual 163/163, full town, trail, audio, interlude, session, lake, quad music and transition-feedback checks pass. The world test verifies actual instance identity, retained dead opponent, horse transport, old barriers removed, lift descent, facility control/door, held input, exact voices, route speech, actual lake preview alignment and music restoration. Six-place native smoke test measured 796324 KB peak RSS before later visual reuse (not a real-phone/WebAssembly certification).

Real Compatibility camera captures show approach 200/330/440/end, the pre-crossing dismount and actual lake arrival; geometry is retained through the cut. Local Chromium boot/gameplay and nonthreaded export are checked. Title/access controls and learning/quiz behavior remain preserved. New world-route regression is added to CI.

The old standalone smelting PBR test still expects the retired UV material named InfernoBullRestoredPBR; the current painted-Bull branch deliberately uses its own textures. No Bull model/material is changed here. This is separate from the passing transition regression. Native Dummy renderer cleanup warnings are retained in raw logs and do not count as visual evidence.

Visited-instance retention is within the active session. Existing manual Continue semantics remain section-start checkpoints, not a serialized whole-world snapshot. No real-phone certification or authenticated public-origin Episode 2 walkthrough is claimed. Actual release/build/pack sizes and public verification follow in RELEASE_RECEIPT.json after deployment.

Final local export: main pack 197,509,232 bytes; streamed extras 127,642,560 bytes (both below 199,229,440 bytes). Chromium verifies canvas, engine boot, no Godot script errors, nonthreaded runtime and Stage 1 gameplay. Exact Episode 2 behavior is covered by the native route/regression tests and Compatibility camera captures, not by an authenticated browser walkthrough.

Full workflow headless suite completed through `scripts/ci-gates-local.sh`; all gates pass with the repository's documented three local pause-menu geometry differences tolerated. The hosted attempt 40730916358 passed those pause checks but stopped at the stable test because its assertion still hardcoded Dude's former voice ID. The interaction already returned the requested new ID. The assertion now checks `3N5PpVsIKXqmtLAhF2Lj`, preserving the same conversation, distance and draw-interruption checks; the full stable battery passes all 98 checks. No runtime code was changed for this assertion correction. Compact full-suite results are in `all-ci-headless-checks.txt`.
