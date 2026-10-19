# Logan's Lake — active production contract

Authority: founder Google document archived verbatim in `LOGANS_LAKE_LOCK.md`,
2026-10-18; character reference `references/Logan.JPG`, provenance
`SOURCE_RECEIPT.json`. This supersedes the older fishing/vesting `WIRE_SPEC.md`.

## Illustration, wire and design

The supplied lake-bank character image is the target for Logan, his outdoor
materials, calm water, timber dock and wooded shore in every beat. Preserve his
hat, weathered face, plaid sleeves, waders, satchel and rope. Fishing accessories
on the supplied costume do not authorize fishing gameplay.

The surface chain is woods → town's certificate/saloon/draw → Rich & Utah's paid
gear → **Logan's Lake**. `gold_town` prebuilds `logans_lake` when geared; the
session carries the existing armory. No Episode 1 scenery edit or title edit.

| Beat | Player verb and visual | Exit condition |
|---|---|---|
| ARRIVE | Walk from the named timber sign toward Logan beside the dock. Armed first-person view. | Within 3.2 m, E or touch prompt |
| INVESTIGATE | Three short readable lines: retain depth, stage incoming cargo, feed the outflow. Logan greets/breathes. | About 20 seconds; spam cannot skip into staging |
| STAGE | Walk to the secured cargo crate; **check staged cargo**, no invented deposit or financial action. | Within 2.8 m, E/touch once |
| HANDOFF | Sign changes to CARGO CHECKED; Logan gestures; the staged shipment starts drifting downstream. | Walk along the shore slope |
| OVERLOOK | High ground above the visible narrow day-88 outflow. Keep firearm/loadout. | Player can look around and return to shore |

The lake is a separate outdoor chamber from Town Stockpile. No fish inventory,
APR, percentages, hard weekly timer, extra currency, wallet operation or reward.
The high overlook and departing cargo establish the river handoff; the later
**sniper combat encounter with bears is not implemented by this lake slice**.
Do not call that later battle complete. No new companion assignment is made.

## Asset and performance contract

Supplied GLB: 23,925,540 bytes; 52,028 triangles, 60,285 split vertices, 65 joints,
three 4K maps and no clips. `prepare_logan.py` preserves the rig/skin/identity, repairs measured source mesh defects,
uses 1K maps and adds Idle/Greet/Point/Approve on the source rest axes. No rerig or
static statue replacement. The generated blend is editable under `source/` and
excluded from Godot by `.gdignore`. The runtime GLB has only selected skin+rig.
Warnings about hips-root position, asymmetric roll and clothing weights remain
recorded, not silently “fixed” by rebinding.

`build_logan_dock.py` creates the timber planks, worn edges, mooring piles and
fitted rope turns. The lake reuses the existing forest, rock and water assets;
tree instances share materials/meshes. Frame the same character and view in
Godot 4.3 Compatibility; Blender lighting alone is not game evidence.

## Code and proof

- Scene: `src/episode2/chamber/logans_lake.tscn` / `.gd`.
- Gate: `tests/ep2_logans_lake_test.tscn`; town-chain regression in
  `tests/ep2_gold_town_test.tscn`; CI includes both.
- Capture rig: `tools/ep2_shots/logans_lake_shot.tscn`.
- Build: pinned Godot 4.3, nonthreaded Web, fresh-import PCK ≤190 MiB.
- Release: title lock, security after staging, all CI gates and texture-reference
  probe, `scripts/ship-to-master.sh`, actual CI upload and public BUILD evidence.

Dialogue is subtitled. Logan voice casting/recording and the later river fight
remain separate work; do not synthesize a random voice and call it founder-approved.
