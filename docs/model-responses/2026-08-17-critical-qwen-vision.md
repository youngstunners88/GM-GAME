<!-- LANE: model-qwen-vision-screenshots
     STATUS: run by the Claude lead, NOT by Qwen VL via OpenRouter.
     REASON (honest, per the directive's "record it honestly and continue"):
     scripts/or-call.mjs is a TEXT-ONLY dispatcher — it has no image-attachment
     path, so a vision model cannot be given the founder's screenshot through
     it. Rather than skip the lane, the lead performed the vision read directly
     on the founder's attached image (it is a genuine vision input in this
     session) and logged the findings in the Qwen skill's required format. -->

# Qwen-lane vision read — Fort Knox Assay panel (founder screenshot)

Source image: the founder's own screenshot, attached with "Remove this
background and improve the words as they are still fucked!!!"

## 1. Text strings that are overlapping or unreadable

Measured against the shipped layout, the labels do NOT geometrically overlap
(`res_stake_assay_test` proves no two Label rects intersect). The failure is
CONTRAST, not collision — which is why the previous "no overlap" fix did not
satisfy the founder:

- `FORT KNOX ASSAY — WEIGH ...` / `...T. 100-DAY` — the header line runs across
  painted gold machinery and is illegible mid-string.
- `STAKED` and `RETURN` — gold text sitting directly on gold-lit brass; the
  words are present but do not separate from the plate behind them.
- The live value numbers are the smallest-weight elements on the panel despite
  being the only thing the player actually needs to read.
- `[E] WEIGH GOLD` competes at the same size/weight as the data labels.

## 2. Is the instrument large enough / distinct from EXIT and the pool plates?

The scale art itself is adequately large (230px). It is NOT distinct enough:
the translucent halo ring behind it renders in the same gold family as the
backdrop, so the needle — the one moving, information-bearing part — loses its
silhouette. `EXIT ->` and the `2888-DAY POOL` plate are the same hue and
similar weight, so all three read as one field of gold.

## 3. Stage 3 clutter visible in the founder's frames

Confirms the separate Grok critique: pickups and gold accents are distributed
at uniform density with no quiet ground, so nothing reads as a landmark.

## 4. Boss visible in any frame?

No boss is visible in the Assay frames; the boss question was answered
instead by direct instrumented measurement (see
docs/captures/2026-08-17-chase-numeric/), which is stronger evidence than a
still image can provide.

## Verdict fed into the fix

The panel's alpha (0.90–0.92) was the root cause of "the words are still
fucked" — the busy painting showed straight through the plate. Opacity and
hierarchy, not outline thickness, are the fix.
