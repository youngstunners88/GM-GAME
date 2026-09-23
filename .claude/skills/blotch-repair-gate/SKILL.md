---
name: blotch-repair-gate
description: "What you are ALLOWED to change once a smudge/blotch has been localised, and the live proof required before writing FIXED. Use after blotch-forensics has named a carrier, before editing any asset or VFX, and before any status update or commit message that claims the smudges are resolved."
---

# Blotch repair gate

`blotch-forensics` says where the defect lives. This says what you may do about
it, and what counts as done. Both halves are constraints, not advice: every one
of them is written from a specific failure the founder paid for.

## Gate 1 — no carrier, no edit

You may only modify an asset that a **measurement names as the carrier**. Not
a plausible suspect. Not "while we're here".

Twice a background plate was rewritten on a theory about the cause:

- a wrap-aware inpaint turned the L3 sunset into a brown mushroom-cloud smear;
- a regenerate-from-source re-rolled the image and moved the sun to the screen edge.

Both were reverted, both were wrong, and the founder saw both. The plates were
never the carrier.

**If localisation is inconclusive, the correct output is a report, not a
change.** Shipping something to look busy is how this bug outlived five fixes.

## Gate 2 — remove means remove

When the founder asks for something **gone**, deleting it is the only
compliant action.

The `COLOR_HAZE` blobs were circled on 2026-08-20. That round *softened* them —
alpha 0.5→0.16, scale 6×4→11×7. He circled the same three shapes again on
2026-09-21. Softening bought a month of re-reports and cost a month of credits.

> A fainter version of a rejected element is still the rejected element.

## Gate 3 — never hide, always remove

Do not blur, darken, dim, or wash a backdrop to make a patch less visible.

> Founder: *"Burying the backgrounds doesn't take them away. It actually
> exposes them more."*

A blur pass on the Blaze Rush backdrop was rejected on sight and correctly so.
Fix the cause or report that you cannot.

## Gate 4 — overlap never hides a join

For the dividing-line variant specifically: a parallax repeat period **shorter**
than the drawn tile makes the art jump backwards at every wrap and
*manufactures* a seam. A 64px overlap did exactly that and put a new dividing
line in Level 1 at x=1216 — a defect introduced while claiming to fix one. The
founder caught it in a day.

Period must **equal** the drawn tile width exactly. Joins are made invisible by
making the plate seamless (`scripts/make-plate-seamless.py`), never by fudging
the tiling.

## Gate 5 — the neutral-VFX rule

Translucent, soft-edged, channel-dominant overlays are smudges by construction,
whatever they were meant to be. Three shipped in this game and all three were
reported: the Blaze smoke puff `Color(0.8, 0.9, 0.8, 0.6)`, the Hall of Blaze
leaderboard bars `Color(0.3, 0.9, 0.5, 0.55)`, and the menu smoke.

Any translucent full-screen-capable VFX must be **channel-neutral** (no channel
beating the others by more than ~0.08) or fully opaque. `scripts/check-green-vfx.py`
enforces this in CI.

Note its `GREEN_MARGIN = 0.08`, not `0.10`: in float, `0.9 - 0.8 == 0.0999…`,
so a `0.10` threshold silently missed the exact bug it was written for. Do not
"tidy" it back to a round number.

## Gate 6 — what "FIXED" requires

Never write FIXED in STATUS.md, a commit message, or to the founder without
**all** of:

1. The change is **pushed** and CI has **exported and deployed** it.
2. You captured the **live itch build** afterwards — not a local export — and
   recorded its build number.
3. You re-ran `scripts/blotch-analyze.py` and the metric **moved on the scene
   the founder named**, not on a different one.
4. The run is **calibrated** (exit 0 against `blotch-oracle.json`).
5. You state the before/after numbers. Not "looks clean now".

A prior session claimed three defects fixed on a probe that only checked a
dictionary value. The founder rejected it because live play still failed. That
is the standard this gate exists to prevent. See `live-build-proof`.

## Gate 7 — update the oracle when he re-grades

Every time the founder grades scenes, write it into
`scripts/blotch-oracle.json` with the date and build number. His grading is the
only ground truth this project has, and it is what makes every detector
falsifiable. Losing a grading round is losing the test set.

## Regression gates that must keep passing

- `scripts/check-green-vfx.py` — translucent channel-dominant VFX in source
- `scripts/make-plate-seamless.py --check --max-wrap 3.0` — tile joins
- `scripts/seam-smudge-gate.py` — per-frame void/seam/blob metrics
- `scripts/blotch-analyze.py` — detector calibration against the founder's matrix

Never weaken a threshold to get a green run. If a gate fires on something
legitimate, add it to that gate's ALLOW set **with a stated reason**.
