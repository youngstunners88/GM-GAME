# Lead task: make two bosses actually chase, and turn gnome shots into arrows

Godot 4.3, GDScript, static typing. `:=` inferring from a Variant is a hard parse
error — always annotate types explicitly. Indentation in these files is TABS.

## Context the founder gave (verbatim intent)
- "Stage 2 boss still not moving / not chasing" — after a previous speed bump.
- "Stage 3 boss too easy" — must actively chase, not patrol-stalk.
- "Gnome arrows must LOOK like arrows, not circular boss orbs" — a drawn/held
  bow, and a projectile with a visible shaft + arrowhead.
- Keep: gnomes must NOT walk off ledges (do not regress that).
- Keep: Stage 3 boss ledge clamp so chasing does not reintroduce void death.

## Hard facts
- Player top speed = 240 px/s (walk 200 x sprint 1.2).
- Distributor: node origin is TOP-LEFT, `BODY = 240`, so centre = origin + (120,120).
- Claim Jumper: origin TOP-LEFT, body 80x80, centre = origin + (40,40).
- Both levels: arena `start_x=3700 end_x=4400`; level code clamps the boss's
  **origin** to `[start_x+90, end_x-90]` = `[3790, 4310]`, and does NOT zero the
  velocity when the clamp bites.
- Tax collector (the "gnome") is 32x32, origin TOP-LEFT, centre = origin + (16,16).
- `boss_projectile.tscn` draws a CIRCLE. Reusing it for the arrow is the bug.

## Files
@include src/boss/distributor.gd
@include src/boss/claim_jumper.gd
@include src/enemies/tax_collector.gd

## Deliver, in this order
1. **Root cause** of "Stage 2 boss doesn't move." Consider specifically: pursuing
   with the ORIGIN instead of the body CENTRE (a 120px x bias), the origin-based
   arena clamp squeezing the reachable centre range, and velocity not being zeroed
   at the clamp. Show which combination pins the boss when the player stands in the
   western part of the arena.
2. **Exact GDScript patch** for `distributor.gd`: centre-relative pursuit, a
   minimum pursuit speed floor so EVERY pursuing state exceeds 240 px/s, and a
   clamp that zeroes the velocity component pushing into the wall. Give full
   replacement function bodies, tabs, fully typed.
3. **Exact GDScript patch** for `claim_jumper.gd`: real chase (speeds above 240 in
   every phase, and continue closing during THROW instead of braking to zero),
   while KEEPING `_ledge_ahead` / `_gap_crossable` / `_clamp_to_arena` behaviour
   intact. Full replacement function bodies.
4. **Arrow projectile**: a new self-drawing `Area2D` arrow script (GDScript, no
   .tscn needed, built entirely in code with `_draw()`), rotated to its travel
   direction, with a clear shaft + triangular head + fletching, sized ~26x8 px,
   damaging the player on contact and freeing on lifetime. Give the complete file.
   Also give the small `_draw()` addition that puts a visible drawn BOW in the
   gnome's hands, aimed at the player, so the shot reads as archery.
5. Any place your patches could break an existing behaviour, called out explicitly.

Give code, not essays.
