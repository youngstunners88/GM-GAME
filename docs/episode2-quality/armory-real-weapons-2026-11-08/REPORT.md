# Armory: the founder's real weapons on both floors (2026-11-08)

Brief: `PROMPT_EPISODE2_ARMORY_REAL_WEAPONS_DISPLAY_2026-11-08.md` (Drive). ADR: `docs/architecture/adr-ep2-armory-real-weapons.md`.

| Done item | State | Evidence |
|---|---|---|
| No placeholder sticks on either floor | DONE | `before/` vs `after/`; gate: no GunWood/GunSteel left in the fit-out |
| Real GLBs on the downstairs racks, cases, counter | DONE | `after/d1-d5`, `c2`, `c3`, `c4`, `c5` |
| Real GLBs upstairs, varied | DONE | `after/u1-u5`, `c1`, `c6`: 6 per rack row, yaw +-0.06, scale 0.96-1.04, 12 families |
| CAD only for furniture / mounts | DONE | only brass pegs added; the racks, cases and boards are the existing ones |
| Shop / Tabs / autonomy intact, pack under gate | gates below | |

Capture: `godot --rendering-method gl_compatibility --rendering-driver opengl3 res://tools/ep2_shots/armory_real_guns_shot.tscn -- out=<dir>`.

Frame cost (same cameras, whole town in view):

| shot | before tris | after tris |
|---|---|---|
| d1 back racks | 99k | 224k |
| d3 window case | 243k | 249k |
| d4 barrels/door | 248k | 268k |
| u2 gallery left | 245k | 270k |

Not done:
- The racked Sharps is the scoped showcase model, so its scope tube stands beside it on its rings.
- No touch-phone test.
- The 4k "Near" cut is what sits in the cases. The full 12k models are still what the Tabs showcase spins.
