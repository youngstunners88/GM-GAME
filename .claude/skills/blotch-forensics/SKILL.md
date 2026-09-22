---
name: blotch-forensics
description: "Locate a reported visual smudge/blotch/blemish and say WHERE IT LIVES — baked into the artwork, drawn over it at runtime, or absent from our render entirely — using measurement rather than inspection. Use the moment the founder reports smudges, blotches, blemishes, smears or 'shit green' anywhere in Lil Blunt Adventure, and BEFORE editing any asset."
---

# Blotch forensics

Answer **where the defect lives** before anyone proposes what to do about it.
Three possible answers, and only three:

1. **In the artwork** — the plate itself carries the patch.
2. **Drawn over it at runtime** — the plate is clean, the render is not.
3. **Not in our render** — we cannot reproduce it at all.

Everything below exists to pick between those three from pixels.

## Rule 1 — test ratios, never a colour name

The founder calls these "green". Measured off his own `l3_blaze` capture, the
patches multiply the sky by **R ×0.86, G ×0.89, B ×0.83**: a near-neutral
*darkening* that only reads green because it sits on a saturated orange sunset.

Five detectors were written for this bug between 2026-08-20 and 2026-09-22.
Every one tested `green > red and green > blue`. There are no such pixels, so
all five reported the game clean and all five were believed.

> Trust the founder's report of **where**. Never trust a reported **colour** —
> a translucent neutral patch takes its apparent hue from what it sits on.

Report per-channel multiply ratios. `scripts/smudge-forensics.py --blobs` does.

## Rule 2 — high-pass before you judge a sky

A painted sky is a smooth gradient. Subtract a heavy Gaussian (σ≈45) and the
gradient flattens to noise while a real blotch survives. Needs no reference and
no alignment, so it works on a screenshot that arrives with nothing to compare
against.

Reference numbers on this project: a clean plate sky measures **std ≈ 4.1**;
our clean capture **≈ 5.0**; the founder's blotched frame of the same scene
**7.18, with a 1st percentile of −19.8 against our −8.0**.

**Do not use high-pass std as the verdict on a busy scene.** Art detail
dominates it: on this matrix it ranks `l2_blaze` (clean, 13.79) dirtier than
`l3_blaze` (blotched, 5.52). It is a sky test, not a scene test.

## Rule 3 — diff against the plate the scene ACTUALLY draws

Backgrounds parallax-scroll and wrap, so align first: roll the plate across all
1280 offsets and take the minimum mean-absolute-difference. Then measure where
the render is *darker* than the plate.

Resolve the plate with `scripts/blotch_scenes.py`, which parses
`src/resources/level_0N_data.tres` and `BLAZE_BACKDROPS` in `blaze_rush.gd`.
**Never hardcode the map.** A stale map makes every frame look blotched and
sends the next session hunting a defect that does not exist.

**Validity gate:** if the aligned frame still differs from its plate by
**mad > 5**, foreground content is covering the plate and the reading measures
*props*, not blotches. Refuse it. Without this gate the matrix scored 5/6
against the founder, three of them by accident — any busy scene clears any
threshold. Main stages are usually unmeasurable this way; Blaze Rush scenes,
whose skies are mostly plate, are usually measurable.

For an unmeasurable scene use the other method: capture the same scene yourself
and diff it against the founder's own screenshot of it.

## Rule 4 — check every committed version of the plate

"It is not in the art" is only true of the art the founder is **running**. Use
`blotch_scenes.all_versions()` and `git show <sha>:<path>` to test each. On this
project `bg_blaze_l3_gold_v2.jpg` has three committed versions and
`bg_l1_forest.jpg` six.

## Rule 5 — mask the founder's annotation ink, carefully

He circles defects in red. Detect ink as red with **both** other channels low
(`G < 70 and B < 70 and R > 110`), then dilate ~9px.

An earlier version tested only `G < 110`. That matched the smudges themselves
and silently erased the evidence — the run reported two blobs instead of four.
Widening an ink mask to be safe deletes the thing you are measuring.

## Rule 6 — calibrate against the founder's graded matrix

`scripts/blotch-oracle.json`. `l2_blaze` is graded **clean** while the other
five are blotched. That single row kills every "it's the founder's
GPU/monitor/browser/screenshot tool" theory — none of those skip exactly one
scene.

`scripts/blotch-analyze.py` self-grades on every run and exits non-zero when
uncalibrated. An uncalibrated detector has no opinion.

## Run it

```bash
bash scripts/blotch-hunt.sh                       # capture live + analyse + calibrate
python3 scripts/smudge-forensics.py founder.png \
  --plates src/assets/backgrounds/bg_blaze_l3_gold_v2.jpg \
  --against artifacts/blotch-matrix/l3_blaze.png --blobs
```

## Current open question

`l3_blaze` is the one measurable scene where our render and the founder's
diverge: he grades it blotched, our capture of the identical live build
(`18305533-1999670`) measures clean at his own window size, across 80 s and
many attempts. That divergence — not the colour, not the plates — is the live
thread. `l2_blaze` being genuinely clean means the answer is in the build, so
"we can't reproduce it" is a statement about our capture method, not a verdict.

## Hand off to

- `blotch-repair-gate` — what you are allowed to DO once localised, and the
  proof required before writing "FIXED".
- `live-build-proof` — the standard for that proof.
