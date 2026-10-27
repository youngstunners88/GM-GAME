# Lake release verification —2026-10-27

Status: production deployment/public proof pending.

Local final production export (Godot4.3 stable, Compatibility, nonthreaded):

- index.pck198808112bytes, below199229440-byte/190MiB limit (421328-byte margin).
- ep2_extras.pck105990144bytes. New art stays in existing streamed extras.
- Zero script/parse errors; pack presence gate passes.
- Empty-project actual imported-resource check:86 checks pass. It validates textures, forest pieces,18 hull waterline sections, independent contacts and unchanged Logan65bones/four clips without source-file fallback.
- Replay using only exported production main/extras: ordinary movement to Logan, investigation, touch staging exactly once, dialogue wait, boarding, two whole rowing strokes, invariant inventory and walk to high overlook all pass. Final contact and world capture: local-exported-lake.jpg.
- Real Chromium boots the exact local export and enters Level1 with no script/SharedArrayBuffer errors. This verifies browser boot/export compatibility; the lake route above is native Compatibility replay of exported packs.
- Complete repository headless CI block passes on lake implementation before concurrent P0 merge; only the script's3 documented local pause-layout differences are tolerated. The new23-check art/contact test and existing ordinary lake story route pass. After preserving master051b61df (bridge, door, music and voiced-story changes), compile/save and all3 new P0 regression tests pass. Lake route/art checks repeated after downstream terrain repair; final pack replay covers the final sign/understory cosmetics.69 model texture-reference probe:0 excluded-but-used textures. Title lock5files and security pass.
- Actual pose and player-camera evidence is in verification/. Full Meshy provenance and actual30-credit spend are in PROVENANCE.json. No additional provider jobs.

The public browser is expected to retain the existing Episode2 access gate. Browser gate/BUILD/extras evidence and native replay of exact public packs must be stated separately; no production unlock bypass is added.
