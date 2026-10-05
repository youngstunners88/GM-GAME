---
name: gm-game-quiz-protocol-only
description: "Write or rewrite the 11-question exams in the three education rooms (Smoke, Diamonds, Gold) so EVERY question teaches the protocol - never the game, room, examiner, quiz, video, whitepaper prop or scorecard. TRIGGER on any edit to src/protocol_portals/data/quiz_*.json, any new quiz, or when the founder says a question is useless / irrelevant / 'nothing to do with the protocol'."
---

# Why this exists
2026-10-02, founder (angry, twice): questions like "Who administers the test in the SMOKE room?", "Is the video study
path allowed?", "What happens when you pass in the SMOKE room?", "What kind of room is this?" were in the exams.
The quiz exists to make the player UNDERSTAND THE PROTOCOL. A question about the game itself teaches nothing.

# The rule
Every question and every answer option is about SMOKE, DIAMONDS or GOLD MINE mechanics: what a token does, where
value flows, how a lock/vest/burn/mint/stake works, what a pool pays. Nothing about rooms, examiners, props,
the quiz, the pass bar, the scorecard, stages or navigation. Wrong options must be plausible protocol mistakes
(a real-sounding wrong payout, a wrong duration), not jokes.

# Source of truth (never invent)
Only facts already taught in `src/protocol_portals/data/portal_copy.json` stops/aspects, or in the founder's
protocol updates in STATUS.md. Current facts:
- SMOKE: culture + sink token; 90% of original SMOKE converted to OFT SMOKE goes to the burn contract (the other 10% goes to the H420 buy-and-burn - the founder said NOT to mention that, it confuses people); five chains
  (Solana, Robinhood Chain, Ethereum, BASE, BSC), omni-chain, no wrapped copies; arb captured and recycled; main
  Lounge pairs X28 (BASE/Ethereum) and BNB (BSC); big BASE/Ethereum LP locked 10 years; Lounge hosts only the SMOKE NFT
  and bong parties. (SMOKE is NOT on PulseChain.)
- DIAMONDS: pays ETH; three independent ETH payout pools; only LP is X28; BLAZE on the mint path, emissions end in
  waves; Vault stakes Diamonds for shares; Crush Bonus forfeits Diamonds for more shares; Handler absorbs first-cycle
  mint-side Diamonds; Diamonds required to mint GOLD; sweeper bots send ETH to Diamond Certificate holders;
  NO auctions, NO NFTs.
- GOLD MINE: mine with ETH or ETH+Diamonds; ~100-day vest, ~1%/day, early claim forfeits unvested; Fort Knox stakes
  GOLD, locks up to 2,888 days, longer = more weight; stakers get TWO payouts on one share (wBTC from Fort Knox +
  XAUT from the Gold Vein, via sweeper bots); XAUT = Tether Gold; Melt Bonus burns up to 3x staked, multiplier up
  to 1,000%; NO auctions, NO NFTs.

# Process
1. Edit `quiz_<protocol>.json` (keep 11 questions, ids, `fact_id`, 3 options, `correct` index; vary the correct
   position - no more than 4 of 11 on one index).
2. Run the gate: `godot --headless --script res://tests/quiz_protocol_only_test.gd` (also runs in CI after the
   portal room test). It bans game-meta words and checks the count.
3. Run `portal_room_test` and `protocol_portals_test`.
4. If a protocol fact changes (founder update), change `portal_copy.json`, the voice clips and the quiz TOGETHER.
5. Ship via `scripts/ship-to-master.sh`; say live only after the itch deploy is green.
