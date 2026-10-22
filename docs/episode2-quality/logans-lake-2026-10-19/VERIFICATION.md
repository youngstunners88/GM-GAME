# Logan's Lake verification

Implementation: `design/ep2/lake/IMPLEMENTATION.md`. Scene:
`src/episode2/chamber/logans_lake.tscn`. Publication remains pending release gates.

- Pinned EL4CTEO toolkit: 22 skills and six project adapters for both agents;
  receipt verification passes (89 files per installed upstream copy).
  Upstream suite: 47 passed, three GPU-dependent skips; validator 22, triggers 25/25.
- Supplied Logan: 65 bones retained, four authored clips, 60,619 vertices,
  52,084 triangles, 4,207,292-byte GLB. Mesh and skin checks pass. The measured
  repairs and accepted split-vertex/hidden-face/rest-rig warnings are recorded
  in `logan-mesh-qa.json`, `logan-rig-qa.json` and `repair-tests.txt`.
- Dock: all 55 objects pass mesh QA (`dock-qa.json`). Piles intentionally extend
  below the deck origin; hidden cleat contact faces remain intentional.
- Full local CI headless gate block passes (the repository runner tolerates its
  three pre-existing pause tap-target geometry differences on this machine).
  Security sentinel has zero high-severity blockers; founder title lock passes.
- Native lake test: 20 checks pass, including normal traversal, interaction
  range/order/repetition, touch signal, armory pause and unchanged inventory.
- `native/` contains six final Compatibility captures. `motion-sheet.jpg`
  samples all four clips at start, quarter/midpoint and end. `mesh-review.jpg`
  records the repaired source geometry; these are not public-build captures.
- Independent visual review found Logan's identity, supplied accessories,
  materials and grounding preserved, and the dock/rifle visually unchanged.
  Terrain/foliage differences are intentional. The reported cargo-sign overflow
  was corrected by widening that new sign. Sparse forest and the straight
  overlook trail remain visual-polish limitations.
- Latest local nonthreaded web export: zero script errors, main pack
  199,048,048 bytes (limit 199,229,440). Full-quality Logan is in streamed extras;
  no unrelated assets were reduced. Fresh-clone release measurement still required.
- Itch-style gzip test: PASS, `[EP2] extras ready (ready)`, HTTP 200.
  Uses browser fetch + Engine.copyToFS, including cancellation on retry/timeout.
- Previous full plain-HTTP browser route passed the access gate, mounted Logan,
  walk/meet/cargo/overlook and held-armory world freeze. Injected-download-failure recovery also passes: player retry mounts the pack
  and restores Logan. See `browser/retry-before.png` and `retry-after.png`.
  Final gzip route also passes: access gate, supplied Logan, walk/meet, cargo,
  overlook and held-armory pause; see `browser-route.txt` and `browser/`.

No generated voice or later river sniper/bear battle is claimed. RunPod spending
was authorized, but RUNPOD is still absent from the running shell; no GPU credits
were spent. Public Chromium verification currently has a certificate-trust
limitation; TLS verification has not been disabled.
