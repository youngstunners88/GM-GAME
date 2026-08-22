# Kimi K3 — MATH ONLY. Be brief and concrete. No long preamble. Output a table.

Godot 4.3, gravity 980. Two bosses, origin = collision box TOP-LEFT.

BOSS 1 "Auditor": BODY 220 (feet = origin.y + 220), walks ~235 px/s.
  Current shipped: LEAP_VELOCITY -620, AIR_JUMP_VELOCITY -570 fires while velocity.y > -120.
  Candidate patch proposes: LEAP -630, AIR_JUMP -570.

BOSS 3 "Claim Jumper": BODY 280 (feet = origin.y + 280), walks 290 px/s (phase2 335, phase3 385).
  Current shipped: HOP_VELOCITY -620, AIR_HOP_VELOCITY -560.
  Candidate patch proposes: HOP -630, AIR_HOP -570.

LEVEL 1 solid rects (x, y, w, h), ground top y=650:
platforms (300,500,100,20) (500,400,100,20) (750,350,120,20) (1100,450,100,20)
(1400,350,100,20) (1700,400,150,20) (2100,300,100,20) (2600,350,100,20)
breakable_blocks 32x32 at (850,500) (950,500) (1350,500) (1750,500) (1850,500)
checkpoints carry a solid 32x48 body at (1100,500) and (2200,500)

LEVEL 3 boss arena: start_x 3700, end_x 4400, boss spawn (4050,500), arena floor y≈650.
  A solid wall 20 wide x 600 tall is built centred at x=4400, y=400 (spans x 4390-4410, y 100-700).
  A second wall (the player seal) is centred at x=3700 same size.
  Boss centre is clamped to [3724, 4376]; his body is 280 wide.

## Deliver EXACTLY these, as tables. No code.

1. Rise for each velocity at g=980: -620, -630, -560, -570. Then leap+airjump TOTAL for
   (-620,-560), (-620,-570), (-630,-570). Four decimal places not needed; 1dp is fine.

2. BOSS 1, LEVEL 1. For each obstacle whose top is above his feet at y=650, give:
   obstacle, top y, rise needed to put FEET on top, cleared by -620? by -630?
   Flag any obstacle where the difference between -620 and -630 changes the answer.

3. BOSS 3, LEVEL 3. His body is 280 wide and centre-clamped to max 4376, so his RIGHT EDGE
   reaches 4376+140 = 4516, which is past the wall face at 4390. State plainly:
   (a) does his body necessarily overlap that east wall at full clamp? show the arithmetic.
   (b) if yes, is `is_on_wall()` therefore true on every grounded frame near the east side?
   (c) does raising HOP -620 -> -630 change that at all? yes/no + one line.

4. VERDICT LINE: for each of the two proposed constant changes (-630, -570), write
   "JUSTIFIED — <obstacle it newly clears>" or "NO MEASURABLE EFFECT — <why>".
