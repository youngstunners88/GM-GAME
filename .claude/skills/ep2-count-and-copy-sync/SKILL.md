---
name: ep2-count-and-copy-sync
description: When the founder changes a number or a name in a feature (4 licenses to 3), change it everywhere it lives - data table, build loop, geometry constants, dialogue, voice clips, docs, tests - and prove no stale copy remains. Use for the gold-town license wall (Prospector, Miner, Foreman, Mine Owner) and any "still X instead of Y" complaint. TRIGGER on "still 4", "instead of 3", "still says", "rename", "change the count".
argument-hint: "sweep <term> | fix <old> <new>"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# One fact, every copy

"There are still 4 certificates instead of 3." The word "still" means a copy survived. A number lives in several places; the fix is the sweep, not one edit.

## License wall specifics (`src/episode2/chamber/gold_town.gd`)
- Header comment ~L10-12 (says four licenses).
- `LICENSE_TIERS` ~L127-131: 4 entries (Prospector's, Miner's, Foreman's, Mine Owner's). Decide which 3 remain from the founder's design/canon (`ep2-narrative-canon`, the Phase 2 docs), **not by guess**; if canon does not say, pick the most defensible reading and list the choice in the report.
- `LICENSE_WALL_AT`, `LICENSE_WALL_STEP`, `LICENSE_WALL_RISE` ~L182-184: spacing and rise tuned for 4; re-centre for 3 so the wall does not look gappy.
- `_build_license_wall()` ~L2386-2411 loops `LICENSE_TIERS.size()`; confirm nothing else hard-codes 4.
- Dialogue `MINISTER1_LINES` ~L106+ (Mike Dean says "four licenses"): rewrite to match; re-record the clips if the line changed (`ep2-voice-id-lock` pipeline, Mike Dean's voice).
- Auction `DOOR_LINE` and other lines that refer to license tiers; the auction hall's license text.
- Phase 2 reframe docs and any spec/README that says four.

## Sweep method
1. `grep -rniE 'four (licen[cs]e|certificate)|4 (licen[cs]e|certificate)|mine owner|foreman|LICENSE_TIERS' src assets docs artifacts tests` (filter to lines, no whole files).
2. Classify each hit: data, geometry, copy, doc, test, voice clip. Fix every one in the same change.
3. Update tests that assert 4.
4. Voice: a changed spoken line needs a regenerated clip with the right voice id; do not leave old audio saying "four".

## Proof
- A test: `LICENSE_TIERS.size() == 3`, wall node count is 3, `MINISTER1_LINES` has no "four"/"4th"/removed-tier name. Fails with an entry re-added.
- Real renderer screenshot of the wall with 3 certificates, centred.
- Post-fix grep output (empty) in the report.
