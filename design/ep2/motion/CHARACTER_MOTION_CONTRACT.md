# Inferno Bull and bear motion/contact contract

Status: skill preparation and acceptance plan; no runtime implementation in this change.
Source baseline inspected: 45f5d1142084baadc926965c54699a8fa0892c41.
Read TRANSCRIPT_ADAPTATION.md and use .claude/skills/ep2-character-performance/SKILL.md for routing.
Keep the living-woods encounter/armory/checkpoint contract and Fort Knox plot; this job improves acting and contact, not story or difficulty.

## Observed source facts, not fresh visual verdicts

| Current source | Fact inspected | What future work must prove |
|---|---|---|
| Bull and bear GLBs under src/episode2/assets | Each skin has 24 joints, both hand joints, no Thumb/Index/etc. finger joints | Whole-rig compatibility; no claim of articulated finger movement without rig work |
| ep2_actor.gd | Non-Hips bone translations dropped; animation playback uses engine clock while actor step(delta) moves the root | Rest-relative retarget and one declared sampling/animation clock |
| ep2_bull_rest_arm.gd; ep2_bull_hero.gd | Rest-arm modifier freezes both arm chains to avoid tearing; rifle rides LeftHand in story rooms | Safe moving arms/contact without returning to torn skin |
| woods_quad.gd, _bull_fire_at | Rifle world position moves o + dir * 0.2 independently of fist; later resets to rest | Grip-preserving recoil/aim; no 20 cm separation and no reset pop |
| smelting_facility.gd, _sync_bull_hand_props | Separate hideout/trade placement path based on hand bone/world transforms | Final drawn pose, correct palm frame, both paths covered |
| ep2_bear_kit.gd | Reading prop placed from average hand positions; bow attached to left wrist with a static string | Independent book-edge/palm, bow grip/nock/string/arrow contact |
| ep2_bear_arms_down.gd | Fixed arm directions blended over walk/run; routine changes set influences immediately | Natural gait variation and smooth, skin-safe pose transitions |
| ep2_bear_kit.gd | Whole model scaled vertically to imply sleeper breathing | Stable world contact and chest-local breathing instead of changing body support |
| Existing bear/woods shot tools and interlude tests | Capture poses and test routines/combat; many simulated step calls happen between engine frames | Continuous pose/contact proof, not a favorable still or a walk-distance-only test |

The source inspection identifies candidate defects; no new rendered before/after result is claimed. Recheck source after Claude's next commits before applying a repair.

## Pin inputs before authoring

Keep the founder's actual Bull and Tripo bear appearance, rifle/logo, helmet/cigar/coat, body scale and approved textures. The .claude/skills/ep2-bull-repose-hero/SKILL.md and ep2-founder-weapon-glb/SKILL.md explain previous skin/prop traps.
Preserve the founder's current whiskey-on-table behavior; do not put the glass back into a hand to fill a pose.
For each action record actor/prop IDs and hashes, source performance and rights, target rig/rest frame, camera, phases/contact intervals, root-motion owner, existing choreography/events and output destination.
Video performance and visual identity are distinct. Generated guide video is not 3D animation. Use current licensed clips or own Blender-authored actions as the default; no body regeneration merely to improve acting.

## Priorities and phases

| Priority | Actor/action | Required phases and contact |
|---|---|---|
| P0 | Bull rifle carry -> low ready -> aim/fire -> recovery | Correct stock/trigger grip; support hand only after free-hand/skin feasibility; actual muzzle; no weapon teleport |
| P0 | Bull walk/sneak/turn/stop | Gaze scans before torso turn; weight transfer, step cadence and planted feet; restrained free movement instead of globally locked arms |
| P0 | Bear patrol/roam/start/stop | Retargeted non-human gait, plausible hips/shoulders, grounded feet, individual pauses and attention |
| P0 | Bear draw/aim/release/recovery | Grip stave, contact nock/string, tension before release; arrow event matches hand and string |
| P1 | Bear read/page-turn -> stand/wake | Both paws support book; release one for page; stump supports pelvis; smooth rise |
| P1 | Bull mount/ride/dismount | Seat/feet support; hands meet actual quad grips; body follows vehicle without arm stretch |
| P1 | Bull lever pull / leaf brushing / equipment handover | Approach -> contact -> force/transfer -> release -> settle; world prop moves only after contact |
| P1 | Bear sleep/wake/hit/fall | Grounded body, chest-local breath, continuous wake/hit/fall, corpse and attack shutdown preserve existing combat |
| P2 | Talk/listen/emotion variations | Voice timings and gaze; safe face capability, no invented facial rig or claimed lip-sync |

