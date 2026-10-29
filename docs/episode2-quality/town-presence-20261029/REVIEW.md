# Continuous town, usable supplies

Founder follow-up: `docs/founder-feedback/2026-10-29_town-presence-healing.md`. The original six FIX-document repairs remain included; their separate release receipt records the verified c903f88 build.

## What changed

The Sheriff's interior was not distance culled. Its open wooden leaf was only rotated 69 degrees: at the allowed left walking lane x=-0.4 it still crossed the player's eye ray. Walking through that leaf suddenly exposed the room. The authored hinge now opens 100 degrees, preserving the original 4,122 triangles, 14 materials, 19 nodes and 225,040-byte GLB. A baseline ray test failed on that lane; the repaired asset clears all three usable lanes while its side wall remains solid. Actual camera captures compare the same threshold/room.

The on-foot town and mounted trail now use one road survey, origin, mesh builder and warm dusty shoulder material. The original town road instance travels with the retained town on mount; the duplicate trail survey is hidden, then restored on return. Both ribbons map every vertex exactly between town and riding coordinates. The first gray hard-edged material capture was rejected and replaced before release.

The original road cart, farmer rig, wheel distance and gait phase now continue into town through a single session owner. He follows the real road and a wall-clear service lane to the General Store yard. An existing town worker collects his parcel, carries it with the real hand attachment through the existing shop doorway, leaves it on the counter and resumes ordinary town life. The same seated farmer/cart and grounded resting donkey remain at the business stop. There is no new reward or compulsory quest. Real duel safety behavior interrupts the errand; only physical arrival advances each stage. A killed carrier leaves the parcel in town and cannot silently complete the job. Existing town snapshots retain journey, worker height, carried goods and completed/interrupted state.

Tabs now has a selectable Dude's Chill Bud card and separate Use action. The owning room restores its existing health to three, then spends exactly one item and saves. Full health, no stock and a failed/dead attempt cannot consume. Selection never equips a weapon; the panel retains its pause ownership. Keyboard H/Down/Accept, pointer and raw second-finger paths use the same transaction. Touch uses the bud/count and three-heart icons without keyboard wording.

The supplied link is the exact 187.632-second `GM Laker2.mp3`, not another text document. It now loops at Logan's Lake on the existing ducked Music bus. The prior supplied draw/ride song remains on that route, and paired ownership restores previous music on leaving. Provenance is recorded in MUSIC_PROVENANCE.json. No Meshy, Tripo, RunPod or audio-generation credits were spent on these repairs.

## Verification and release

Current focused native results: doorway5, shared road9, selectable full-heal14, continuing delivery28 and lake theme8, all zero failed (64 checks). The 28-check delivery includes an actual crowd duel interruption/resume, every approach collision circle against real town walls, fresh moving/porch/carry restore, grounded stopped hooves and death handling.

The complete local workflow run is retained at `/tmp/tmp.WtLH1oj5Hk` in the execution workspace. It exposed one freed-active-room teardown reference in the Episode2 touch gate, corrected in `_persist_town`. All other failures were the same three pre-existing local pause tap-target geometry differences already documented by the repository gate. Affected full-town/crowd/touch checks are rerun after the final ownership/material changes; reconciled results and exact export/browser/public evidence are added below before claiming this follow-up released.

Physical-phone behavior and an authenticated public-origin Episode2 playthrough are separate evidence boundaries. Native automation and emulated browser touch alone do not certify them.
