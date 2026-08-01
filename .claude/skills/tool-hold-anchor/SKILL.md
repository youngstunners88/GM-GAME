---
name: tool-hold-anchor
description: Static audit that a held-tool/weapon sprite is anchored to a grip point (not sprite-center) using the ACTUAL exported texture dimensions, with a browser screenshot required before claiming it fixed. Run after adding/modifying any held-tool visual, or when a founder repeats "the tool renders at the feet" after a prior fix.
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash
---

# Tool Hold Anchor Audit

**This is a static + evidence audit.** It reads code, checks the actual
texture file, and requires a screenshot before a fix can be marked done —
it does not accept "the math looks right" as proof.

## Context (why this exists)

This project's torch-in-hand complaint was raised, "fixed," and reported
broken again more than once. Reading the code shows genuinely careful
grip-anchored math already in place (`lil_blunt_visual.gd::set_tool()`)
with comments describing exactly this prior fix — which means either the
founder saw a stale/uncached build, or the math is subtly wrong for the
CURRENT texture dimensions, or there's a rendering-order issue the position
math can't see. Static reading alone could not resolve this ambiguity last
time; only a live screenshot can.

## Check 1 — Grip anchoring, not sprite-center

1. Find the tool-attachment function (e.g. `set_tool()`).
2. Confirm the sprite's local position is computed from a GRIP point (some
   fraction up from the sprite's bottom edge, matching how a held pole is
   actually gripped) rather than defaulting to the sprite's geometric
   center.
3. **FAIL** if the position math assumes center-anchoring for an asset
   taller than it is wide.

## Check 2 — Real texture dimensions, not assumed

1. Find the ACTUAL exported texture file the tool uses (e.g.
   `sprite_item_torch.png`).
2. Get its real pixel dimensions (`Read` the file or use an image tool) —
   do not trust a comment's stated dimensions without checking.
3. Confirm the position math in code reads `texture.get_height()` /
   `get_width()` at runtime rather than hardcoding a size that could drift
   if the asset is regenerated (e.g. via the art pipeline).
4. **FAIL** if the code hardcodes a size, or if the current texture's real
   dimensions don't match what a comment claims they are.

## Check 3 — Screenshot required before "fixed"

1. Confirm a real exported build (or local editor run) was screenshotted
   with the tool equipped, in a normal gameplay pose (standing, both facing
   directions).
2. **FAIL any claim of "fixed" that has no attached screenshot evidence** —
   this exact defect has been marked fixed from code review alone before
   and was not actually fixed.

## Check 4 — Z-order / draw order

Confirm the tool sprite is added as a child AFTER (or otherwise draws in
front of) the body/limb sprites it should appear in front of — a
positionally-correct tool hidden behind a leg or torso sprite reads as "not
showing" even when the coordinates are right.

## Check 5 — Animation coupling (idle-correct is not walk-correct)

Static grip math being correct only proves the tool is right in the ONE
pose it was measured in (usually idle). If the body sprite gets ANY
per-frame offset during other states — a walk bob, a lean/rotation, a
squash-stretch tween — and the tool sprite is a SIBLING rather than a
CHILD of the body sprite, the tool will not inherit that offset and will
visibly drift relative to the hand exactly when the animation plays. This
was a real, previously-undetected bug in this codebase (2026-08-03): idle
math was provably correct, but `_process()`'s walk-cycle bob/lean applied
to the body sprite (`_spr`) was never mirrored to the sibling tool sprite
(`_tool`), so the torch floated relative to the hand only while walking —
exactly the kind of thing a single idle-pose screenshot cannot catch.

1. List every per-frame transform the body/limb sprites receive across ALL
   states (idle, walking, jumping, landing, dashing, taking damage) —
   position offsets, rotation, scale tweens.
2. For each one, confirm the tool sprite receives the SAME offset (either
   because it's a child of the transformed node, or because the code
   explicitly re-applies the same delta to it).
3. **FAIL** if any state applies a body transform the tool doesn't share.
4. Screenshot evidence (Check 3) must include at least one frame captured
   DURING movement/animation, not just a static idle pose — an idle-only
   screenshot cannot surface this class of bug.
