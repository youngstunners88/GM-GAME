# Rich's Armory trade — 2026-10-17 (Asia/Seoul)

The founder lock `PROMPT_EPISODE2_RICH_ARMORY_UTAH_RIVER.md` is built through the counter on branch `feat/rich-armory-lock`: the off-street building and lane, Rich and Utah as rigged, animated bodies, and the crypto-only trade that sells the long rifle, cartridges and the river gear.

Evidence, all with pinned Godot 4.3 (`tests/`):

- `ep2_gold_town_test` ALL PASS — 18 Armory checks: the lane walk off Main Street and in through the door, both shopkeepers present before entry with authored clips playing (`counter` / `idle`), the trade offered at the counter and nowhere else, the purse as Episode 1 crypto, no-crypto refusal, the long rifle bought once for 3 debited coins, cartridges only behind the rifle, river gear, a non-crypto tender refused, Esc closing the trade, `GEARED` reached with both in hand, and the ending payload carrying `armory_visited` / `sniper` / `sniper_rounds` / `river_gear`.
- `ep2_personal_armory_test` ALL PASS (73 checks) — the earlier purchase contract plus the new catalogue-shape, not-a-quick-switch-slot, sniper/river purchase and snapshot round-trip checks. GameManager disk round trip, corpse search and surface retry still pass.
- `ep2_fort_knox_arc_test` ALL PASS — the town beat list asserted as `STREET … WON, TIP, ARMORY, GEARED, DONE`, no banned narrative beats.
- `scripts/ci-gates-local.sh` — every CI headless gate passes locally (pause tap-target machine difference tolerated: 3 lines). The xvfb render capture stage is skipped on this box (needs apt/xvfb).
- Bodies: judgment renders of the shipped GLBs are in `captures/` — Rich `rich_idle_front`, `rich_greet_front`, `rich_counter_three`, `rich_walk_three`; Utah `utah_idle_front`, `utah_idle_side`, `utah_greet_front`, `utah_carry_three` — rendered from the clips the room plays (or the next beat's clip), against `utah_ref.jpg` and Rich's founder art. These are Blender renders, **not** in-game gameplay-camera captures — that capture remains outstanding on this box.
- Honest boundaries: no export, no deployment and no recorded voice belong to this entry. `RICH_UTAH_LINES.md` scripts the voice pass; nothing there is voiced. The day-88 river set-piece itself is not built.

---

# Western icon armory and Blender correction — 2026-10-15

The founder rejected the old text panel and primitive Remington. The current correction replaces both: actual weapon renders, western leather/brass/Bookman styling, hold/preview/release selection and a real SceneTree pause. Keyboard, controller, raw second-finger hold/drag/release, frozen world physics/reload clocks, release/cancel/focus-loss/scene-exit cleanup and existing pause ownership are exercised by `ep2_personal_armory_test`. Portrait uses a 390-unit stacked layout; font MSDF preserves scale.

The Remington and contact-fitted hand are authored in headless Blender. Editable sources, reproducible commands, budgets/provenance and finite-geometry checks are in `blender/`. Existing Winchester source assets and Claude's world/Bull/town choreography are unchanged. Existing earned ownership, finite independent ammo, corpse arrows, source-gun acquisition, viewport handoffs and checkpoint conservation still pass.

Validation: compile, personal armory, range lesson, smelting facility, session root, town, companion/cart, interlude, save compatibility, runner revolver and Stage 3 revolver all pass with pinned Godot 4.3. The broader pause-menu suite reports three existing fullscreen-button hit-target collisions; an isolated checkout of unchanged master f6203903 reproduces those same three profile failures (and one additional baseline scene-start timing failure whose cause was not investigated). None involves the Episode 2 selector. No unrelated mobile layout source was changed.

The current nonthreaded web export is 199,005,552 bytes (189.79 MiB), below the 190 MiB gate. Strict local Chromium verification passes all five game gates with PLAYING observed and no errors. TLS remains enabled; the provided platform proxy CA is trusted only in a disposable browser profile constrained to the four existing game hosts, then removed. Native camera captures show actual selected guns, ADS, empty ammo and the icon selector with an explicit earned-guns/three-arrow capture fixture; actual corpse/checkpoint tests are separate.

The requested Jev 1.14 routing skill and request helper are separate from runtime gameplay. The user subsequently selected direct TypeSafe. Six offline tests pass for bounded JSON/binary multipart, provider/credential separation, pins, typed output and no retry/fallback. The live direct request fails at proxy CONNECT 403 before provider acceptance; no Jev visual verdict is claimed. Official SDK sources establish the image encoding, not a successful account call. Context limits and model-specific pricing remain unverified.

Publication and live status must be recorded in release-receipt.json. Public GitHub Actions/itch and TypeSafe API/docs remain blocked. A narrow network draft update returned INVALID_ARGUMENT; revision/readback retained the four previous game-service hosts. No network configuration change or live deployment is claimed.

---

## Historical first implementation (superseded presentation)

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

The real prebuilt-room activation path is now exercised: removing/re-entering the viewport must reconnect firearm and selection callbacks once. Surface inventory is captured during setup before the first player input, rather than after an early shot. Both regressions pass against WoodsQuadChamber.

Final source publication: master `2f0a58a9` includes runtime lifecycle correction `d0b4b18d` and every preceding armory change. The shipping script verified compile, armory, range, facility, session, town, companion/cart and interlude gates, plus security sentinel and title-screen lock. Final PCK: 198,484,640 bytes (189.29 MiB), nonthreaded Compatibility export.

The strict local browser check now passes with PLAYING observed and no errors. Chromium's regular-profile root import was rejected by automatic approval because it would persistently broaden that profile's trusted roots. The recommended safer alternative succeeded: a temporary isolated profile used the environment's provided CA, constrained to the four already-allowed game-service hosts. TLS verification stayed enabled; the temporary profile was removed after testing. No regular-profile or system trust setting was changed. This is local game validation, not public upload/BUILD verification.

See release-receipt.json for the exact final source and checked/unchecked results. GitHub Actions/itch endpoint access and both requested decision reviews remain blocked by the environment's restricted HTTP policy.
