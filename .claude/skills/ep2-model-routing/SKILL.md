---
name: ep2-model-routing
description: Pick the cheapest model that can actually do a given Episode 2 job - local code, Jev typed decisions (direct TypeSafe or OpenRouter), the Jev Router, Gemini 4 Argon for 3D/visual reasoning, Astra, DeepSeek - with verified slugs, prices, limits and a calibration protocol so a model is trusted only after it matches a known answer. TRIGGER on "which model", "route this", "use Gemini / Jev / Astra / DeepSeek", "second opinion on the 3D", "typed decision", before ANY paid OpenRouter or TypeSafe call, and when the founder names a model.
---

# Model routing (verified 2026-10-15 from OpenRouter's PUBLIC catalog and the TypeSafe docs; no key was available locally)

Claude owns the repo, every commit and every "fixed". Other models give ADVICE that is re-derived against files, numbers
and engine captures before it informs anything (CLAUDE.md MODEL ROLE SPLIT). This skill only decides WHO to ask.

## Order of operations (stop at the first row that answers it)
| # | If the question is... | Use | Cost |
|---|---|---|---|
| 1 | exact / measurable / known rule (counts, sizes, UV overlap, stretched edges, lint) | **local code** (`bull_game_inspect.py`, `ref_metrics.py`, tests) | $0 |
| 2 | a small ambiguous semantic call over MEASURED facts (ship? which of 3 fixes first?) | **Jev decisions** via `node scripts/jev.mjs` (skill `jev-1-14-routing`) | ~$0.00002 |
| 3 | a visual/3D judgement needing real pixels or mesh reasoning | **Gemini 4 Argon** `google/gemini-4-argon` (skill `gm-game-lane-gemini-3d`) | <= ~$0.25/review |
| 4 | founder-reference fidelity grade of a real capture | **GPT-6 Astra** (`art-direction-fidelity-check`) | ~$0.15 |
| 5 | volume triage (logs, many frames, long diffs) | **DeepSeek V4.1 Flash** via `scripts/or-call.mjs` | ~$0.01 |
| 6 | open-ended, cost/quality unknown, not decision-critical | **`typesafe/jev-router`** (chat completions; it picks model + effort) | variable |

## Verified facts (do not re-litigate; re-verify only when a call fails)
- `google/gemini-4-argon`: 1,048,576 ctx, input text+image+file+audio+video, $2 in / $10 out per M, `:batch` variant half price,
  tools + structured outputs + reasoning_effort supported, max completion 65,536. The founder's "gemini-4-argons" is a typo:
  the real slug is SINGULAR.
- `typesafe/jev-router`: OpenRouter chat model, price shown as -1 (variable pass-through, so cost is NOT bounded by the
  catalog: always set `max_tokens` and treat the first runs as probes), 1M ctx, accepts image/video/audio/file. It is a
  router, not the typed Decisions API.
- Jev TYPED decisions: docs model ids `jev-1.14.0` (= alias `jev-preview`) and `jev-1.13.0`. **`jev-latest` still points at 1.13.**
  Docs models page says text-only; images are an EXPERIMENTAL header (`TypeSafe-Danger-Zone-Images`). Image limits: PNG/JPEG,
  each side 256-1568 px, total 78,400-2,458,624 px, 16 MiB each. New `box` question type (experimental). Long context
  (262k) needs `TypeSafe-Danger-Zone-Long-Context`. "All models perform worse on multimodality than on text."
- Decisions are ONLY for choices over text/measurements. For pixels, use row 3/4 and feed Jev the NUMBERS they produce.

## Trust protocol (a model is "good at 3D" only after this)
1. Calibration set = a case where Claude already knows the answer (the 2026-10-15 Bull: black face comes from the Hunyuan
   painter's albedo; self-emission fogs the figure; stale extracted `_0/_1.jpg` scrambles UVs). Files:
   `docs/episode2-quality/bull-hunyuan-2026-10-15/`.
2. Send the same pack to the candidate (Argon) and one control (Astra). Score: does it find the known cause, does it
   invent files/features, does its repair plan avoid the known dead ends?
3. Record the result in `docs/model-responses/` with date, model id, tokens, cost. Only then raise or lower its lane.

## Rules
- Dry-run first (`scripts/or-call.mjs ... --dry-run` prints tokens and worst-case $). Cap spend per task at $1 unless the founder says more.
- Never send keys, wallet data, or the whole repo. Send only the images and facts the question needs (`@include` expands files).
- `OPENROUTER_API_KEY` / `TYPESAFE` live in the environment (names only; never print values). The local laptop currently has none:
  the founder stores them ONCE, hidden-input, outside the repo, then every command does `source ~/.config/gm-game/env`:
  `mkdir -p ~/.config/gm-game; read -rsp "OpenRouter key: " K; echo; (umask 077; printf 'export OPENROUTER_API_KEY=%s\n' "$K" > ~/.config/gm-game/env); unset K`
  (add a `TYPESAFE=` line the same way for direct Jev). Never paste a key in chat; never commit that file.
- Money-moving or shipping decisions are never delegated: a model answer cannot approve a deploy.
