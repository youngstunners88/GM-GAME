---
name: crouton-lane
description: Use Crouton Alpha (stealth/crouton-alpha on OpenRouter, free, 1M context, image/audio/video in) as extra hands for bulk reading, GDScript triage, screenshot second readings and drafts, behind free-only, privacy and measurement guards. TRIGGER when the founder says Crouton, stealth model, free model, "give load to a cheap model", or when a task is mostly volume (scan many .gd files, read all dialogue, triage many frames) and a paid model would be waste. Never for ship decisions, FIXED claims or the critical path.
---

# Crouton lane: free extra hands, measured before trusted

`stealth/crouton-alpha` (checked 2026-11-04): $0 in and out, 1,048,576-token context, text + image + audio + video in, text out, tools and JSON mode work. It is an
**anonymous provider's preview: prompts may be kept** (not used for training), the price can change, the model can disappear. Its output is a **lead, not a fact**:
Claude re-derives every claim against the real files (MODEL ROLE SPLIT) and it never decides ship/block, never says FIXED, never says live.

## Where it sits in the model split
| Need | Use |
|---|---|
| Art-direction fidelity of a real screenshot vs the founder's reference | Astra (`art-direction-fidelity-check`) |
| Cheap first-pass triage of long logs / many diffs | DeepSeek V4.1 Flash |
| Ship/block decision on numbers | Jev (`jev-1-14-routing`) |
| **Free bulk reading, a second reader on .gd files or frames, drafts** | **Crouton (this skill)** |
| Anything that writes the repo | Claude (or `opus-offload`/`kimi-k31-offload` packets Claude reviews) |

## Run it
```bash
export NODE_USE_ENV_PROXY=1 NODE_EXTRA_CA_CERTS=/root/.ccr/ca-bundle.crt   # this sandbox only: Node's fetch ignores HTTPS_PROXY otherwise
node scripts/crouton-call.mjs prompts/x.md out.md --kind review --dry-run   # checks the catalogue says $0, shows effort and budget, sends nothing
node scripts/crouton-call.mjs prompts/x.md out.md --kind review --task gd-scan [--json] [--image shot.png]
node scripts/crouton-call.mjs --status                                      # measured success per task from .farm/crouton-log.jsonl
```
The prompt file takes `@include <path>` lines (inlined; missing or private paths abort before anything is sent). Always ask it for **file + line** and verify each one.

## The call template (why it exists)
It reasons by default at `max` effort, and that thinking spends `max_tokens`: a 400-token budget returned `content: null`, `finish_reason: length`. So the lane always sends
`reasoning.effort` by `--kind` (classify=minimal, review=low, draft=low, digest=medium) and `max_tokens >= 4000`; an empty answer cut off by length is retried once with double
the budget. Use one `--task` name per kind of job: the measurement is per task.

## Guards (pinned by `tests/crouton_lane_test.mjs`; run `node --test tests/crouton_lane_test.mjs`)
- **Free only:** known-free id, live catalogue at $0 (daily, fail closed), and one call reporting `usage.cost > 0` writes `.farm/crouton.tripped` and refuses everything after.
  Read why, then delete the file by hand. Allowance `CROUTON_DAILY_CALLS` (default 200).
- **Private stays home:** key-shaped strings and live key values, `0x` wallet addresses (CLAUDE.md: never in code, so never out), and `@include` of `.env*`, `*.key`, `*.pem`,
  `config.json`, `lil-blunt-icp/` (canisters, wallets), `GM Game/` (the vault) and `.farm/` are refused. Founder feedback docs are the founder's: ask before sending one.
- **Off the critical path:** no CI step, no other script, nothing under `src/` uses it (a test fails otherwise). The front-page lock, NFT rules and ship gates are not its business.

## What to give it (and what each is measured on)
1. **GDScript triage** (`--task gd-scan`): whole files or folders for null access, wrong signal wiring, Godot-3 API, int division, `:=` from a Variant. Bench: 12 paired fixtures with one
   known bug each. `gdparse` stays syntax-only and a real export stays the ground truth.
