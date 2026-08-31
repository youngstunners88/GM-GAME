# Kimi K3 — MATH ONLY, tables, no preamble. Godot 4.3, gravity 980.

Level 1 full-stage hunt. Boss "Auditor": BODY 220, origin=collision top-left,
feet=origin.y+220, walk ~235px/s. LEAP_VELOCITY -620, AIR_JUMP_VELOCITY -560
(air-jump fires while velocity.y > -120). He must chase the player across the
whole stage, grounded, no sky-float, no permanent freeze.

Level 1 solids (x,y,w,h), ground top y=650:
platforms (300,500,100,20)(500,400,100,20)(750,350,120,20)(1100,450,100,20)
(1400,350,100,20)(1700,400,150,20)(2100,300,100,20)(2600,350,100,20)
ground_segments (0,650,400,70)(500,650,300,70)(900,650,400,70)(1400,650,400,70)
(1900,650,300,70)(2300,650,500,70)(2800,650,600,70)
breakable_blocks 32x32 at (850,500)(950,500)(1350,500)(1750,500)(1850,500)
checkpoints carry a solid 32x48 body at (1100,500) and (2200,500)
secret_walls 32x32 at (468,586)(1368,586)(2768,586)  [being removed from the corridor]

Known: at LEAP -620 he clears 196px; platform (1100,450) top is 200px above the
y=650 ground so he misses it by ~4px. Raising to -630/-570 fixed that number but
made him climb into pockets and REGRESSED both a hunt test (stuck 1335 frames)
and a sky-float test. So more vertical impulse is NOT the answer.

## Deliver, as tables/short answers:
1. For a 220-tall boss walking WEST along y=650 ground, is his ONLY hard vertical
   obstacle on the ground lane the checkpoint bodies (1100,2200) and breakable
   blocks? List every solid whose vertical span overlaps his body band
   [430,650] and sits in the ground lane. (secret_walls are being removed.)
2. If the checkpoint solids are made ONE-WAY (passable horizontally, landable
   from above) and the boss is given the ability to SMASH breakable blocks on
   contact, does any ground-lane obstacle remain that a 220px body cannot pass
   moving horizontally? Yes/no per obstacle.
3. He needs to MOUNT platform (1100,450) [top 450, 200px rise] only if the
   player is up there. From the y=650 ground, what single LEAP_VELOCITY exactly
   clears 200px (feet to 450)? What does that same velocity clear stacked with
   a -560 air-jump? Give the numbers.
4. Player: jump_force -430 (94px), double_jump -370. Walking (no jump) west
   along y=650, with secret_walls removed, is the ground lane from x=3350 to
   x=100 free of any solid that overlaps a 28px-tall player body at feet y=650?
   List any remaining blocker.
