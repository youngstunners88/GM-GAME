# Logan's Lake — verified public release,2026-10-27

**LIVE:** https://youngstunners88.itch.io/smokerealm
**BUILD:** `2026-10-27-b1615aa`
**Released source:** `b1615aaceeec51538bed3004dc629a7a095a96db`
**Production CI:** https://github.com/youngstunners88/GM-GAME/actions/runs/40444088899

The production run completed successfully, including the full regression suite, camera captures, export and86-check lake resource gate. The actual butler log confirms53.28MiB fresh data uploaded. Public Chromium confirms the exact BUILD and streamed extras HTTP200; the Episode2 access gate remains present.

## Actual public build checks

- Downloaded public `index.pck`:198775376bytes; `ep2_extras.pck`:105989440bytes. Both below199229440bytes/190MiB, without unrelated asset reductions.
- Empty-project packed imports:86 checks pass, including actual textures, forest geometry, independent oars/contacts,18 waterline sections and the original Logan65-bone skin/four clips. Raw source files cannot mask missing imports.
- Actual public-pack native Compatibility replay:12 checks pass. Ordinary movement reaches Logan/cargo/overlook; touch stages once; dialogue holds departure; Logan boards/rows; two complete strokes retain palm/seat contact; inventory stays unchanged. An independent raycast of the drawn terrain confirms support beneath Logan.
- Actual public-pack browser WebGL replay: the same12 checks pass, with no script/shader errors. Public engine JS/WASM/Web3 files match the tested local release binaries. This uses a local-only external fixture with the downloaded production packs; it is **distinct from an authenticated public-origin lake playthrough**. No production unlock or URL bypass was added.
- The public-origin browser separately verifies BUILD, extras and preserved access controls. `verification/PUBLIC_RECEIPT.json` records exact public URLs, pack sizes/hashes and evidence boundaries.

## Source and visual checks

Pinned Godot4.3 Compatibility art/contact23 checks and the original lake story route pass. The contact test independently raycasts the actual generated terrain triangles; a height-function-only check had missed interpolation beneath Logan's boots. The final surface and waterline soil band are corrected. Independent palms, seat, boots and unchanged limb lengths are checked over two complete strokes; blades enter water on power and clear it on recovery.

The complete hosted regression suite passes on the final source. Local compile/save, merged concurrent bridge/door/music tests,69-model excluded-texture probe (zero references), title lock5files, harness and security checks pass. Concurrent master work is preserved. Nonthreaded Godot4.3 Compatibility export remains intact.

Six actual player-camera views, boarding and eight rowing phases were inspected. Final player views are `verification/after-*.jpg`; the actual public capture is `public-lake.jpg`. `logan-rowing.mp4` contains90 real native frames at15fps, six seconds of rowing (motion validation before the final shore-only refinements; same actor/oar geometry). No generated/interpolated frames.

Actual Meshy spend **30 credits**, preview20+texture10; no reruns. Sanitized provider task receipts and provenance are included. Blender4.3.2/local tooling were used because documented Blender5.2.2 and Game Development Studio `game-dev` were unavailable. The normalized boat/forest mesh QA reports pass; founder characters and existing world art remain intact.

Automatic approval review rejected canceling the superseded pre-export run for lack of explicit cancellation authorization. It was left running; the final revision completed the normal release queue successfully.
