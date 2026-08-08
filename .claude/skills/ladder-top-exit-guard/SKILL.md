---
name: ladder-top-exit-guard
description: Static audit that every ladder.tscn instance in a level script either sets a custom top_exit_offset or genuinely lands within a nearby platform's x-range using the default. Run after placing/moving any ladder, or when a founder reports "climbing a ladder doesn't land on the platform."
user-invocable: true
allowed-tools: Read, Glob, Grep
---

# Ladder Top-Exit Offset Audit

**This is a static audit.** It reads level scripts and platform/ground data
and reports; it does not fix.

## The defect that shipped (why this exists)

`ladder.gd`'s `top_exit_offset` defaults to `Vector2(0, -20)` — "stand
directly above my own x, 20px above my own top." That's only correct if a
platform happens to sit directly above the ladder's own x-position.
Level_02's ladders set this explicitly per-instance (computed from the
actual nearby platform); level_01's and level_03's did not. One of level_01's
two ladders (`x=770`) happened to still land inside its platform's x-range by
coincidence; the other (`x=2345`) did not — the nearest platform starts 55px
to the right, so topping out with the default dropped the player in open
air, short of the platform. The MECHANISM (`_top_out_ladder()`) is correct;
the bug is missing per-instance DATA tuning.

## Check — per ladder instance

For every `preload("res://src/level/ladder.tscn").instantiate()` call in a
level script:

1. Note the ladder's `global_position` (`(lx, ly)`) and `height`. Its top_y
   is `ly`; if `top_exit_offset` is not set, the effective exit target is
   `(lx, ly - 20)`.
2. If `top_exit_offset` IS set, read the value and compute the target:
   `(lx + offset.x, ly + offset.y)`.
3. Find the level's `platforms` array (`Array[Vector4]`, each
   `(x, y, width, height)` = top-left position + size) and/or relevant
   `ground_segments`.
4. Find the nearest platform to the exit target: does the target's X fall
   within `[platform.x, platform.x + platform.width]`, and is the target's Y
   within ~24px of the platform's surface Y?
5. **PASS** if a platform exists there. **FAIL** if the exit target lands in
   open air — report the ladder's position and the nearest platform found
   (if any), and compute the correct offset:
   `offset = (platform.x + platform.width/2 - lx, platform.y - 20 - ly)`.

## Cross-check

Compare against a level whose ladders ARE known-correct (level_02 as of this
writing) — confirm the pattern (explicit offset, computed the same way) is
what a passing ladder looks like, so the audit isn't inventing its own
standard.
