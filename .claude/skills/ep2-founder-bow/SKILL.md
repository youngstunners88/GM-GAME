---
name: ep2-founder-bow
description: The founder's Tripo "medieval bow" (Drive 2026-10-20, zip + glb) as THE player's bow - split the fused model into riser+left arm / limbs / arrow / string hand, flex the limbs, draw a real string, fluid draw-loose-renock motion, paired sounds, the clear GM emblem, streamed so the main pack is untouched. TRIGGER on "the bow", "medieval bow", "replace the bow", "bow viewmodel", "draw / loose / nock", "bow sound", "GM logo on the bow", "Recovered Bear Bow", any edit to ep2_bow_view.gd / ep2_bow.gd.
---

# The founder's bow (ep2-founder-bow)

Founder (2026-10-20): "build in the bow and arrow that we have now and replace it with the one in the game. Make sure that the movements are good and fluid and that the
proper paired sound is linked. Make sure that the GM logo is clear just like on the rifle ... reconfigure the graphic in the selection tab so that the bow with the hands
holding it can be selected." The Drive files are ONE Tripo mesh (`medieval+bow+3d+model.zip` FBX 4K, `medieval bow 3d model.glb`, 51k tris, 45-bone junk auto-rig - ignored).
Download with curl (never the Drive MCP): `curl -sL -o f "https://drive.usercontent.google.com/download?id=<id>&export=download&confirm=t"` (ids 18IR5I4M... zip, 1d1SztaT... glb).

## What the mesh really is (measured)
A pose reference like the rifle: Lil Blunt's LEFT arm (green sleeve, studded bracer with a leaf concho, glove fist) gripping the riser, two separate limbs, a nocked arrow with
fletching, his RIGHT hand pinching the arrow 0.26 m ahead of its tail, and a thin rod where the string should be. **It is at FULL DRAW** (hand 0.5 m behind the grip). The limb
axis (tip to tip) and the arrow axis are 89.9 degrees apart - those two axes ARE the bow frame. Islands separate cleanly (`bpy.ops.mesh.separate(type="LOOSE")`); the limbs are
only ~190 verts each (subdivide before bending). The "gold badge" is two small domed pin heads, one each side of the riser (~7 cm).

## What `tools/ep2_blender/build_founder_bow.py` makes (-> `src/episode2/extras/bow/founder_bow.glb`, streamed, ~1.9 MB, 22k tris)
Bow frame: origin = grip, +y along the limbs, +z the way the arrow flies, +x the archer's LEFT (looking along z). Nodes: `Model/BowArm` (riser + arm + glove + bracer + sleeve),
`Limb_Up` / `Limb_Low` (a `draw` shape key each: tip 0.13 m toward the archer, quadratic from the root), `Emblem` (the GM disc, both sides), `Arrow` and `RightHand`
(origin AT the nock, so a node position is a string position), empties `Nock_Rest` (z -0.20) / `Nock_Full` (z -0.52) / `Tip_Up` / `Tip_Low` / `Grip` / `ArrowRest`.
- The shaft behind the founder's pinch is cut (`--pinch-z -0.31`): string, nock and fingers are one point.
- The two cut sleeve ends are grown into tapered cloth (material `SleeveCloth`, linear (0.03, 0.056, 0.02): the first sample read pale mint) so no flat cut shows in first person.
- GM emblem: the rifle's own art (`artifacts/.../founder_2026-10-10b/emblem/gm_emblem_color.jpg` + emit), a flush disc 8 cm across (the rifle's is 7.5) laid on each pin head by a ray,
  covering it completely. Founder rule (`ep2-winchester-logo`): the logo disc only - no brown ring, no bezel. A 4.5 cm disc left the old gold dome showing round it (a ring again).
