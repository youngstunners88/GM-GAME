# Grok 4.6 — DESIGN AUDIT ONLY. Be blunt.

Level 1 = full-stage HUNT (no arena seal). Auditor BODY 220, contact = instant
run restart. PR #52 made all floating platforms + the checkpoint block ONE-WAY
so the 220px boss stopped pinning on two torso-height platforms (the old
"floating" bug). Both auditor gates went green.

Founder hard-refresh REJECTS it: "the boss walks through the blocks as if they
don't apply to him — nothing Lil Blunt can leverage for distance; fight
impossible. Also still some flying (improved not done)."

Measured geometry: of the 8 floating platforms, only TWO — (300,500) top y=500
and (1100,450) top y=450 — have bottoms below the boss's head (bottom 520/470 >
head 430), so only those two are horizontal WALLS to a grounded boss. The other
six sit above his head; he walks under them regardless of solid/one-way.

Proposed fix (option C from the founder's own list):
- Revert ALL floating platforms to SOLID (player regains spacing surfaces).
- The invisible checkpoint "StandSurface" (a save-trigger block, not gameplay
  geometry) gets a BOSS COLLISION EXCEPTION (boss ignores it), so it can't pin
  him — it was never a spacing platform.
- Give the Auditor a horizontal-commit VAULT: when blocked by a solid platform
  at body height (is_on_wall while grounded), leap with velocity.x committed
  toward the player so he clears/mounts the platform instead of pinning. Keep
  LEAP -620 (raising it regressed hunt before). Keep the existing height cap so
  the vault can't runaway-climb.

## Deliver
1. Does this restore "platforms block the boss for spacing" WITHOUT re-creating
   the 46s pin? Name the failure mode if the vault mis-fires at (300,500) or
   (1100,450).
2. The "still some flying" residual: with platforms solid again + a vault, what
   specifically could still read as flying, and how does the height cap need to
   interact with the vault to prevent it? (Peak-height cap vs landing-height cap.)
3. Boss-exception on the checkpoint StandSurface: any downside vs one-way for it?
   (Player still needs to not stand on an invisible block; boss must not pin.)
4. The new gate must assert BOTH "boss collides with the spacing platforms" AND
   "boss still closes the gap over the full stage". What exact measurements
   should that gate take so it can't be gamed (like the earlier gates were)?
5. Rank: is the vault strictly necessary, or is boss-exception on ONLY the two
   wall platforms (leave them solid to player, invisible to boss) enough to make
   both the founder's "blocks apply" (player side) and "boss crosses" true?
