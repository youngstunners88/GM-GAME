# Web pack budget (index.pck) - where it stands and how to make room

The itch.io per-file limit is 200 MB; CI fails the build above **190 MiB** (199,229,440 bytes) and a failed master build never deploys.

| date | build | `index.pck` (CI "Verify export output") |
|---|---|---|
| 2026-10-09 | master c6fa391 (first-person everywhere) | 187 MB |
| 2026-10-10 | branch with the modelled flame quad (v1, Blender kit-bash) | 188 MB |
| 2026-10-10 | AI-built flame quad (Tripo via Muapi) replacing it | master run 38016691615 passed the 190 MiB gate and deployed (butler pushed 222.85 MiB total, +32.6 MiB fresh) |
| 2026-10-10 | master after other sessions' merges | 188 MB (run 38031277359) - effectively full |
| 2026-10-10 | 14 non-face model textures -> lossy WebP (carts, mine tunnel, forge rifle, helmet, wrecks, whiskey, gatling, ore cart, cauldron, coin, founder rifle @0.9) | -10.0 MB (11.7 -> 1.7 MB packed; PSNR >= 31.5 dB, rifle render 54.8 dB) |
| 2026-10-10 | mine lift rework (Tripo cage 0.96 MB, kit 0.05, skull/barrel/crate 0.4, textures 0.35) | +1.8 MB |

Headroom is about **2 MiB**. A hero character (AwesomeX) is 3-5 MB, a building set 1-2 MB, a voice batch 1-2 MB: the next big prep piece does not fit
without freeing room first.

## What the pack stores (local export, 2026-10-10)

music 54 MB (21 mp3/ogg tracks), textures ~75 MB VRAM-compressed (backdrops, vault art, portal maps, model textures), 5 cutscene videos 30 MB,
voice lines ~11 MB (346 files), portal VO ~4 MB (75 files), models ~16 MB. `python3 tools/pck_audit.py --dead` prints the table for the current tree.

## Rules for any new asset

1. State its packed cost (imported `.scn` + `.ctex` sizes in `.godot/imported/`), not the source file size.
2. Models: paint big, ship small (the quad's paint atlas is 1024x320, rubber/rim/steel 256/256/128), track a `.glb.import` with `meshes/generate_lods=false`
   and `meshes/create_shadow_meshes=false` (`git add -f`), merge parts by material (draw calls matter on web as much as bytes). The whole quad is 0.88 MB.
3. Verify with a branch push: CI prints the real number. The local export reads ~5 MiB higher than CI.

## Proven on the quad: lossy WebP for MODEL textures (2026-10-10)

The extracted GLB textures default to `compress/mode=0` + `detect_3d/compress_to=1` (lossless / VRAM): a 1024 base colour packs to **1.65 MB**. Tracked `.jpg.import` files with
`compress/mode=1`, `compress/lossy_quality=0.75`, `detect_3d/compress_to=0` pack the same texture to **0.20 MB** with no visible loss (metal-rough 0.53 -> 0.02 MB). The Meshy models already in the
pack (hideout props, Bull, bears, carts) still use the defaults: re-importing them lossy is worth roughly 1.5 MB each - needs a per-texture look first (hero faces, logos), then one tracked `.import` per texture.

## Ways to make room (each needs the founder's say or a runtime trace)

| lever | est. saving | risk |
|---|---|---|
| `src/assets/logos/founder/ref_*.png` (8 annotated founder feedback screenshots, never loaded by name) | ~1.1 MB | none visible; they are references, not game art |
| `src/assets/portals/vo/*.mp3` (75 files never referenced by name) | up to 3.3 MB | maybe loaded through a runtime-built path - trace first |
| `src/assets/portals/plate_*_whitepaper.jpg`, `portals/leaders/*.png` | ~1.5 MB | same |
| `src/assets/sounds/voice/*` that no manifest id points at | ~1.9 MB | same |
| the existing Meshy model textures as lossy WebP (see above) | ~10 MB across ~8 models | low: look at each hero/face texture first |
| big 2D backdrops/maps as lossy WebP import (`compress/mode=1`) | 10+ MB | colour/blotch risk on art the founder is sensitive about - run `scripts/blotch-hunt.sh` |
| music / voice bitrate (e.g. 128 -> 96 kbps) | 10+ MB | the founder's songs: his call |
| the 5 cutscene videos | 30 MB total | films must always play (`ep2-film-always-plays`) - do not touch |

`tools/pck_audit.py` lists the candidates and sizes; it is a name-reference scan, so a run-time-built path looks "dead". Never delete a founder asset on that list alone.

## 2026-10-10 bear woods realism
| added | size (source) |
|---|---|
| `src/episode2/assets/woods/` forest kit GLB, bark/floor/branch/fern textures (+ bark normal), Tripo rock | ~2.3 MB (lossy WebP import, mipmaps on) |
| ElevenLabs woods soundscape (`ep2_woods_ambience_loop.ogg`, gust, 3 bird calls, flutter) | ~0.6 MB |

## 2026-10-10 (b) Lil Blunt's rifle + Tripo bears
| change | size (imported) |
|---|---|
| bear_rigged.glb = founder Tripo bear (46.7k tris) + 1024 albedo; old Meshy texture removed | ~+2.8 MB (CI 186 MB after) |
| winchester_1886_founder.glb = founder "rifle 3d.glb" (22k tris, 2048 albedo, 1024 MR/normal, 512 emissive); old rifle_color/mr/emblem files retired | ~+1.3 MB |
