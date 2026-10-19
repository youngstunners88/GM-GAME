---
name: ep2-lake-proof
description: Verify Logan’s Lake visually and functionally, then publish through GM-GAME’s title, security, pack and CI deployment gates.
---

# ep2-lake-proof

Read ep2-logans-lake, gm-blender-godot, the release skill, and design/ep2/lake/IMPLEMENTATION.md. Evidence levels remain separate: IN CODE, WIRED, SEEN, SHIPPED.

1. Verify pinned skill files, inspect supplied vs exported GLB metrics/skin/clips, and parse semantic QA results. Upstream skips are not passes.
2. Run pinned Godot 4.3 import/compile, tests/ep2_logans_lake_test.tscn, tests/ep2_gold_town_test.tscn and the repo CI gate block. A parser-only check is insufficient.
3. Render tools/ep2_shots/logans_lake_shot.tscn in Compatibility mode. Inspect arrival, Logan close-up, dialogue, staging, handoff and overlook. Pair Logan.JPG with the actual character capture; check identity, posed hands, foot contact, readable lake/outflow, inventory HUD and material/foliage correctness. If a view fails, identify the responsible new file/material before changing it.
4. Exercise the ordinary browser route and touch interaction, plus pause/armory freeze. Keep the Episode 2 access lock intact; test warps must run after authorization and cannot grant production unlocks. Browser and native screenshots are distinct evidence.
5. Fresh web export <=190 MiB, zero script errors, no excluded texture references. Preserve thread_support=false. Add/stage first, then security-sentinel and front-page-lock. No bypass or arbitrary allowlisting to force a ship.
6. Update STATUS with scene and known limitations, vault log, commit/push, fresh-merge concurrent master and scripts/ship-to-master.sh. Verify the exact master-source CI export AND butler upload, then public BUILD and changed scene before saying live. If a gate fails, report the actual failure and correct it within scope; do not claim completion from a pushed branch.
