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
