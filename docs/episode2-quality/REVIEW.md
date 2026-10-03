# Episode 2 player-view improvement — 2026-10-03

Reviewed the founder's design brief and three actual reference images against Claude's source at `36515d5836a00200d5c3c32406a1b3944221f89d`.

## Changes and evidence

| Player-view finding | Improvement | Comparison |
| --- | --- | --- |
| Grey wedges outside the outer ballast decks | Textured rock shoulders and instanced rubble, outside playable lanes | `mine-before-after.jpg` |
| A solid wall and orange rectangle block the cliff opening | Open forest skyline, distant golden-hour woods, forge light recessed below the skyline | `cliff-before-after.jpg` |
| Looking back exposes an empty brown hideout background | Rock arrival face, timber frame, lamps and closed iron mine gate | `hideout-entry-before-after.jpg` |
| Plain rectangular gold bars and clipped molten colour | Shared beveled ingot mesh; channel energy 2.2 → 1.3 | `hideout-gold-before-after.jpg` |

Comparison boards use actual Godot Compatibility GL renders at the same camera positions. Native captures include mine 20/100 m, a 240 m inspection cliff leg at 155/205/225 m, and arrival/forward/midroom/left/right/back/up in the hideout. The shortened cliff inspection leg is not a full campaign traversal.

The furnace comparison region had both red and green clipped in 16.5% of pixels before adjustment and 0% after adjustment. This is a local colour-retention measurement, not a calibrated whole-game blotch grade.

## Preserved contracts

Lil Blunt, the Tripo Bull, Winchester, helmet, whiskey glass, Bitcoin and tunnel model files are byte-identical. Their inventory is recorded in `protected-assets.json`. No movement, collision, damage, economy, story beat, access-code, film, music or control binding was changed. Front-page lock passes for all five protected files.

The new forest asset is a distant environment plate. Its provenance, import settings and byte budget are in `provenance.json`; it is not presented as a generated founder character or a complete replacement 3D environment.

## Reusable skills

Three installed personal skills are mirrored under `.claude/skills/`: `gm-game-ep2-mine-art`, `gm-game-ep2-hideout-art` and `gm-game-ep2-founder-assets`. They require source-grounded asset identity, player-camera review, the locked controls and film contract, Compatibility rendering, and export/deployment evidence. The founder-assets skill includes a read-only GLB structural inspector; it does not claim that skin metadata proves deformation quality.

## Verification completed before publication

- All 17 bounded Episode 2 suites pass: 548 assertions, zero script or parse errors. Facility suite rechecked after the molten material change: 96 assertions pass.
- Whole-project compile gate: 277 scripts and 205 scenes pass.
- Security sentinel: 18/18 after staging; front-page and green-VFX gates pass.
- Fresh CI-preset nonthreaded Web export: 197,017,040 bytes (187.89 MiB), below the 190 MiB gate; zero script/parse errors.
- Chromium exact-export test: fresh access prompt and invalid-code rejection; runner start and arrow/mouse input using a QA-only preloaded existing unlocked-device save. The PCK and published gate are unchanged by that fixture.

## Limits and release evidence

The 2,000-cycle stress soak was not repeated. External model graders were unavailable because this runtime does not expose their environment credentials. `blotch-hunt.sh` could not complete its live browser matrix in the initial container browser setup, so no calibrated detector pass or external art score is claimed. Native views prove the bounded scenery changes; they do not prove every frame of Bull's animation or a full film-to-exit browser playthrough.

Publication must be confirmed separately by master's CI export, the butler deploy step and its successful push log, followed by a matching live BUILD identity and browser input check. Source commits alone do not prove a live release.
