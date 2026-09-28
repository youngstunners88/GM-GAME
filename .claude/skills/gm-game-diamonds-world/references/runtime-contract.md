# Runtime and verification contract

## Inspect before designing
- Read the repository’s instructions, `portals/CONTEXT.md`, `portals/STATUS.md`, `StudyRoom.gd`, `PortalExplorer.gd`, `TourStop.gd`, `Companion.gd`, and the relevant room scene/copy. Refresh the default branch and inspect recent diffs; preserve concurrent work.
- Baseline reviewed: `youngstunners88/GM-GAME` master `aa5e1f5a12387abbd8c98e46f57e745dc0ebd798` on 2026-09-27. Top-down maps arrived in `85ad26978861b7c40ae96a79a26cae14f3c1f1d8`; the export gate repair followed in `ce9ce1cf1830d09b4ddd1b94d30b7d75e1b4ffed`. Do not revert to the older side-on tour-strip comments.
- Founder inspiration: https://docs.google.com/document/d/1HSqakFkrnyASYnzLRghu2q3nVTiJr7UzknQlwMkkdDM/edit . There are 18 images: 4 SMOKE, 6 DIAMONDS, 8 GOLD MINE in document order. Fetch with Google Drive; inspect actual pixels and preserve section membership. Use as inspiration, not a mandate to stretch a poster over the map. Do not persist temporary authenticated image URLs.

## Diagnose the void first
At the reviewed baseline `_build_backdrop()` creates `Backdrop` at z=-100, but `_build_floor_and_walls()` creates a fully opaque `FloorSlab` at z=-50 spanning the whole 2800×1100 map. It hides the gradient, pillars and motes below it. This is source evidence, not a confirmed runtime screenshot. Fix the layer relationship before commissioning additional art. Capture before/after from the same camera.
- Use an opaque ground substrate beneath terrain, then paths and station foundations, decorative structures, actors and atmospheric accents, then HUD. Keep UI in CanvasLayer; setting a local z-index cannot cross CanvasLayer order.
- Do not just remove all background darkness or hide the floor node. Keep a continuous substrate and collision containment. Add top-down terrain as a separate Node2D component instead of growing StudyRoom’s session/UI responsibilities.
- Baseline diamonds/gold landmark loops place some shapes beyond x=2800. Clamp/author against current bounds, not obsolete strip spacing. Separate decorative facades from walkable paths so visible architecture matches collision.

## Protect the working game
- Preserve four-direction explorer, both-axis companion following, visited-stop gate, official paper/video URLs, ladder arrival/ascent, return coordinates, question banks, scorecard semantics and front page. Do not change Episode 2 or existing lounge/vault/Blaze Rush entries.
- Keep the 11 questions and 7/11 threshold. Fail supports Retry or Proceed with score. Completion eligibility is not mint confirmation. No wallet, token or reward changes are part of world dressing.
- Preserve each authored stop ID and its collision/interaction envelope. Read actual envelope sizes before placement. Keep clear walkways at least 3 player-body widths, with a clear arrival route and no long forced maze.
- Make the map feel expansive through districts, loops, landmarks, foreground/midground/background and camera reveals. Do not enlarge coordinates without reauthoring camera limits, navigation and all interactions. Initial envelope is 2800×1100; verify it on the active branch.
- Keep text in native UI; generated signs carry no protocol facts. Approved logos remain separate faithful textures. Author top-down/three-quarter props to one camera convention; no first-person scenes or full 3D conversion.

## Provider routing
- Use the selected Google Drive skill for references and the repository’s media pipeline for MuAPI imagery. Inspect credential presence only; never read or echo values. Missing MuAPI configuration blocks MuAPI generation, not analysis or skill authoring. Do not silently swap providers; name a proposed alternative and obtain the required authorization.
- Use the current Meshy plugin skill for CLI/auth/output handling. A missing environment key does not establish that a stored Meshy session is absent. Check CLI auth status if a Meshy job is actually needed. Never copy credential files. Meshy is optional for reusable props rendered to 2D; a background image is not a mesh.
- Apply Build 3D Game Rooms to actual 3D prop/room production: purpose, scale, attachment/front axes, runtime camera, passage semantics, reference approval, paid budget, isolated mesh-ready prompts, immutable task records, cleanup and review gates. Do not upload a whole settlement illustration to Meshy as one terrain mesh. Its Meshy-5 pin and the repo’s Meshy-7 note conflict: record and resolve the selected pipeline/model explicitly before a paid call; never invent compatibility or silently override a gate.
- Use Game Development Studio for available production, admission and rendering workflows. Inspect `game-dev --version`, capabilities and doctor first. If absent, report that workflow unavailable; do not install it or claim receipts. Normal repository code work can continue independently with its own evidence.
- Separate human layout/reference approval, paid spend, asset acceptance and deployment. Do not infer them from a successful lint or render. Preserve actual credits, task IDs, provenance, hashes and licenses. Never auto-resubmit a job whose outcome is unknown.

## Capture and accept
1. Fresh-import in the repository’s Godot version, run existing portal logic/room/ladder tests, and produce a fresh non-threaded web export. Syntax-only validation is insufficient.
2. Capture the actual loaded build at gameplay zoom: arrival, each learning district, examiner, both study interactions, pass, fail/retry and ascent. Also capture one full-map diagnostic; never use it as the sole gameplay proof.
3. Walk every required stop and both study routes. Check companion labels, overlay input, stop activation, exam gate and return. Include all four map extremes to catch voids and out-of-bounds landmarks.
4. Inspect pixels for visible ground, material contrast, coherent perspective, smoke/glint/dust restraint, actor/label separation and distinct regional silhouette. A text-only model cannot certify a screenshot it did not inspect.
5. Compare capture timings and export size to the same baseline on the same runtime. Record measured evidence; do not claim FPS or GPU passes from a static image. Keep preview/evidence assets outside the runtime import path using the project’s evidence exclusion convention.
6. Record source revision, changed paths, provider status/spend, captures, test results and remaining gates. Use the repository’s shipping workflow only when its actual gates pass. Report local, branch, merged and deployed states separately.

## Target budgets (proposals, not measured results)
Start with <=4 MiB compressed new art per region, <=2048-pixel atlas sides, <=48 ambient particles per region, no realtime 3D geometry in the 2D map, and <=0.12 fog alpha over walkways. Profile before changing budgets. Respect the project’s existing export-size gate; no performance claim follows from these targets.
