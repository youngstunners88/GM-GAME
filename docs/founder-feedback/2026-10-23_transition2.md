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

## Local release gates and publication

- Gameplay source: `e1b93d22d1d79bfd805d6e160350d3481e03249a`.
- Fresh-import main pack: **199173136B / 199229440B**, margin **56304B**. Warm-cache pack199205824B; real nonthreaded4.3 export has zero script errors. Texture reference probe:69models/0excluded-but-used textures. Local Chromium boots this export and reports extras ready/HTTP200.
- Staged-source security sentinel:18checks/no blockers. Founder-approved front-page5-filelock:PASS. Full localCI and targeted runtime gates passed as recorded above. The final null guard changes only the missing-kit fallback; normal-kit runtime behavior is identical to the recorded captures/tests.
- Normal nonforced branch/master push succeeded. [Production workflow39965066342](https://github.com/youngstunners88/GM-GAME/actions/runs/39965066342) is running for that exact source. Expected stamp: `2026-10-23-e1b93d2`. Actual upload and publicly served BUILD remain unverified until the final receipt.

## Final production and public receipt — verified 2026-10-24

- Exact gameplay source `e1b93d22d1d79bfd805d6e160350d3481e03249a`; generated export commit `b17acfad5fea9649bbf25a536a13e07d6427402f`. [Master run39965066342](https://github.com/youngstunners88/GM-GAME/actions/runs/39965066342), export job120452670367: **SUCCESS**. Actual TRANSITION2 runtime regression, complete gameplay block, rendered portal/town checks, title/security gates and web export pass.
- Exact CI main pack **199173008B / 199229440B**, margin **56432B**, from its exported HTML fileSizes. Streamed extras **54443936B**. Nonthreaded pinned4.3 export.
- Actual butler upload completed2026-10-23T14:12:00Z:275.98MiB/14files,44.50MiB fresh data,40.62MiB patch; “Pushed to https://youngstunners88.itch.io/smokerealm”. No missing-secret upload skip.
- Actual public Chromium verification: **BUILD `2026-10-23-e1b93d2`**, iframe18305533-2194028, extras ready/HTTP200, preserved access-code prompt. [Public log](../episode2-quality/transition2-2026-10-23/public-build.txt), [public screenshot](../episode2-quality/transition2-2026-10-23/public-access.png).
- The changed action is verified by native actual-camera captures, real held-input runtime tests and the local export checks above. A protected public Episode2 walkthrough is not claimed. The public check confirms the shipped BUILD and mounted extras. Verification date here uses the client's2026-10-24 date; the BUILD and upload retain their actual2026-10-23 UTC stamp.
- Live: https://youngstunners88.itch.io/smokerealm. Final documentation/routing receipt does not alter gameplay source or require another export.
