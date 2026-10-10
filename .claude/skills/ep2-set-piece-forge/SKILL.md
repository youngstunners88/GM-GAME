---
name: ep2-set-piece-forge
description: Rebuild an Episode 2 room / set piece to look like a founder target image - Muapi GPT Image 2 reference stills, Tripo image-to-3D hero props, a headless-Blender modular kit, game clean-up, assembly in the chamber script, capture graded against the target with numbers, Jev + Microsoft decision models on those numbers, Astra on the pictures. TRIGGER when the founder sends an aesthetic target for a room ("this is the kind of aesthetic I want", "rework the elevator / walkway / cave"), a room looks boxy or primitive next to his picture, or a new story room needs building to a reference. Proven on the mine lift (2026-10-10).
user-invocable: true
allowed-tools: Bash, Read, Write, Edit
---

# Set-piece forge: founder target image -> a room that looks like it

First run: the MINE LIFT (founder target `artifacts/episode2-gold-mine/references/founder_2026-10-10/lift_walkway_target.jpg`):
a box tunnel + thin-bar cage became a plank bridge over a pit, a rusted riveted Tripo cage with roof gears, chains, lanterns, skulls,
banners and braziers, for ~1.5 MB of pack and ~$4 of Muapi. Read the steps in order; every trap below cost a capture round.

## 0. Intake (5 min)
- Commit the target to `artifacts/episode2-gold-mine/references/founder_<date>/<name>.jpg`. It is the grading reference.
- Write the room's BEATS and FRAMINGS before any art: which camera positions must match which picture (arrival, inside, exit...).
  The capture rig must have a shot at each framing (`tools/ep2_shots/interlude_shot.gd` `lift_0_entry`, `lift_6_exit_walkway`).
- Read the chamber's test first (`tests/ep2_interlude_test.gd`): beats, constants, collision and node names it relies on stay.

