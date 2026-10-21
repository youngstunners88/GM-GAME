---
name: ep2-jack-hammer-narrative
description: The Episode 2 main antagonist Jack Hammer (Jackson Mccree) and his first thread - ask the Sheriff for work, the gold XAUt bounty, the cell/jailor placing him at the auction, a horse bought for half a Bitcoin, the ride-and-shoot trail, arrival at the auction. TRIGGER on "Jack Hammer", "Jackson Mccree", "bounty", "XAUt", "ask the Sheriff for a job", "buy a horse", "stables", "the auction ride", "main antagonist", or any edit to src/episode2/story/ep2_jack_hammer*.gd.
---

# Jack Hammer thread (ep2-jack-hammer-narrative)

Founder lock (Doc "Jack Hammer", 2026-10-21): `design/ep2/jack_hammer/PROMPT_EPISODE2_JACK_HAMMER_BOUNTY_HORSE_AUCTION.md` - READ IT FIRST. "Job from the Sheriff. Name on the bounty: Jack Hammer. Horse for half a coin. Auction before the vault."

## The ten rules (do not bend)
1. **Jack Hammer** (what the town says) / **Jackson Mccree** (the paper). Never another main name, never renamed mid-pass.
2. Bounty paid in **gold XAUt** - no soft currency, no new token name.
3. Entry: Lil Blunt **asks the Sheriff for a job** (after the draw / certificate cluster, with the auction map in hand) -> learns the bounty.
4. The **jailor or the accomplice in the cell** puts Jack Hammer at the **auction** (one clear line, no long interrogation). The existing accomplice does it; no jailor NPC is required.
5. The horse costs **half a Bitcoin** of Episode 1 crypto - the Armory's tender rule: real crypto, no soft currency, never free, never twice. **Ruling 2026-10-21: one BTC coin face = one Bitcoin; the horse takes one face and half a Bitcoin comes back as change** (`buy_horse_with_face`).
6. The trail is a **ride-and-shoot set-piece**: bandits / antagonists try to shoot him off the horse. Same size class as the day-88 river mountain cover. Not a horse RPG.
7. No horse protocol product: no staking, no horse LP, no yield.
8. No full second open world: a short trail + the auction, which is a SECOND SETTLEMENT in the next town (founder ruling 2026-10-21; `AUCTION_PLACE`).
9. **Fort Knox stays the climax.** Jack Hammer feeds it; he never replaces it.
10. Update `STATUS.md` with his identity, the bounty job, the stable purchase and the auction ride (the lock's own rule 10).

He is the culprit principal of the bears / early-claims thread the jailhouse already opened (`ep2-jailhouse`). The town has no bears: they are spoken of as brought in.

## What exists (2026-10-21, narrative pass)
- `src/episode2/story/ep2_jack_hammer.gd` - `Ep2JackHammer`: identity constants, `NOTICE`, every `LINES[beat]`, `OBJECTIVES` (single source). Voice ids `jh_*`.
- `src/episode2/story/ep2_jack_hammer_arc.gd` - `Ep2JackHammerArc`: pure-logic order and tender (`ask_sheriff_for_work -> reveal_bounty -> hear_auction_word -> reach_stable -> buy_horse -> start_trail -> arrive`), `lose_horse()`, `snapshot/restore` (bounded, a corrupt save can never put him on the trail without a horse), `result()` for room hand-offs.
- `design/ep2/jack_hammer/` - the lock, `JACK_HAMMER_LINES.md` (script), `BEAT_SHEET.md` (where each beat plugs into `gold_town.gd`, build order).
- Gate: `tests/ep2_jack_hammer_test.tscn` (EP2_JACK_HAMMER). **Not wired into play yet**: the data, wording and order are enforced; the town beat, the stable and the trail are the next builds.

## Extending it (checklist)
1. Read the lock + the beat sheet; do not rename, do not reorder, do not delete the Armory / Logan locks.
2. Change words only in `Ep2JackHammer.LINES` (see `ep2-jack-hammer-dialogue`); change rules only in `Ep2JackHammerArc`; run the gate.
3. A new town beat updates `ep2_gold_town_test` and `ep2_fort_knox_arc_test` (it lists the town beats exactly) in the SAME commit.
4. The horse purchase debits the Episode 1 purse the way the Armory does (`ep2_armory_shop.gd`, `GameManager.spend_coins`); `buy_horse()` only decides and returns what is left.
5. Jack Hammer's model / voice: the Doc leaves his look OPEN - get the founder's reference art first (`ep2-founder-intake`); never invent his face.
6. STATUS.md, vault `GM Game/Projects/Jack Hammer.md` + Work Log, commit, `ship-to-master.sh`, live probe.

## Open decisions (ask the founder; the code's defaults are proposals, not canon)
Purse unit for "half a Bitcoin" (the purse is whole coin faces); auction = second settlement or event hall; horse-shot-out cost; bounty paid on sighting / capture / Fort Knox; the XAUt handoff presentation; Jack Hammer's look and voice. Listed in `JACK_HAMMER_LINES.md`.
