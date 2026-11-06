# Weapon consistency: Borchardt C93 + scoped Sharps (founder 2026-11-05)

Work order: `PROMPT_TRIPO_BORCHARDT_AND_SCOPED_SHARPS.md`. Raw numbers: `weapon_consistency_receipt.json`. Captures: `docs/captures/weapon-consistency/`.
Gate: `tests/ep2_weapon_consistency_test.tscn`. Shots: `tools/ep2_shots/weapon_consistency_shot.tscn` (+ `weapon_consistency_measure.py`), `tools/ep2_shots/sharps_scope_shot.tscn`.

## Cause (measured before anything changed)

- The old Borchardt model was gun + hand in one mesh, 0.35 m overall, with the hand baked at the gun's scale. The Remington's is 1.0 m of gun and arm.
- Before, at the hip, gun only: Borchardt 130 x 123 px, Remington 297 x 325 px. The arm was shrunk too, which is why it read as a keychain.
- The Remington's own gun is 0.54 m in its model: **about 1.5x a real C93 (0.355 m)**. A real-size pistol can never match it on screen without a first-person scale.

## The fix

- `extras/armory/borchardt_c93.glb`: Tripo, gun only, 0.355 m real size, one file for the first-person view and the stranger's draw and drop.
- `extras/armory/lil_blunt_gun_hand.glb`: the Remington's own glove, bracer and vine arm with the gun taken out (`tools/ep2_forge/founder_gun_hand.py`).
- `Ep2ArmoryGunView.HELD`: `gun_scale` 1.527 on the view's Gun node only. Same hand position, eye point and carry as the Remington. **This is a deliberate first-person size, not real size**, the same exaggeration the Remington already has.
- `extras/armory/sharps_scoped.glb`: the founder's Sharps body (his tab model) with a tube built in Blender (`tools/ep2_forge/build_scoped_sharps.py`): 0.56 m, 22 mm, flared eyepiece, brass collars, two raised rings, no rail. The raised ladder sight was removed because it stood where the tube goes.

## Borchardt vs Remington, 1280 x 720, fov 58, same camera, gun only

| Measure | Remington | Borchardt | Difference | Target | Result |
|---|---|---|---|---|---|
| Aimed silhouette length (px) | 338 | 324 | -4.1% | within 5% | PASS |
| Aimed silhouette diagonal (px) | 366.6 | 364.0 | -0.7% | - | - |
| Muzzle screen height (px) | 436.1 | 409.5 | 3.7% of screen | within 5% | PASS |
| Grip heel | off the bottom | off the bottom | same | within 5% | PASS |
| Arm in the centre third, aimed | 0.37% | 0.0% | - | none | PASS |
| Hip silhouette diagonal (px) | 440.3 | 454.5 | +3.2% | not a keychain | PASS |
| **Aimed height over the bore (px)** | **55** | **14** | **-75%** | **within 10%** | **NOT MET** |
| Aimed silhouette width (px) | 142 | 166 | +17% | - | wider |

**Not met, on purpose:** a C93 has a low flat top, and the Remington has a tall hammer and frame. Matching this number would mean reshaping the gun, which the order forbids. The wider silhouette is the C93's toggle knobs. The founder decides from the A/B image: `docs/captures/weapon-consistency/AB_ads_remington_borchardt.png`.

## Sharps, real town chamber

| Measure | Before | After |
|---|---|---|
| Aimed fov | 58 | 28 (2.22x the normal aimed view, 3.25x the hip) |
| Board 1.8 m tall at 100 m, 1280 x 720 | 8.0 px at the hip | 26.0 px scoped |
| Same board, 844 x 390 | 4.3 px at the hip | 14.1 px scoped |
| Reticle centre vs the aim point | - | 0 px (projected) |
| Aimed spread | 0.62 deg | 0.05 deg, about 1 px |
| Kick at full aim | 65% kept | 25% kept (0.028 rad) |
| Lens radius | - | 46% of the short side of the screen |

Played in the town chamber: equip, shoulder, fire, reload, switch to the Remington (fov 58, no lens), back to the Sharps (fov 28, lens). Sequence in `sharps_scope_shot.gd`.
The aimed fov and look speed have one source, `Ep2ArmoryState.aimed_fov` / `aimed_look_scale`, read by `interlude_base.gd`, `lake_trail.gd` and `smelting_facility.gd`.

## Tripo

Host `https://openapi.tripo3d.ai/v3` (the `.com` host answers 401 for this key). Model `v3.1-20260211`. Balance 500 -> 390, **110 of the 400 credit cap**.

| Task | Mode | Credits | Used? |
|---|---|---|---|
| `d912cc5a-9712-43a6-ba66-a6111644973b` | image-to-model, Borchardt | 60 | Yes |
| `4839f612-17ff-4686-9bd6-e448e13e3026` | text-to-model, scoped Sharps | 50 | **No**: short modern scope with turrets, and the rifle read as a double barrel |

The Sharps took the order's second route (scope added in Blender). It gave an exact optical axis and the same rifle as the founder's tab, so no retry was spent.
The `*_Image_*.jpg` files the order named as references are texture atlases, not photos. The Borchardt's input was a clean side render of the founder's `showcase/borchardt.glb`.

## Left as is, and why

- **Rich's voiced line still says "a tang sight".** It is voiced and there is no ElevenLabs key on this machine, so text and voice were left matching, as the order allows. His rifle's tang sight is folded down under the scope, so the line is not false, but it does not mention the scope. Needs a new take.
- `showcase/borchardt.glb` and `borchardt_held.glb` are unchanged: the new pistol was made from the first, so the silhouette is the same.
- `meshy/borchardt.glb` and `meshy/sharps_buffalo.glb` are now unused and were not deleted.
- The Gatling post's GLB was not rebuilt: the kit script would have replaced the 2.2 MB model with a 170 KB one.
- The aim blend stays the shared 0.24 s (`Ep2Winchester.ADS_TIME`), not the order's ~0.15 s, so every gun keeps the same feel.
- A small torn flap remains on the index finger of the extracted glove, visible on the Borchardt's icon.
- The hideout reads the scope rule, but the story gives no Sharps there, so its lens was not captured.
