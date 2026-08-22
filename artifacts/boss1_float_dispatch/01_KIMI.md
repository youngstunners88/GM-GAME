# Kimi K3 — Godot 4.3 collision geometry check (answer directly, keep reasoning short)

A 220x220 boss (`CharacterBody2D`, collision shape `position=(110,110)
size=(220,220)`, so its ORIGIN is the body box's top-left) kept getting
permanently walled in a 2D platformer level, then pogo-jumping in place, which
players read as "floating in the sky".

Level 1 solid geometry, as (x, y, w, h) rectangles in world space:

platforms:
(300,500,100,20) (500,400,100,20) (750,350,120,20) (1100,450,100,20)
(1400,350,100,20) (1700,400,150,20) (2100,300,100,20) (2600,350,100,20)

ground_segments:
(0,650,400,70) (500,650,300,70) (900,650,400,70) (1400,650,400,70)
(1900,650,300,70) (2300,650,500,70) (2800,650,600,70)

breakable_blocks (each 32x32, origin top-left at the listed point):
(850,500) (950,500) (1350,500) (1750,500) (1850,500)

checkpoints (each carried an invisible solid 32x48 body, origin top-left):
(1100,500) (2200,500)

Boss motion: gravity 980, jump velocity -620, a second air-jump of -560 that
fires while velocity.y > -120. He walks left/right at ~215 px/s.

Measured failures: x froze at exactly 2200 (checkpoint body), and after that
was fixed, at exactly 1882 (pressed against the block whose left edge is 1850).

## Answer these four things. Be brief and concrete. No long preamble.

1. Is "feet = origin.y + 220" correct for that collision shape? Yes/no + one line.
2. Peak rise for jump(-620) then air-jump(-560) at gravity 980, in pixels.
   Show the two numbers and the total. Can he clear a block whose top is at
   y=500 when standing on ground whose top is at y=650?
3. Using ONLY the rectangles above, list every x-position where a 220-wide,
   220-tall body walking horizontally at ground level (feet on y=650 ground)
   would be stopped by a solid whose top is ABOVE his feet but which he cannot
   step onto. Give coordinates.
4. Both ground gaps (x 400-500, 800-900, 1300-1400, 1800-1900, 2200-2300,
   2800 is contiguous) — for each, can a 220-wide body walking at 215 px/s
   fall in and become unable to climb back out, given the jump numbers in (2)?
   One line per gap.
