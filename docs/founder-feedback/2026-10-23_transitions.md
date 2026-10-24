# Transitions work — 2026-10-23

Source: [founder document](https://docs.google.com/document/d/1V5_GH8g7z15yiSypN-DNI4FHpHCOLhdMFcqURYwGP_E/edit).
Baseline: `bb2047c27620ad358dff92ea6b749356a63e4da4`; freshly fetched master matched the checkout. Since the prior checkpoint the only overlapping woods change adds the town people handoff; it is preserved.

| # | Founder said | Measured source cause | Implemented repair | Proof / status |
|---|---|---|---|---|
| 1 | “Don't have Lil Blunt's voice announcing the NFTs. The jingle and display ... is enough” after each boss | All boss kinds scheduled a voice timer at 1.7 seconds | Return after the boss jingle. Cards, ICP and test rewards retain their behavior | PASS: NFT_ISSUER + TRANSITION_FEEDBACK (all three boss voice timers tested) |
| 2 | “end of level 3 ... beginning of Episode 2 ... more immediate” | Critical warm queue scanned hideout assets/audio and the later hideout film; final dissolve 0.6 s | Warm the opening runner; leave the hideout warming to its existing session-root path. Dissolve 0.18 s; preserve the approved film/cover/access rules | PASS: queue 115 → 27; dissolve 0.60 → 0.18 s; TRANSITION_DIRECTOR |
| 3 | “he interrupts himself ... let's not make him talk about the handle” | LEVER started `vo_bull_lift_lever`; RISE started plan speech independently of its carried hold | Remove handle VO, retain reach and pull; incoming speech finishes before plan. Surface exit has no blocking arrival speech | PASS: silent lever and full EP2_INTERLUDE |
| 4 | “takes way too long ... forest looks totally different ... one location” | Separate primitive conifers/sky wall in lift; gate waited for Bull's whole exit show; next room reset player to SPAWN | Lift vista uses gameplay forest builders and daylight. Explicit coordinate mapping preserves player/Bull/gaze. Ready exit does not wait for the walking show | PASS: identical near-slice transforms, exact eye/Bull/gaze mapping; actual session-root before/after captures inspected |
| 5 | “revealing the quad bike ... getting on ... smoother” | Reveal/answer/mount voice waits serialize movement; passenger glides directly from arbitrary distance to seat | Reveal speech overlaps brush; answer overlaps on-foot approach; mount line overlaps climb. Wait on actual approach/climb completion; music still starts on mount | PASS: three lines complete in order; 11.92 s to ride; max 0.098 m camera step at 60 Hz; complete Compatibility-rendered action inspected |

New skills: `gm-game-transition-repair`, `gm-game-transition-dialogue`, `gm-game-location-continuity`, installed for Claude and Codex and routed from CLAUDE.md. Older NFT-congrats instructions now explicitly defer to the new boss-silence request.

No assets, paid generation, canister/economy rules, title files or access credentials are changed. Runtime, visual and release evidence will be recorded here; preparation is not a shipped fix.

## Verification before release

- Godot 4.3 pinned binary; import refreshed twice. SCRIPT_COMPILE, TRANSITION_FEEDBACK, EP2_INTERLUDE, TRANSITION_DIRECTOR, EP2_SESSION_ROOT and SAVE_COMPAT: ALL PASS.
- Full CI headless block: PASS. Three already documented local pause tap-target geometry differences remain the runner's sole allowance.
- Opening queue measured by executing old/current builders: 115 → 27 resources. This is a source/loading-path measurement, not a promised wall-clock speed on every device.
- The actual session root performs the captured doorway handoff. The entire quad reveal-to-ride action is sampled from the actual 3D chamber; temporal continuity is separately checked at 60 Hz. [Board](../episode2-quality/transitions-2026-10-23/transition-board.jpg), [sequence](../episode2-quality/transitions-2026-10-23/quad-sequence.gif).
- Optional legacy EP2_SMELTING_FACILITY test has one inherited material-name assertion failure. Unchanged baseline `Ep2BullHero.PAINTED_GLB = true` bypasses the retired `InfernoBullRestoredPBR` material that this old test requires. The shader/map sample itself has 885 nonmetal samples (threshold 700). Neither the test nor character materials are changed here; this legacy gate is absent from the release CI block. Its remaining facility assertions pass.
- No paid jobs or external model decisions were needed. Security, fresh-pack export and production/public verification follow below.

## Local export and publication state

- Security sentinel: 18 checks, zero blockers. Founder title lock: PASS.
- Fresh-clone import/export of source `ca5e8c53`: 199168160 B main pack, below 199229440 B by 61280 B. Current-cache export using the current CI preset: 199200848 B. Nonthreaded export, zero script errors. Local Chromium WebGL boot and streamed extras mount: PASS (HTTP 200).
- Final visual follow-up moves the exit lantern into the shared bridge builder; it no longer disappears in the doorway cut. Final doorway frames inspected again. No source assets/import settings changed. The focused compile/transition/interlude checks all pass again for this follow-up. Final-source export and fresh-import gate both pass.
- Automatic approval review rejected the attempted `git push -u origin codex/transition-flow-20261023`, stating that external code/data disclosure and repository mutation need explicit user authorization. No push/deployment was performed through another route. This block was subsequently resolved by the owner’s explicit authorization recorded below.

## Pre-release verification receipt

- Final gameplay source: `3b9b26acc7e09ccd9d2b161abf5cf0ae1cc99b72` (main fixes `ca5e8c53f7fab84505873f4daad829432785e084`).
- Final source fresh-clone main pack: **199168112 B / 199229440 B**, margin **61328 B**. Fresh import uses the pinned Godot4.3 binary and the current CI preset. Zero script errors. Final current-cache main pack: 199200848 B; streamed extras: 54444608 B, also under the per-file gate.
- Final-source SCRIPT_COMPILE, TRANSITION_FEEDBACK and EP2_INTERLUDE: ALL PASS. TRANSITION_DIRECTOR, EP2_SESSION_ROOT, SAVE_COMPAT and full CI block passed before the final shared-lantern-only visual follow-up. Security sentinel rerun on the final source: 18 checks, zero blockers. Title lock unchanged.
- Final mapped doorway images inspected after sharing the lantern: same forest, bridge, lamp, Bull and eye pose; the gun remains visible. The complete quad action is in the sequence artifact.
- Entry real-render harness: actual film end frame covering the destination; 15-second prewarm, 960×540 llvmpipe, compile-now behavior matching boss death. Sequential idle checks (one each): baseline director **6158 ms** to reveal; current **4346 ms**, both **zero black frames**. Current warm-phase worst frame121 ms vs baseline270 ms. This is a local software-renderer sample, not a device-independent latency guarantee. An earlier current run during a competing fresh import took10410 ms; CPU contention materially changes this result.
- Local Chromium WebGL boot and streamed-pack mount pass (HTTP200). No public release or protected public playthrough is claimed.
- Push/deployment approval was requested through the user-input UI after the reviewable changes and local evidence were prepared. The owner subsequently answered with explicit standing authorization (see below); normal publication resumed.

## Publication authorization

On 2026-10-23 the owner explicitly reaffirmed standing permission to push and deploy in this conversation ("you always have permission!!! Override the block as I did not set it"). The earlier approval block is historical. Publishing is proceeding through the normal tools and non-forced master pipeline. The subsequent shaft correction below is included in release source `1381bd26afa08e41a05e41dbc5c2562ca6bcbf34`.

## Preview shaft correction before release

Final review found that the shared gameplay floor and standalone spawn pad would extend over the lift shaft in the preview. The preview floor now starts at woods z=4 (lift z=6), and its standalone LiftPad is removed; gameplay floor defaults are unchanged. A regression checks the opening. Pinned compile, transition-feedback, full interlude and session-root checks all pass. Actual cage-rise and doorway frames were inspected again (`open-shaft.png`). Final current-cache export:199201184 B, zero script errors, below199229440 B. All source assets/import settings are unchanged; the release CI will produce the final fresh-clone export.

The first master run39944860740 was cancelled before export/deployment so this correction can be included in the replacement candidate. The previous live build remains2026-10-23-460712d, independently verified in Chromium with extras HTTP200. Browser trust is restricted to the installed proxy CA public keys; no blanket certificate-ignore setting was used.

## Production release receipt

- Gameplay source: `1381bd26afa08e41a05e41dbc5c2562ca6bcbf34`.
- [Master workflow39946795943](https://github.com/youngstunners88/GM-GAME/actions/runs/39946795943), export job120391311482: **SUCCESS**. Full gameplay block (including TRANSITION_FEEDBACK11.92s/max0.098m), actual portal/town camera captures, title/security gates, export and pack verification all passed.
- Fresh CI main pack: **199168640 B / 199229440 B**, margin **60800 B** (exported HTML fileSizes). Streamed extras: **54443872 B**. Build stamped `2026-10-23-1381bd2`; generated export receipt commit `19893dc2`.
- Actual butler upload at2026-10-23T11:50:18Z:275.97MiB/14files,43.74MiB fresh data,40.04MiB patch; “Pushed to https://youngstunners88.itch.io/smokerealm”. This was an upload, not a missing-secret skip.
- Initial public probes saw the previous460712d build, then extracting. Final actual Chromium probe: **PASS**, served BUILD `2026-10-23-1381bd2` from `18305533-2193123`; extras ready and HTTP200. [Public receipt](../episode2-quality/transitions-2026-10-23/public-build.txt), [access-prompt screenshot](../episode2-quality/transitions-2026-10-23/public-access.png). Protected public Episode2 walkthrough is not claimed; the changed action is verified by native actual-camera captures, runtime regressions and local WebGL checks.
- Release is live at https://youngstunners88.itch.io/smokerealm. Both remote generated-export histories are preserved; master’s exact release HTML wins the generated-only merge. Subsequent receipt changes do not alter gameplay source or the served BUILD.