2. **Screenshot second reading: DO NOT USE for blotches.** Measured 2026-11-04: it called all six frames in `artifacts/blotch-matrix-1999670` clean (confidence 0.75-0.92, 3 of 3
   runs each), agreeing with `scripts/blotch-oracle.json` on 1 of 6 (only the negative control `l2_blaze`). It cannot see a near-neutral 15% sky darkening, which is exactly what the BLOTCH
   RULE says eyes and eyeballing models miss. `blotch-analyze.py` is the measurement. Other image jobs (a screenshot description, a UI read) are fine but unmeasured; add a bench first.
3. **Canon / dialogue sweeps** (`--kind digest`): all Episode 2 dialogue for contradictions (`ep2-narrative-canon`), design docs against code names. Verify by grep.
4. **Drafts** (`--kind draft`): STATUS and changelog text from `git log`, test-case lists, doc skeletons. Claude edits and owns the commit.

## Measure before you trust: `node scripts/crouton-bench.mjs gd|blotch|all [--runs N] [--dry-run]`
Ground truth is written down first (`tests/crouton-bench/make_gd_fixtures.py` for the GDScript pairs; the founder's graded matrix for frames). Scores: right, wrongly flagged,
missed, findings that cite a line that does not exist, coverage. A failed call is not a look. Exit code is non-zero unless the verdict is eligible/calibrated. Reports are in
`artifacts/crouton-bench/<day>-<task>.json`; the latest numbers are in the table below. Eligible means "may be a triage second reader", nothing more. Add real regressions to the
fixtures as they happen; the injected set is a floor.

### Latest measured results (2026-11-04, `stealth/crouton-alpha`, `--kind review`, temperature 0)
| Bench | Reads | Right | Wrongly flagged | Invented lines | Verdict |
|---|---|---|---|---|---|
| `gd` (12 paired fixtures, 3 runs each, corrected fixtures) | 36 bug + 36 clean | caught 32/36 (recall 0.889) | 1/36 (0.028) | 0 | **not eligible**: recall is just under the 0.9 bar fixed in advance |
| `blotch` (6 founder-graded frames, 3 runs each) | 18 | agrees on 1/6 scenes | n/a (it called every frame clean) | n/a | **uncalibrated: no opinion; do not use** |
How to read this. The pair it never caught was the `:=` inference from a Variant (0/3), the Godot 4.3 hard error the export gate rejects and `gdparse` passes: keep a local check for that
and do not lean on Crouton for it. It missed a Timer-started-before-`add_child` once in three. Everything else in the set it found, with correct line numbers, and it invented no line.
Run 1 reported a false alarm on `yield_godot3_clean.gd`; that was an error in the fixture (`extends Node` setting `modulate`, which only a CanvasItem has) and Crouton was right. The fixture is
fixed and the first report is kept as `artifacts/crouton-bench/2026-11-04-gd-run1-fixture-error.json`. Twelve pairs is a smoke set (the 95% interval on recall is roughly 0.74-0.96): useful as a
second reader whose every finding Claude verifies, not as a gate. Next step if wanted: a v2 prompt that lists the repo's Godot 4.3 traps, measured on new fixtures, not these.

## Troubleshooting
- `tripped` / `billed`: a call reported a cost. Stop, check the catalogue price, delete `.farm/crouton.tripped` only when it is free again.
- `no longer free` / `not in the catalogue`: the preview ended or was priced. Tell the founder; do not switch to a paid id inside this lane.
- `fetch failed`: Node ignored the proxy. Use the `NODE_USE_ENV_PROXY=1` line above (or `npm install undici`).
- `empty-length` after the retry: the task needs more room than 8000 tokens; narrow the question or use `--kind classify`.
- A finding names a line or symbol you cannot find: that is the model inventing it. Count it, drop it, move on.
