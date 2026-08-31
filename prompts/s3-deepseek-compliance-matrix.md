Role: COMPLIANCE MATRIX. Auditing whether this session's founder prompt has
actually been satisfied, item by item, BEFORE the team claims done. Do not be
generous — mark PARTIAL or NOT MET wherever evidence doesn't fully support
DONE. This matrix is being built BEFORE implementation, as a pre-flight
checklist, so every item's status is NOT STARTED — your job is to specify
what PROOF each item needs, not to grade finished work.

Founder prompt (full text) + all real facts:
@include docs/founder-prompts/PROMPT_VAULT_INTERIORS_S2_CHASE_S3_PRESSURE.md
@include prompts/_session3_facts.md

Build a table: Item | What the prompt requires | What evidence would PROVE it
(a specific, falsifiable check — not "code was touched" or "looks right") |
Status (NOT STARTED for all, this pass).

For T1/T2 (vault interiors): the founder explicitly rejected "a hole in the
ground with a ladder and tokens" as insufficient. What distinguishes a
"complete section" from that, in a way an automated gate could actually check
(e.g. "N distinct StaticBody platform tiers exist, not 1" / "at least 2
entity types beyond a coin scene are spawned" / "the ladder is reachable from
every tier")? Don't let this ship as another single-tier box with a paint job.

For T3 (Stage 2 chase/crystals): the founder says a PRIOR session's fix
"FIXED" claim failed live. What would make THIS pass's gate actually
trustworthy where the last one wasn't? (Hint from the prompt's own framing:
the last gate proved the fix in an idealized/bounded-test arena; what's
different about proving it in the REAL arena geometry, and does "gate passes"
even guarantee "founder sees it live," or is there a category of bug —
runtime-only, browser-only, cache — that a headless gate structurally cannot
catch? Flag that honestly if so.)

For T4 (Stage 3 pressure): the founder says "too easy to kill," which is a
different complaint than the previous session's "too easy to escape." What
falsifiable check proves the fight is no longer trivial (e.g. a time-to-kill
floor under realistic play, or a required number of hits taken)?

Also confirm you're reading the founder's KEEP list correctly (don't flag
these as open questions): larger final boss SCALE stays; the vault's downward-
entrance concept stays; the vault's distinct-from-Blaze/Lounge architecture
stays. Only the vault's INTERIOR CONTENT and the two bosses' behavior are in
scope this session.

Be concise — a table plus short notes, not an essay.
