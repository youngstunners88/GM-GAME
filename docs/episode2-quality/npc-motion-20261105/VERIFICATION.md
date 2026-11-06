# Character motion and protected NPC response

Baseline: `0acdb2a55c2ffed1aa3dc9cee2ee854b89822f81`. Integrated master: `0e1ee4e8` (including the updated scoped showcase Sharps). This report describes the implemented candidate; deployment proof is recorded separately when available.

## Scope and behavior

- Utah and Rich: instance-local, rest-aware shoulder/elbow/wrist tracks with restrained gestures; grounded locomotion on both rigs, with actor speed driving clip speed. UE, Mixamo and dotted townfolk names are resolved explicitly. Longest rest-child axes avoid UE twist-bone mapping errors; leaf hands retain their local bone axis.
- Rich: the user-selected `extras/armory/showcase/sharps.glb`, including master's scoped model update, replaces the procedural hand prop. Measured grip/support/muzzle anchors restore its canonical 1.21 m length. Held upper-body variants retain dialogue and grounded-walk legs; the case copy hides while the rifle is held. Its existing rifle report is reused.
- Dude: the original lenses were baked clear-looking artwork on an opaque atlas. Only their measured UV regions are darkened; original frame, geometry, skin and animations remain. Bright and dim Compatibility captures confirm black lenses.
- Mounting: horse nose is native +X while humans face +Z. The controller now accounts for both frames, aligns first, stages reaching/step-up/leg-over/settling over 2.2 seconds, and reverses that motion when dismounting. Landing obstruction pauses both root and animation clocks. The horse returns to its heading smoothly.
- Protected hits: explicit roster is Dude, MinisterMikeDean (the user confirmed both Minister/Mike Dean labels), bartender, sheriff, Rich, Utah, General Store clerk (`Shopkeeper_Bldg_A`) and `StableAssistant`. The seven other than Rich use the existing gun-only golden Remington, as assigned by the user; Rich uses the showcase Sharps. A registered nearest-ray hit starts the response before injury/arrest. Misses, intervening facades, and ordinary NPC rules retain their existing behavior.
- Sheriff: preserves the founder's current walking skin/mesh/materials and adds two arm chains. Bartender: preserves the supplied mesh/materials and adds a standing rig and arm chains. Blender authoring recipe is `tools/ep2_motion/add_protected_arms.py`; inputs can be recovered from baseline Git. No replacement body or paid generation was used.
- Draw/aim/fire: the actual attached hand, weapon frame and muzzle supply the firing transform, including manual simulation. Final wrist aiming tracks the current player eye rather than a stale pre-draw position. Bursts share one response, one weapon and one restart. The assistant's chore props are stowed during the response and restored afterward.
- Restart: reuses `chamber_failed` and session routing, restoring the recorded arrival/checkpoint in the current chamber instance. Story beat, purchases, population and interrupted NPC clip/time are retained. The woods copy covers Dude, assistant and office cast through the same response component; bear/trunk/facade occlusion remains respected. It invokes the existing surface-elevator attempt retry (health, ammo, bears and quad state follow that established checkpoint contract), preserving the purse and pre-checkpoint progress. Town retries also dismount the Gatling before restoring arrival.

## Evidence

- Protected town: 213 checks, 0 failures, eight entities, two encounters each. Covers misses, registered hits, survival, burst ownership, blocked controls, draw-before-shot, decisive single fire, bore direction, root height, exact clip/playback restoration, arrival retry and progress preservation. Dude’s second encounter interrupts a reverse dismount.
- Protected woods: 40 checks, 0 failures, four entities twice, same failure signal and section restore.
- Ranch, armory guns, two-storey armory, town law, founder fix document, world routes, save compatibility and script compilation passed after master integration.
- Two complete mount/ride/dismount cycles: maximum root frame displacement 0.03030 m; maximum yaw step 0.16221 rad; rider/horse forward dot >= 0.99999994. Both end at the same mount mark without offsets. Reproducible gate: `tests/ep2_mount_alignment_test.tscn`.
- The protected, woods and mount gates are included in the existing CI workflow. The full local release suite passed (three documented pause tap-target geometry differences on this host are tolerated by the existing gate). The fresh export gate now rejects failed exports and empty packs instead of reporting a zero-byte pack as passing. A valid fresh export and public deployment must still be verified before publishing claims.
- Runtime captures: original armory introduction completed with 23 Gatling rounds and 2 plates; supplied Sharps visible from the player's camera. Final response capture tool: `tools/ep2_shots/protected_npc_shot.tscn`, writes `.farm/protected-npc/` (player view plus firing diagnostic for all eight). Bright/dim Dude lens and staged mount diagnostics are included beside this report.

Not founder-verified; not tested on a physical phone. Native tests and renderer evidence do not alone prove a public deployment. Release/upload/public BUILD verification remains a separate required gate.

## Export and browser receipt

