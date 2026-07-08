# Client Protocol Updates — Living Log

**Purpose**: Raw capture of Rich's tokenomics/protocol updates as he shares them,
so future design/code sessions have the source material without relying on chat
history that isn't in this repo. Append new dated entries at the top. Do not
delete old entries — superseded info stays for traceability, just mark it superseded.

**Confidentiality**: Anything marked 🔒 CONFIDENTIAL below must not appear in
`docs/` (marketing/changelog), `web/` (public launcher), or any player-facing
text. This file lives in `design/` — internal only.

---

## 2026-07-08 — SMOKE listings, GoldMine genesis buy-and-burn, Diamonds NFTs

### Raw notes (from Rich, WhatsApp)

> SMOKE is launching on Robinhood this week and Solana maybe next week.
> It will be all the same supply on Solana and Robinhood, same as it is for
> Base and Binance now. The OFT token is layer zero and the same token can
> be bridged to all EVM chains.

> I would not include anything from the phase 2 tabs on the whitepaper as I
> plan to make adjustments to those details.
>
> Also, there are TWO main adjustments to phase 1 design.
>
> The Diamonds that was being sent to the treasury, is now going to the smoke
> lounge for those wrapped token NFTs I told you about and the gold forfeited
> in the gold rush auction. Well, only the portion that was getting melted,
> will now be sent to the Smoke Lounge for a 2nd NFT there.

> well, I am changing the code to make it Diamonds NFTs, where instead of
> Blaze in the NFT's it will be DIAMONDS that I put up, that I have minted.
> But from this concept there will be a requirement. It will cost 3 Billion
> Smoke token plus a Stake in GOLD's Fort Knox to obtain a rare 420 NFT, the
> NFT will have a payout from the sales of the DIAMONDS sold and all smoke
> taken it will be burned.
>
> so those are two separate things, the diamonds NFT's just allow people who
> want diamonds instantly to buy the NFT and get what they paid for, the 420
> NFT must have stake shares in Gold's Fort Knox and then pay with SMOKE to
> gain access to the reward payouts, so it two separate NFTs and two separate
> purposes. the buy of Diamonds don't have to care at all about the 420 NFT's,
> they buying the diamonds and that's all they need to do.

> 🔒 Smoke will get a buy and burn from the Gold Mine genesis. I am sending my
> allocation to the buy and burn. Don't tell anyone yet about that, but this
> game idea triggered me some thoughts about that too.

> Also, I have another NFT project that is already coded and planned for
> SMOKE that is separate from what I just mentioned too. It could be a good
> way to interject funds into this game idea you have. So, do you remember
> the plan I had for the Blaze NFT's last year, to sell Blaze in NFT's wrapped
> 1000 Blaze per NFT?

### Structured summary

**Chain expansion** (not a Phase 1/2 whitepaper item — token distribution, not protocol mechanics):
- SMOKE (OFT, LayerZero) launching on Robinhood this week; Solana possibly next week.
- Same total supply across Base, ETH/Binance, PulseChain, Solana, Robinhood listing.
- Solana is *not* an EVM chain — LayerZero bridging claim ("bridged to all EVM chains") does not cover it; Solana support is presumably a separate OFT deployment or wrapped bridge. Needs confirmation before any game reference.

**Whitepaper Phase 2 — do not implement.** Rich is actively revising those
mechanics; nothing describing them (certificates, SWF payout tiers, etc. — see
`goldmine_protocol_design.md` Pillar 5) should be extended further until he
gives updated numbers.

**Two Phase 1 adjustments (routing changes, not new mechanics):**
1. Treasury Diamonds → now routed to the "Smoke Lounge" (funds wrapped-token
   NFTs there), not the treasury split described in `goldmine_protocol_design.md`
   Pillar 4.
2. Of the GOLD forfeited to the Gold Rush Auction, the **melted portion only**
   (see `RESERVE_FORFEIT_SPLIT` in `goldmine_system.gd`) now also routes to the
   Smoke Lounge, funding a second NFT there — instead of Strategic Reserve.

**New NFT line — "Diamonds NFTs" vs "420 NFT" (two distinct products):**
- *Diamonds NFT*: instant-buy, mints against Diamonds Rich has already minted.
  No Fort Knox requirement. Buyer just wants Diamonds now.
- *420 NFT*: rare, gated — costs 3B SMOKE (burned on purchase) + requires an
  existing Fort Knox stake. Payout comes from Diamonds-NFT sales revenue.
  Two entirely separate purchase paths; a 420 NFT holder doesn't need a
  Diamonds NFT and vice versa.

**🔒 CONFIDENTIAL — GoldMine genesis buy-and-burn:** Rich is sending his own
GoldMine genesis allocation to a SMOKE buy-and-burn. Not public yet — do not
reference in any docs/, web/, or marketing copy.

**Prior/separate — Blaze NFTs:** Already-coded NFT project, wraps 1000 BLAZE
per NFT. Being floated as a funding mechanism for game development, not a
game-mechanic request. No design action needed unless Rich asks for an
in-game tie-in.

### Assessment — does this require game changes right now?

**No urgent code changes.** Everything above is on-chain/tokenomics routing
(where real Diamonds/SMOKE/GOLD go), not something the game currently
simulates at that level of detail. `goldmine_system.gd`'s treasury split and
melt/reserve split are **abstracted gameplay currencies**, not literal ledger
entries — the player never sees "Smoke Lounge" as a destination today.

**Recommended (non-urgent) follow-ups, only once Rich confirms these are final:**
- Update `goldmine_protocol_design.md` Pillar 4 text to mention the Smoke
  Lounge destination for documentation accuracy (cosmetic doc change, no
  gameplay-code change needed — the split percentages a player feels don't
  change).
- If Rich wants it *felt* in-game, a natural hook is a cosmetic "Smoke Lounge"
  vault/shrine visual tied to Diamond collection and the melt mechanic
  (Pillar 4's existing "Future Extensions" already lists a Melt Altar — this
  could be reskinned as the Smoke Lounge when the time comes).
- No changes needed for Diamonds NFT / 420 NFT — these are off-game purchase
  products, not something the platformer needs to model.

**On adding Solana explicitly to the game:** Recommend **not** doing this.
The game already keeps chain references abstract (Ethereum rings, gold
tokens, generic "GOLD/wBTC/XAUT" currencies) specifically so it doesn't need
to change every time a listing or chain changes — CLAUDE.md's rule against
hardcoding real addresses extends in spirit to not hardcoding a single chain
into core mechanics. If/when the Solana listing is stable and Rich wants
marketing tie-in, a lightweight cosmetic touch (e.g. a level banner, a
collectible skin) is lower-risk than a mechanic. Revisit after both listings
are live and confirmed stable, not while still "maybe next week."
