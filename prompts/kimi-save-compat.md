ROLE: You are a save-system verification engineer. Audit backward compatibility for the Lil Blunt save format.

CONSTRAINT (non-negotiable): Do not invent methods, file paths, or functions
that do not appear in the inlined files below. If you need something that was
not provided, name exactly what is missing instead of guessing.

CORRECTION TO AN EARLIER BRIEF: there is no `progression_state.gd` and no
`crypto_state.gd`. Both are Dictionaries declared inside `game_manager.gd`,
which also owns `save_session()` / `load_session()`. The complete file is
inlined below — read it rather than assuming a structure.

FILES (complete current source):

@include src/autoload/game_manager.gd
@include tests/save_compat_test.gd

CURRENT STATE:
- v1.0 saves exist in the wild
- v1.2 adds: progression_state, crypto_state (live cache), wallet_address, four new signals
- The save-compat test currently has 18/18 assertions passing
- Hostile hand-edited saves are clamped (level 99 dropped, duplicates collapsed)
- Old v1.0 saves self-heal their level field

TASKS:
1. SAVE FORMAT VERSIONING
   - Confirm the save format has a version field
   - List all fields written in v1.0 vs. v1.2
   - Identify any v1.2 fields that would be missing in a v1.0 save and how they default

2. MIGRATION PATHS
   - v1.0 → v1.2: what transforms happen on load?
   - v1.2 → v1.0: is downgrade possible? Should it be?
   - What happens if a v1.0 save is loaded after v1.2 crypto_state signals are active?

3. EDGE CASES
   - Save file is completely empty (0 bytes)
   - Save file has valid JSON but missing required fields
   - Save file has extra fields not recognized by current version
   - Save file has negative values (e.g., level: -5)
   - Save file has NaN or Infinity in numeric fields
   - Two saves with the same player name but different wallets

4. TEST EXPANSION
   For each edge case above, write the test assertion.
   Format: `assert(condition, "message")` or equivalent.
   Target: expand from 18/18 to at least 25/25 assertions.

5. CRYPTO_STATE VERIFICATION
   - Confirm no balance or price data is written to disk
   - Confirm crypto_state is rehydrated from ICP on every session start
   - List every field that crypto_state holds and whether it is transient or persistent

CONSTRAINTS:
- Do not invent save file paths. Verify against actual project structure.
- The test asserting "no price ever reaches disk" must remain and pass.
- Do not weaken existing clamping logic.
