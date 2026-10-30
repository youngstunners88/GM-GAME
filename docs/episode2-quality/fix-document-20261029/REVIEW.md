# FIX document repair — verification

Brief and source revision: [founder FIX document](../../founder-feedback/2026-10-29_fix-document.md). Final runtime verification baseline: `5828ac41` (includes `8c082cca` and `a44d40be`). Publication proof is recorded separately after deployment.

## Result by complaint

| Complaint | Implemented behavior | Evidence |
|---|---|---|
| Tunnel film glitches | No separate elevator viewport behind playback; hidden room children stop processing; streamed prop upgrades wait. Normal processing and early elevator preparation resume in the lesson. Full founder video/audio, skip policy and fallback remain. | continuity log; exported-browser result and film frame |
| Facility → elevator glitches | Preserve real oblique gaze, position, held movement and stride; mirror Inferno's clip phase and owner; suppress duplicate preview gun/HUD. Inset the portal image beyond the camera near clip and preserve opaque foreground depth. | before/after camera frames, continuity20, native/WebGL pixel oracle |
| Sheriff bouncing | Keep founder mesh/materials; add a weighted nine-bone lower-body skeleton and speed-matched grounded walk. | Sheriff pose strip, Blender skin QA, motion13 |
| Rich / dismissible tabs | Top-left × calls each panel's own close/resume path. Trade, map, selector, both pause paths and other dismissible tabs use the shared control. No synthesized Escape/fullscreen calls. | panel8; exported desktop fullscreen click checks |
| Utah erratic walk | Instance-owned grounded walk/carry clips use his rig's rest transforms. Existing working gestures remain. | Utah pose strip, motion13, full town rerun |
| Mike Dean → Dude / horse | Town boundary lies beyond the actual ranch. The same referred Dude/yard owns negotiation and E mount. Unfinished town return preserves the active errand and objective. | routed document12; full town, stable and route regressions |

Three reusable skills were added: `ep2-founder-regression-repair`, `ep2-story-boundary-regressions`, `ep2-gaits-and-panel-exits`. The context manifest and CLAUDE routing point to them.

## Checks

- 55 focused native checks pass: routed story12, gait13, continuity20, close8, actual Compatibility pixels2. Logs reject script/parse errors and pin completed counts.
- Sheriff maximum stance-height error0.915mm, frame slip0.280mm; Utah walk0.658/0.155mm, carry0.821/0.153mm. Swing clearance≈75mm. These are final-scale FK measurements across loops, not clip-name checks.
- Complete local CI headless block was run. Its only new failure was the old full-town whitelist rejecting the newly installed `GroundedCarry` name. The whitelist was updated and the **entire town story rerun passes**. Existing three pause geometry differences are the exact machine exception already documented in `ci-gates-local.sh`. Other gates passed. `regression-results.txt` retains both the original result and corrective reruns; it does not represent the initial run as wholly green.
- Full town, transition prebuild, film feedback, interlude, doorway stride and seamless chain reruns pass. Blender skin QA passes with normalized weights, no unweighted vertices, and ≤4 influences. The intentional in-place pelvis root warning is retained.
- Real nonthreaded Godot4.3 Compatibility export: **197,567,376B** main pack, zero script/parse errors. Fresh-clone import/export: **197,534,560B**, below199,229,440B by1,694,880B. No unrelated texture/model degradation was introduced.
- Exact exported engine/packs:8 browser assertions pass; trade/map/Episode1 pause/selector click-close preserve actual DOM fullscreen. Explicit fullscreen exit still works. Additional WebGL foreground/background pixel assertions:2 pass.
- Full film reaches decoder reason `end`, ready lesson, no elevator rendering during playback. Solo software-WebGL sample:60.803s wall,59.499s last sampled stream position,606 render callbacks, worst callback interval1.184s. Stream-position updates are an audio/decoder clock, **not decoded video frames**. This is completion/background-work evidence, not a smooth24fps or phone-performance certification. A previous heavily contended run is not used as a benchmark. Native video-file decode also completes without errors.
- Title-screen lock, harness inertness, security and texture-reference gates are required in the final release gates. Actual production CI and public BUILD are required before marking deployment complete.

## Evidence and limits

The native pictures use the real player camera. The external-only web fixture uses production engine/packs and actual panel hosts; UI-only checks turn off the town's3D renderer after the film to avoid measuring software scene rendering while testing dismissal. It adds no shipped unlock, debug URL or story warp. The WebGL pixel fixture tests the shipped shader directly. An initial pixel-fixture HTML syntax error was corrected in its external bootstrap; the final WebGL result has no script/GLSL failures.

Synthetic CDP Escape did not leave fullscreen, also reproduced on a minimal browser control. It is not claimed as proof of the browser's physical Escape shortcut. The implementation leaves that shortcut untouched; explicit intentional exit and click-close/fullscreen retention were observed.

No physical-phone certification or authenticated public-origin Episode2 walkthrough is claimed. Public boot/access checks and external replays of exact public packs must be distinguished in the release receipt. No Meshy/provider credits were spent on this repair. Blender4.3.2 was available; the documented5.2 executable and game-dev CLI were absent.
