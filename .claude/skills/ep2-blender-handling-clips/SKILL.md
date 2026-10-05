---
name: ep2-blender-handling-clips
description: Author Lil Blunt's Winchester handling in headless Blender - rifle parented to the right-hand bone with a locked offset, hands touching grip and fore-end, and three exported clips winchester_ready / winchester_aim / winchester_lever on the hero armature - then export a < 8 MB game GLB and prove the hands meet the gun. TRIGGER on tools/ep2_blender/winchester_handling.py, "hands floating", "liquid arm", "winchester_ready/aim/lever", or any hero-rig + weapon animation work.
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Grep, Glob
---

# Winchester handling clips (Blender -> Godot)

Inputs: `src/episode2/assets/lil_blunt_hero.glb` (exists) + `src/episode2/assets/weapons/winchester_1886_founder.glb` (`ep2-founder-weapon-glb`). Script: `tools/ep2_blender/winchester_handling.py` (`pip install "bpy==4.2.0"`, `import bpy` before `bmesh`; run `python3`, headless, no EGL so no renders).

## Build order
1. Import hero (armature + mesh), import the shrunk rifle, normalise rifle to muzzle +Z / stock -Z (Blender: forward = -Y; rifle-local (x,y,z) -> Blender (x,-z,y)).
2. Parent the rifle to the right-hand bone with `parent_type='BONE'` and a **locked** offset (set once, never keyed, no scale keys, no constraints that stretch). It must not stretch in any clip: assert scale == (1,1,1) at every key.
3. Define two contact empties on the rifle: `GRIP` (wrist of stock) and `FOREND` (under the wood). Solve each hand to its empty with IK or by hand-keying; the palm centre must sit within **1.5 cm** of the empty in every frame of every clip. Measure it in the script (bone head/tail world positions) and fail the build if over.
4. Clips (NLA/actions, 30 fps, names exact):
   - `winchester_ready`: low ready, muzzle down-range ~20 deg below horizon; hideout walking; loopable.
   - `winchester_aim`: shouldered, cheek on stock, eye along barrel; first-person target practice; holdable pose + tiny breathing.
   - `winchester_lever`: one cycle (lever down, forward, up) starting and ending on the `aim` pose, ~0.65 s (matches `Ep2Winchester.CYCLE`).
5. Export GLB with animations (`export_animations=True`, `export_force_sampling=True`), textures <= 2K, **< 8 MB**; check `os.path.getsize`.

## Godot wiring
- Hideout hand-over: Bull gives THIS rifle (swap the box/forge rifle, keep the `holder("RightHand")` contract).
- First-person: the viewmodel keeps the procedural sway/recoil (`_animate_fps`) driving the rifle node; play `winchester_lever` on each shot, `winchester_aim` while ADS, `winchester_ready` at hip. Do not double-animate: clips own the arms, GDScript owns the camera-relative offset.
- Retire `tools/ep2_forge` Winchester only after the new GLB loads in the three tests.

## Prove (a picture, not a claim)
Run `tools/ep2_shots/range_lesson_shot.tscn` (see `ep2-blender-props`) and add a REST capture: both hands visibly touching the gun, no see-through arm, no floating hand, muzzle down-range, lower right. Add the max palm-to-contact distance to the capture METRIC lines. Update STATUS with the build tag; the founder accepts on hard refresh only.
