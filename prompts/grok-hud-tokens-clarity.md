# Review: does this HUD actually communicate "tokens ≠ coins" clearly?

Founder: "We need to add a 'TOKENS' allocation because the $TITANX, $DIAMONDS,
AND $GOLD are tokens and not coins. The coins are Ethereum in stage 1, Solana
in stage 2 and Bitcoin in stage 3." He also separately asked "PUFFS" renamed
to "BLAZE DIAMONDS", and "EXIT" renamed to "TAP OUT" with Lil Blunt's face
art placed next to the button.

Current on-screen HUD order (top to bottom), after this pass:
```
SCORE: 000000
[health hearts]
COINS 0
RINGS 0
TOKENS          <- new section header label, smaller font, distinct color
GOLD 0
DIAMONDS 0
TITANX 0        <- new row
wBTC 0
XAUT 0
BLAZE DIAMONDS 0   <- was "PUFFS 0"
[power-up bar]
```

@include /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/diff_hud.txt

## Deliver
1. Does grouping GOLD/DIAMONDS/TITANX/wBTC/XAUT all under one "TOKENS" header
   read clearly as "these are protocol tokens, not coins" to a player with no
   context? Or does it read as visual clutter / an undifferentiated wall of
   numbers? Be specific about what would make it read better or worse.
2. wBTC and XAUT were NOT explicitly named by the founder as needing the
   "TOKENS" reclassification (he named only $TITANX/$DIAMONDS/$GOLD) — I
   included them in the TOKENS group anyway because they're clearly not
   "coins" either (GoldMine-internal derived pools). Do you agree, or should
   they sit outside the TOKENS group?
3. "BLAZE DIAMONDS" sits BELOW the entire TOKENS cluster, separate from
   "DIAMONDS" (a different counter — GoldMine protocol allocation vs. the
   Blaze Rush minigame's own currency). Is having both "DIAMONDS" and "BLAZE
   DIAMONDS" as separate rows, close together, going to confuse a player into
   thinking they're the same stat? If so, what's the minimal wording change
   that fixes it without touching the underlying data model?
4. "TAP OUT" + a drawn/painted Lil Blunt face next to the button — does that
   combination read as "this is too difficult, I'm out" the way the founder
   wants, or does it read as something else? You don't have the image itself,
   so answer based on the LABEL + PLACEMENT design alone (icon immediately
   left of a 210x58 button reading "TAP OUT (Q)").
5. One-sentence rewrite suggestions for any row label you think is unclear,
   ranked by how much it matters.

Terse, concrete, no filler.
