# Kimi K3 audit — torch/tool attach hierarchy (findings-first)

Godot 4.3 project. The founder has repeated a "torch renders at the feet,
not the hand" complaint across MULTIPLE sessions despite the code containing
what reads as a correct fix (grip-anchored math with comments describing
this exact prior fix). Static reading alone has not resolved this before.
Your job: find whatever static analysis CAN prove, and be explicit about
what only a screenshot can settle.

**Findings first**: SEVERITY — file:line — issue — fix. No preamble.

## Specific questions

1. **Attach point**: trace `set_tool()` in `lil_blunt_visual.gd`. Confirm the
   exact node hierarchy: is `_tool` (the Sprite2D) parented directly to
   `LilBluntVisual`, or to some other node (a body/limb sprite) whose own
   position/rotation/scale could shift the tool's effective screen position
   independent of the `_tool.position` math?
2. **Z-order**: what is the child ADD ORDER of `LilBluntVisual`'s children
   (body, legs, arms, head, `_tool`)? In Godot 2D, later-added siblings draw
   ON TOP. If `_tool` is added early (before legs/body), a leg/torso sprite
   added later would draw OVER it, which would look like "invisible" or
   "hidden at the feet" even with correct position math — this is a
   DIFFERENT bug than a position bug and needs a different fix (reorder
   `add_child`, or set `z_index`).
3. **Facing flip interaction**: `_tool.flip_h = not facing_right` and
   `_tool.position.x = TOOL_HAND_X if facing_right else -TOOL_HAND_X`
   (referenced in two places — confirm both fire in the same order and
   don't fight each other, e.g. one runs on `set_tool()` only while the
   other runs on every facing change, leaving them desynced after a
   mid-animation flip).
4. **Animation coupling**: is `_tool`'s position ever affected by whatever
   moves the legs/body sprites during a walk/idle animation cycle (e.g. if
   walk animation shifts `LilBluntVisual`'s own child Y-positions, and
   `_tool` is a sibling that does NOT get the same per-frame offset, it
   could visually drift relative to the hand as the walk cycle plays even
   if the STATIC math is correct)?
5. **What CANNOT be resolved from code alone**: state plainly which parts of
   this complaint require an actual rendered screenshot to settle (e.g. "the
   math computes position (X,Y) but whether that VISUALLY reads as 'in hand'
   depends on the sprite's actual transparent-pixel bounding box within its
   texture, which this audit cannot see").

## Files

@include src/player/lil_blunt_visual.gd
@include src/player/player.gd
