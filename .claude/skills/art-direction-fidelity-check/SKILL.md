---
name: art-direction-fidelity-check
description: Grade a REAL screenshot of the running game against the founder's reference art using GPT-6 Astra via OpenRouter. Run this after every visual change to Episode 2 and BEFORE reporting any visual work as done. Not optional on an art turn — a description of a screenshot is not a screenshot.
user-invocable: true
allowed-tools: Bash, Read, Write, Grep, Glob
---

# Art-Direction Fidelity Check

## Why this exists

Every serious Episode 2 defect so far was invisible to logic gates and only
found by looking at pixels:

| Defect | What every gate said | What the pixels said |
|---|---|---|
| Hazards were pure data with no mesh | 21/21 green | you take damage from nothing |
| Materials blown out | 8 gates green | the screen is white |
| **Both 3D cameras faced backwards** | 8 gates + 2 playtests green | the track is behind you |

That last one had survived two human playtests, because "it looks dark and
confusing" reads as "it's a graybox" until someone measures it.

This skill is the discipline that closes that gap: **capture real pixels, send
them to a model that can see, act on what it says.**

## The two commands

### 1. Capture

```bash
node scripts/serve-web.mjs 8899 web &            # if not already serving
node scripts/capture-ep2.mjs http://localhost:8899/game/index.html artifacts/ep2-shots
```

Writes `ep2_runner_start.png`, `ep2_runner_mid.png`, `ep2_runner_late.png` and
`capture.json` (which records any GDScript errors seen in the console). It
warps in with `?ep2=1` so a capture never depends on beating three bosses.

The build must be exported first — a capture of a stale `index.pck` grades the
last change, not this one:

```bash
GODOT="$(scripts/bootstrap-godot.sh | tail -1)"
"$GODOT" --headless --export-release "Web" web/game/index.html
```

### 2. Review

```bash
OR_MAX_TOKENS=6000 node scripts/or-call.mjs openai/gpt-6-astra \
  prompts/templates/astra-fidelity-check.md artifacts/episode2-gold-mine/art/astra_fidelity_<date>.md \
  --image artifacts/ep2-shots/ep2_runner_mid.png \
  --image artifacts/founder-art/references/ep2_runner_ref_3_minecart_ride.jpg \
  --image artifacts/founder-art/references/ep2_runner_ref_1_boulder_bandits.jpg \
  --image artifacts/founder-art/references/ep2_runner_ref_2_zipline.jpg
```

**Image order is load-bearing** — the prompt template tells the model the FIRST
image is the live capture and the rest are references. Reorder them and you get
a review of the reference art.

Add `--dry-run` first if you want the cost before spending. A four-image review
costs roughly **$0.14-0.20** at Astra's $10/$50 per million.

## Rules

1. **Astra is for grading pixels, not for writing code.** It is 5-10x the price
   of Sonnet per token. Use it for fidelity review and world-building
   brainstorming; never for test-writing, scripts or pipeline plumbing.
2. **Its output is unvalidated.** `or-call.mjs` stamps that warning into every
   saved file. Verify each claim against the real scene before acting. Its
   art-direction extraction pass correctly refused to assert albedo from lit
   images — take that caution seriously rather than treating hex values as
   measurements.
3. **Archive every review** under `artifacts/episode2-gold-mine/art/` next to
   the capture it graded. A review with no matching screenshot is a claim.
4. **Never report a visual task as done on a DRIFTING or OFF MODEL verdict**
   without saying so in the same breath, with the ranked drift list attached.
5. **Ignore its engine advice that assumes Forward+.** The web build runs
   Godot's **Compatibility** backend: no volumetric fog, no SSR/SSAO/SDFGI, and
   metallic surfaces with no reflection source render near-black. The prompt
   template already tells it this; if a recommendation still assumes them, drop
   the recommendation, not the backend.

## Reading the verdict

`ON MODEL` / `DRIFTING` / `OFF MODEL`, then a ranked drift list where each item
names the smallest fix. Work the list top-down and re-capture — the ranking is
by damage, so the first item is usually worth more than the rest combined. In
the 2026-09-10 pass the top item was "darkness erases the playable scene",
which no amount of palette accuracy below it would have compensated for.

## Relationship to the headless gates

`tests/ep2_art_direction_test.tscn` locks the *numeric* conditions behind these
findings — effective ambient, tonemap white, "no ordinary surface competes with
gold", and camera framing — so a regression fails in CI instead of waiting for
the next review. **The gate is the ratchet; this skill is how the ratchet gets
its next notch.** When a review finds something real, add the assertion.