- The string is NOT in the file: two cylinders tip -> nock built by `Ep2BowView._add_strings`.
- Import: `meshes/generate_lods=false` (the rifle's lesson: LOD folds a thin disc), textures `compress/mode=1` lossy 0.85, 4.3 format, `git add -f` the `.import` files.

## In the game (`src/episode2/chamber/ep2_bow_view.gd`)
`Ep2BowView.make(true)` is the founder bow where `Ep2Extras.has(Ep2Extras.BOW)`; the bears keep `make(false)` (their bow and arrow are unchanged). The contract the woods and the
viewmodel read is kept: `Nock`, `NockedArrow`, `RightHand`, `String0/1`, `limbs`. `animate_founder(root, bow)` every viewmodel step:
- **draw** (0.7 s, smoothstep): nock z -0.20 -> -0.52, limbs 0 -> 1, strings follow the flexed tips, the bow arm pushes out 3 cm; `Ep2Bow` adds the draw to `ads` (up to 0.85, relaxes slowly)
  so the bow comes up to the eye and the view tightens like aiming.
- **loose**: the string snaps forward in 0.12 s, limbs and string shiver (damped `exp(-15 t) sin(62 t)`), the hand drops away with no arrow; **re-nock**: from 38 % of the 0.35 s cycle
  the arrow and hand are brought up from below onto the string. Never a static bent texture.
- Flying arrow: `Ep2BowView.player_arrow()` = the founder's arrow with its origin at the HEAD (swept hit tests start at the point), `FOUNDER_ARROW_LEN` 0.746 behind.
- **Sounds, paired** (`ep2_viewmodel.gd`): `ep2_bow_creak` (0.88 s) played at the start of the draw with pitch 0.88/0.7 so it ends as the string reaches full draw, STOPPED if the draw is
  cancelled (switch / sprint); `ep2_bow_loose` on the loose; `ep2_arrow_thunk` where the arrow stops (a bear or a trunk, `woods_quad._tick_player_arrows`).
- Placement (the Winchester is canted too): `vm_scale` 0.62, `hip_offset (-0.47,-0.04,-0.05)`, `hip_rotation yaw PI+0.90`, aimed `ads_pos (-0.02,-0.10,-0.55)` with `ads_rotation yaw PI+0.35`
  (the viewmodel reads `ads_pos` / `ads_rotation` metas for views not squared to the target). Square-on from behind, the arrow, string hand and both sleeves stack along the
  line of sight; a NEGATIVE cant puts the string hand on the left. Late mounting: `Ep2Viewmodel._ensure_founder_bow()` swaps the view in when the bow is first selected if the
  streamed pack mounted after attach (and re-applies the world-shadow setting).
- Toning: `_tone_founder` scales the textured surfaces to 0.84 (cloth 0.55) on per-bow material copies: the Tripo textures wash out in the desert sun.

## Rebuild
```
curl ... -> bow.zip, unzip (FBX + .fbm)          # into a fresh scratch dir
blender -b --factory-startup -P tools/ep2_blender/build_founder_bow.py -- --src <tripo fbx> --out src/episode2/extras/bow/founder_bow.glb [--shots dir]
godot --headless --import   (4.3 pinned: .godot-cache/Godot_v4.3-stable_linux.x86_64, twice)   # then lossy textures + generate_lods=false, git add -f the .import files
godot --rendering-driver opengl3 --path . res://tools/ep2_shots/bow_model_shot.tscn -- out=<dir>   # the bare model: rest/full draw from 5 views + emblem close-ups
godot --rendering-driver opengl3 --path . res://tools/ep2_shots/bow_vm_shot.tscn -- out=<dir> [hip_rot=0,0.9,-0.15 hip_off=.. ads_pos=.. ads_rot=.. scale=..]   # in Lil Blunt's eye, 16:9
```
Gate: `tests/ep2_bow_test.tscn` (EP2_BOW) - founder bow in extras, contract nodes, nock at full draw, limbs flex, string tip->nock, emblem disc 7-9 cm both sides, flying arrow origin,
creak length/pitch, viewmodel shows the founder bow and the draw creaks and flexes, swept arrow hits. Pack: nothing in `index.pck` but ~100 KB of script + a lossy icon; the old
`bow_left_hand.glb` / `bow_right_hand.glb` (231 KB each) were deleted.

## Traps (each cost a round)
- Window grabs from the compositor are NOT 16:9 (a portrait tile hid the bow's real framing): put the chamber in a `SubViewport` 1600x900 (`bow_vm_shot.gd`).
- `godot --headless --import` is needed after every GLB rebuild or the run shows the stale import (the sleeve colour "did not change" for two captures).
- Boundary-loop detection of the wrist/sleeve cuts finds nothing useful (Tripo's ends are closed caps and decimation shatters loops): find the sleeve island and the hand's PCA axis instead.
- The viewmodel's windowed frame is bright: judge colours in the engine, never the Blender Workbench preview.
- Do not grow the file on the main pack: anything outside `src/episode2/extras/` pays the 199,229,440 B gate (margin was 97 KB).

## 2026-10-21 rework (founder: "the bow is absolutely trash")
- First-person pose: vm_scale 0.46, hip_offset (-0.34, 0.17, -0.22), hip_rotation y PI+0.75 z -0.12; the string hand exists only while drawn (smoothstep 0.30-0.50 of the draw) because its forearm otherwise crosses the near plane; sleeve growth 0.80/0.90 m; string-hand glove tinted to the bow hand's leather.
- Limbs: `--limbs procedural` (default) replaces the Tripo paddle limbs with built recurves between the SAME root/tip points (measured from the Tripo limbs, so Tip_Up/Tip_Low and the string do not move). Material `LimbWood` uses a generated laminate texture (extracted by Godot as `founder_bow_limb_laminate.jpg`: commit it and its pinned 4.3 `.import`, lossy 0.85). `--limbs tripo` restores the old ones.
- After any GLB rebuild: re-render the card (`render_weapon_icons.py --which bow`), run ep2_bow / ep2_weapon_icons / ep2_personal_armory tests, restore 4.7-dirtied imports, run the pinned 4.3 import and commit only its real diff.
