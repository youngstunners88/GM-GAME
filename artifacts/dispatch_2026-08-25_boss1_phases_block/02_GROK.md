# GROK 4.6 — design resolution: Boss 1 solid-to-all-blocks vs chase-without-pin vs player-land

UNVALIDATED co-worker audit. Claude verifies before shipping. Audit + design only; do not rewrite the codebase.

## The bind (all four must hold at once)
1. EVERY cyan block solid to the boss — no walk-through of ANY platform (founder circled one and says "still phases"). This kills the current fix, which excepts overhead platforms and so ghosts them.
2. Player lands on every thick platform (no fall-through). Global one-way is REJECTED — it broke player landing before.
3. Spacing platforms block the boss so the player can gain distance.
4. Boss still chases the full stage: no 46s pin, no sky-float, no wedge inside geometry.

## Why it's hard (the geometry, verified)
Boss is a 220px SOLID square. Ground top y=650 → grounded feet 650, head 430. WALLS (block grounded boss): floating (300,500) & (1100,450), plus 5 breakable 32px cubes at y500. OVERHEAD floating platforms: (500,400)(750,350)(1400,350)(1700,400)(2100,300)(2600,350).
To get past a WALL a solid tall boss must jump. But platform gaps are NARROWER than his 220px body, so during the jump his shoulder clips a neighbouring OVERHEAD platform's underside and stalls. Concrete clip pairs:
- Vault (1100,450) [x1100-1200] → clips (1400,350) [x1400-1500] (gap 200 < 220).
- Vault (300,500) [x300-400] → clips (500,400) [x500-600] (gap incl. a pit; body reaches it).
The previous "phase during vault" approaches ALL failed (measured, real body-vs-platform): whole-group phase = ghost level 26%; target-only = wedged inside a neighbour, runaway vy; airborne-only = sealed inside a deck on landing; and every collision TOGGLE on a moving body is artefact-prone. Current shipped state = permanent overhead exception = the founder's "walks through everything" again.

## History that must not repeat
- Global one-way: player fell through + boss walked through. REJECTED.
- Broad/permanent collision exceptions on platforms: boss ghosts them (current bug). REJECTED as the end state.
- Raising LEAP: runaway sky-climb, other gates regress.
- Gates that measure raycasts/gap pass while the live boss phases — gates MUST measure the boss's real BODY vs the real platforms.

## DELIVERABLE
1. CHOOSE ONE resolution and justify it against all 4 constraints, explicitly rejecting global one-way and permanent platform exceptions. Candidate space (pick/combine, be concrete):
   (a) Small LEVEL-GEOMETRY nudges so every gap a vault must pass is >= 220px (widen/raise/move the clip-neighbour overhead platforms); then EVERYTHING solid, no phasing, no exception — boss jumps cleanly. Give exact new coordinates and confirm each clip pair is resolved AND the player platforming isn't ruined.
   (b) Narrow the boss COLLISION WIDTH (not height, not sprite) only during the vault so his shoulder clears the neighbour; give the width + the exact frames it applies + why it can't let the player pass through him.
   (c) Boss climbs ONTO platforms (staircase) staying solid; explain how he avoids the ascent clip.
   (d) Something better.
2. GAUNTLET checklist: per-gate pass/fail criteria for: player-solid-land, player-no-fallthrough, stage-1 return path, auditor grounded (sky~0), EVERY cyan block solid-to-boss (measured on the boss BODY), auditor hunt (closes, no pin), Boss 3 regression, full suite + security.
3. EIGHT failure modes that appear if only "boss hunt closes gap" is tested (the trap that let prior fixes look green while live was broken).
4. The single measurement that would have caught the current live phase-through (so the new gate is ungameable).

@include src/resources/level_01_data.tres
