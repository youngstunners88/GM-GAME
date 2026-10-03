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
