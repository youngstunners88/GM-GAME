---
name: ep2-meshy-studio
description: Episode 2's Meshy-first 3D studio — turn founder Meshy share links into in-game assets (share → task id → remesh → cut/split → shrink → contact sheet → install), and use the FULL Meshy stack (Meshy-7, ultra, 4K/8K PBR, multi-image, retexture, smart topology, remesh LODs, rig + 678 animation clips, nano-banana-pro inside Meshy) instead of hand-built primitives. TRIGGER on any meshy.ai link, "the 3D looks cheap", a new Episode 2 model/set piece/character, or before building any 3D prop procedurally.
---

# Rule zero (founder, 2026-09-28)
*"These are some of the 3D models that are way better than the shit you created. You have the
API key."* Meshy output is the quality bar. Never hand-build a prop out of boxes while a Meshy
model of it exists or can be made; procedural geometry is only for things Meshy can't make
(3 parallel rails of exact gauge, pit trestles, ties).

# Tooling (installed + verified 2026-09-28)
- **CLI**: `meshy` 0.4.0 (`npm i -g meshy-cli@0.4.0`; the SessionStart hook reinstalls it).
  Auth is automatic from `MESHY_API_KEY` in the environment (`meshy auth status` → source env,
  verified). Never `auth login --with-key`, never a key in a file or chat.
- **Official skills** (project-level): `meshy-3d-generation`, `meshy-3d-printing` in `.claude/skills/`.
- **MCP**: `.mcp.json` → `meshy` (`@meshy-ai/meshy-mcp-server@0.5.2`, env `${MESHY_API_KEY}`),
  24 tools (`meshy_remesh`, `meshy_rig`, `meshy_animate`, `meshy_retexture`, …) from next session.
- **Balance**: `meshy balance --output-schema v1 --format json --no-update-check` (613 on 2026-09-28).
  Costs: image→3D 30 (Meshy-7 textured), +5 ultra, 8K +5, remesh 5, rig 5, animate 3/clip.

# Founder share link → in-game asset
1. `curl -sSL https://www.meshy.ai/s/<code>` → the redirect URL ends in the **task uuid**.
2. `GET /openapi/v1/image-to-3d/<uuid>` (or text-to-3d / multi-image-to-3d) with our key works
   for the founder's own models → `model_urls.glb`, `thumbnail_url`, prompts.
3. They are HUGE (0.5–2.7 M verts, 50–170 MB). `meshy remesh create --input-task-id <uuid>
   --topology triangle --target-polycount 30000..40000 --target-formats glb --async` (5 credits),
   list `GET /openapi/v1/remesh` to get the id, download the glb.
4. `python3 tools/meshy/shrink_glb.py in.glb out.glb --max 2048 --aux-max 1024` (50 MB → 3 MB).
5. **Look before placing**: `node scripts/glb-shot.mjs out.glb sheet.png` (6-view contact sheet,
   bounds, triangle count; needs `npm i --no-save three`).
6. Edit with trimesh (`pip install trimesh scipy`): measure slices of face centroids to find
   floors/walls/tracks; `m.submesh([keep_idx])` to CUT (e.g. a dead-end wall, a baked floor);
   `scipy.cluster.vq.kmeans2` on centroids to SPLIT a multi-object scene (don't `split()` — OOM).
7. Record provenance in `src/episode2/assets/founder_meshy_sources.json`.

# What we built from the founder's four models (2026-09-28)
| Share | Use | Edit |
|---|---|---|
| NW7Dog "Three Track Gold Mine Stage" | `mine_tunnel_shell.glb`, tiled every 15.2 m | dead-end back wall + baked floor cut → open shell over our 3-rail trestle; scale (11.9, 9.5, 8.3): track spacing 0.30 native → 2.5 m, inner walls ±0.47 → 5.5 m |
| NrZuH8 "Gold Mine Stage" | `leaf_cart.glb` convoy + parked carts; `leaf_cart_wreck_a/b.glb` debris | kmeans split of 6 carts; the two half-carts become the smash |
| uKupoa "Hanging Mine Gunslinger" | `lil_blunt_zipline.glb` — shown while on a cable, yawed so the revolver (model −X) faces the reticle | none |
| 2SbhCb corridor | not used — only 2 tracks | — |

# Push the quality further (in priority order)
1. **Set pieces from key art**: `meshy image-to-3d create --image-url <keyart crop> --ai-model meshy-7
   --should-texture true --enable-pbr true --texture-resolution 4k` (+ `--ultra-mode true` for hero
   pieces). Scaffolds with lanterns, gold-ore walls, chamber gates, the boss.
2. **Multi-view** (`multi-image-to-3d`) from Nano Banana Pro front/side/back renders of the SAME
   character → cleaner characters than single-image.
3. **Retexture** a model to match the mine palette (`meshy retexture create --input-task-id …
   --image-style-url <keyart>`), instead of regenerating.
4. **LODs** by remeshing the same task at 40k / 12k / 3k and swapping by distance
   (`GeometryInstance3D.visibility_range_*`) — the web build's frame budget.
5. **Animation library**: 678 clips; `meshy_animate` / `tools/meshy/meshy_rig.py --rig-task <id>
   --actions …` re-bakes a clip set on an EXISTING rig within 3 days (no re-rig cost). Seated
   riding: 33 Chair Sit Idle Male, 361 Sit Dodge, 300 Sit Cheer.
6. **Smart topology** (`--model-type smart-topology --target-polycount 8000`, 15 credits) for
   many-instance props (lanterns, crates, gold heaps).

# Gates
- contact sheet reviewed; `ep2_glb_pipeline_test`; motion test rig scale sane;
- web pack < 190 MiB (`scripts/ep2-local-export.sh` prints pck); browser capture under `?ep2bot=1`.
