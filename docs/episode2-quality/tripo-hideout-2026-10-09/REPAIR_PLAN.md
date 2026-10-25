# Inferno Bull hideout: founder corrections, 2026-10-09

Status: inspected sources and references; implementation and release NOT completed.
Baseline: f52fcd0a7d90cca2cba91470f6caa57c118f6262.
Execution blocker: exec-server reports "409 Conflict, environment_offline: Environment is not connected".
No current credential availability, ZIP contents, Blender render, GLB geometry, or gameplay test was verified this session.
Keep this distinction in STATUS and any client response. Prior release evidence is historical, not validation of these requested changes.

## Founder request

Configure the uploaded Tripo3d_Blender_Bridge-latest.zip with Blender and use existing configured credentials where appropriate. Improve the gold and hideout furnishings. Replace the generic training bear with a warrior holding a bow and arrows. Make exposed lava/molten gold burn Lil Blunt, show his pain reaction, and have Inferno Bull visibly jump across and warn him to mind his step.

The new bear instruction supersedes older taxidermy-only target guidance. It does not authorize changing target rewards, count, rifle handling, education/NFT contracts, or founder-locked menu art.

## Sources actually retrieved

| Source | Verified |
| --- | --- |
| [Bear warrior 3d model_Clone1.glb](https://drive.google.com/file/d/13_LAB19Ep9P_9sDROHEsSe4TO4_Xtu2V/view) | Authenticated download available; 22,815,764 bytes. Geometry, orientation, rig and bow silhouette not inspected yet. |
| [Inferno Bull in the Fort Knox Armory.png](https://drive.google.com/file/d/1BNvaRExNjm8puGdpUYi4xIZKWauLvfLz/view) | Image viewed. Engraved timber gun wall, brass/black iron, lantern pools, ornate firearms, whiskey, soot stone and molten gold. |
| [Inferno Teaching Lil Blunt.png](https://drive.google.com/file/d/1Alq_TCqo1Jj2GIcxNWy6vbaM7AXHmv8f/view) | Image viewed. Sandbag firing bench, brass casings, ingot crates and a bear with a clearly recognizable bow on the training poster. |
| [Inferno Giving Lil Blunt.png](https://drive.google.com/file/d/15JDO5CYVjACVWXJpC-s6PfSiubYzNGxH/view) | Image viewed. Wealthy furnished room: reflective bullion, cowhide, whiskey, gun displays, Fort Knox arch/skull, furnace and rear molten channel. |

Never commit expiring signed download URLs or credentials. Preserve the founder original outside the exported runtime pack before creating a reduced derivative.

## Diagnosis against current source

1. `range_dressing.gd::BEAR_PROP` uses `assets/hideout/bear_standing.glb`, the generic unarmed standing bear, not the founder warrior. `_build_taxidermy_bear` assumes unit height and minimum Y -0.5. Replacing the path without measured dimensions will misplace/overscale the model.
2. `assets/mine_bear_archer.glb` already exists (3,424,740 bytes) and may be reusable. Inspect it alongside the founder GLB before paying to regenerate anything. Its presence does not prove a match.
3. `hideout_dressing.gd` gold is bright yellow albedo, metallic 0.40, roughness 0.26 plus emission. The Blender ingot source uses `Finish_CastGold` with metallic 0.35. These are different material paths: fixing one does not establish that all gold is fixed.
4. Compatibility rendering previously made high-metallic objects black without reflection lighting. Do not blindly increase metalness or compensate with more yellow emission. Inspect reflection availability and the actual imported/runtime material first.
5. `smelting_facility.gd::_collide` blocks the entire channel at all heights when `abs(z - CHANNEL_Z) < 1.1 && abs(x) > 1.0`. It prevents both entry and jumping. The visible molten plane is 18.6 m by 1.7 m at Y 0.14, Z 10.5; the bridge is 2.0 m by 2.8 m at X 0. Never use unrelated whole-room bounds for damage.
6. `smelting_facility.gd::get_health` returns a constant 3; its comment explicitly says this chamber has no health/fail state. A red overlay alone would not implement burning. The user's new hazard requirement needs an explicit chamber health/recovery contract.
7. `FacilityShow` currently supports walk/face/reach/clip/call and Lil Blunt hop, but no Bull jump action. Actor position, gait and hand-prop attachments must agree throughout the new jump.
8. Current master includes Claude's new raised rifle badge. Preserve those asset/material/tool changes.

## Concrete repair sequence

### A. Restore execution and establish the baseline

Reconnect the existing execution environment. Inspect presence of Tripo credential aliases without printing values; do not assume the keys are absent because the host was offline. Inspect the uploaded ZIP and its registration, networking, file writes and credential persistence before enabling it. Use the appropriate add-on path in TRIPO_BLENDER_SETUP.md.
Fetch current master again into an isolated clean branch; preserve concurrent rifle work.
Read the current art, player-view, reference-match, props-visible, voice and ship skills.
Capture arrival, mid-room, look left/right/back, firing line and Bull hands through the actual Compatibility game cameras.

### B. Gold and the wealthy armory

Identify every actual gold carrier: authored ingot, older pile, ore cart's baked surfaces, racks, brass accessories and coin displays. Override only named bullion surfaces; do not recolor wood or weapons globally.
Author separate cast and polished bullion treatments in Blender: softened bevels, shallow denomination/serial detail, restrained surface variation and dark grooves. Use standard glTF PBR with baked texture details rather than unsupported procedural nodes.
Set up tested Compatibility reflection/lighting support before tuning metallic; judge two camera angles. Aim for bright moving edge highlights and darker body reflections, not uniform yellow blocks or black metal.
Compose believable weighed stacks, crates/coin trays and darker storage structures, with visible gaps and support contact. Enrich the existing firing bench with sandbags and spent brass; retain clear walking and targeting lanes.
Keep existing environment geometry that already works. This is a repair of specific quality failures, not a global tint.

### C. Archer training bear

Inspect the founder GLB in neutral front/side/three-quarter views and separate fur, bow, bowstring, nocked arrow, quiver, straps and armor if possible.
Prefer a repaired derivative of the supplied warrior; compare the existing mine archer as a reuse option.
Retain a readable bow curve, string, nocked arrow and quiver silhouette after reduction. Pose/facing should make its threat understandable from Lil Blunt's firing line. Fix fused parts, absent arrow shafts or clipped weapon geometry in Blender.
Measure native height/minimum Y and record explicit placement constants. Keep chest hit centre and radius aligned to the existing bear target; do not let the bow absorb the target hit or obscure the protocol plaques.
Preserve five target kinds, count, topple/hit-reset behavior and lesson progression. Clarify in the lesson that these are armed mine bears.
Preserve original founder bytes as source-only. The current generated web config declares 199,157,072 bytes against a 199,229,440-byte gate: only 72,368 bytes of apparent headroom at this baseline. Re-measure after fresh import/export. Adding the 22.8 MB original to runtime is unacceptable. Optimize/replace existing assets and verify total pack bytes rather than raising the cap.

### D. Molten contact, jump and pain

Replace the infinite-height channel barrier with named visible surface bounds and bridge-safe bounds. Keep unrelated room/prop collision behavior.
Evaluate contact after horizontal AND vertical movement every simulation step, including when standing still. Grounded feet on exposed molten surface burn; clearing it while airborne and crossing the bridge are safe.
Use a bounded burn cooldown and one feedback event per damage tick; never charge once per rendered frame. Introduce real chamber-local health consistent with the three-heart contract and reset semantics. Verify session/HUD consumers first.
On contact: Lil Blunt pain bark from an existing appropriate asset if available, short character flinch and camera response, brief clear warning, and escape opportunity. Do not add persistent tinted overlays; if using a short flash, it must be zero/hidden at idle and must satisfy the repository blotch checks.
If lethal contact is possible, recover to a safe bank without taking a second equipment/payment charge or erasing prior economy/progression. Define and test recovery deliberately; no softlock during a handoff, reload or lesson.
Add a sequencer jump action with a finite airborne arc between measured marks outside the bridge; show takeoff, crossing and landing. Maintain Bull's handprops/rest pose and return his root Y/gait cleanly.
Place the warning before player exposure: "Mind your step, Lil Blunt. That molten gold will burn. Jump it, or take the bridge." Use subtitles immediately; record/generate actual matching voice only through the authorized configured voice pipeline. Do not substitute an unrelated voice file or claim a recorded warning exists when it does not.
Guard the beat so film resume, lesson replay, hurt recovery and pause do not repeat it or steal player look indefinitely.

## Verification required before shipping

| Requirement | Evidence |
| --- | --- |
| Gold has real depth and reflection contrast | Same-camera Compatibility before/after; close and room views; verify actual runtime materials. |
| Archer threat reads | Firing-line view plus front/side asset inspection; bow, string, arrow and quiver visible. |
| Safe routes | Bridge and airborne crossing cause no burn; both exposed banks burn on contact; room bounds unchanged. |
| Reliable damage | Standing contact burns at bounded intervals; pause/control lock suppresses inappropriate damage; no frame-rate dependence. |
| Story jump | Bull takeoff/cross/landing, warning timing, clean rest pose and visible rifle/glass. |
| Progression | Five targets, demo/handoff, reload, ADS, film skip/resume, equipment, recovery and exit remain usable. |
| Export | Fresh Godot 4.3 import/export, no script errors, PCK below 190 MiB, non-threaded Compatibility. |
| Release | Required impacted suites/security/front-page/VFX gates; non-forced master update; CI/butler upload success; matching public BUILD and real input playtest. |

Do not claim any row passed until its evidence exists. The current work stops at inspected diagnosis and this saved implementation brief.
