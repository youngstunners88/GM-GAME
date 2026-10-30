# Facility/elevator physical crossing repair

Founder reports the transition still breaks. Baseline masterbf6c9957 includes concurrent mobile-control work, preserved by fast-forward.

Two concrete remaining logic defects: when the preview was not live, facility EXIT could resolve at z14, 2.4m before the physical plane16.4; get_handoff then omitted lift_player because it also depended on preview visibility. The lift could use its directed spawn. Also the retained lift return threshold extended0.9m into the lift side; after cooldown a just-entered player could be returned to the facility.

The crossing now depends only on the open story exit, destination readiness and physical plane. Looking away never changes the collision or spawn decision. Both return directions use the same plane. Existing rendering, dialogue, held movement, animation and access/title locks are preserved.

Focused results: new physical-crossing8, existing continuity20, world-routes28 (including cooldown bounce/reverse), door-stride and seamless-chain pass without script/parse failures. Full workflow, actual Compatibility camera sequence, final export/pack and release/public verification are pending; no live claim yet. No paid-provider spend.

The lift also forced incoming player height to0. The physical handoff now preserves airborne height, vertical velocity and air-jump usage. Continuity20 is strengthened to cross at y0.6 with upward velocity2.3; its final rerun is queued separately because the full run began before this small correction.