Priorities are implementation order, not claims any clip exists. Preserve rifle teaching locks, acquisition, player-camera motion, living-woods personality/hearing, retry, quiet route and mobile work.

## Animation and contact ownership

One declared clock advances source phase, animation, root/locomotion and events. Presentation callbacks cannot re-emit arrows, shots, leaves or rewards. Pause, slow/different frame rates, blending, cancellation, retries and hidden/prebuilt chambers must not advance/switch poses inconsistently.
Choose in-place room-driven locomotion or root motion explicitly. Record the stride speed and deceleration/pivot behavior. Align chunk/loop pose and velocity; context is not proof of seam continuity.
Have one primary rigid-prop contact frame and independent character/secondary contacts. Preserve bone lengths; solve reachable limbs with anatomical poles/joint limits and fade weights. If the fused Bull hand cannot move without tearing, repair that geometry/skin before a two-hand action. A restrained carry can remain separate; firing cannot be faked with a gun moving by itself.
Props stay rigid; a parented node is not sufficient. Feet/pelvis meet actual ground/seat. Test world metres after scale, multiple yaws, transition and final modifier/attachment updates.

## Provisional measurable acceptance profiles

These are targets to be calibrated against actual mesh/contact landmarks, not measurements made here. Any exception must be justified before testing; never loosen one after a failed run just to get green.

| Invariant | Proposed profile | Evidence |
|---|---|---|
| Palm/independent prop grip during hold | max 0.015 m gap; report penetration separately | Final skinned palm landmark vs independent prop frame/surface |
| Planted-foot drift | <= 0.02 m across a declared plant interval | World-space trajectory including locomotion/root correction |
| Planted sole/ground | gap <= 0.015 m, penetration <= 0.005 m on the sampled support | Ground query and evaluated sole landmark |
| Bone lengths and rigid prop dimensions | No animation-induced scale/length change | Evaluated transforms and edge lengths |
| Event synchronization | One actual event per declared release/strike/contact crossing; no repeats on pause/retry | Timestamped event ledger and pose samples |
| Pose continuity | No teleport/pop at clips/loops/blends; declare angular/velocity budgets per action | Quaternion/position/velocity traces plus timed review |
| Skin integrity | No new torn/inverted/bridge surfaces; compare baseline stretch in elbows/coat/fist | Evaluated mesh samples and runtime close-ups |
| Frame/pack cost | Within current measured browser/190 MiB gate; record delta | Real export and browser measurements |

Book/hand and bow/string errors must use independent anchors, not a midpoint that makes its own measurement zero. Fingers are an additional topology/rig task; a 24-joint wrist rig alone does not satisfy realistic finger-grip evidence.

## Required evidence and future gates

Input readiness -> neutral/rest retarget identity -> skin-safe motion -> contact intervals -> temporal/interaction transitions -> real game capture -> integration/release.
A plan checker verifies structure and records missing inputs only. Neither plan validity, a guide-video render, a Blender still nor a skeleton track count proves those later gates.
Proposed new acceptance tests are ep2_character_motion_test and ep2_prop_contact_test; these do not yet exist. Implement meaningful broken-case tests with actual rig/contact and event sampling when changing runtime.
Keep the existing ep2_interlude, ep2_smelting_facility, ep2_hideout_corrections, ep2_range_lesson, ep2_runner_motion, ep2_glb_pipeline, ep2_fort_knox_arc and script_compile gates.

Capture complete clips and transitions from the player's eye plus diagnostic front/side/back, overlay-free and with contact markers; pin SHA/hashes, timestamps/inputs and seed. Inspect frames and a timed sequence. Score identity, event timing, pose, contacts and world continuity separately. Jev/Microsoft review text metrics only when reachable; retain real responses/unavailability. Never pretend a static metric or model answer is a visual approval.
Skills-only publication is a repository commit, not a game deployment. Any later implemented runtime fix follows smokerealm-ship after the evidence above.
