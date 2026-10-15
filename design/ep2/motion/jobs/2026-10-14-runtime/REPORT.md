# Bull and bear runtime motion

Source baseline: `ac20beace6535262dda0f8a269dbad3eac137ae6`. Branch: `codex/bull-bear-motion-implementation`.
The archived founder transcript supplied performance/contact principles; this is actual Godot implementation using the existing founder meshes and approved clips, without a video swap or paid generation.

## Changes

- Ep2Actor advances animation, locomotion, reach blends and acting through `step(delta)`. Entering a walk at zero speed during a pivot can now resume. Rest-relative rotations and hips offsets replace absolute source-rig poses; scale tracks are removed, including their baked idle-height compensation. Immutable tracks start from rest each step, preventing additive drift.
- The bear mesh had **zero hand weights**, with wrists about 48 cm below the sculpted paws. `tools/ep2_forge/repair_bear_arm_bind.py` fits elbow/wrist pivots and smooths arm/hand weights. Mesh positions, faces, UVs and textures remain unchanged. Embedded non-Hips translation channels are also removed so the runner retains the repaired arm lengths. Original input is recoverable from the pinned baseline.
- Independent book edges, bow grip and nock drive bounded arm solves. Skin-surface landmarks are measured independently of the prop; no limb is stretched. Reading retains seated legs but removes the human clip's large torso hunch. The page-turn paw moves across the leaf while the other supports the cover.
- Archers stand side-on, hold their bow during movement, draw a visible arrow/string, release the drawing paw at arrow emission and recover. Torso-relative prop frames are updated before solving hands, avoiding an attachment-frame delay. Sleeping breath acts on the chest without scaling the whole body.
- Bull has restrained carry swing, gaze, breath and hip-fire/recoil. His rifle pivots at a measured fist surface rather than translating 20 cm away. Flashes use the barrel. Hideout personal rifle uses the free left fist; the traded rifle still uses the right hand and retains its ownership/tutorial gates.

## Verification

Godot **4.3**, Compatibility/OpenGL, 1280×720, software Mesa through rootless Xvfb. Baseline and candidate reading views plus an eight-second candidate sequence are retained here. Bull carry/aim use the actual woods rig, materials and controller in a clear diagnostic camera. Player-camera hideout and woods routine captures are under `.farm/actor-motion/` in the task workspace.

`ep2_character_motion_test` samples actual **skinned paw vertices** against independent prop markers throughout eight seconds of reading/page turning, two seconds of draw/hold, and release/recovery, at two body headings. Approach/blend precedes the declared hold interval. It also checks neutral-rest transfer, the pause/animation clock, gait resumption and Bull's primary grip during three shots. Settled contacts pass the 15 mm gate; recorded maxima round to 0.1 mm or less. This gate is now in CI.

Native gates passed: character_motion, interlude, smelting_facility, hideout_corrections, range_lesson, runner_motion, glb_pipeline, fort_knox_arc, script_compile. Smelting's personal-rifle parent assertion was updated to the anatomical left hand while keeping the separate-reward assertion. Security Sentinel passed. Known dummy-renderer material/resource cleanup messages are separate from script/parse failures.

Nonthreaded web export: **198,120,176 bytes**, below 190 MiB. Chromium passes all five game gates (canvas, boot, no Godot errors, thread configuration, Stage 1 gameplay). The verifier's overall result remains **false** because remote backend fetches fail this cloud Chromium's proxy CA validation. TLS checks were retained. This browser run does not certify Episode 2 rendering; native captures cover the changed rigs.

## Remaining limitations

- The existing Bull right fist/pouch and elbow skin still tears during a two-hand quad reach. A diagnostic candidate reached both grips within 1.4 mm, but its rendered coat/torso failed. That candidate was rejected; the previous quad posture remains. Correct quad grip requires further mesh/topology work, not a larger IK reach. Rifle handling remains restrained one-hand hip fire rather than a fabricated two-hand shoulder pose.
- Both rigs still have 24 joints with no finger joints. Wrist/paw contact is implemented; articulated finger closure is not claimed. Planted-foot slip and full mount/leaf/lever performance are not certified by this contact gate.
- No Jev/Microsoft opinion or provider-generated motion was returned. Relevant provider/Google Doc access is blocked by this cloud's outbound policy; the pasted transcript and local rig work were used.
- Git operations are available, but GitHub Actions API access and the public itch page return **403 Forbidden** through this environment's proxy. Push/merge and CI/deploy proof must be reported separately. A local export or a CI export commit alone is not proof of a butler upload.

## Reproduce

Use the pinned Godot 4.3 executable and installed 4.3 templates. Captures need `DISPLAY=:99`; this task provisioned Xvfb from signature/checksum-verified official Debian packages into `/workspace/scratch/actor-motion/xvfb/` without system installation. Runtime data/cache/config are under `/workspace/.gm-game-{data,cache,config}`.

```sh
godot --headless res://tests/ep2_character_motion_test.tscn
godot --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 1280x720 res://tools/ep2_shots/bear_poses_shot.tscn -- states=sit_read sequence=1 out=.farm/reading
godot --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 1280x720 res://tools/ep2_shots/bull_motion_shot.tscn
```

`SHA512SUMS.txt` identifies the inspected assets and retained images/video. `design/*`, tools and tests are excluded from the web pack by the existing preset.
