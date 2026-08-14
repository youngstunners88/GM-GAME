@include prompts/_s9_facts.md
# Fable-5 — implementer. Terse, code-shaped, each with GATE:.
1. Implement lock hysteresis in distributor.gd _hover_pursue per the design
   direction in the facts (cooldown after release; only re-arm on genuine
   imminent collision). Give the exact GDScript diff (new vars + modified block).
2. A real-arena headless gate driving a weaving+HOPPING kinematic player that
   measures the boss's net horizontal pursuit + lock duty, discriminating pre/post.
3. S3 Claim Jumper: a real-arena kite-path gate proving horizontal travel toward
   a player who moves + jumps, no ledge suicide. (claim_jumper already has
   _higher_ground_ahead + pdx-scaled hop from s6.)