## 1. Reference stills (Muapi GPT Image 2, ~$0.09 each) - `tools/ep2_forge/muapi_ref.py`
Add items to `tools/ep2_forge/fort_knox_refs.json` (the generator's spec; any room may live there):
- **object item** for each hero prop: `hero_3q` = i2i with `"refs": [<target>]` ("take THE CAGE from the reference image ... show ONLY
  that, complete, identical design"), then `front` / `side` / `back` = i2i `"from": "hero_3q"` straight-on elevations. Lock `object`
  (grey studio backdrop) - that is what Tripo reads best.
- **scene item**: the framings the target does not show (inside the lift, the exit to daylight), i2i from the target, lock `env`.
- **kit item**: seamless textures ("IGNORE the studio backdrop: a flat, evenly lit SEAMLESS TILING TEXTURE ..."), a banner on pure
  chroma green (keyed to alpha), small props (skull, barrel, crate) on the grey backdrop.
Run views in parallel (`gen <item> --view <v> &`), then `board <item>` and LOOK. Re-roll only what is wrong.

## 2. 3D
| what | how | cost / time |
|---|---|---|
| hero prop (cage, machine, vehicle) | `muapi_3d.py run tripo3d-h31-multiview-to-3d --images front side back --set texture_quality='"detailed"' --set geometry_quality='"detailed"' --set face_limit=60000` | $1.16, ~6 min |
| small prop (skull, barrel, crate) | `muapi_3d.py run tripo3d-h31-image-to-3d --images <one view> --set face_limit=4000..8000` | $0.30, ~4 min |
| architecture (decks, posts, rails, chains, beams) | headless Blender KIT: `tools/ep2_blender/build_lift_kit.py` pattern - one GLB of named pieces, NAMED materials (Planks/Timber/RustIron), no textures | free, 30 s, ~170 KB |
Render every AI result before using it: `tools/ep2_shots/glb_hero_shot.tscn glb=<abs path> auto=1 studio=1`.

## 3. Clean-up - `tools/ep2_forge/ai_prop_to_game.py`
`--fit W,H,D` (0 = keep proportion), `--yscale`, `--ymap src:dst,...` (piecewise height remap), `--yaw`, `--anchor`, `--cut x0,x1,y0,y1,z0,z1`
(delete faces in a box: doorways), floaters dropped, 1024/256 JPEG textures, normal map dropped, ONE mesh, double-sided.
- AI proportions are not game proportions: the Tripo cage's plank panel came out 1.65 m - ABOVE Lil Blunt's 1.55 m eye, so the lever
  beat showed planks. `--ymap 1.62:1.0,3.47:3.2` squashed the panel to waist height and stretched the bars; Inferno (2.9 m) still clears the top frame.
- Profile heights before choosing numbers (histogram of vertex y; see the session log in this skill's history): panel / bars / frame / gears.
- Cut doorways to just under the top frame or bar stubs hang from it.

## 4. Import discipline (each new asset, same commit)
- Every new `.glb.import`: `meshes/generate_lods=false`, `meshes/create_shadow_meshes=false`. **Auto-LOD folds thin details into the
  surface** (the rifle's 0.9 mm GM disc vanished; a 2 cm rivet will too). Prove with the IMPORTED file, never only a runtime GLTFDocument load.
- Every texture `.import`: `compress/mode=1`, `lossy_quality=0.75-0.8`, `detect_3d/compress_to=0`. `git add -f` the `.import` files.
- Godot does not always re-extract a GLB's embedded images: after re-exporting, write them over `<glb>_<image>.*` yourself.
- Pack: the CI gate is 190 MiB. Before adding, measure (`index.pck = N MB` in the CI log; `docs/pck_budget_doc.md`). The lift paid for
  itself by switching 14 non-face model textures to lossy WebP (11.7 MB -> 1.7 MB, PSNR >= 31.5 dB, rifle render PSNR 54.8 dB).

## 5. Assemble in the chamber script
- One `_kit(piece, pos, rot, scl)` helper that duplicates the kit node and assigns the shared triplanar materials by material NAME.
  **Scale in LOCAL axes: `Basis.from_euler(rot) * Basis.from_scale(scl)`.** `Basis.from_euler(rot).scaled(scl)` scales WORLD axes - an
  upright beam came out 1.3 m thick.
- **Looking down +z, screen-RIGHT is -x.** The target's right-hand gallery first landed on the left.
- Keep the beats, constants, node names and collision the test reads; narrow collision to the new walkway (between its rails).
- Haze without volumetric fog (Compatibility renderer): additive camera-facing radial HALO cards at lanterns and braziers (`_halo`).

## 6. Grade against the target - numbers first
`python3 tools/ep2_forge/ref_metrics.py <target> <capture>` per framing. Lift history (entry vs target, lum 0.20 / sat 0.56 / edge 0.10):
| pass | lum | sat | edge ratio | closeness | change |
|---|---|---|---|---|---|
| warm ambient + thick warm fog | 0.09 | 0.96 | 0.29 | 0.25 | one orange murk |
| palette cool ambient 0.62, fog 0.011, exposure 1.3, sat 0.92 | 0.076 | 0.86 | 0.45 | 0.31 | rock + timber read |
| + lantern halos, braziers, exposure 1.55 | 0.11 | 0.85 | 0.56 | 0.38 | glow in the smoke |
| cavern 13 m -> 8 m (decision models), barrels/crates, emblem wall, saturation 0.78 | 0.10 | 0.80 | 0.57 | **0.42** | cage fills the view |
Other framings (vs the Muapi scene refs), final: arrival 0.51, inside the rising cage 0.57, top exit walkway **0.73** (old top 0.45, old arrival 0.20).
Rule from `Ep2Palette`: COOL ambient against WARM lanterns. A warm ambient + warm fog + warm textures crushes blue to zero.

## 7. Decisions (text-only models get the NUMBERS; vision models get the pictures)
- `JEV_MODEL=microsoft/microsoft-decision-1 node scripts/jev.mjs --state "<metrics table + what changed>" --bool ... --choice ...` and the
  same with Jev (`~typesafe/jev-latest`, the default). Both live on `POST /api/alpha/decisions`; both are TEXT-ONLY. Use them for:
  ship-vs-iterate on the metric table, and design choices (which option meets the founder's stated rules).
- Astra (`node scripts/or-call.mjs openai/gpt-6-astra prompt.md out.md --image capture.png --image target.jpg`, ~$0.06-0.2): one
  fidelity pass on the real captures; its fixes become the next increment's list. DeepSeek V4.1 Flash for cheap triage of many frames.

Lift results (2026-10-10): layout - Jev `shorten` 0.99 / microsoft-decision-1 0.96 (cut the cavern so the cage dominates); ship -
both "clearly better" (0.83 / 0.97), "at target quality" no (0.09 / 0.01), `ship_and_iterate` (1.00 / 0.99). Astra 4/10 "partly" in both
passes (`docs/model-responses/2026-10-10-mine-lift-astra-pass*.md`). The arc gate earned its keep: the emblem wall first used a
protocol the founder's Fort Knox arc keeps out of this chapter - `ep2_fort_knox_arc_test` failed it; run that test after any set dressing.

## Next increment for the lift (Astra pass 2, in order)
1. Space: widen the cavern 40-60 %, raise the roof, an elevated timber tier + a side landing (keep the 8 m depth - the cage stays big).
2. Lighting hierarchy: 4-6 lantern pools, peaks -25 %, cool overhead fill, 2-3 haze cards behind the cage.
3. Exit: a real conifer model (Tripo from a Muapi still, like the barrel) in three layers + a 20-30 m dirt path; sunlight 3-5 m inside the mouth.
4. Materials: cage rust patches (a Muapi rust mask over the Tripo bake), 3 plank tints, larger rock breakup.
5. Density: 3-4 big gears + 4-6 chain runs above the cage (MOVING with it), more skulls/banners on the widened walls.

## Second run: the BEAR WOODS (outdoor, founder target `founder_2026-10-10/woods_exterior_target.jpg`)
An outdoor set is a FOREST KIT + materials + life, not hero props:
- Muapi `woods_kit` item: seamless bark + forest-floor textures, a fir branch on pure green and a fern on pure magenta (keyed to alpha),
  a mossy rock on grey (-> Tripo image-to-3D $0.30 -> `ai_prop_to_game.py --fit 0,1.2,0 --tex-base 512`), a ride-view scene still.
- `tools/ep2_blender/build_forest_kit.py`: Trunk (height 1, radius 1, root flare; scaled per instance), Crown (fir-branch cards for a
  40 m tree, **two cards crossed along each branch** - one lying, one on edge; a single tilted card read as a flat stripe), Fern, Snag.
- Chamber: one MultiMesh per layer (giants, young firs, ferns, snags, rocks, sun shafts). Bark is WORLD-triplanar (`uv1_world_triplanar`,
  scale ~0.42 uniform - 0.22 vertical stretched it into stripes) + a normal map derived from the bark still. Crowns/ferns use
  `src/episode2/art/ep2_foliage_wind.gdshader` (vertex sway grows with local height; per-instance phase from the world root).
- **Texture imports for tiled/world textures need `mipmaps/generate=true`** (the default import had them off -> shimmer and noise).
- Young firs must stay >= 7 m off the trails: their low branches otherwise fill the view and hide the giants.
- Close the horizon: grow the giants past the play area (the camp side showed white sky between trunks), green the sky horizon.
- Life: `Ep2Wildlife` (`src/episode2/chamber/ep2_wildlife.gd`): birds + ElevenLabs bed/gust/3D calls; the chamber calls `step(delta)`
  from its tick so tests and captures drive it.
- Woods results: closeness start 0.67 -> 0.75, trail 0.69 -> 0.76, ride 0.70 -> 0.78. Jev / microsoft-decision-1: better 0.87 / 0.997,
  `ship_and_iterate`, priority `trunks`. Astra 4/10 "partly" (`docs/model-responses/2026-10-10-woods-astra-pass1.md`); next: an
  irregular layered conifer (Tripo/Meshy) instead of crossed cards, trunk moss, roots/clutter, stronger dappled sun.

## 8. Ship
Tests (`ep2_interlude_test`, `ep2_fort_knox_arc_test`), STATUS.md, `scripts/ship-to-master.sh`, prove the master deploy.
