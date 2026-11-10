# Scoped player-quality audit — Dude's patch and healing item

The review covers the ranch plants, their shop showcase and the healing supply in Tabs. Existing title/access rules, weapon logic and nearby NPC behavior are preserved.

| Defect | Player impact | Smallest repair and acceptance evidence |
|---|---|---|
| Fragmented foliage (high) | Plants do not read as cannabis at buying distance | Accepted original-reference Tripo grove; same-camera before/after and three ranch angles show stems, leaf fans and purple flowers. |
| Slab/rails across plants (high) | Roots read as props balanced on lumber | Irregular textured ground mound and low boundary stakes; taller growth sits behind the bed and outside the paddock rail footprint. |
| Additive white emission (medium) | Texture colors wash out | Instance-local, non-metallic rough materials with albedo-multiplied fill; warm-ranch and neutral shop captures retain color. |
| Generic leaf in healing UI (medium) | Supplied actual bud is absent | Exact original-model render, streamed and asserted loaded; actual host restores 1 → 3 hearts, consumes one item and keeps pause ownership. |
| New preview caption overlap on short screens (medium) | Caption touches the purse | Found in landscape capture; pending obsolete deployment cancelled. 64px preview on short screens, re-captured at 844×390 and 390×844; healing test remains 14/14. |

Acceptance observations: approach and E trigger remain clear; world/soil materials are visible; plants are separate from UI; art neither intercepts pointer events nor changes stock/payment/save behavior. Final artifact, texture, raw touch/keyboard and pause checks are recorded in the report and local-verification receipt.

The existing unrelated weapon-ammo text overflow on a short desktop viewport remains as documented by the prior weapon-tab release. It does not block the changed bud interaction. No FPS improvement is claimed: triangle and pack budgets were measured; physical-phone performance was not tested.

The cloud quality-audit helper `scripts/preflight.py` and `game-dev` CLI are absent from this checkout/environment. Their receipts are not claimed. This pass used the existing pinned Godot, project regression/export tools, Tripo doctor/balance, environment readiness, actual GitHub job status and Chromium verification instead. No decision-service verdict was required or fabricated.

Public deployment/build/payload verification is completed separately before the release receipt is marked complete.
