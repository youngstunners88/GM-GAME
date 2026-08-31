ANSWER FIRST, minimal reasoning. Godot 2D platformer collision inventory. Packet only.

Boss = 220x220 solid square. Ground top y=650 → grounded feet 650, head 430.
A cyan rect is a WALL to the grounded boss iff (y+h) > 430; else OVERHEAD (boss walks under it).
Boss chases WEST; at a wall he pins with his WEST face on the wall's EAST face, body = [eastface, eastface+220] extending EAST. He must jump to clear a wall; while rising his body sweeps up through y-bands and CLIPS any OVERHEAD platform whose x-range overlaps [eastface, eastface+220] (a clip = deadlock).

DATA (x,y,w,h):
Floating platforms h=20: (300,500)(500,400)(750,350)(1100,450)(1400,350)(1700,400)(2100,300)(2600,350)
Breakable cubes 32x32 at y500 (WALLS): (850,500)(950,500)(1350,500)(1750,500)(1850,500)
All use the same cyan texture — ALL must end up SOLID to the boss (no exceptions).

REQUIRED OUTPUT (tables only, terse):
1) For each of the 13 rects: WALL or OVERHEAD; east face x; if WALL, body x-range at pin.
2) Every clip pair (WALL, OVERHEAD) where the overhead x-range overlaps the wall's body x-range. Give the overlap px.
3) Every ground-squeeze: consecutive WALLS whose east-face-to-next-west-face gap < 220 (boss can't stand between).
4) A MINIMAL set of X-only nudges (keep every Y unchanged so player jump heights are preserved) that makes ALL clip overlaps <=0 AND all ground gaps >=220, moving as FEW rects as little as possible. Give exact new (x,y,w,h) only for moved rects. Confirm no two rects overlap after moving.
Keep total answer under 1200 words. Do not restate the problem.
