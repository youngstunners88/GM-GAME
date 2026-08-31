Role: COMPLIANCE MATRIX. You are auditing whether this session's founder
prompt has actually been satisfied, item by item, BEFORE the team marks it
done. Do not be generous — flag PARTIAL or NOT MET wherever the evidence
doesn't fully support DONE.

Founder prompt for this session (full text):
@include docs/founder-prompts/PROMPT_NO_PIXELATION_L1_DEATH_S2_CHASE_CRYSTALS.md

Definition of done (from that file):
- Sharp TAP OUT face + logos (no pixelation).
- Band art stable (not jittery).
- L1: no ghost death.
- S2: chases in real arena + crystal/shard volleys.
- Final boss larger and effective.
- Multi-model log present for this session.
- Gates green; deploy; build id.

Build a table with columns: Item | What the prompt requires | What evidence
would PROVE it (not just "code was touched") | Status (this pass: NOT
STARTED for all items — this matrix is being built BEFORE implementation, as
a checklist the implementation must later satisfy, not a review of finished
work).

For each of T1-T5, list the SPECIFIC, falsifiable verification the team
should run before claiming done — e.g. for T3 (L1 ghost death) that means
"a real-physics test where the player is driven near but never overlapping
the boss's Hitbox shape for N seconds and asserts boss_contact_restart()
never fires", not "read the code and it looks fine". For T4 (Stage 2 chase +
crystal attack) note that this exact boss has shipped multiple "chase is
fixed" claims before that were contradicted by the founder playing it live —
what would make THIS pass's verification actually trustworthy where the
previous ones weren't (hint: a gate that never damages the boss past Phase 1
proved nothing last time)?

Also flag: the founder's three standing decisions this session are (1) keep
"BLAZE DIAMONDS" HUD label and $DIAMONDS/$TITANX/$GOLD naming as-is, (2)
keep Stage 1 TitanX progress across boss death, (3) push Stage 2 chase
further. Confirm these read as settled, non-negotiable inputs to you (they
are) — do not add them to the matrix as open questions.

Be concise — a table plus short notes, not an essay.
