# Smelting facility ↔ elevator repair

The previous code could resolve2.4m before the physical doorway when the preview was inactive, omit the actual player position and use the lift's directed spawn. A0.9m overlap in the return boundary could then bounce a newly entered player back after cooldown. Both directions now use the same physical plane, independently of which way the player looks. Destination readiness and the existing story exit remain required.

Height, vertical velocity and consumed air-jumps survive the crossing. Inferno transfers his actual rotation and skeletal transforms; immediate bone-transform flush prevents a stale first pose. A retained lift explicitly restores its HUD and viewmodel after a preview, without resurrecting a companion who has left that part of the story.

The visual preview also had two problems. A broad1.6m depth guard kept nearby old-room walls and Inferno visible over the elevator. A weapon-only alpha render now protects camera-held meshes while replacing world scenery at the near clip. The already-graded destination image was graded again by the facility; the portal material now inverts the pinned Godot4.3 GLES3 source-room output transform. Coefficients/order were checked against official4.3 `drivers/gles3/shaders/tonemap_inc.glsl`, `effects/post.glsl` and `scene.glsl`.

The actual Compatibility paired capture is [native-cut-pair.jpg](native-cut-pair.jpg). It compares the same eye/simulation instant on either side. Capture simulation is frozen, the real post-lesson stand-up is completed, the armory is seeded and the camera explicitly updated; slow software frames otherwise create misleading actor movement. Physical movement is verified separately by the stride, airborne and return tests.

Verification:

- Full local CI headless block passes with its three documented machine-dependent pause-layout exceptions.
- Final affected reruns: crossing8/8, airborne/pose continuity20/20, retained world routes28/28, door-stride and seamless-chain pass.
- Actual OpenGL Compatibility foreground/near-wall oracle2/2; real chamber capture completes without script/parse/shader failures. Native renderer teardown emits resource-leak diagnostics, retained in the evidence rather than counted as gameplay success.
- Title-screen lock5files, harness/access isolation and security sentinel pass. No paid-provider spend, asset degradation or export threading changes.

Baseline masterbf6c9957 includes concurrent mobile controls and is preserved. Final warm/cold exports, browser replay, CI deployment and observed public BUILD will be recorded in the release receipt. A native paired capture alone does not prove the public game.

Final warm export:197660832B, script_errors=0. Fresh clone export:197628144B, margin1601296B under199229440. Texture-reference probe scanned68models with0excluded-but-used textures. The external web replay loads scenes dynamically after autoload initialization (a preload in the first fixture draft compiled before AudioManager was available; that fixture was rejected).

The WebGL replay uses a640×360 internal viewport, displayed in1280×720 Chromium, because this environment renders through SwiftShader. It holds each capture until the browser takes its screenshot, using an external F9 handshake; this is not a production input binding or access bypass. The full-resolution native pair remains the detailed art evidence. Browser before/after images retain the same camera and companion geometry; fixed-size HUD text looks enlarged at the fixture's internal resolution.

Local exported-pack browser replay passed: one resolved crossing, expected inside camera(0.3,1.55,-11.6), visible HUD/weapon, all three captures, no script/parse/shader/page errors. See evidence/local-web-result.json and local-web-pair.jpg. Release verification follows separately.
