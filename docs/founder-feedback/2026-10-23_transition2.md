# Transition 2 — 2026-10-23

Source: https://docs.google.com/document/d/13UCLeD1_nYO6njF8S2Q7dkC_l_qi5Fm4T8_195_IrUw/edit
Baseline: e9d52778848acc20dadd8478cbf1072d4fd08f90, freshly fetched master matches, clean checkout.

| Founder request | Measured cause | Repair | Proof |
|---|---|---|---|
| “characters literally walk through a beam ... remove that beam when the elevator door opens” | Shaft front brace at y16/z4.05 crosses surface exit at chest height | Hide only that brace before opening gate; keep other support timbers | PASS: inside-cage before/after; Transition2 brace-before-gate regression |
| “walk straight out ... absolutely no pause” | setup resets input; root only sends changed held keys. Bull restarts at standalone trail point behind him; bob/animation and intro reset | Retain held input/stride; resume next forward waypoint and actor phase; skip repeated intro; prepare wildlife ahead of cut | PASS: actual root holds W across swap, continues30ticks, release/diagonal/back/sprint; mapped first frame and stride; forward Bull |
| “INFERNO bag is actually blocking the view ... lil blunt a little bit higher” | Quad rear-rack BACK_EYE=1.40 with current painted driver/pack | Raise supported passenger stance; normal and ADS capture/aim-hit check | PASS: normal/ADS/side/backroad captures; actual road bear ray/hit and6→5ammo,18reserve unchanged |

Existing location-continuity skills extended in both agent directories. New passenger-sightline skill installed/routed for both agents. Preserve first person, founder models, title/access, finite armory, all encounter contracts and nonthreaded4.3 export.

## Verification before publication

- Pinned Godot4.3 SCRIPT_COMPILE, TRANSITION2, TRANSITION_FEEDBACK, EP2_INTERLUDE, EP2_SESSION_ROOT, SAVE_COMPAT: ALL PASS. Full local CI headless block: PASS; only the existing three pause tap-target machine differences are tolerated by its existing runner.
- [Actual-camera comparison](../episode2-quality/transition2-2026-10-23/comparison.jpg), [aimed bear](../episode2-quality/transition2-2026-10-23/aim-road-bear.png), [held-walk trace](../episode2-quality/transition2-2026-10-23/held-walk.json). The former passenger setting is reconstructed on identical unchanged driver/pack/road geometry; exit-brace “before” is captured from original source before repairs.
- Driver-visible/hidden render difference in the fixed central116×108-pixel corridor falls40.006%→1.054%. Foliage TIME/shadow variation contributes residual changes, so this is not claimed as a pure silhouette mask. Inspected normal/ADS and side/rear views; actual target visible above sights, aimed shot fires and reduces bear2→1HP. Fixture uses an existing road bear positioned22m ahead for reproducibility; no gameplay enemy placement is changed.
- The held-input defect is eliminated; all sampled ticks retainforward input and stride. Native instrumented cut CPU28.742ms, next ticks2.001/0.455ms; one later sample69.719ms under concurrent headless checks. Samples advance60Hz with occasional rendered captures, not a realtime browser FPS benchmark, and do not promise zero renderer stalls on every device. First baseline multi-frame render exceeded its240s software-render timeout; the separate old-eye comparison and final capture completed.
- Wildlife meshes/audio are prepared before the cut and ambience starts only on activation; runtime regression checks silent prebuild and audible activation.
- Legacy optional smelting material-name assertion from the previous release remains outside this scope; actual release suite passes. Native llvmpipe emits existing teardown/RID/null-material diagnostics; rendered captures complete and no gameplay script error is accepted.
- No source assets, title/access policy, economy or paid generation changed. Fresh-import export/security gates and actual production/public proof pending.
