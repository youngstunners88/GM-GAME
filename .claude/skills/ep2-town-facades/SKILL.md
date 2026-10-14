---
name: ep2-town-facades
description: Make GoldMine town doors and windows visible, grounded and consistent with collision and interior access. Use for blank building faces, unreadable shopfronts and flat scenic facades.
argument-hint: "building-id | all"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# Readable doors and windows

## Phase 1: Inspect and author

Before writing, use the user's existing scope as approval; ask only for missing necessary inputs. Skills-only scope prepares targets; runtime art authoring follows when requested.

Start with `ep2-living-town`; inspect `tools/ep2_blender/build_town_kit.py` (`window`, `shell`, `building`) and `ep2_gold_town.gd` (`FOOTPRINT`, `_walls_of`, materials/signs). The generator already contains door/window definitions. Never report them absent or fixed based only on source text.

For each `facades` record in the plan:

- Distinguish a closed scenic door from a traversable office/saloon passage. Keep the latter's opening, threshold and approach clear. Opening a new door requires its interior and collision/story contract; a texture does not open a wall.
- Inspect frontal and oblique first-person views at y=1.55 m. Check the glass/recess is not buried behind a continuous siding wall: cut/rebuild wall panels around windows when visibility requires it. Add depth with jambs, lintels, sills and shadow. Avoid black flat rectangles and reflective surfaces that hide the opening in Compatibility.
- Give buildings distinct use: office notice/stamp queue; saloon swing-door frame and balcony; general-store display; hotel curtains/laundry; assay weighing/sacks. Reuse painted signs, shared weathered materials, restrained warm interior light. Do not add active Auctions/Treasury mechanics or Diamonds signage.
- Capture at least two readable windows per street-facing building as the starter target, adapting intentionally where the actual facade warrants another arrangement. An added side avenue needs side/back facade attention too; do not expose untouched blank walls to the new route.

## Phase 2: Capture and verify

Use the existing headless Blender safety and reference-match skills for actual authoring. Keep named kit pieces/anchors and game-to-Blender frame `(x,-z,y)` intact. Check normals, wall/roof seams, glass backing, threshold height and collision after GLB export. Source-generator presence and proposed window counts are never visual acceptance. Add import settings explicitly and measure pack impact before integrating art. PASS requires actual camera evidence for a runtime claim. Next step: `ep2-town-proof`.
