# Bull hand props, hideout and mine repair

Baseline: master `d9c000673cae48afd6a3877cb5b9aa670caafd66` (Claude's latest TransitionDirector work retained). Native captures: Godot 4.3 Compatibility GL, llvmpipe, 960 × 540. Same player-view rig and runner distances before/after. Tight hand crops are supplementary; gameplay-scale captures are on the boards.

| Defect | Repair | Native verdict |
|---|---|---|
| Whiskey absent after the default film | Return existing glass to left hand after equipment delivery; nonmetal textured material visible without reflections | PASS: fresh VERB_TEACH facility, visible glass |
| Winchester hidden by body/attachment orientation | Sync rigid props from final modified bones, respecting whole GLB node matrix; distinct personal gun and traded reward | PASS: seated, carry, offer, film resume |
| Resting forearm curls into coat | Scoped modifier restores imported right-arm rest rotations during idle only | PASS: relaxed arm; no mesh/skin edits |
| Furnace blocks Fort Knox | Move furnace beside exit; add stone jambs and partly open timber doors | PASS: doorway clear; existing exit unchanged |
| Repeated mine shell / weak room framing | larger staggered MultiMesh timber pressure bents, elongated wood grain, rock relief and ore outcrops; pegged hideout joinery, hanging lanterns, brown textured rocks | PASS: 20/100 m and player arrival / left / right / back / up |

556 assertions pass in all 17 bounded Episode 2 suites. Compile passes 280 scripts / 207 scenes. Front-page lock, green VFX and staged security sentinel pass. Fresh nonthreaded Web PCK: 197,183,504 bytes, below 199,229,440. Protected models, Lil Blunt, film, music, progression, economy, access gating and keyboard bindings retain their original sources.

The founder's image supplies composition/material hierarchy; these are actual game captures, not generated concept images. Full cinematic fidelity remains PARTIAL: some existing cauldron, skull, gold and flame materials remain simpler than the reference. No paid assets commissioned. No provider score or calibrated blotch pass claimed. Blotch-hunt was invoked but stopped during live URL resolution, before analysis. Native capture/test shutdown still emits pre-existing material/resource cleanup warnings, also present in the baseline. No script/parse failure is accepted.

Browser mine PASS (final PCK): near/mid run captures, observed rails 1 -> 0 -> 1 with ArrowLeft/ArrowRight, zero script/page errors.

Browser local PASS: invalid access code rejected; default film -> target practice; real mouse yaw 0 -> 1.312 rad; W moves (-0.7,0,5.4) -> (1.491184,0,5.980082); click requests pointer lock; K controls; zero script/page errors.

Release status: local verification complete; live completion is recorded separately after the exact CI/butler run and matching public BUILD. Browser review uses a fresh context, blocks external backend/telemetry requests and injects only a saved-unlock fixture into test HTML; the original PCK and shipped gate are unchanged. Pointer-locked synthetic headless mouse motion has cancelling recenter events; unlocked real mouse events verify camera turns. Movement must be observed in game telemetry while a key is held.


## Verified release — 2026-10-03

Source `3469b642d085b80be2ce947214eb9d2e516f53bc`; public build `2026-10-03-3469b64`. [Release workflow](https://github.com/youngstunners88/GM-GAME/actions/runs/37141122366) completed successfully, including secret scan, Security Sentinel, protected title screen, rendered portal checks, nonthreaded Web export (188 MiB), security audit and butler upload. The public itch iframe displayed the matching BUILD.

Desktop live input PASS at 1280 × 720: invalid entry rejected; default film resumes into VERB_TEACH target practice; mouse yaw changes from 0 to 1.312 radians; W moves from (-0.7, 0, 5.4) to (1.052947, 0, 5.864066); pointer lock is true after click; K controls invoked; zero script/page errors. `browser-live.json` records the run, with `live-bull.jpg` from the actual Web renderer. The near-side whiskey is visible; the far-side personal gun is occluded from this side angle, with the fresh native frontal crop proving both hand props. Full cinematic fidelity remains partial. Mobile and long soak were not checked. Backend/telemetry traffic was blocked, and the second navigation used the documented HTML-only saved-unlock fixture; shipped PCK and gating are unchanged.

`release-receipt.json` passes the player-quality receipt checker. `ci-deployment.json` retains deployment step outcomes. Only the verified prose fingerprint is ignored by gitleaks; the subsequent full CI scan passed.
