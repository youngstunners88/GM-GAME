# Armory implementation evidence — 2026-10-15 (Asia/Seoul)

Implemented the session-owned armory convention, real first-person golden Remington, named quick slots, independent finite ammunition, touch/controller selection, keyboard rebinding, searchable persistent bear bodies and atomic surface resource/loot restoration. See CONVENTION.md for the behavior and limits.

The Winchester uses the existing founder firearm and hand assets. The repository's runner references `golden_revolver.glb`, but that file is absent. The new dedicated FPS Remington is procedural geometry built against `artifacts/founder-art/references/stage3_golden_revolver_reference.jpg`: gold barrel/frame/cylinder, six chambers, under-barrel web/ejector, walnut grip, sights, hammer, trigger guard and Lil Blunt's leafy grip/bracer. It uses the existing revolver reports, empty and reload sounds. It is not a new Tripo/Meshy generation or a fully articulated finger/reload rig.

`tests/ep2_personal_armory_test.tscn` exercises real resource transactions and integration: earned old-save migration, invalid save shapes, GameManager disk round trip, independent ammo, dry fire, 180 ms swap gate, retained cooldowns, interrupted/completed loading, no attach/prebuild refill, keyboard/controller routing, raw finger events, modal fire/movement blocking, hideout acquisition/lesson lock, finite runner reload, a real bear corpse search and full surface retry. CI runs this gate before export.

Existing range lesson, smelting facility, session root, save compatibility, runner revolver, Stage 3 golden-revolver, GoldMine town and interlude tests passed locally with pinned Godot 4.3. The title-screen fingerprint gate and security sentinel passed. Final merged-source compile, armory/lesson/world gates and pack result are recorded by the release validation script/output.

`tools/ep2_shots/armory_shot.tscn` captures the actual mine-lift scene using native Godot 4.3 Compatibility rendering. The capture explicitly declares both acquired guns; the panel's three arrows are a capture fixture. The real corpse claim is separately tested against WoodsQuadChamber. Captures show the named slots, each firearm, Remington ADS and empty count, and arrow storage. No live browser traversal or fully articulated reload hand is inferred from these captures.

Both requested decision models were attempted using the existing API credential: `~typesafe/jev-latest` and `microsoft/microsoft-decision-1`, OpenRouter `/api/alpha/decisions`. Both connections failed at the mandatory proxy with `CONNECT tunnel failed, response 403`. Neither model supplied a recommendation or ship verdict. The proposal, measurements and tests are local evidence, not external model approval.

Claude's concurrent town, cast, road, companion and Bull asset work is preserved through a fresh non-forced merge of master. Publication must use the existing master export/butler workflow. A pushed source commit is not live deployment proof: GitHub Actions upload logs and the public BUILD must be checked separately. At implementation time the Actions/itch endpoints were blocked by the cloud proxy.

Final local release validation: merged source includes Claude's `236ff712` Bull shape/pipeline commit. Script compile, armory, range, facility, session, town, companion/cart and interlude gates passed; save/runner/Stage 3 gates also passed during implementation. The 4.3 nonthreaded export measured 198,479,472 bytes (189.29 MiB) before the small restart correction. All five local browser game gates passed and PLAYING was observed; the strict browser check remained failed because remote backend/telemetry fetches hit `ERR_CERT_AUTHORITY_INVALID`. TLS verification was retained.

Source `388dbc0c` was published through merge `fba4e6b8` by the non-forced shipping script. Final review then added saved training completion/shared gun restoration for hideout restarts, with real re-entry and full-gun lesson assertions. The final release commit/export must include that correction.

GitHub Actions API and the public itch page each returned HTTP 403. A configuration draft adding `api.github.com`, `openrouter.ai`, `youngstunners88.itch.io`, `itch.io` and `html-classic.itch.zone` was attempted, but the configuration service returned INVALID_ARGUMENT and could not confirm saving. Readback still contained only the prior four custom hosts. No network setting was applied and no deployment success is claimed.

The final finite-ammo integration also restores the runner-entry resource checkpoint on a failed attempt and cancels an incoming FPS loader before the runner cylinder timer takes ownership. The armory integration gate exercises both paths.

Restart corrections `52467762` and `87d3a8e8` reached master after a safe merge of CI export commit `83e80f7d`. A final cached-view lighting correction applies the existing Winchester daylight treatment even when the Remington is initially equipped, and applies shadow settings to both cached props. Its regression assertions pass. No firearm art, title screen, world choreography or tuning numbers changed in that correction.

Cached lighting correction `231fcca3` reached master. Final carry regression checks that an equipped prop is already positioned/oriented before its first physics tick, preventing a camera-origin frame during fast switching. Ammo tooltips use player-facing wording.
