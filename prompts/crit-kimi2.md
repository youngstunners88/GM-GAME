You are Kimi K3 with the skill `model-kimi-chase-geometry`, second lane: the
Stage 3 final boss. Founder says >10 times that this boss "still doesn't move".
All prior "FIXED" claims are REJECTED. Re-derive from scratch; do not trust any
comment in the file that claims a prior fix worked.

@include src/boss/claim_jumper.gd

Stage 3 arena: boss_arena = {start_x: 3700, end_x: 4400, spawn: (4050, 500)}.
The level sets boss.arena_min = Vector2(3700, spawn.y-400) and
boss.arena_max = Vector2(4400, spawn.y+60) BEFORE add_child, and ALSO calls
arm_boss_arena_seal() which raises a World-layer StaticBody wall at x=3700.
Level 1 deliberately does NOT arm that seal because the wall CAGED the boss
(its collision_mask includes the World bit).

Answer with exact line/constant evidence:
1. Does Claim Jumper's collision_mask include World (bit 1)? If so, is he caged
   or blocked by the arena seal wall / arena geometry? Leading hypothesis.
2. Is a 700px-wide arena (3700..4400) minus his own body inset actually enough
   room for a chase to be VISIBLE at all, given the camera follows the player?
   Compute his real reachable centre range.
3. Trace every state's horizontal velocity. Is there a state (VULNERABLE,
   THROW, telegraph, landing/recovery) that zeroes or near-zeroes horizontal
   movement for a large fraction of the cycle so he reads as "jumping in place"?
4. MAX_VULN_DAMAGE_PER_WINDOW / VULNERABLE_SEPARATION — do these make him
   trivial or make him look passive?
5. MINIMAL change (no new states) so he visibly closes distance and can kill a
   non-suicidal player.
Lead with your single highest-confidence root cause. Be concise and specific.
