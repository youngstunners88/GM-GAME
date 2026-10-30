# Facility/elevator physical crossing repair

Founder reports the transition still breaks. Baseline masterbf6c9957 includes concurrent mobile-control work, preserved by fast-forward.

Two concrete remaining logic defects: when the preview was not live, facility EXIT could resolve at z14, 2.4m before the physical plane16.4; get_handoff then omitted lift_player because it also depended on preview visibility. The lift could use its directed spawn. Also the retained lift return threshold extended0.9m into the lift side; after cooldown a just-entered player could be returned to the facility.

The crossing now depends only on the open story exit, destination readiness and physical plane. Looking away never changes the collision or spawn decision. Both return directions use the same plane. Existing rendering, dialogue, held movement, animation and access/title locks are preserved.

Focused results: new physical-crossing8, existing continuity20, world-routes28 (including cooldown bounce/reverse), door-stride and seamless-chain pass without script/parse failures. Full workflow, actual Compatibility camera sequence, final export/pack and release/public verification are pending; no live claim yet. No paid-provider spend.

The lift also forced incoming player height to0. The physical handoff now preserves airborne height, vertical velocity and air-jump usage. Continuity20 is strengthened to cross at y0.6 with upward velocity2.3; its final rerun is queued separately because the full run began before this small correction.

Final corrections also preserve Inferno's actual skeletal pose and rotation, including immediate bone-transform flush. The initial broad depth guard retained nearby old-world walls and Inferno within1.6m; it now renders only camera-held meshes into an alpha mask. The actual Compatibility near-wall oracle passes2/2. Paired exact-eye images `mask-views/cut_a.png` and `cut_b.png` show stable geometry and pose; the surrounding facility remains naturally graded as the facility. The doorway image compensates its second grading pass using the pinned Godot4.3 GLES3 filmic/post coefficients (official drivers/gles3/shaders/tonemap_inc.glsl, effects/post.glsl and scene.glsl). The capture freezes simulation and completes the stand-up beat first, avoiding misleading slow-render movement. Retained lift activation also restores HUD/viewmodel after preview without resurrecting past-story Inferno.

Full local workflow passed with only its three pre-existing permitted pause-layout assertions; affected final source reruns and final warm/cold exports follow before release. Native process teardown emits renderer resource-leak diagnostics; these are not hidden or treated as browser gameplay proof. No script/parse/shader failures in accepted captures.
