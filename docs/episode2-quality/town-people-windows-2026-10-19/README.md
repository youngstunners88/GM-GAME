# Town windows and doors + townspeople (founder brief 2026-10-19)

Drive prompt `PROMPT_EPISODE2_TOWN_WINDOWS_DOORS_EXISTING.md` + "we're lacking townsmen and townswomen ... full discretion".

## Windows and doors
- Root cause: `false_front()` stood a full-height slab in front of the real wall, hiding every window and door (before_*.png: blank boards).
- Fix: `tools/ep2_blender/build_town_kit.py` - real holes (`wall_holes`), framed glass, shutters, panelled / double / batwing doors, side and
  back windows; the false-front slab now starts at the roofline. The two-storey Armory uses the same hole-cutting.
- Streamed: `src/episode2/extras/town/town_kit2.glb` (1.96 MB) via `Ep2Extras.TOWN_KIT` (ADR-0005); same piece names, no new `Bldg_*`.
- Proof: ray through every window and doorway centre meets no wall (+ a control that must hit); EP2_GOLD_TOWN, EP2_ARMORY2 still ALL PASS.

## People
- Five rigged people (3 men, 2 women), ~0.2 MB each: clerk, old-timer, rancher, dressmaker, lady. `build_townfolk.py` -> `src/episode2/extras/people/`.
- `Ep2TownPeople`: routes down the open middle of Main Street, pauses, greeting when Lil Blunt is within 3.6 m (cooldown 18 s), not in lock-step.
- Gate `tests/ep2_town_people_test.tscn` (ALL PASS): routes clear of every wall/prop, 120 s of walking, greeting.

| File | What it shows |
|---|---|
| `before_a/b_fronts_blank.png` | BEFORE: blank boards |
| `after_1..7_*.png` | AFTER: both rows, Saloon, Treasury, Certificates, up the street, the Armory lane |
| `after_9/10_people_*.png` | the townspeople on Main Street (real renderer, eye height) |
| `townfolk_lineup_blender.png` | the five figures side by side |

## Not claimed
People are stylised on-box figures (the founder-accepted Rich/Utah family), not Tripo hero models; their colours still read pastel in the desert
grade. Runpod was not needed this pass (the prompt says not to spend it on blank walls). Church windows/door are as before.
