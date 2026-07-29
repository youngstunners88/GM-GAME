# Evidence — D. Facing & walk animation

## Finding: ALREADY CORRECT (verified, not rebuilt)
`src/player/lil_blunt_visual.gd` is a SINGLE animation owner. `facing_right`
is a property with a setter that flips sprite+anim+tool together; the player
sets it once per frame from `input_handler.handle_facing_direction(direction)`.
No competing code path overwrites it; art is not pre-flipped, so only code
mirrors → no double-mirror. Legs/arms animate procedurally (swinging-legs
walk cycle added in a prior turn; `moving` flag drives it).

## Verification
Real web export boots to PLAYING and the player renders/animates (see
gameplay-boot-after-corrections.png — Lil Blunt visible in-level with HUD).
No new animation owner introduced (brief rule 7 preserved). PASS provisional;
a human playtest confirming left/right facing + visible arm/leg motion across
idle/run/jump/climb/attack/hurt/power-up states is the final tick (steps in
the report). No defect found to fix.
