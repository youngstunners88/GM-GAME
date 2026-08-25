# KIMI K3 — Level 1 collision inventory for Boss 1 "still phases the circled cyan block"

You are auditing a Godot 4.3 2D platformer. UNVALIDATED — Claude will verify every claim against the real files before any of it informs code. Packet only; ship no product code.

## The report
Founder hard-refresh: the first boss (Auditor, a 220px-square CharacterBody2D) STILL walks through a circled CYAN block on Level 1. He also requires: Lil Blunt (the player) must LAND on the thick solid platforms; the spacing platforms must BLOCK the boss so the player can gain distance; the boss must still CHASE (no permanent pin, no sky-float).

## Ground truth geometry (from level_01_data.tres, verbatim below)
- Ground top surface y = 650 (segments have gaps = pits). Boss grounded: feet y=650, head y=430 (BODY=220).
- Floating platforms (x, y, w, h=20), top=y, bottom=y+20:
  (300,500) (500,400) (750,350) (1100,450) (1400,350) (1700,400) (2100,300) (2600,350)
- Breakable blocks (32x32 cubes) at y=500 (top 500, bottom 532): (850,500)(950,500)(1350,500)(1750,500)(1850,500)
- A platform is a WALL to the grounded boss iff its band intersects [430,650] i.e. bottom>430:
  WALLS = (300,500),(1100,450) + all 5 breakable blocks (bottom 532). OVERHEAD = the other 6 floating platforms (bottom<=420).

## What Claude's last change did (the current live behaviour)
auditor.gd, in _ready(), gives the boss a PERMANENT collision exception on every "overhead" platform (bottom <= grounded head 436). Rationale was: a solid 220px body vaulting a WALL clips the UNDERSIDE of a nearby OVERHEAD platform and stalls, so excepting overheads lets his jump clear the walls. CONSEQUENCE (the bug): the boss now visibly walks THROUGH those 6 overhead platforms — the founder circled one and says "still phases."

## The core geometric constraint (verify)
Platform horizontal spacing is NARROWER than the boss body (220px). E.g. vaulting WALL (1100,450) [x 1100-1200], the boss body [1200-1420] overlaps overhead neighbour (1400,350) [x 1400-1500] by 20px; rising through y350-370 his east shoulder clips (1400,350) underside -> stall. Same family: (300,500) vs (500,400).

## DELIVERABLE (packet only)
1. TABLE: every floating platform + breakable block: node/pos/size / is it a WALL or OVERHEAD to the grounded boss / currently solid-to-player? / currently solid-to-boss? (given the overhead exception).
2. Which node(s) the "circled cyan block" most plausibly maps to (it is cyan = tile_block-chain, and the boss phases it → an OVERHEAD floating platform). Rank the 6 candidates by how prominent/mid-screen they are.
3. The MINIMAL, EXACT set of changes to make ALL cyan blocks (incl. overhead) SOLID to the boss WITHOUT (a) the player falling through any platform and (b) the boss dead-locking on a vault clip. Consider: per-neighbour exception only, small geometry nudges to widen sub-body-width gaps to >=220px, narrowing the boss collision WIDTH only during a vault, or landing-on-top staircase. Give exact coordinates/numbers.
4. For each option, state the exact clip pairs (wall + neighbour) it resolves and any it does not.

@include src/resources/level_01_data.tres
