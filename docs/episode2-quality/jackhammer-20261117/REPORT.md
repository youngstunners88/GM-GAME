# Official Jackhammer Wanted — 2026-11-17

Source: Drive `1GCG24Wf3uzR6GX_xVstsOFWnt596UEAM`, “Jackhammer Wanted”, 2048×2048 JPEG, 3,471,099 bytes. SHA-256: `2f8056dc2537b8986cbe67121379264a5fc65d23a4ba551a14096b3a53aea252`.

The original is preserved under `artifacts/episode2-gold-mine/references/`. The runtime PNG uses the existing founder-bill white-margin flood key (9% fuzz), trimmed/resized then centered on a transparent 1024×1024 canvas without stretching. Mipmaps enabled. No face, wording or reward was changed. Old JPEG and import removed; town loader accepts PNG only for Jack Hammer. Cabin, hideout, auction and cabin tooling use this same PNG.

Saloon's 0.62 m bill is Jack Hammer. Notice board: Jack Hammer 0.56 m, RH 0.40 m. RH also remains on Bldg_A and the cabin. Three 0.42 m Armory bills sit on timber backing over the old rectangular blank papers, at their original local centres; square paper alone would leave the old rectangular margins exposed.

The 4×4 m billboard is at Armory-local `(42, 3.5, 1.6)`, world `(-62, 3.5, 1466.4)`. The existing gun is at `(-29.6, 0, 1466.4)`. Building-footprint ray measurement found no building between them; the billboard is 35.2 m from the grazing horse. Its bottom is 1.5 m up; both solid supports are beyond all existing plates/bales. Center and four corners fit the gun's yaw/pitch clamps. Existing plate discs keep nearest-hit priority; the new target uses a rectangle. Same lit official texture, timber frame, 200 preallocated/reused holes, dust and hit signal, holed at 25 and shredded from 90 hits. No gameplay drum refill was added.

## Evidence

- `ep2_wanted_rebalance_test`: actual town, cabin, hideout and auction furnishing census; verifies canonical PNG, old JPEG absence, count and area dominance **excluding the range billboard**, Armory centres and widths, no overlapping wall bills, founder source hash, 1024 texture and torn alpha. CI runs it.
- `ep2_gatling_hits_test`: mount, mouse-look, camera ray, shoot; exhausts one drum against billboard, verifies visible holes/shred and bounded node count, then resets the fixture's rounds to prove every existing plate still hittable. The refill exists only in the test.
- Mutation checks: putting RH back in the large saloon slot fails the prominence gate; disabling the rectangle fails actual mounted hits, holes and shred. Restored both before final tests/export.
- Captures here are Godot 4.3 Compatibility renders of the real chamber at 1280×720. `board`, `saloon_porch`, `saloon_jack_close`, `armory_front/left/right`, `gatling_from_porch`, and mounted `gatling_clean/burst/shredded`. Reviewed directly.

Native evidence and release proof are recorded in `validation.txt` and the release receipt when available. Native renders are not founder acceptance. The source poster has no eye patch and specifies BTC; the model/narrative locks are unchanged. **FIXED remains pending the founder's hard-refresh town + Armory Gatling walk.**
