# Official Jackhammer Wanted — 2026-11-17

Source: Drive `1GCG24Wf3uzR6GX_xVstsOFWnt596UEAM`, “Jackhammer Wanted”, 2048×2048 JPEG, 3,471,099 bytes. SHA-256 prefix: `2f8056dc2537b898` (full checksum in `release-receipt.json`).

The original is preserved under `artifacts/episode2-gold-mine/references/`. The runtime PNG uses the existing founder-bill white-margin flood key (9% fuzz), trimmed/resized then centered on a transparent 1024×1024 canvas without stretching. Mipmaps enabled; runtime import uses WebP at quality 0.90 to stay within the existing pack limit. The canonical PNG remains lossless. The compressed hideout warm-up manifest also names the PNG, so the film does not encounter a missing JPEG or a cold poster load. No face, wording or reward was changed. Old JPEG and import removed; town loader accepts PNG only for Jack Hammer. Cabin, hideout, auction and cabin tooling use this same PNG.

Saloon's 0.62 m bill is Jack Hammer. Notice board: Jack Hammer 0.56 m, RH 0.40 m. RH also remains on Bldg_A and the cabin. Three 0.42 m Armory bills sit on timber backing over the old rectangular blank papers, at their original local centres; square paper alone would leave the old rectangular margins exposed. Their roll follows the measured imported Paper vertices (Blender-to-Godot reverses the rotation); the gate checks every baked front-paper corner against the actual opaque backing geometry.

The 4×4 m billboard is at Armory-local `(42, 3.5, 1.6)`, world `(-62, 3.5, 1466.4)`. The existing gun is at `(-29.6, 0, 1466.4)`. Building-footprint ray measurement found no building between them; the billboard is 35.2 m from the grazing horse. Its bottom is 1.5 m up; both solid supports are beyond all existing plates/bales. Center and four corners fit the gun's yaw/pitch clamps. Existing plate discs keep nearest-hit priority; the new target uses a rectangle. Same lit official texture, timber frame, 200 preallocated/reused holes, dust and hit signal, holed at 25 and shredded from 90 hits. No gameplay drum refill was added. The optional poster-construction and frame/canvas/hole-pool builders stream with the art, keeping the core pack within its existing 190 MiB budget; hit logic remains in the gun.

## Evidence

- `ep2_wanted_rebalance_test`: actual town, cabin, hideout and auction furnishing census; verifies canonical PNG, old JPEG absence, count and area dominance **excluding the range billboard**, Armory centres and widths, no overlapping wall bills, founder source hash, 1024 texture and torn alpha. CI runs it.
- `ep2_gatling_hits_test`: mount, mouse-look, camera ray, shoot; exhausts one drum against billboard, verifies visible holes/shred and bounded node count, then resets the fixture's rounds to prove every existing plate still hittable. The refill exists only in the test.
- Mutation checks: putting RH back in the large saloon slot fails the prominence gate; disabling the rectangle fails actual mounted hits, holes and shred. Restoring the wrong Armory roll also fails the actual baked-corner coverage check. All mutations were restored before final tests/export.
- Captures here are Godot 4.3 Compatibility renders of the exact downloaded public packs at 1280×720, with only test/capture fixtures overlaid (runtime and art were not replaced). `board`, `saloon_porch`, `saloon_jack_close`, `armory_front/left/right`, `gatling_from_porch`, and mounted `gatling_clean/burst/shredded`. Reviewed directly.

Final census: **13 Jack Hammer / 3 RH**, **3.5916 / 0.9494 m²** (3.78×), excluding the 16 m² range billboard.

Native evidence and release proof are recorded in `validation.txt` and `release-receipt.json`. Native renders are not founder acceptance. The source poster has no eye patch and specifies BTC; the model/narrative locks are unchanged. **FIXED remains pending the founder's hard-refresh town + Armory Gatling walk.**

## Release verification

Shipped to [SmokeRealm](https://youngstunners88.itch.io/smokerealm), public **BUILD `2026-11-17-b1d62a9`**, source `b1d62a9a291c2001809dac87c182b6b378c640b1`. [Release workflow](https://github.com/youngstunners88/GM-GAME/actions/runs/44020326089) completed successfully, including its actual butler upload.

Fresh public Chromium loaded and reloaded that BUILD with both packs HTTP 200, extras ready, and no script errors. The downloaded public core/extras then passed the 40 poster checks, actual mounted Gatling hits/holes/shred and all five old plates, and eight hideout warm-up checks. The shipped canonical texture is byte-identical to the pinned import of the verified founder image. Hashes, pack sizes and method are in `release-receipt.json`; `upload-proof.txt` contains the actual upload notice.

The browser check covers the BUILD, reload, pack loading and protected access screen. World checks and captures are native replays of those exact public packs. The founder's hard-refresh town + Armory Gatling walk remains the acceptance gate.
