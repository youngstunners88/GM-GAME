# Five street townspeople: reference rebuild

Source baseline: eef7f782; integrated master 2092bd73 before final checks. Original five GLBs are retained in originals/ and baseline.json. All thirteen Drive images were read visually; role choices and exclusions are in REFERENCE_REVIEW.md. No paid asset generation was used.

## Reproduction

Use native Blender 5.2.1, separate background processes, with ALSOFT_DRIVERS=null. Never connect to or close the owner's live Blender session. For each role clerk, oldtimer, rancher, dressmaker, lady:

```sh
ALSOFT_DRIVERS=null blender -b --factory-startup -t 2 -P tools/ep2_blender/rebuild_street_people.py -- --only clerk
ALSOFT_DRIVERS=null blender -b --factory-startup -t 2 -P tools/ep2_blender/review_street_people.py -- --person clerk --render
python tools/ep2_blender/audit_street_people.py
```

Editable sources and three 1024px maps per character are in sources/. CC0 anatomical source and license are in source/. Installed toolkit verification passed (89 audited files). Export uses standard embedded JPEG/PNG PBR, one draw surface, UVs, tangent normals and ORM roughness/metallic. No compressed-mesh extension or custom shader dependency.

## Evidence and results

- All five installed semantic asset and rig checks pass: qa/*/asset.json and rig.json. Warnings retain deliberate clothing openings, UV seams/stacking and enclosed garment surfaces. No loose geometry, degenerates, unweighted vertices or excess influences.
- Every vertex and edge evaluated at 12 samples/second in all five original clips; receipts include source hashes and worst deformations. Shortened the legacy head/neck proportions by moving head landmarks and bind together. Fixed mesh-only bind normalization, wrist gaps, sleeve/waist welds, incorrect hem influence and hidden inverted blouse-tail shells.
- Raw native captures cover nine samples of every clip at two views, plus faces/hands and four angles. Compact inspected sheets are in gameplay/sheets/. Raw captures are local, gitignored.
- gameplay/session contains matching actual GoldTownChamber before/after captures with the real HUD, weapon, desert light, 78-degree lens, 1.55m player eye and autonomous roster greetings. The fixture changes no shipped gameplay or access controls.
- Full existing CI headless suite passed, including town behavior, animation, armory, motion and new street asset gate (130 checks). Existing runner tolerates exactly three machine-dependent pause tap-target assertions. No new exception was added. Script compile: 356 scripts and 248 scenes pass.
- Texture exclusion probe: 69 models, zero excluded-but-used images. Extras presence: 11 named and 48 shipped extras present. Title lock passes. Security Sentinel: 18/18.
- Local export: index.pck 199079200 bytes, extras 28552160 bytes, zero script/parse errors. Limit 199229440 bytes; main margin 150240 bytes. Fresh-import gate must pass after commit before publication.
- Local Chromium web launch is blocked by sandbox socket permissions (SIGTRAP). Native gameplay proof is complete; browser/public proof is tracked separately and must not be inferred from native captures. Existing engine shutdown resource/UID warnings persist; no SCRIPT ERROR in successful gates.

## Visual limits

This is a stylized real-time reconstruction, not a photoreal scan. Reference facial projection is strongest from the front; profiles and simplified solid hair/beards remain less natural than the references. Hands have anatomical separated fingers but retain rigid Hand weights because the original 20-joint skeleton has no finger bones. Clothing has authored folds and material-specific texture/roughness, no cloth simulation. Point can compress the shoulder (worst local edge excess roughly 1–3 cm); silhouettes remain stable through the reviewed clips. Children, pianist gameplay role and prisoner roster expansion are outside this first five-character replacement.

Deployment evidence is recorded in the release receipt after successful CI and public verification.
