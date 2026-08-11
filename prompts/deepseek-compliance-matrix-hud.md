# Compliance matrix: did this session satisfy the founder's prompt?

Below is the founder's prompt (with its own T1-T6 task list and security
decisions), then a summary of what I actually changed and verified this pass.

Produce a strict PASS / PARTIAL / FAIL matrix — one row per T1-T6 item, one
row per each of the 3 "founder answers" (legal pages / DeFi / glob broaden),
and one row per "Definition of done" bullet. For each: quote the requirement,
name the concrete evidence, give a verdict. Be harsh — flag anything claimed
done that the evidence doesn't actually support.

## The founder's prompt
@include /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/founder_prompt.md

## What I changed (diffstat)
@include /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/full_diffstat.txt

## What I verified, in my own words

- T1 (PUFFS -> BLAZE DIAMONDS): changed in both hud.gd (main HUD) and
  blaze_rush.gd (in-mode HUD) plus the finish toast. Verified via a headless
  Godot test measuring the REAL rendered Control rects (not hand-calculated
  constants) that the new label text doesn't overlap or overflow the HUD row
  at worst-case digit counts.
- T2 (diamond claim-reset): built a real-physics reproduction test that
  drove the actual player through the actual candle+diamond pair repeatedly.
  Got a 100% reproduction rate (30/30 cycles) of the exact bug the founder
  described, BEFORE my fix. Root cause: the diamond's own pickup signal
  arrives one physics step late, after the crash's guard flag has already
  been cleared. Fix: reject any pickup where the player isn't actually near
  the token (distance-based, not timing-based). Verified 0/30 after the fix,
  AND verified a legitimate un-crashed pickup still counts.
- T3 (TAP OUT + face art): extracted the founder's attached face image from
  the session transcript (already had a transparent background, no keying
  needed), cropped and saved it as a project sprite, wired it into the HUD
  row next to the renamed button. Verified layout via the same real-Control-rect
  test (T1's test also covers this).
- T4 (TOKENS vs COINS): added a "TOKENS" section header + a new TITANX
  counter (previously untracked entirely) to GameManager, wired through a
  new HUD row. Found and fixed a REAL bug while doing this: coin.gd swaps
  its sprite to a TitanX/DIAMONDS/GoldMine logo per stage but was crediting
  ALL of them to the generic "COINS" counter regardless — so a
  TitanX-branded pickup on Stage 1 literally incremented "COINS" on the HUD,
  which is exactly the mislabeling the founder described. Re-routed each
  stage's branded pickup to the correct system (titanx/diamonds/gold) and
  wrote a test proving it.
- T5 (Stage 2 boss chase, again): did NOT just re-trust the existing
  real-physics gate. Rebuilt the actual web export using the EXACT CI recipe
  (same export_presets.cfg content, same Godot version), served it locally,
  and drove a REAL Chromium browser through the main menu into real
  gameplay — confirmed the engine boots cleanly, Level 1 loads, and
  real keyboard input moves the player with correct physics/camera/HUD
  behavior. Found and fixed a STALE click-coordinate calibration bug in the
  existing browser verification tooling itself (button had moved, ratio was
  off by 0.11 of viewport height) that was causing false negatives. Also
  independently confirmed via GitHub Actions job logs that the itch.io
  butler deploy for the commit containing the prior chase fix ACTUALLY
  succeeded (real upload, not a skipped/silent no-op) — ruling out "the fix
  never actually deployed" as an explanation for the founder still seeing it
  broken. Did NOT script a full blind platformer traversal all the way to
  the Level 2 boss room itself (assessed as impractical/risky to do
  reliably in the time available) — relies on the existing real-physics,
  real-arena-bounds gate for the specific in-arena chase claim.
- T6 (Stage 3): re-audited level_03_gold_rush.gd + level_03_data.tres from
  scratch — full spawn inventory (every type has a gameplay function, no
  plain "coin" type at all in this level), all hardcoded colors (2 in the
  script, 4 in the level data, all brown/gold, none orange-clutter), and
  DIRECTLY inspected the wBTC and big-axe sprite PNGs' pixel colors (Bitcoin
  orange 247,147,26 is the actual official Bitcoin brand color, not a
  mismatched leftover). Did not get live in-browser Stage 3 screenshots
  (would require the same full blind traversal problem as T5, times two
  levels).
- Founder answers: legal pages marked with an explicit "DRAFT — NOT LEGAL
  REVIEWED" banner in both terms.md and privacy.md, nothing else touched.
  DeFi checks stay skip, reason text now explicitly says "FOUNDER DECISION".
  The `*.js` -> `**/*.js` checklist-scanner glob broaden was trialled,
  produces 3 false-critical failures, and was NOT shipped — left as a
  written backlog item with exact numbers.

Output the matrix only. No preamble.
