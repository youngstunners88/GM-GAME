# Evidence — G. Multi-level progression  &  H. Secret route

## G — root cause (the real bug)
All 3 levels + the secret realm ALREADY EXIST as scenes and are individually
loadable. But EVERY boss ended by loading the MAIN MENU, and the menu's Play
only ever loaded Level 1 → Levels 2 and 3 were UNREACHABLE through normal play
(beat L1 boss → menu → Play → L1 again). This is the "one boring level" report.

## G — fix (reconcile, not rebuild — brief rule 7)
Added a single progression registry to GameManager: `LEVEL_SEQUENCE` +
`next_level_scene(cleared_index)` + `highest_unlocked_level` (persisted in
save.json). Routed all endings through it:
- Auditor (L1) victory screen Continue → Level 2 (was menu).
- Distributor (L2) → Level 3 (was menu; copy now "Onward to the Gold Rush").
- Claim Jumper (L3, final) → menu, marks campaign complete (also fixed its
  free-after-load ordering bug).
- Menu Continue → resumes at `highest_unlocked_level` (was hardcoded L1).
No levels duplicated or rebuilt; the existing L2/L3 (already built in a prior
turn with their own depth) are simply now reachable in sequence.

## H — finding
The secret doorway + secret realm (Chill Lounge, with return loop) already
exist (src/level/secret_door.gd + secret_realm.gd). Reconciled against the
brief's multi-room spec — it's a single themed room today, meets "memorable
doorway / transition beat / reward / clear return route / no wallet soft-lock"
but is not yet the full 6-room escalation. Left intact (works, reachable);
documented as an enhancement candidate rather than rebuilt this pass to honor
"do not create empty copies / preserve existing work."

## Verification
Real export boots; L1 reaches PLAYING. Full L1→L2→L3 progression walk is a
human-playtest step (harness plays L1 only). PASS for reachability wiring
(code + boot); end-to-end campaign human tick pending in the report.
