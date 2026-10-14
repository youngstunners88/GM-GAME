# Episode 2 living-town tools

Offline Python 3 standard library; no credentials, dependencies, paid jobs or runtime mutations.
Run from the game repository. Read `.claude/skills/ep2-living-town/SKILL.md` first.

```sh
python3 tools/ep2_town/town_tool.py audit --repo . --out work/town/audit.json
python3 tools/ep2_town/town_tool.py plan --repo . --seed 22015 --out work/town/plan.json
python3 tools/ep2_town/town_tool.py validate work/town/plan.json --repo .
python3 tools/ep2_town/town_tool.py handoff work/town/plan.json --repo . --out work/town/handoff
python3 -m unittest discover -s tools/ep2_town -p 'test_*.py'
```

`audit` reads the shared Godot layout/footprints and the Blender generator, preserving source commit and typed `sha256:<base64>` checksums. Public source provenance uses this encoding to distinguish it from raw private-key-shaped hexadecimal literals in the repository scanner. The adapter understands the current explicit layout and axis-aligned building orientations; it fails on an unrecognised/mismatched layout rather than guessing. Generator presence does not prove visible doors/windows.

`plan` proposes a connected circuit: the existing main street, north/south cross streets and west/east avenues. It preserves every existing building coordinate, office/saloon doorway and main travel/duel lane. Stable/assay/feed/service yards host 12 ambient characters/animals, two instruments and two props. All 16 asset bindings remain unresolved until production. Phases are seeded; positions are deliberately clustered. Side avenues need actual terrain, paving, navigation and dressing in both shared-town users.

`validate` checks declared cast/story constraints, source drift, road/building clearance, connected road centre lines, doorway approaches, placement overlaps, complete facade targets, travel/duel exclusions, path segments against building/keepout rectangles, and declared actor/audio/pack budgets. Exit 0 = valid **proposal**, 1 = rejected proposal, 2 = malformed input/source adapter failure. It does not resolve engine meshes, real navigation, full moving-actor conflicts, audio mix or GPU cost. Null PCK size means unmeasured. Budgets are proposed caps, never performance evidence.

`handoff` writes the validated plan, schematic SVG, asset job briefs, capture job list, validation report and a Godot `Marker3D` scene. The marker scene is a placement reference only, with no meshes or runtime connections. The piano reuses the existing `Bar_Piano` candidate; a played piano still requires an approved pianist and contact animation. The fiddle needs its actor attachment and bow contact. No jobs are submitted automatically.

All plan points are Godot world `[x,z]` in metres, not relative offsets; captures use `[x,y,z]`. Correct source changes require replanning and preserving accepted creative changes deliberately. Never manually replace hashes to conceal drift.
