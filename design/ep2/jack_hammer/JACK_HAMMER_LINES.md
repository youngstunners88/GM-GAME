# Jack Hammer thread - the script (text now, voice later)

**Status: UNVOICED (2026-10-21).** Source of truth is `Ep2JackHammer.LINES` / `NOTICE` / `OBJECTIVES` (`src/episode2/story/ep2_jack_hammer.gd`); this file reads it as a script so a voice pass and
the founder can mark it up. Same conventions as the Armory (`design/ep2/armory/RICH_UTAH_LINES.md`) and the jail scene (`gold_town.gd JAIL_LINES`): timed text toasts, `WHO: text`,
`id` = the future `vo_<id>` file. **Status of the words: DRAFT for founder pass - the lock fixes the facts, not the phrasing (the Doc lists exact dialogue as open).**

## Rules for every line (they are gated by `tests/ep2_jack_hammer_test.gd`)
- Name lock: **Jack Hammer** in speech; **Jackson Mccree** on the paper. Never another main name.
- Bounty is **gold, paid in XAUt**. No dollars, no percentages, no yields, no digits, no addresses, no whitepaper numbers.
- Spoken lines say **"coin"**, never "Bitcoin" / "crypto" / tickers (the tender shows on the panel as BTC).
- No horse-as-protocol-product: no staking, no horse LP, no yield. The horse is a horse.
- The town has no bears (`ep2-sheriff-jake`): bears are spoken of as brought in, not seen.
- The Sheriff is a weathered adult lawman, dry and short; the accomplice bargains, he does not confess everything. Lil Blunt speaks little.

## The beats (first-play order from the lock)
**0 - after the draw: the Sheriff has just handed him the map to the auction** (existing `Beat.WON`). The job ask follows in the same cluster.

**1 JOB_ASK** (objective: *Ask the Sheriff where a man finds paid work.*)
- LIL BLUNT: Sheriff. Where does a man find paid work in this town?
- SHERIFF: Paid work. With that rifle and that map, you came to the right door.
- SHERIFF: Top sheet on the board behind me. Read it, then come back and ask me again.

**2 BOUNTY** - the notice on the wall:
> WANTED / JACKSON MCCREE / called JACK HAMMER / For bringing bears onto claimed ground and for jumping early claims. / REWARD: GOLD, paid in XAUt.
- SHERIFF: Jack Hammer, the town calls him. Jackson Mccree on the paper.
- SHERIFF: He brought the bears in so the early claims could be jumped before the vault side locks up. Whoever puts him in front of me draws the reward.
- SHERIFF: It is paid in gold. XAUt, by the book.
- LIL BLUNT: Where do I find him?
- SHERIFF: Nobody has seen him sit still. Ask the man in my cell. He knows more than he told me.

**3 JAIL_WORD** (the existing jail; the accomplice supplies it - the lock's "jailor or accomplice". No new NPC is needed; a jailor can be added later without changing a line's meaning)
- LIL BLUNT: Jack Hammer. Where will he be?
- ACCOMPLICE: The auction. He never misses one. He walks in to bid, or he walks in to take it. Depends who is selling.
- ACCOMPLICE: You want him, you get there before the doors open. It is a ride.

**4 STABLE** (Episode 2 surface stable; one stable hand)
- STABLE HAND: Heading for the auction? Nobody walks that trail.
- STABLE HAND: She is sound and she does not spook at gunfire. Half a coin and she is yours.
- (short of the tender) STABLE HAND: No coin, no horse. I do not take credit.
- (sold) STABLE HAND: She is yours. The trail runs out past the last lamp. Keep low and keep riding.

**5 TRAIL** - ride-and-shoot barks while they try to unhorse him: BANDIT: That is the rider! Get him off that horse! / Hammer's coin says he never reaches the auction! / Shoot the horse if you cannot hit the man!
Horse shot out from under him (fail branch, kept light): he goes on **on foot**; the arrival card changes.

**6 AUCTION** - arrival card: *THE AUCTION. JACK HAMMER IS EXPECTED.* (mounted) / *THE AUCTION - ON FOOT. THE HORSE DID NOT MAKE IT.* What happens inside is the next pass.

## Voice plan (when a key exists)
Sheriff: the town's Sheriff voice (see `ep2-sheriff-jake`). Accomplice: his jail voice. Stable hand + bandits: new, short. **Jack Hammer himself has no voice and no model yet** - the Doc leaves his full visual / VO open;
get the founder's reference art (`ep2-founder-intake`) before building anything he appears in. Files: `ep2_jh_<id>.ogg`, mono 64k (`ep2-voice-barks`).

## Founder rulings (2026-10-21) - these were open decisions 1 and 2
1. **Purse unit: ANSWERED.** One BTC coin face equals one Bitcoin. The horse takes ONE face and half a Bitcoin comes back as change (`Ep2JackHammer.HORSE_FACES_PAID = 1`, `HORSE_CHANGE_BTC = 0.5`, `Ep2JackHammerArc.buy_horse_with_face()`; the caller debits the face and credits the change).
2. **Where the auction is: ANSWERED.** A second settlement in the next town (`Ep2JackHammer.AUCTION_PLACE = "next_town"`): the trail ends at its edge. Still a bounded settlement, not a second open world.
3. **Jack Hammer's look: ANSWERED.** Mean, with an eye patch (`tools/ep2_blender/build_jack_hammer.py`, skill `ep2-jack-hammer-character`). Everything else about him (scar, sledgehammer, gold tooth...) is a proposal until the founder judges it.

## Still open (the founder's - recommended defaults are the code's, not canon)
3. What a horse shot out from under him costs (delay vs on foot vs retry).
4. Bounty pay on sighting vs capture vs Fort Knox; the XAUt handoff presentation (chest / certificate).
5. Jack Hammer's voice (his look is ruled: mean, eye patch).
