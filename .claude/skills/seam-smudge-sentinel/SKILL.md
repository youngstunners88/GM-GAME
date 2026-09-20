---
name: seam-smudge-sentinel
description: Detect and fix the "dividing line" / "green smudge" defect class — the seams that make the game look poorly pasted together. Use whenever a backdrop, parallax layer, tile mirroring, or plate art changes; whenever the founder reports a line, seam, join, sliver or smudge; and BEFORE writing FIXED for any visual defect.
---

# Seam & Smudge Sentinel

The founder has circled this same defect class across many passes. Every prior
"FIXED" leaned on somebody eyeballing a screenshot, and every one of them was
wrong. This skill makes the defect a **number**.

## The rule that matters

**Never write FIXED for a seam or smudge from looking at a picture.**
Run the gate, quote the numbers, and only then make a claim.

## What actually causes the dividing lines

Three distinct mechanisms. They need different fixes — this is why one "fix"
kept failing to remove the others.

1. **Void gap.** The drawn backdrop tile is narrower than the viewport (or
   exactly equal, with zero margin), so raw `COLOR_VOID` / clear colour shows
   through as a hard near-black bar.
   *Fix:* `fill` must satisfy the viewport WIDTH as well as the height, plus a
   small pad; round the width up to a whole pixel.

2. **Overlap jump (self-inflicted, 2026-09-19).** Setting
   `motion_mirroring = drawn_width - N` makes the repeat period SHORTER than
   the tile, so the art jumps backwards N px at every wrap — a visible line
   **even on a perfectly seamless plate**. Measured live at x=1216 (=1280-64)
   in Level 1.
   *Fix:* the repeat period must EQUAL the drawn width exactly.
   **Overlap never hides a join. It manufactures one.**

3. **Non-seamless plate.** The plate's right edge does not continue into its
   own left edge, so the butt-join is a hard step.
   *Fix:* `scripts/make-plate-seamless.py` (offset-then-heal + Poisson blend).

## Tools

```bash
# Per-frame metrics on captured screenshots (void bar, seam, green blob)
python3 scripts/seam-smudge-gate.py /path/to/frames/    # exit 1 on FAIL

# Plate tile-join health. ~1 = seamless, >=3 = hard join.
python3 scripts/make-plate-seamless.py --check src/assets/backgrounds/*.jpg
python3 scripts/make-plate-seamless.py src/assets/backgrounds/bg_x.jpg  # repair
```

The plate check runs in CI (`export-game.yml` → Background art gate), so a
regression cannot ship silently.

## Measuring a join correctly

Compare the **step** across the join, normalised by the plate's own typical
column-to-column change:

```
ratio = mean|col[0] - col[W-1]| / median(mean|col[x+1] - col[x]|)
```

Do **not** compare 30-column means — that punishes a legitimate gradient and
will score a genuinely repaired plate as worse. That mistake was made and
caught on 2026-09-20.

## False positives to expect (verified)

The composited frame contains intentional art that looks like a seam:
- **platform trim rows** (bright cyan horizontal lines)
- **light shafts / waterfalls** (thin bright vertical lines)
- **rock/silhouette edges** (genuine dark-against-light boundaries)

A real seam is a **discontinuity**: content does not continue across it. Require
both a hard step AND a wide-window colour difference either side before
failing. A gate that cries wolf gets ignored exactly like one that sleeps.

## Repairing a plate — what not to do

A hand-rolled cosine/mirror blend was tried and **rejected on sight**: it left a
washed-out mirrored band that looked exactly like the pasted-together artifact
being removed. Use `cv2.seamlessClone` with `NORMAL_CLONE` (not `MIXED_CLONE` —
MIXED keeps the strongest gradient from either source, preserving the very edge
you are deleting).

Never "fix" a smudge by darkening the plate. The founder called this out
directly: burying a backdrop makes smudges louder, not gone. `mean_luma` is
reported by the gate so a darkening "fix" is itself detectable.

## Model roles (see CLAUDE.md MODEL ROLE SPLIT)

- **DeepSeek V4.1 Flash** — real vision, verified. Use it to LOOK at frames.
- **Jev (`~typesafe/jev-latest`)** — decisions model at
  `POST /api/alpha/decisions`, NOT `/v1/chat/completions`, and NOT in
  `/v1/models`. **Text only — it cannot see images** (control-tested: bar 0.22
  vs no-bar 0.19). Feed it the gate's NUMBERS, never a screenshot.
- **Claude** — owns the diagnosis, the patch, the commit and the FIXED claim.
