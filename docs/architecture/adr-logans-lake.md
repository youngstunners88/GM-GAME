# ADR: Logan's Lake as an Episode 2 interlude

Accepted 2026-10-19. Authority: `design/ep2/lake/LOGANS_LAKE_LOCK.md`.

Use the existing Ep2Interlude/session chain so first-person weapons, finite ammo,
pause, input and prebuilding remain shared. GoldTown's geared result names
`logans_lake`; it waits for prebuilding rather than ending the episode. The lake
is distinct from Town Stockpile and contains no economy calls or rewards.

Use five local beats and one range/beat-gated interaction. Dialogue is captioned;
the stage action checks existing cargo once. The visible narrow outflow and high
overlook establish the next day-88 encounter. That later sniper/bear encounter
requires its own future implementation and is not claimed here. No new save
format is introduced; the lake's staging state belongs to the current visit.

The supplied 65-joint Logan skin is retained, with source-rest-space gestures.
Blender tools operate on a derivative, preserve UVs/weights and record measured
repairs. Sources are dev-only. Godot gets a plain GLB, existing texture families,
instanced forest and one simple water material, under the existing web pack gate.

Regression evidence: ordinary movement through the complete lake, rejection of
early/far/repeated interactions, conserved armory snapshot, world/water bounds,
town transition result and real Compatibility/browser captures. Security/title,
texture references, fresh export size and actual deployed BUILD remain release
requirements. GPU credit authorization does not replace credential readiness.

Uses ADR-0005’s existing streamed extras pack for Logan, preserving his exact GLB
and texture bytes. The lake delays interaction while the pack loads and offers
a retry on failure. The original town fallbacks remain unchanged. Browser proof
must cover mounted textures and the slow/failure path, not just native art.
