# Grok 4.6 — Truth audit: is the Claim Jumper stuck/double-jump fix actually FIXED?

## Founder's own definition of done (verbatim, do not soften or reinterpret)
- [ ] Boss leaves the previously stuck platform and continues pursuit
- [ ] Double jump implemented and used in real chase paths
- [ ] Coordinate trace or capture proves both in the real Stage 3 arena
- [ ] No regression to glued-to-player lock-on
- [ ] Gates green
- [ ] Butler ships fresh data
- [ ] STATUS.md updated honestly
- [ ] Founder hard-refresh confirms movement beyond the stuck point

## Founder's hard rules (verbatim)
- No "FIXED" from STATUS memory or local play only.
- No speed-as-main-fix.
- No scope creep.
- If blocked on missing geometry/art, write WAITING ON FOUNDER FILE and
  continue the rest.

## What was actually done this session
Root cause: `_clamp_to_arena()` clamps X at the arena wall but not the Y
ceiling. A hop taken at the clamped wall re-armed every 0.7s with X pinned,
climbing in place forever instead of ever getting a grounded chase frame.
Fix: added `already_high_enough` (true when >400px above the player's y),
gating the hop-arm condition AND the air-hop fire condition (both were
needed — gating only one was proven insufficient on the sibling Auditor
boss bug this same session).

@include src/boss/claim_jumper.gd

Measured evidence (headless, real level_03_gold_rush.tscn, NOT an empty test
box): player parked beyond the arena's east wall (x=4500, wall at x=4400)
for 16s of real physics — min_y=29.3 from a spawn_y of 500 (bounded climb,
not unbounded), 8 air-hop events fired during that window, 0 frames spent
past the ceiling+120px tolerance. Existing regression tests
(chase_separation, double_jump, difficulty, pressure) all still pass.

## What has NOT yet happened (be honest about this in your audit)
No live browser/itch.io capture yet. No founder hard-refresh confirmation
yet (cannot happen until this ships). Full 59-test suite and security
sentinel have not yet been re-run with BOTH this fix and a sibling Auditor
fix in place together.

## Your job
Audit against the founder's own checklist above, item by item. For each
unchecked item, say whether it's:
(a) satisfied by what's described here and should be marked done,
(b) NOT yet satisfiable without further work (name exactly what work), or
(c) a claim that risks being scope-creep-rejected if presented as "FIXED"
    prematurely.
Be adversarial — this founder has explicitly and repeatedly rejected
claims that turned out to be "wired but not visible" or "passes in an
empty test box but not the real arena." Do not accept the headless
measurement as sufficient for the "Founder hard-refresh confirms" checkbox
— that one is definitionally not satisfiable by Claude alone. Flag it as
still open. Give a one-paragraph final verdict: is it honest to tell the
founder this residual is FIXED pending deploy, or should the language be
more hedged?