Cold asset import/export: source `ca1820d5`, main pack 199,052,304 bytes. The code-only vehicle/checkpoint update was fast-forwarded to `686eba0a` in that clean checkout, with no asset differences; the final re-export succeeded with no script/parse errors at 199,051,680 bytes. The streamed pack is 196,763,360 bytes. Both are below 199,229,440 bytes (190 MiB), and their headers are valid Godot PCKs. This avoids using the stale textures left in the original working cache.

Chromium boot of the asset-identical clean export passed: build `dev-local`, streamed extras ready, extras HTTP 200. Native final checks are 213 town and 40 woods, including interrupted reverse dismount and Gatling exit after death. Deployment and public BUILD confirmation are separate and still pending at this receipt.

The failed earlier clean export exhausted the 8 GiB workspace by duplicating 4 GiB of Git history. The gate now shares immutable Git objects while keeping the checkout and import cache fresh; it also fails on an unsuccessful export or an empty pack and retains failure logs. No source, textures or gameplay were trimmed to fit the size gate.

## Changed implementation files

- `src/episode2/actors/ep2_armory_pose.gd`, `ep2_ranch_pose.gd`, `ep2_town_folk.gd`: rig mapping, bounded arm motion, supplied rifle contacts and held variants, phased mount pose.
- `src/episode2/actors/ep2_protected_retaliation.gd`: explicit hit-only roster, draw/aim/fire, authoritative muzzle, debounce and interrupted-state restore.
- `src/episode2/chamber/ep2_town_law.gd`, `gold_town.gd`, `woods_quad.gd`, `ep2_stable_yard.gd`: target registration, movement ownership, supplies, existing checkpoint retries and horse alignment.
- `src/episode2/session/ep2_session_root.gd`, `world_routes.gd`: failure signal routing and town arrival capture.
- Assets: `assets/town/dude_stable_owner.glb` and its new lens atlas PNG; `assets/town/bartender.glb`; `extras/people/previous_sheriff/sheriff_walk.glb`, all under `src/episode2/`.
- Authoring/evidence: `tools/ep2_forge/dude_black_lenses.py`, `tools/ep2_motion/add_protected_arms.py`, `tools/ep2_shots/protected_npc_shot.gd/.tscn`.
- Regression gates: protected town/woods and mount alignment tests; updated protected expectations in `ep2_town_law_test.gd`; CI workflow additions; hardened `scripts/pack-gate-fresh.sh`.

Final diagnostic images beside this report show all eight firing actors, plus the clerk and assistant from the actual player camera. They are runtime captures, not generated reference art.

## Final integration and measured rifle contact

Integrated master `df2cdb0e` without dropping its crowd keep-clear, saloon doors, Inferno/body dialogue, raft damage or river audio work. The merged candidate passed common-sense, protected town, protected woods, town law, gold town, ranch, river cover and script compilation checks.

An independent wrist-to-model-landmark measurement caught an unreachable support target in the earlier rifle pose. Rich now carries the rifle diagonally in front of his body with a reachable fore-end grip, turns into a side-on firing stance, and maintains the left-hand contact as the aiming wrist follows the player. A 0.5-second rifle draw interpolates from the actual current pose, including when he already holds the rifle; it does not snap through an idle pose. The new `ep2_rich_grip_test` checks six held clips at four headings and four phases plus the live aim/fire sequence: 253 checks, zero failures, maximum wrist-landmark error 0.000166 m. Bone lengths are preserved; the fore-end target is measured independently on the supplied model.

The new master adds only three small river sound assets and their import descriptors to the prior asset baseline; all model and texture bytes remain unchanged. Final source export and pack receipts are regenerated after integration.

Final integrated source `c5bfc21f` was exported successfully in the retained clean-derived checkout after importing the new river audio and refreshing the merged global classes. Main PCK: 199,143,040 bytes; extras: 196,808,288 bytes; valid headers, both below 199,229,440 bytes. Export reports zero script/parse errors. Chromium boot of this exact export passed with build `dev-local`, extras ready and HTTP 200. All nine integrated native gates passed, including 253 rifle contact checks, 213 protected town checks and 40 woods checks.

## Verified public release

Released source: `f628bba49d499799a908498231975be9e6fdc86e` (runtime identical to locally verified `c5bfc21f`). Production workflow [42178674856](https://github.com/youngstunners88/GM-GAME/actions/runs/42178674856) completed successfully. Its actual logs confirm 213 town, 40 woods and 253 rifle-contact checks with zero failures, plus mount alignment; all release gates passed. CI packed extras at 196,808,352 bytes and passed both 190 MiB file gates. Butler pushed 14 files and reported the successful SmokeRealm upload at 07:29:26 UTC on 2026-11-06.

After itch finished processing, Chromium opened the current public iframe obtained from https://youngstunners88.itch.io/smokerealm. The game itself printed build `2026-11-06-f628bba`; Episode 2 extras reported ready and HTTP 200. Public probe completed at approximately 07:36 UTC. This verifies the actual delivered release, separately from native behavioral tests and local rendering. No access control was bypassed, and no harness feature was published. The public startup/stream was verified; the protected interactions and visual changes were exercised in native runtime, while the exact local export was checked for browser boot and asset streaming. Not founder-verified or tested on a physical phone.
