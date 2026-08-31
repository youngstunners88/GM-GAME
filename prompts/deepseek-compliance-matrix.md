# Compliance matrix for a founder change request

Below is the founder's prompt, then the code as it now stands after my pass.
Produce a strict PASS / PARTIAL / FAIL matrix, one row per numbered task
(T1..T6) plus one row per item in the "RESPONSE TO PR #19" table and one row
per item in "Definition of done".

For each row give: the requirement in the founder's own words (short quote),
the evidence in the code that satisfies it (file + what changed), and a verdict.
Mark FAIL or PARTIAL wherever the evidence does not actually establish the
claim — you are the check on wishful reporting, so be harsh. Explicitly flag
anything claimed as fixed where the code does not support it.

Also list anything in "OUT OF SCOPE" that the diff appears to have touched.

## The founder's prompt
@include /root/.claude/uploads/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/b36991fc-PROMPT_BOSS_CHASE_ARROWS_BLAZE_SPACING_S3.md

## Code after the pass
@include src/boss/distributor.gd
@include src/boss/claim_jumper.gd
@include src/level/level_02_crystal_caverns.gd
@include src/enemies/gnome_arrow.gd
@include src/enemies/tax_collector.gd
@include src/dashmode/blaze_rush.gd
@include src/collectibles/wbtc.gd
@include src/powerups/big_axe.tscn
@include src/enemies/hostile_vine.gd
@include tests/blaze_band_density_test.gd
@include tests/stage3_defence_test.gd

NOTE: these are the files the pass touched, plus the ones the founder's KEEP
list refers to. If a requirement's evidence is genuinely not in ANY file above,
say "not in the provided files" rather than asserting it was not done — but do
still mark it PARTIAL, not PASS.

Output the matrix only. No preamble.
