You are Kimi K3 auditing Stage 3 ("GoldMine Rush") of a Godot 4.3 2D platformer
for FUNCTIONLESS / randomly-placed props and geometry problems. The founder has
complained for multiple sessions that Stage 3 has "different blocks placed
randomly that are useless" and that some blocks "look shit / trashy / cheap."

Ground is at world y=650 (surface). Level spans x 0..4400. Player stands ON
ground; to use an interactive prop (melt forge) the player must physically
stand INSIDE it and press E.

Ground segments (x_start,y,width,height): (0,650,560),(700,650,520),
(1320,650,200),(1660,650,960),(2760,650,800),(3700,650,700).
=> pits/gaps at x: 560-700, 1220-1320, 1520-1660, 2620-2760, 3560-3700.

Here is the level data and the stage script and the melt forge:
@include src/resources/level_03_data.tres
@include src/level/level_03_gold_rush.gd
@include src/level/melt_forge.gd

Specific question I need answered:
1. The 5 melt_forges are at y=450-500. Their body spans origin.y-40..origin.y+45.
   Confirm they FLOAT above the y=650 ground (bottom edge ~495-545, i.e.
   ~105-155px of air below them) and therefore the player standing on the
   ground CANNOT stand inside them to press E — making them functionally dead
   AND visually "random floating blocks." Yes/no + which ones.
2. Is 5 identical melt stations in one stage redundant? Recommend how many to
   keep and at which x (near a GOLD source so "burn GOLD for a boost" has a
   real tradeoff), placed ON the ground (origin.y ~= 605-610 so the base sits
   at 650).
3. List any OTHER non-platform object that is not clearly enemy / collectible /
   power-up / interactive-with-purpose and reads as random decoration.
4. Do NOT propose removing: timed GoldGate + pressure plate, Fort Knox vault
   door, Gold Rush Reserve, boss arena, secret walls in pits, mine carts.
Give a concise, itemised verdict with concrete x-positions.
