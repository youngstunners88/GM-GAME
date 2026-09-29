---
name: ep2-layered-production
description: The Episode 2 production workflow — five layers built in order, each gated before the next is layered on top - (1) illustration/key art, (2) wire spec of action, environment and characters, (3) design imagery over the wire spec, (4) 3D, (5) fluid motion + emotion. TRIGGER on any Episode 2 feature, level, character, set piece or "make it look/feel better / less cheap / more drastic" request, BEFORE writing code or generating assets.
---

# Why this exists
The founder (2026-09-27): *"create a logical workflow between the illustrative process of
imagery design and the wire spec foundation of the action and the environment and the
characters, then layer it with the design element of the imagery, then with the 3-D imagery,
then with the fluid movements of the characters and the emotions."* Every "cheap / grey /
too simple" report so far came from skipping a layer: 3D props with no wire spec behind them
(nothing strategic to do), or gameplay with no motion layer (statues sliding on rails).

# The five layers (build in order; never skip a gate)

| # | Layer | Owner files | Tools | Gate before the next layer |
|---|---|---|---|---|
| 1 | **Illustration** — key art per beat: what the moment LOOKS like | `artifacts/episode2-gold-mine/references/`, founder art | founder refs first; MuAPI (`scripts/generate_art.py`) for missing beats; `founder-art-intake` | every beat of the wire spec has a reference image named in the spec |
| 2 | **Wire spec** — the rules and numbers: verbs, hazards, speeds, lanes, cart life cycle, pacing, character footprints | `design/episode2_runner_wirespec_design.md`, `src/episode2/runner/tracks/episode2_tracks.gd`, sim `runner_graybox.gd` | `ep2-runner-level-grammar` skill | `ep2_runner_carts_test` (rules + **autopilot solvability**: every leg winnable with 0 hits, do-nothing run fails, ≥4 cart wrecks per leg) |
| 3 | **Design imagery** — palette, materials, telegraphs, HUD language mapped onto the wire spec | `src/episode2/art/ep2_palette.gd`, telegraph colours in `runner_view.gd` (`C_JUMP/C_DUCK/C_HOP/C_DANGER...`) | `art-direction-fidelity-check` (Astra) on a REAL capture | every verb has one colour + one word; the HUD tells cart state (strip: live / X / + / !) |
| 4 | **3D** — Meshy models FIRST (founder links, Meshy-7 PBR, remesh, retexture), seamless textures, scale contracts | `src/episode2/assets/`, `tools/ep2_forge/forge_runner_assets.py`, `tools/meshy/*`, `scripts/glb-shot.mjs` | `ep2-meshy-studio`, `ep2-asset-forge` | `ep2_glb_pipeline_test`, AABB/scale sane, pck < 190 MiB (`scripts/ep2-local-export.sh` prints it) |
| 5 | **Motion + emotion** — rigged skeletal clips chosen from sim state, reactions, camera feel | `src/episode2/runner/runner_motion.gd` (pure), view plays it | `ep2-motion-emotion` skill, `tools/meshy/meshy_rig.py` | `ep2_runner_motion_test` (priorities, rig clip contract, rig scale sane, live leg has no script errors) |

Then the **proof layer** over all five: `ep2-browser-playtest` with `?ep2bot=1` (the autopilot
plays; you only take screenshots), then **`ep2-reference-match-loop`**: the capture goes on one board beside the
founder's target image and passes his checklist. Founder feedback docs enter through `ep2-founder-intake`.
Look at every frame yourself before saying it works.

# Separation of concerns (hard rules)
- **Sim owns numbers, view owns pixels, motion owns clip choice.** The view reads the sim and
  never writes to it; `RunnerMotion` is static functions over sim state (headless-testable).
- **Layout is data** (`episode2_tracks.gd`, a `.gd` const — JSON is dropped by the web export).
- A layer may only consume the layer below through its public surface: tracks → sim `setup(opts)`;
  sim → view via getters/signals; rigs → motion via clip names in `RIDER_CLIPS/BEAR_CLIPS`.
- Research findings (`docs/research/3d/`) feed any layer but never land without a repro here.

# Routing: which model/tool does what
- Rules, tests, sim, view, motion: Claude in-session (OpenRouter Opus only when credits allow —
  check `/api/v1/credits` first; it was at $3 left on 2026-09-27).
- Unknowns ("why is the 3D blank on web?"): `ep2-3d-strategy-research` BEFORE the second
  bisection round.
- Pixels judged against refs: Astra (`art-direction-fidelity-check`). Audio judged: Gemini
  (`scripts/varco-grade.mjs`). Volume triage of logs/frames: DeepSeek Flash.

# Definition of done for an Episode 2 feature
1. Wire spec updated (numbers + beats) and the solvability gate passes.
2. Every new visual has a reference, a palette entry and a telegraph.
3. Assets forged at web size; pck under the gate.
4. Characters react (clip + emotion) to every new event.
5. Browser capture under `?ep2bot=1` reviewed frame by frame; no blank/dark frames
   (see research 001), no script errors.
6. STATUS.md, commit, `scripts/ship-to-master.sh`.
